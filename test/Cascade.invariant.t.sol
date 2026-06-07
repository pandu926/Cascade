// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Cascade} from "../src/Cascade.sol";
import {CascadeHandler} from "./handlers/CascadeHandler.sol";

/// @title CascadeInvariantTest — stateful proof of solvency + accounting closure
/// @notice Runs the bounded CascadeHandler through randomized sequences of
///         register/invoke/claim and, after every sequence, reconciles three
///         conservation properties against on-chain state and the handler's ghost
///         oracle:
///           1. solvency           — held balance always covers every claim,
///           2. no-wei-created      — held balance == paid-in - claimed,
///           3. accrued == paid     — outstanding accrued + claimed == paid-in.
///         Together these prove Cascade never creates or destroys wei across ANY
///         interleaving of its public actions.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract CascadeInvariantTest is Test {
    Cascade internal cascade;
    CascadeHandler internal handler;

    function setUp() public {
        cascade = new Cascade();
        handler = new CascadeHandler(cascade);

        // Drive only the handler; never call the raw Cascade ABI directly (its
        // unbounded register/invoke would revert constantly and the run would be
        // dominated by reverts rather than real state transitions).
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = CascadeHandler.register.selector;
        selectors[1] = CascadeHandler.invoke.selector;
        selectors[2] = CascadeHandler.claim.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @dev Sum of every roster actor's currently-claimable balance. The actor
    ///      roster is the complete creator universe, so this is total outstanding
    ///      accrued across the whole contract.
    function _sumOutstanding() internal view returns (uint256 total) {
        uint256 n = handler.actorCount();
        for (uint256 i; i < n; ++i) {
            total += cascade.balances(handler.actors(i));
        }
    }

    /// @notice Solvency: the contract can always honor every outstanding claim —
    ///         its held native balance is never less than the sum of claimable
    ///         balances. (No payee can ever be left short.)
    function invariant_solvency() public view {
        assertGe(address(cascade).balance, _sumOutstanding(), "insolvent: held < outstanding claims");
    }

    /// @notice No wei created or destroyed: the held balance is exactly everything
    ///         ever paid in minus everything ever claimed out.
    function invariant_no_wei_created() public view {
        assertEq(
            address(cascade).balance,
            handler.ghost_totalPaidIn() - handler.ghost_totalClaimed(),
            "held balance != paidIn - claimed (wei created/destroyed)"
        );
    }

    /// @notice Accounting closure: outstanding accrued plus already-claimed equals
    ///         total paid in — every incoming wei is accounted for as either still
    ///         claimable or already withdrawn, never lost and never duplicated.
    function invariant_accrued_equals_paid() public view {
        assertEq(
            _sumOutstanding() + handler.ghost_totalClaimed(),
            handler.ghost_totalPaidIn(),
            "accrued + claimed != paidIn (accounting leak)"
        );
    }
}
