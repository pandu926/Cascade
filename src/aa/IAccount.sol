// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PackedUserOperation} from "./PackedUserOperation.sol";

/// @title IAccount — ERC-4337 v0.7 account validation interface
/// @notice Matches eth-infinitism v0.7.0 IAccount. The EntryPoint calls
///         `validateUserOp` during the verification phase.
interface IAccount {
    /// @notice Validate a UserOperation's signature and pay any required prefund.
    /// @param userOp The operation being validated (its `signature` field is the proof).
    /// @param userOpHash Canonical hash (from EntryPoint) the signature is checked against.
    /// @param missingAccountFunds Amount the account must send to the EntryPoint as prefund.
    /// @return validationData 0 on a valid signature, 1 on failure (NEVER revert on a sig
    ///         mismatch — that would break EntryPoint simulation). Upper bytes may pack a
    ///         time range, unused here.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData);
}
