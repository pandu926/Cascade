// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";

/// @notice Registers a skill on an already-deployed Cascade instance.
/// @dev Reads every parameter from the environment (no secrets logged):
///        CASCADE     - deployed Cascade address
///        PRICE       - invoke price in wei (may be 0 for a leaf skill)
///        DEP_IDS     - comma-separated dependency skill ids (optional, default empty)
///        DEP_SHARES  - comma-separated bps shares, aligned 1:1 with DEP_IDS (optional)
///      Network resolved via `--rpc-url`; signer via `PRIVATE_KEY`.
contract RegisterScript is Script {
    function run() external returns (uint256 id) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Cascade cascade = Cascade(vm.envAddress("CASCADE"));
        uint256 price = vm.envUint("PRICE");

        // Optional dependency arrays — default to empty (a leaf skill) when unset.
        uint256[] memory depIds = vm.envOr("DEP_IDS", ",", new uint256[](0));
        uint256[] memory depShares = vm.envOr("DEP_SHARES", ",", new uint256[](0));
        require(depIds.length == depShares.length, "DEP_IDS/DEP_SHARES length mismatch");

        vm.startBroadcast(pk);
        id = cascade.register(price, depIds, depShares);
        vm.stopBroadcast();

        console2.log("Registered skill id:", id);
        console2.log("  price (wei):", price);
        console2.log("  dependencies:", depIds.length);
    }
}
