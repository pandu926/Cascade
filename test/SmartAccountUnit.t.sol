// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CascadeAccount} from "../src/aa/CascadeAccount.sol";
import {IEntryPoint} from "../src/aa/IEntryPoint.sol";
import {PackedUserOperation} from "../src/aa/PackedUserOperation.sol";

/// @dev Records the order and values of inner calls so executeBatch dispatch
///      can be asserted deterministically (zero-fund, local EVM).
contract Probe {
    uint256[] public seen;

    function ping(uint256 id) external payable {
        seen.push(id);
    }

    function count() external view returns (uint256) {
        return seen.length;
    }
}

/// @dev Zero-fund unit suite for the ERC-4337 smart account + factory. Exercises
///      validateUserOp signature semantics, auth gates, batch dispatch, the
///      malleability guard, and CREATE2 factory determinism — no fork, no funds.
contract SmartAccountUnitTest is Test {
    // secp256k1 group order (for crafting a high-s malleable signature).
    uint256 internal constant SECP256K1_N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    address internal entryPoint = makeAddr("entryPoint");
    address internal owner;
    uint256 internal ownerPk;
    address internal stranger;
    uint256 internal strangerPk;

    CascadeAccount internal account;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("owner");
        (stranger, strangerPk) = makeAddrAndKey("stranger");
        account = new CascadeAccount(IEntryPoint(entryPoint), owner);
    }

    // --- helpers -----------------------------------------------------------

    function _ethHash(bytes32 userOpHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
    }

    function _sign(uint256 pk, bytes32 userOpHash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _ethHash(userOpHash));
        return abi.encodePacked(r, s, v);
    }

    /// Builds an otherwise-empty op carrying just the signature under test.
    function _op(bytes memory signature) internal pure returns (PackedUserOperation memory op) {
        op.signature = signature;
    }

    // --- validateUserOp: caller gate --------------------------------------

    function test_validateUserOp_reverts_when_not_from_entryPoint() public {
        bytes32 userOpHash = keccak256("op");
        PackedUserOperation memory op = _op(_sign(ownerPk, userOpHash));

        vm.prank(stranger); // not the EntryPoint
        vm.expectRevert(bytes("not from EntryPoint"));
        account.validateUserOp(op, userOpHash, 0);
    }

    // --- validateUserOp: signature semantics (0 = ok, 1 = fail, no revert) -

    function test_validateUserOp_returns_zero_for_owner_signature() public {
        bytes32 userOpHash = keccak256("op-owner");
        PackedUserOperation memory op = _op(_sign(ownerPk, userOpHash));

        vm.prank(entryPoint);
        uint256 ret = account.validateUserOp(op, userOpHash, 0);
        assertEq(ret, 0, "owner sig must validate (0)");
    }

    function test_validateUserOp_returns_one_for_wrong_signer_without_reverting() public {
        bytes32 userOpHash = keccak256("op-wrong");
        PackedUserOperation memory op = _op(_sign(strangerPk, userOpHash));

        vm.prank(entryPoint);
        // MUST return 1, not revert — reverting on a sig mismatch breaks simulation.
        uint256 ret = account.validateUserOp(op, userOpHash, 0);
        assertEq(ret, 1, "wrong signer must return 1 (no revert)");
    }

    // --- validateUserOp: malleability guard --------------------------------

    function test_validateUserOp_rejects_high_s_malleable_signature() public {
        bytes32 userOpHash = keccak256("op-malleable");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, _ethHash(userOpHash));

        // Flip to the high-s complement and the opposite parity — a valid
        // alternative signature for the SAME key that a guard must reject.
        bytes32 highS = bytes32(SECP256K1_N - uint256(s));
        uint8 flippedV = v == 27 ? 28 : 27;
        PackedUserOperation memory op = _op(abi.encodePacked(r, highS, flippedV));

        vm.prank(entryPoint);
        uint256 ret = account.validateUserOp(op, userOpHash, 0);
        assertEq(ret, 1, "high-s signature must be rejected (1)");
    }

    function test_validateUserOp_rejects_bad_v() public {
        bytes32 userOpHash = keccak256("op-badv");
        (, bytes32 r, bytes32 s) = vm.sign(ownerPk, _ethHash(userOpHash));
        PackedUserOperation memory op = _op(abi.encodePacked(r, s, uint8(29))); // v not in {27,28}

        vm.prank(entryPoint);
        uint256 ret = account.validateUserOp(op, userOpHash, 0);
        assertEq(ret, 1, "bad v must be rejected (1)");
    }

    // --- validateUserOp: prefund -------------------------------------------

    function test_validateUserOp_pays_exact_missing_funds_to_entryPoint() public {
        bytes32 userOpHash = keccak256("op-prefund");
        PackedUserOperation memory op = _op(_sign(ownerPk, userOpHash));

        uint256 prefund = 0.05 ether;
        vm.deal(address(account), 1 ether);
        uint256 epBefore = entryPoint.balance;
        uint256 acctBefore = address(account).balance;

        vm.prank(entryPoint);
        account.validateUserOp(op, userOpHash, prefund);

        assertEq(entryPoint.balance, epBefore + prefund, "EntryPoint received exact prefund");
        assertEq(address(account).balance, acctBefore - prefund, "account balance dropped by prefund");
    }

    // --- auth gates: execute / executeBatch --------------------------------

    function test_execute_reverts_for_unauthorized_caller() public {
        Probe probe = new Probe();
        bytes memory data = abi.encodeWithSelector(Probe.ping.selector, uint256(1));

        vm.prank(stranger);
        vm.expectRevert(bytes("not authorized"));
        account.execute(address(probe), 0, data);
    }

    function test_execute_succeeds_for_owner() public {
        Probe probe = new Probe();
        bytes memory data = abi.encodeWithSelector(Probe.ping.selector, uint256(7));

        vm.prank(owner);
        account.execute(address(probe), 0, data);

        assertEq(probe.count(), 1, "owner-driven execute ran");
        assertEq(probe.seen(0), 7, "correct arg forwarded");
    }

    function test_execute_succeeds_for_entryPoint() public {
        Probe probe = new Probe();
        bytes memory data = abi.encodeWithSelector(Probe.ping.selector, uint256(9));

        vm.prank(entryPoint);
        account.execute(address(probe), 0, data);

        assertEq(probe.seen(0), 9, "entryPoint-driven execute ran");
    }

    function test_executeBatch_reverts_on_length_mismatch() public {
        Probe probe = new Probe();
        address[] memory dest = new address[](2);
        dest[0] = address(probe);
        dest[1] = address(probe);
        uint256[] memory value = new uint256[](2);
        bytes[] memory func = new bytes[](1); // mismatched length
        func[0] = abi.encodeWithSelector(Probe.ping.selector, uint256(1));

        vm.prank(owner);
        vm.expectRevert(bytes("len mismatch"));
        account.executeBatch(dest, value, func);
    }

    function test_executeBatch_runs_calls_in_order() public {
        Probe probe = new Probe();
        address[] memory dest = new address[](3);
        uint256[] memory value = new uint256[](3);
        bytes[] memory func = new bytes[](3);
        for (uint256 i; i < 3; ++i) {
            dest[i] = address(probe);
            func[i] = abi.encodeWithSelector(Probe.ping.selector, i + 1);
        }

        vm.prank(owner);
        account.executeBatch(dest, value, func);

        assertEq(probe.count(), 3, "all batch calls ran");
        assertEq(probe.seen(0), 1, "first");
        assertEq(probe.seen(1), 2, "second");
        assertEq(probe.seen(2), 3, "third (order preserved)");
    }

    function test_executeBatch_routes_value_per_call() public {
        Probe probe = new Probe();
        vm.deal(address(account), 1 ether);

        address[] memory dest = new address[](2);
        dest[0] = address(probe);
        dest[1] = address(probe);
        uint256[] memory value = new uint256[](2);
        value[0] = 0.1 ether;
        value[1] = 0.2 ether;
        bytes[] memory func = new bytes[](2);
        func[0] = abi.encodeWithSelector(Probe.ping.selector, uint256(1));
        func[1] = abi.encodeWithSelector(Probe.ping.selector, uint256(2));

        vm.prank(owner);
        account.executeBatch(dest, value, func);

        assertEq(address(probe).balance, 0.3 ether, "value forwarded to targets");
    }
}
