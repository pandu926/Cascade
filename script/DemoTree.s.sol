// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";

/// @notice The killer-demo driver: register an A->B->C tree, invoke C once, and show
///         three distinct creator balances rise in a single transaction.
/// @dev Demo numbers are IDENTICAL to test/Demo.fork.t.sol so the live run reproduces
///      the locally-proven result. Creator/payer keys default to the standard anvil
///      mnemonic (so a local `anvil` run is fully funded with zero testnet funds) and
///      can be overridden via env for the live wave (01-03) — only flags/env differ,
///      never the code. RPC is resolved via `--rpc-url`.
contract DemoTreeScript is Script {
    // --- demo constants (keep in lockstep with test/Demo.fork.t.sol) -------
    uint256 internal constant PRICE_C = 0.001 ether; // small: fits the ~0.01 PHRS live budget
    uint256 internal constant SHARE_C_TO_B = 5000; // 50% of C's payment flows into B's subtree
    uint256 internal constant SHARE_B_TO_A = 4000; // 40% of B's slice flows into A's subtree

    // Standard Foundry/anvil test mnemonic — its first accounts are pre-funded on anvil.
    string internal constant DEFAULT_MNEMONIC =
        "test test test test test test test test test test test junk";

    function _empty() internal pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _one(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    /// @dev env key if present, else the anvil-default derived key at `idx`.
    function _key(string memory envName, uint32 idx) internal view returns (uint256) {
        return vm.envOr(envName, vm.deriveKey(DEFAULT_MNEMONIC, idx));
    }

    function run() external {
        uint256 aKey = _key("CREATOR_A_KEY", 0);
        uint256 bKey = _key("CREATOR_B_KEY", 1);
        uint256 cKey = _key("CREATOR_C_KEY", 2);
        uint256 payerKey = _key("PRIVATE_KEY", 3);

        address creatorA = vm.addr(aKey);
        address creatorB = vm.addr(bKey);
        address creatorC = vm.addr(cKey);

        // Reuse an already-deployed Cascade if CASCADE is set; else deploy a fresh one.
        Cascade cascade;
        address existing = vm.envOr("CASCADE", address(0));
        if (existing == address(0)) {
            vm.startBroadcast(payerKey);
            cascade = new Cascade();
            vm.stopBroadcast();
            console2.log("Deployed Cascade at:", address(cascade));
        } else {
            cascade = Cascade(existing);
            console2.log("Using existing Cascade at:", existing);
        }

        // Register the A->B->C tree, each from a distinct creator.
        vm.startBroadcast(aKey);
        uint256 idA = cascade.register(0, _empty(), _empty()); // leaf
        vm.stopBroadcast();

        vm.startBroadcast(bKey);
        uint256 idB = cascade.register(0, _one(idA), _one(SHARE_B_TO_A));
        vm.stopBroadcast();

        vm.startBroadcast(cKey);
        uint256 idC = cascade.register(PRICE_C, _one(idB), _one(SHARE_C_TO_B));
        vm.stopBroadcast();

        console2.log("Registered tree  A:", idA);
        console2.log("                 B:", idB);
        console2.log("                 C:", idC);

        // Balances BEFORE the invoke.
        uint256 a0 = cascade.balances(creatorA);
        uint256 b0 = cascade.balances(creatorB);
        uint256 c0 = cascade.balances(creatorC);
        console2.log("--- balances BEFORE (wei) ---");
        console2.log("  creatorA:", a0);
        console2.log("  creatorB:", b0);
        console2.log("  creatorC:", c0);

        // ONE paid invoke of C fans royalties up the whole tree.
        vm.startBroadcast(payerKey);
        cascade.invoke{value: PRICE_C}(idC);
        vm.stopBroadcast();

        // Balances AFTER + deltas — three distinct creators rise in one tx.
        uint256 a1 = cascade.balances(creatorA);
        uint256 b1 = cascade.balances(creatorB);
        uint256 c1 = cascade.balances(creatorC);
        console2.log("--- balances AFTER (wei) ---");
        console2.log("  creatorA:", a1);
        console2.log("  creatorB:", b1);
        console2.log("  creatorC:", c1);
        console2.log("--- deltas (wei) ---");
        console2.log("  creatorA +", a1 - a0);
        console2.log("  creatorB +", b1 - b0);
        console2.log("  creatorC +", c1 - c0);
        console2.log("  total    +", (a1 - a0) + (b1 - b0) + (c1 - c0));
    }
}
