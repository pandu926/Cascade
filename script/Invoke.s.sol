// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Cascade} from "../src/Cascade.sol";

/// @notice Pays for and invokes a skill, fanning the payment up its declared tree.
/// @dev Reads from the environment:
///        CASCADE      - deployed Cascade address
///        SKILL_ID     - id of the skill to invoke
///        INVOKE_VALUE - exact wei to send (must equal the skill's registered price)
///      Cascade enforces exact payment (`msg.value == price`), so INVOKE_VALUE must
///      match the price set at registration. Network via `--rpc-url`; signer via PRIVATE_KEY.
contract InvokeScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        Cascade cascade = Cascade(vm.envAddress("CASCADE"));
        uint256 skillId = vm.envUint("SKILL_ID");
        uint256 value = vm.envUint("INVOKE_VALUE");

        vm.startBroadcast(pk);
        cascade.invoke{value: value}(skillId);
        vm.stopBroadcast();

        console2.log("Invoked skill id:", skillId);
        console2.log("  paid (wei):", value);
    }
}
