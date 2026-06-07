// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PackedUserOperation — ERC-4337 v0.7 user operation
/// @notice Hand-written to match eth-infinitism v0.7.0 layout EXACTLY. Field order
///         is FIXED: the userOpHash binds these fields in this order, so reordering
///         silently breaks signature validation against the real EntryPoint.
/// @dev `accountGasLimits`: HIGH 128 bits = verificationGasLimit, LOW 128 = callGasLimit.
///      `gasFees`:          HIGH 128 bits = maxPriorityFeePerGas,  LOW 128 = maxFeePerGas.
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}
