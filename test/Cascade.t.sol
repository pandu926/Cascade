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

    // --- register revert paths --------------------------------------------

    function test_register_reverts_when_dep_not_yet_registered() public {
        // depId == newId (2) is not yet registered (only id 1 exists after this).
        vm.prank(creatorA);
        cascade.register(0, _empty(), _empty()); // id 1
        vm.prank(creatorB);
        vm.expectPartialRevert(Cascade.BadDependency.selector);
        cascade.register(0, _one(2), _one(1000)); // references id 2 which doesn't exist yet
    }

    function test_register_reverts_on_cycle_via_forward_reference() public {
        // A skill cannot reference an id >= its own (forward reference => cycle).
        // The very first skill (id 1) referencing id 1 is a self-cycle.
        vm.prank(creatorA);
        vm.expectPartialRevert(Cascade.BadDependency.selector);
        cascade.register(0, _one(1), _one(1000));
    }

    function test_register_reverts_when_shares_exceed_10000_bps() public {
        vm.prank(creatorA);
        uint256 idA = cascade.register(0, _empty(), _empty());
        vm.prank(creatorB);
        uint256 idB = cascade.register(0, _empty(), _empty());

        uint256[] memory ids = new uint256[](2);
        ids[0] = idA;
        ids[1] = idB;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 6000;
        shares[1] = 4001; // 10001 total > 10000

        vm.prank(creatorC);
        vm.expectPartialRevert(Cascade.SharesExceedMax.selector);
        cascade.register(1 ether, ids, shares);
    }

    function test_register_reverts_when_dep_id_is_zero() public {
        vm.prank(creatorA);
        vm.expectPartialRevert(Cascade.BadDependency.selector);
        cascade.register(0, _one(0), _one(1000));
    }

    function test_register_reverts_on_length_mismatch() public {
        vm.prank(creatorA);
        uint256 idA = cascade.register(0, _empty(), _empty());
        vm.prank(creatorB);
        vm.expectRevert(Cascade.LengthMismatch.selector);
        cascade.register(0, _one(idA), _empty());
    }

    function test_register_reverts_when_depth_exceeds_8() public {
        // Build a linear chain: id 1 (depth 1) ... id 8 (depth 8) all OK,
        // then id 9 would be depth 9 > MAX_DEPTH(8) and must revert.
        uint256 prev;
        for (uint256 level = 1; level <= 8; ++level) {
            vm.prank(creatorA);
            if (level == 1) {
                prev = cascade.register(0, _empty(), _empty());
            } else {
                prev = cascade.register(0, _one(prev), _one(1000));
            }
        }
        // 9th registration trips the cap.
        vm.prank(creatorA);
        vm.expectPartialRevert(Cascade.DepthExceeded.selector);
        cascade.register(0, _one(prev), _one(1000));
    }

    // --- invoke revert paths ----------------------------------------------

    function test_invoke_reverts_on_wrong_msg_value() public {
        (,, uint256 idC) = _registerTree();

        // Underpayment.
        vm.deal(payer, PRICE);
        vm.prank(payer);
        vm.expectPartialRevert(Cascade.WrongValue.selector);
        cascade.invoke{value: PRICE - 1}(idC);

        // Overpayment.
        vm.deal(payer, PRICE + 1);
        vm.prank(payer);
        vm.expectPartialRevert(Cascade.WrongValue.selector);
        cascade.invoke{value: PRICE + 1}(idC);
    }

    function test_invoke_reverts_on_unknown_skill() public {
        vm.prank(payer);
        vm.expectPartialRevert(Cascade.UnknownSkill.selector);
        cascade.invoke{value: 0}(0);
    }

    // --- claim semantics ---------------------------------------------------

    function test_double_claim_does_not_double_pay() public {
        (uint256 idA,,) = _registerTree();
        idA; // silence unused

        vm.deal(payer, PRICE);
        // invoke the top skill (id 3) so balances accrue.
        vm.prank(payer);
        cascade.invoke{value: PRICE}(3);

        uint256 accrued = cascade.balances(creatorA);
        assertGt(accrued, 0, "A should have accrued");

        // First claim pays out the accrued amount.
        uint256 before = creatorA.balance;
        vm.prank(creatorA);
        uint256 paid = cascade.claim();
        assertEq(paid, accrued, "first claim pays accrued");
        assertEq(creatorA.balance, before + accrued, "wallet credited once");

        // Second claim transfers nothing (balance was zeroed).
        vm.prank(creatorA);
        uint256 paidAgain = cascade.claim();
        assertEq(paidAgain, 0, "second claim pays zero");
        assertEq(creatorA.balance, before + accrued, "no double pay");
    }

    // --- per-level remainder conservation (dust) --------------------------

    function test_remainder_conserves_exactly() public {
        // Shares chosen so integer division leaves a remainder at every level.
        // price = 100 wei; C->B 3333 bps => 100*3333/10000 = 33 (floor), C keeps 67.
        // B->A 3333 bps => 33*3333/10000 = 10 (floor), B keeps 23, A gets 10.
        uint256 price = 100;
        uint256 shareCB = 3333;
        uint256 shareBA = 3333;

        vm.prank(creatorA);
        uint256 idA = cascade.register(0, _empty(), _empty());
        vm.prank(creatorB);
        uint256 idB = cascade.register(0, _one(idA), _one(shareBA));
        vm.prank(creatorC);
        uint256 idC = cascade.register(price, _one(idB), _one(shareCB));

        uint256 toB = (price * shareCB) / 10000; // 33
        uint256 cCut = price - toB; // 67
        uint256 toA = (toB * shareBA) / 10000; // 10
        uint256 bCut = toB - toA; // 23
        uint256 aCut = toA; // 10

        vm.deal(payer, price);
        vm.prank(payer);
        cascade.invoke{value: price}(idC);

        assertEq(cascade.balances(creatorC), cCut, "C absorbs its remainder");
        assertEq(cascade.balances(creatorB), bCut, "B absorbs its remainder");
        assertEq(cascade.balances(creatorA), aCut, "A leaf cut");

        // Exact conservation despite floor() at every intermediate node.
        assertEq(
            cascade.balances(creatorA) + cascade.balances(creatorB) + cascade.balances(creatorC),
            price,
            "sum accrued == price exactly"
        );
    }

    // --- account-agnosticism ----------------------------------------------

    function test_account_agnostic_eoa_path() public {
        (,, uint256 idC) = _registerTree();

        // A plain EOA (no contract code) invokes via vm.prank — identical path.
        address eoa = makeAddr("plainEOA");
        assertEq(eoa.code.length, 0, "caller is a codeless EOA");

        vm.deal(eoa, PRICE);
        vm.prank(eoa);
        cascade.invoke{value: PRICE}(idC);

        // Same accrual result as any other caller.
        assertEq(
            cascade.balances(creatorA) + cascade.balances(creatorB) + cascade.balances(creatorC),
            PRICE,
            "EOA path conserves identically"
        );
    }

    // --- invariant-style fuzz: conservation across random valid trees ------

    function testFuzz_conservation_holds_for_random_shares(
        uint256 priceSeed,
        uint256 shareCB,
        uint256 shareBA
    ) public {
        uint256 price = bound(priceSeed, 1, 1_000_000 ether);
        shareCB = bound(shareCB, 0, 10000);
        shareBA = bound(shareBA, 0, 10000);

        vm.prank(creatorA);
        uint256 idA = cascade.register(0, _empty(), _empty());
        vm.prank(creatorB);
        uint256 idB = cascade.register(0, _one(idA), _one(shareBA));
        vm.prank(creatorC);
        uint256 idC = cascade.register(price, _one(idB), _one(shareCB));

        vm.deal(payer, price);
        vm.prank(payer);
        cascade.invoke{value: price}(idC);

        assertEq(
            cascade.balances(creatorA) + cascade.balances(creatorB) + cascade.balances(creatorC),
            price,
            "conservation: sum accrued == price for any valid tree"
        );
    }
}
