// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";

/// @notice Deploys the Cascade registry/router and prints its address.
/// @dev Network is chosen at run time via `--rpc-url` (e.g. `--rpc-url atlantic_testnet`).
///      Signing key is read from the `PRIVATE_KEY` env var (gitignored `.env`); it is
///      never logged. Add `--broadcast` to send the tx live (done in wave 01-03).
contract DeployScript is Script {
    function run() external returns (Cascade cascade) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        cascade = new Cascade();
        vm.stopBroadcast();

        console2.log("Cascade deployed at:", address(cascade));
    }
}
