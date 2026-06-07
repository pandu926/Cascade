// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";

/// @notice Withdraws the caller's accrued royalty balance (pull-payment).
/// @dev Reads CASCADE (deployed address) from the environment. The caller is the
///      `PRIVATE_KEY` signer; whatever has accrued to that address is transferred out.
///      Network via `--rpc-url`; signer via PRIVATE_KEY.
contract ClaimScript is Script {
    function run() external returns (uint256 amount) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Cascade cascade = Cascade(vm.envAddress("CASCADE"));

        address claimant = vm.addr(pk);
        uint256 accrued = cascade.balances(claimant);
        console2.log("Accrued before claim (wei):", accrued);

        vm.startBroadcast(pk);
        amount = cascade.claim();
        vm.stopBroadcast();

        console2.log("Claimed (wei):", amount);
    }
}
