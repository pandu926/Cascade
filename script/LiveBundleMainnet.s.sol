// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";
import {CascadeAccount} from "../src/aa/CascadeAccount.sol";
import {AccountFactory} from "../src/aa/AccountFactory.sol";
import {IEntryPoint} from "../src/aa/IEntryPoint.sol";
import {PackedUserOperation} from "../src/aa/PackedUserOperation.sol";

/// @title LiveBundleMainnet — GATED live ERC-4337 v0.7 batch demo on Pharos MAINNET.
/// @notice Mainnet-guarded sibling of script/LiveBundle.s.sol (which is FROZEN to
///         atlantic-testnet, chainId 688689). This script is HARD-guarded to mainnet
///         (chainId 1672) and REFUSES to broadcast on any other chain — the testnet
///         guard is intentionally left untouched (immutability + don't weaken a safety
///         guard). It reuses LiveBundle's EXACT, fork-proven v0.7 build/sign/handleOps
///         mechanics (_buildSignedOp, _batchInvoke, _pack) verbatim.
/// @dev FLOW (factory-preferred per 05-CONTEXT, proving AA-01 live on mainnet):
///        1. PRE-FLIGHT BUDGET GATE runs FIRST — STOPS CLEANLY (revert, no broadcast)
///           if the estimated live cost exceeds the funded EOA balance. Never half-spends.
///        2. Deploy AccountFactory(ep) — or reuse a prior one via env FACTORY (retry-safe).
///        3. factory.createAccount(broadcaster, salt) — deterministic CREATE2 account whose
///           owner == broadcaster EOA (so the broadcaster key signs valid UserOps).
///        4. Fund the account just enough (prefund + the two invoke values) — funds only the
///           shortfall, so a re-run after a handleOps revert never double-funds.
///        5. Build ONE PackedUserOperation: callData = executeBatch([cascade,cascade],
///           [price1,price2],[invoke(id1),invoke(id2)]); sign the eth-signed-prefixed
///           getUserOpHash with the owner key; EOA self-bundles via ep.handleOps([op], EOA).
///
///      The account is deployed via a normal createAccount tx, so the UserOp's initCode is
///      EMPTY (account already exists) — identical to LiveBundle's proven empty-initCode op.
///
///      CASCADE address is read from env (the 05-01 mainnet deployment) — never hardcoded.
///      The two batched skills + their exact prices are read from env (Cascade.skills is
///      internal — no on-chain getter); Cascade enforces msg.value == price as the fail-safe.
///
///      Secrets: PRIVATE_KEY is read from env ONLY and is NEVER echoed. Owner == broadcaster.
contract LiveBundleMainnetScript is Script {
    // --- Canonical EntryPoint v0.7 (SAME singleton on mainnet, orchestrator-confirmed) ---
    address internal constant EP_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /// @dev Pharos mainnet chainId. The hard guard refuses to broadcast anywhere else.
    uint256 internal constant MAINNET_CHAIN_ID = 1672;

    // --- Gas estimates (upper bounds; mirror LiveBundle) -------------------
    /// @dev Factory deploy tx.
    uint256 internal constant FACTORY_DEPLOY_GAS = 700_000;
    /// @dev createAccount (CREATE2 deploy of the account).
    uint256 internal constant ACCOUNT_DEPLOY_GAS = 500_000;
    /// @dev The EOA's handleOps tx: validation + 2-call executeBatch + 2 invoke trees.
    uint256 internal constant HANDLEOPS_GAS = 600_000;

    // --- UserOp gas fields (empty initCode — account pre-deployed, light validation) -
    uint128 internal constant VERIFICATION_GAS_LIMIT = 200_000;
    uint128 internal constant CALL_GAS_LIMIT = 400_000;
    uint256 internal constant PRE_VERIFICATION_GAS = 80_000;

    struct LiveParams {
        uint256 pk;
        address broadcaster;
        address cascade;
        uint256 gasPriceWei;
        uint256 salt;
        uint256 nativeValueNeeded;
        uint256 id1;
        uint256 id2;
        uint256 price1;
        uint256 price2;
    }

    function run() external {
        // --- inputs (env-driven; never echo PRIVATE_KEY). Assembled directly into
        //     the params struct to keep run()'s stack shallow. --------------------
        LiveParams memory p;
        p.pk = vm.envUint("PRIVATE_KEY");
        p.broadcaster = vm.addr(p.pk);
        // The mainnet Cascade (05-01) — REQUIRED from env, never hardcoded.
        p.cascade = vm.envAddress("CASCADE");
        // Observed mainnet floor is 10 gwei; override via env if it changes.
        p.gasPriceWei = vm.envOr("GAS_PRICE_WEI", uint256(10 gwei));
        // CREATE2 salt selecting the account (default 0).
        p.salt = vm.envOr("SALT", uint256(0));
        // The two EXISTING live skills to batch. Defaults: id2 = B (price 0) and
        // id3 = C (price 0.001 ether) from 05-02. C's fan-out raises both B's and C's
        // creators; invoke(B) at value 0 emits the second Invoked event.
        p.id1 = vm.envOr("SKILL_ID_1", uint256(2));
        p.id2 = vm.envOr("SKILL_ID_2", uint256(3));
        p.price1 = vm.envOr("PRICE_1", uint256(0));
        p.price2 = vm.envOr("PRICE_2", uint256(0.001 ether));

        // The account must hold: prefund (refunded post-op) + the two invoke values.
        uint256 opGas = uint256(VERIFICATION_GAS_LIMIT) + uint256(CALL_GAS_LIMIT) + PRE_VERIFICATION_GAS;
        p.nativeValueNeeded = (opGas * p.gasPriceWei) + p.price1 + p.price2;

        _gateAndBroadcast(p);
    }

    /// @dev Pre-flight budget gate (runs FIRST, STOPS CLEANLY on shortfall — never a
    ///      half-spend) then, only if it fits, the hard-guarded live broadcast.
    function _gateAndBroadcast(LiveParams memory p) internal {
        uint256 balance = p.broadcaster.balance;
        // The EOA pays its own factory deploy + createAccount + handleOps tx gas out of pocket.
        uint256 eoaGasCost = (FACTORY_DEPLOY_GAS + ACCOUNT_DEPLOY_GAS + HANDLEOPS_GAS) * p.gasPriceWei;
        uint256 estimatedTotal = eoaGasCost + p.nativeValueNeeded;

        console2.log("=== LiveBundleMainnet PRE-FLIGHT budget gate ===");
        console2.log("  chainId:", block.chainid);
        console2.log("  broadcaster:", p.broadcaster);
        console2.log("  cascade:", p.cascade);
        console2.log("  balance (wei):", balance);
        console2.log("  gas price (wei):", p.gasPriceWei);
        console2.log("  est EOA gas cost (wei):", eoaGasCost);
        console2.log("  required native value prefund+p1+p2 (wei):", p.nativeValueNeeded);
        console2.log("  estimated TOTAL (wei):", estimatedTotal);

        if (estimatedTotal > balance) {
            console2.log("  >>> LIVE BLOCKED: estimate exceeds balance. NO broadcast. <<<");
            console2.log("  shortfall (wei):", estimatedTotal - balance);
            // STOP CLEANLY — never half-spend.
            revert("LIVE BLOCKED: estimated cost exceeds balance; top up the broadcaster EOA");
        }

        // Refuse to ever target anything but Pharos mainnet.
        require(block.chainid == MAINNET_CHAIN_ID, "wrong chainId: refusing to broadcast");

        _execute(p);
    }

    function _execute(LiveParams memory p) internal {
        IEntryPoint ep = IEntryPoint(EP_ADDR);

        vm.startBroadcast(p.pk);

        // Deploy (or reuse) the factory — proving AA-01 live on mainnet.
        AccountFactory factory;
        address factoryEnv = vm.envOr("FACTORY", address(0));
        if (factoryEnv != address(0) && factoryEnv.code.length > 0) {
            factory = AccountFactory(factoryEnv);
        } else {
            factory = new AccountFactory(ep);
        }

        // Deterministic account; owner = broadcaster so the broadcaster key signs valid ops.
        // createAccount is idempotent — safe to call again on a retry.
        address account = factory.createAccount(p.broadcaster, p.salt);

        // Fund the account ONLY for the shortfall: prefund + the two invoke values.
        // Funding the delta keeps a re-run (after a handleOps revert) from double-funding.
        if (account.balance < p.nativeValueNeeded) {
            uint256 topUp = p.nativeValueNeeded - account.balance;
            (bool funded,) = payable(account).call{value: topUp}("");
            require(funded, "account funding failed");
        }

        // Build + sign the batched op, then self-bundle it through the real EntryPoint.
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildSignedOp(ep, account, p);

        // ONE self-bundled handleOps; the broadcaster is the fee beneficiary.
        ep.handleOps(ops, payable(p.broadcaster));

        vm.stopBroadcast();

        console2.log("=== LIVE SETTLED ===");
        console2.log("  EntryPoint:", EP_ADDR);
        console2.log("  Cascade:", p.cascade);
        console2.log("  factory:", address(factory));
        console2.log("  account:", account);
        console2.log("  factory.getAddress (determinism check):", factory.getAddress(p.broadcaster, p.salt));
        console2.log("  invoked skill id 1:", p.id1);
        console2.log("  invoked skill id 2:", p.id2);
    }

    /// @dev Build a fully-packed op and sign the eth-signed-prefixed `getUserOpHash`
    ///      (authoritative hash from the real EntryPoint). Mirrors the fork-proven flow.
    function _buildSignedOp(IEntryPoint ep, address sender, LiveParams memory p)
        internal
        view
        returns (PackedUserOperation memory op)
    {
        op = PackedUserOperation({
            sender: sender,
            nonce: ep.getNonce(sender, 0),
            initCode: "", // account already deployed via createAccount — no initCode
            callData: _batchInvoke(p.cascade, p.id1, p.id2, p.price1, p.price2),
            accountGasLimits: _pack(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: PRE_VERIFICATION_GAS,
            gasFees: _pack(uint128(p.gasPriceWei), uint128(p.gasPriceWei)), // legacy-safe: maxFee == maxPriority
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = ep.getUserOpHash(op);
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(p.pk, ethHash);
        op.signature = abi.encodePacked(r, s, v);
    }

    // --- helpers -----------------------------------------------------------

    /// @dev Pack two uint128s high|low per the v0.7 layout.
    function _pack(uint128 high, uint128 low) internal pure returns (bytes32) {
        return bytes32((uint256(high) << 128) | uint256(low));
    }

    /// @dev callData = executeBatch([cascade,cascade],[p1,p2],[invoke(id1),invoke(id2)]).
    ///      Targets the EXISTING live skills — no re-registration anywhere.
    function _batchInvoke(address cascade, uint256 id1, uint256 id2, uint256 price1, uint256 price2)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory dest = new address[](2);
        dest[0] = cascade;
        dest[1] = cascade;
        uint256[] memory val = new uint256[](2);
        val[0] = price1;
        val[1] = price2;
        bytes[] memory fn = new bytes[](2);
        fn[0] = abi.encodeWithSelector(Cascade.invoke.selector, id1);
        fn[1] = abi.encodeWithSelector(Cascade.invoke.selector, id2);
        return abi.encodeWithSelector(CascadeAccount.executeBatch.selector, dest, val, fn);
    }
}
