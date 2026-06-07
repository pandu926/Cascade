// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";
import {CascadeAccount} from "../src/aa/CascadeAccount.sol";
import {IEntryPoint} from "../src/aa/IEntryPoint.sol";
import {PackedUserOperation} from "../src/aa/PackedUserOperation.sol";

/// @title LiveBundle — GATED, OPTIONAL live ERC-4337 v0.7 batch demo on atlantic-testnet.
/// @notice Bonus on-chain evidence: deploy a CascadeAccount live, fund it minimally, and
///         submit ONE self-bundled `handleOps` that batches TWO `invoke`s of the EXISTING
///         live Cascade skills (skillCount stays 3 — NO re-registration) through the real
///         EntryPoint v0.7. AA-01/02/03 are ALREADY proven by the Wave 2 fork test against
///         the real EntryPoint; this script is bonus and may be budget-blocked at 10 gwei.
/// @dev THE PRE-FLIGHT GATE RUNS FIRST and STOPS CLEANLY (revert, no broadcast) if the
///      estimated live cost (gas × price + required native value) exceeds the funded EOA
///      balance — never a half-spend. Only if it fits does it deploy + bundle.
///
///      Footprint-shrink (03-RESEARCH §8 mitigation 3): the account is deployed DIRECTLY
///      (`new CascadeAccount`) — the factory is skipped for the live step (its path is
///      already proven on the fork) — so initCode is empty and the heaviest cost is cut.
///
///      Price sourcing: `Cascade.skills` is `internal` (no public price getter), so the two
///      target skill prices are read from env (PRICE_1/PRICE_2) with the known live A->B->C
///      demo defaults rather than on-chain — the same constraint 03-02 documented. Cascade
///      still enforces `msg.value == price` on-chain (fail-safe: a wrong value reverts).
///
///      Secrets: PRIVATE_KEY is read from env ONLY and is NEVER echoed. The signer/owner of
///      the account is the broadcaster EOA derived from PRIVATE_KEY.
contract LiveBundleScript is Script {
    // --- Live, VERIFIED constants on atlantic-testnet (chainId 688689) -------
    address internal constant EP_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address internal constant CASCADE_ADDR = 0xd41C32562D0BE20D354120E1De11A91abC340F50;
    /// @dev Funded self-bundling EOA / top-up target.
    address internal constant TOPUP_ADDR = 0x67680b09bB422cC510669bd5208D947066D4aeaE;
    uint256 internal constant ATLANTIC_CHAIN_ID = 688689;

    // --- Gas estimates (upper bounds from 03-RESEARCH §8) -------------------
    /// @dev Direct `new CascadeAccount` deploy tx (vs the heavier factory path).
    uint256 internal constant ACCOUNT_DEPLOY_GAS = 500_000;
    /// @dev The EOA's `handleOps` tx: validation + 2-call executeBatch + 2 invoke trees.
    uint256 internal constant HANDLEOPS_GAS = 600_000;

    // --- UserOp gas fields (no initCode now — direct deploy, so validation is light) -
    uint128 internal constant VERIFICATION_GAS_LIMIT = 200_000;
    uint128 internal constant CALL_GAS_LIMIT = 400_000;
    uint256 internal constant PRE_VERIFICATION_GAS = 80_000;

    function run() external {
        // --- inputs (env-driven; never echo PRIVATE_KEY) --------------------
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address broadcaster = vm.addr(pk);

        // Default 1 gwei (the hoped-for price); override via env to reflect the
        // price the node/forge will actually use (observed floor is 10 gwei).
        uint256 gasPriceWei = vm.envOr("GAS_PRICE_WEI", uint256(1 gwei));

        // The two EXISTING live skills to batch. Defaults: A->B->C demo tree
        // (id1 = A, price 0) and (id3 = C, price 0.001 ether). NO re-registration.
        uint256 id1 = vm.envOr("SKILL_ID_1", uint256(1));
        uint256 id2 = vm.envOr("SKILL_ID_2", uint256(3));
        // Prices read from env (Cascade.skills is internal — no on-chain getter).
        uint256 price1 = vm.envOr("PRICE_1", uint256(0));
        uint256 price2 = vm.envOr("PRICE_2", uint256(0.001 ether));

        uint256 balance = broadcaster.balance;

        // --- PRE-FLIGHT BUDGET GATE (runs FIRST, before any broadcast) ------
        // EntryPoint will demand a prefund covering this op's gas at gasPriceWei.
        uint256 opGas = uint256(VERIFICATION_GAS_LIMIT) + uint256(CALL_GAS_LIMIT) + PRE_VERIFICATION_GAS;
        uint256 prefund = opGas * gasPriceWei;
        // The account must hold: prefund (refunded post-op) + the two invoke values.
        uint256 nativeValueNeeded = prefund + price1 + price2;
        // The EOA pays its own deploy tx + handleOps tx gas out of pocket.
        uint256 eoaGasCost = (ACCOUNT_DEPLOY_GAS + HANDLEOPS_GAS) * gasPriceWei;
        uint256 estimatedTotal = eoaGasCost + nativeValueNeeded;

        console2.log("=== LiveBundle PRE-FLIGHT budget gate ===");
        console2.log("  broadcaster:", broadcaster);
        console2.log("  balance (wei):", balance);
        console2.log("  gas price (wei):", gasPriceWei);
        console2.log("  est EOA gas cost (wei):", eoaGasCost);
        console2.log("  required native value prefund+p1+p2 (wei):", nativeValueNeeded);
        console2.log("  estimated TOTAL (wei):", estimatedTotal);

        if (estimatedTotal > balance) {
            uint256 shortfall = estimatedTotal - balance;
            console2.log("  >>> LIVE BLOCKED: estimate exceeds balance. NO broadcast. <<<");
            console2.log("  top up address:", TOPUP_ADDR);
            console2.log("  shortfall (wei):", shortfall);
            // STOP CLEANLY — never half-spend.
            revert("LIVE BLOCKED: top up 0x67680b09bB422cC510669bd5208D947066D4aeaE - estimated cost exceeds balance");
        }

        // --- IT FITS: proceed with the live broadcast -----------------------
        _broadcastLive(pk, broadcaster, gasPriceWei, nativeValueNeeded, id1, id2, price1, price2);
    }

    /// @dev The live broadcast path, factored out to keep `run()` under the EVM
    ///      stack-depth limit. Only reached when the pre-flight gate passes.
    function _broadcastLive(
        uint256 pk,
        address broadcaster,
        uint256 gasPriceWei,
        uint256 nativeValueNeeded,
        uint256 id1,
        uint256 id2,
        uint256 price1,
        uint256 price2
    ) internal {
        // Refuse to ever target mainnet.
        require(block.chainid == ATLANTIC_CHAIN_ID, "wrong chainId: refusing to broadcast");

        IEntryPoint ep = IEntryPoint(EP_ADDR);

        vm.startBroadcast(pk);

        // Deploy the account DIRECTLY (skip the factory — §8 footprint-shrink).
        // Owner = broadcaster, so the broadcaster key signs valid UserOps.
        CascadeAccount account = new CascadeAccount(ep, broadcaster);

        // Fund the account minimally: prefund + the two invoke values.
        (bool funded,) = payable(address(account)).call{value: nativeValueNeeded}("");
        require(funded, "account funding failed");

        // Build + sign the batched op, then self-bundle it through the real EntryPoint.
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildSignedOp(ep, address(account), pk, gasPriceWei, id1, id2, price1, price2);

        // ONE self-bundled handleOps; the broadcaster is the fee beneficiary.
        ep.handleOps(ops, payable(broadcaster));

        vm.stopBroadcast();

        console2.log("=== LIVE SETTLED ===");
        console2.log("  EntryPoint:", EP_ADDR);
        console2.log("  Cascade:", CASCADE_ADDR);
        console2.log("  account:", address(account));
        console2.log("  invoked skill id 1:", id1);
        console2.log("  invoked skill id 2:", id2);
    }

    /// @dev Build a fully-packed op and sign the eth-signed-prefixed `getUserOpHash`
    ///      (authoritative hash from the real EntryPoint). Mirrors the Wave 2 fork flow.
    function _buildSignedOp(
        IEntryPoint ep,
        address sender,
        uint256 pk,
        uint256 gasPriceWei,
        uint256 id1,
        uint256 id2,
        uint256 price1,
        uint256 price2
    ) internal returns (PackedUserOperation memory op) {
        op = PackedUserOperation({
            sender: sender,
            nonce: ep.getNonce(sender, 0),
            initCode: "", // account already deployed — no initCode
            callData: _batchInvoke(id1, id2, price1, price2),
            accountGasLimits: _pack(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: PRE_VERIFICATION_GAS,
            gasFees: _pack(uint128(gasPriceWei), uint128(gasPriceWei)), // legacy-safe: maxFee == maxPriority
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = ep.getUserOpHash(op);
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        op.signature = abi.encodePacked(r, s, v);
    }

    // --- helpers -----------------------------------------------------------

    /// @dev Pack two uint128s high|low per the v0.7 layout.
    function _pack(uint128 high, uint128 low) internal pure returns (bytes32) {
        return bytes32((uint256(high) << 128) | uint256(low));
    }

    /// @dev callData = executeBatch([cascade,cascade],[p1,p2],[invoke(id1),invoke(id2)]).
    ///      Targets the EXISTING live skills — no re-registration anywhere.
    function _batchInvoke(uint256 id1, uint256 id2, uint256 price1, uint256 price2)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory dest = new address[](2);
        dest[0] = CASCADE_ADDR;
        dest[1] = CASCADE_ADDR;
        uint256[] memory val = new uint256[](2);
        val[0] = price1;
        val[1] = price2;
        bytes[] memory fn = new bytes[](2);
        fn[0] = abi.encodeWithSelector(Cascade.invoke.selector, id1);
        fn[1] = abi.encodeWithSelector(Cascade.invoke.selector, id2);
        return abi.encodeWithSelector(CascadeAccount.executeBatch.selector, dest, val, fn);
    }
}
