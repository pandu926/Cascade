// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Cascade} from "../src/Cascade.sol";

/// @dev Zero-fund local suite for the recursive royalty router. Exercises the
///      full A->B->C register/invoke/claim flow entirely on the forge EVM.
contract CascadeTest is Test {
    Cascade internal cascade;

    address internal creatorA = makeAddr("creatorA");
    address internal creatorB = makeAddr("creatorB");
    address internal creatorC = makeAddr("creatorC");
    address internal payer = makeAddr("payer");

    uint256 internal constant PRICE = 1 ether;
    uint256 internal constant SHARE_C_TO_B = 5000; // 50% of C's payment flows into B's subtree
    uint256 internal constant SHARE_B_TO_A = 4000; // 40% of B's slice flows into A's subtree

    function setUp() public {
        cascade = new Cascade();
    }

    // --- helpers -----------------------------------------------------------

    function _empty() internal pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _one(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    /// Registers the canonical A->B->C tree and returns the ids.
    function _registerTree() internal returns (uint256 idA, uint256 idB, uint256 idC) {
        vm.prank(creatorA);
        idA = cascade.register(0, _empty(), _empty());

        vm.prank(creatorB);
        idB = cascade.register(0, _one(idA), _one(SHARE_B_TO_A));

        vm.prank(creatorC);
        idC = cascade.register(PRICE, _one(idB), _one(SHARE_C_TO_B));
    }

    // --- happy path (the killer demo) --------------------------------------

    function test_end_to_end_invoke_raises_three_balances_and_conserves() public {
        (,, uint256 idC) = _registerTree();

        // Expected split using the exact CONTEXT.md math.
        uint256 toBSubtree = (PRICE * SHARE_C_TO_B) / 10000; // 0.5 ether
        uint256 cCut = PRICE - toBSubtree; // 0.5 ether
        uint256 toASubtree = (toBSubtree * SHARE_B_TO_A) / 10000; // 0.2 ether
        uint256 bCut = toBSubtree - toASubtree; // 0.3 ether
        uint256 aCut = toASubtree; // 0.2 ether

        vm.deal(payer, PRICE);
        vm.prank(payer);
        cascade.invoke{value: PRICE}(idC);

        // All three distinct creator balances rise in a single transaction.
        assertGt(cascade.balances(creatorA), 0, "A balance should rise");
        assertGt(cascade.balances(creatorB), 0, "B balance should rise");
        assertGt(cascade.balances(creatorC), 0, "C balance should rise");

        // Proportional to depth, per the declared shares.
        assertEq(cascade.balances(creatorC), cCut, "C cut");
        assertEq(cascade.balances(creatorB), bCut, "B cut");
        assertEq(cascade.balances(creatorA), aCut, "A cut");

        // Conservation: every wei of the payment is assigned.
        assertEq(
            cascade.balances(creatorA) + cascade.balances(creatorB) + cascade.balances(creatorC),
            PRICE,
            "sum of accrued == price"
        );

        // Each creator can independently pull their accrued royalties.
        uint256 beforeA = creatorA.balance;
        vm.prank(creatorA);
        cascade.claim();
        assertEq(creatorA.balance, beforeA + aCut, "A wallet credited");

        uint256 beforeB = creatorB.balance;
        vm.prank(creatorB);
        cascade.claim();
        assertEq(creatorB.balance, beforeB + bCut, "B wallet credited");

        uint256 beforeC = creatorC.balance;
        vm.prank(creatorC);
        cascade.claim();
        assertEq(creatorC.balance, beforeC + cCut, "C wallet credited");

        // Contract fully drained — no wei stranded.
        assertEq(address(cascade).balance, 0, "contract drained");
    }
}
