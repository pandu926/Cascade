// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "./IAccount.sol";
import {IEntryPoint} from "./IEntryPoint.sol";
import {PackedUserOperation} from "./PackedUserOperation.sol";

/// @title CascadeAccount — minimal ERC-4337 v0.7 single-owner smart account
/// @notice A proxy-free, gas-lean account: owner-ECDSA `validateUserOp` + `execute`
///         and `executeBatch` so one UserOperation can pay multiple Cascade skills.
/// @dev Account-agnostic target (Cascade) only reads msg.sender/msg.value, so this
///      account is just another caller. Signature recovery is inline (no OZ in lib/)
///      with a malleability guard. validateUserOp returns 0/1 and NEVER reverts on a
///      signature mismatch — reverting there would break EntryPoint simulation.
contract CascadeAccount is IAccount {
    /// @dev v0.7.0 Helpers.sol: 0 = valid signature, 1 = failed.
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// @dev Half the secp256k1 group order. s values above this are the malleable
    ///      (high-s) complement and are rejected (EIP-2).
    uint256 internal constant SECP256K1_HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    IEntryPoint public immutable entryPoint;
    address public immutable owner;

    /// @notice Thrown when `execute`/`executeBatch` is called by neither the EntryPoint nor the owner.
    error NotAuthorized();

    /// @notice Thrown when `validateUserOp` is called by an address other than the EntryPoint.
    error NotFromEntryPoint();

    /// @notice Thrown when `executeBatch` receives dest/value/func arrays of unequal length.
    error LengthMismatch();

    /// @notice Deploy a single-owner ERC-4337 account.
    /// @param anEntryPoint The canonical EntryPoint singleton this account trusts.
    /// @param anOwner The ECDSA key authorized to sign UserOperations and call directly.
    constructor(IEntryPoint anEntryPoint, address anOwner) {
        entryPoint = anEntryPoint;
        owner = anOwner;
    }

    /// @dev Restricts a call to the trusted EntryPoint or the account owner.
    modifier onlyEntryPointOrOwner() {
        if (msg.sender != address(entryPoint) && msg.sender != owner) revert NotAuthorized();
        _;
    }

    /// @inheritdoc IAccount
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        if (msg.sender != address(entryPoint)) revert NotFromEntryPoint();

        bytes32 ethHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        validationData =
            _recover(ethHash, userOp.signature) == owner ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;

        _payPrefund(missingAccountFunds);
    }

    /// @notice Route a single call (EntryPoint or owner only).
    function execute(address dest, uint256 value, bytes calldata func)
        external
        onlyEntryPointOrOwner
    {
        _call(dest, value, func);
    }

    /// @notice Route N calls in order — the machinery one UserOp uses to pay many skills.
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
        external
        onlyEntryPointOrOwner
    {
        if (dest.length != func.length || value.length != func.length) revert LengthMismatch();
        for (uint256 i; i < dest.length; ++i) {
            _call(dest[i], value[i], func[i]);
        }
    }

    receive() external payable {}

    // --- internals ---------------------------------------------------------

    /// @dev Pay the EntryPoint exactly `missingAccountFunds`; ignore call success
    ///      on purpose — the EntryPoint verifies the payment itself (v0.7.0 BaseAccount).
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool ok,) = payable(msg.sender).call{value: missingAccountFunds}("");
            (ok); // silence: EntryPoint enforces prefund
        }
    }

    /// @dev Bubble up the inner revert reason verbatim.
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }
    }

    /// @dev Inline ECDSA recover with a malleability guard (no OZ dependency):
    ///      reject malformed length, high-s, v not in {27,28}, and zero-address recover.
    ///      Returns address(0) on any rejection so validation reports failure (never reverts).
    function _recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) return address(0);

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (uint256(s) > SECP256K1_HALF_N) return address(0);
        if (v != 27 && v != 28) return address(0);

        return ecrecover(hash, v, r, s); // address(0) on invalid sig
    }
}
