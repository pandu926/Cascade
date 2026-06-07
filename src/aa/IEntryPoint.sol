// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PackedUserOperation} from "./PackedUserOperation.sol";

/// @title IEntryPoint — minimal ERC-4337 v0.7 EntryPoint interface
/// @notice Only the surface this phase uses. Matches the canonical v0.7.0 EntryPoint
///         singleton deployed on Pharos at 0x0000000071727De22E5E9d8BAf0edAc6f37da032.
interface IEntryPoint {
    /// @notice Execute a batch of UserOperations (self-bundled by an EOA).
    /// @param ops The operations to run.
    /// @param beneficiary Address that receives the collected gas fees.
    function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;

    /// @notice Canonical hash an account validates its signature against.
    /// @dev Binds all fields except `signature`, plus this EntryPoint address and chainId.
    function getUserOpHash(PackedUserOperation calldata userOp) external view returns (bytes32);

    /// @notice Authoritative 2D nonce (192-bit key + 64-bit sequence) for `sender`.
    /// @param key The nonce key; 0 is the default sequence.
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    /// @notice Add to the deposit of `account` held by the EntryPoint.
    function depositTo(address account) external payable;

    /// @notice Deposit balance held by the EntryPoint for `account`.
    function balanceOf(address account) external view returns (uint256);
}
