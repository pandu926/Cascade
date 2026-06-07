// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CascadeAccount} from "./CascadeAccount.sol";
import {IEntryPoint} from "./IEntryPoint.sol";

/// @title AccountFactory — CREATE2 deployer for CascadeAccount
/// @notice Proxy-free, deterministic deployment so an agent's account address is known
///         counterfactually (before deploy). `createAccount` is idempotent; the same
///         (owner, salt) always maps to one address — the EntryPoint's initCode path
///         relies on this exact determinism.
contract AccountFactory {
    IEntryPoint public immutable entryPoint;

    /// @notice Deploy the factory bound to a fixed EntryPoint.
    /// @param _entryPoint The EntryPoint wired into every account this factory deploys.
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }

    /// @notice Deploy (or return the existing) CascadeAccount for (owner, salt).
    /// @dev Idempotent: if code already exists at the counterfactual address, returns it
    ///      without redeploying or reverting (AA10-safe for repeated initCode).
    /// @param owner The ECDSA owner key the account will trust.
    /// @param salt CREATE2 salt selecting one of many accounts for the same owner.
    /// @return The deployed (or pre-existing) account address.
    function createAccount(address owner, uint256 salt) public returns (address) {
        address predicted = getAddress(owner, salt);
        if (predicted.code.length > 0) {
            return predicted;
        }
        return address(new CascadeAccount{salt: bytes32(salt)}(entryPoint, owner));
    }

    /// @notice Counterfactual CREATE2 address for (owner, salt) — equals the deploy address.
    /// @param owner The ECDSA owner key the account would trust.
    /// @param salt CREATE2 salt selecting one of many accounts for the same owner.
    /// @return The deterministic address `createAccount(owner, salt)` resolves to.
    function getAddress(address owner, uint256 salt) public view returns (address) {
        bytes32 codeHash = keccak256(abi.encodePacked(type(CascadeAccount).creationCode, abi.encode(entryPoint, owner)));
        return
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), codeHash)))));
    }
}
