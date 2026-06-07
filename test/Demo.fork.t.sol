// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Cascade} from "../src/Cascade.sol";

/// @dev End-to-end local proof of the A->B->C killer demo with ZERO testnet funds.
///      Runs entirely on the forge EVM and mirrors the exact numbers in
///      script/DemoTree.s.sol, so the live wave (01-03) reproduces this result by
///      pointing the same flow at the testnet RPC — no code changes, only flags.
contract DemoForkTest is Test {
    Cascade internal cascade;

    address internal creatorA = makeAddr("demoCreatorA");
    address internal creatorB = makeAddr("demoCreatorB");
    address internal creatorC = makeAddr("demoCreatorC");
    address internal payer = makeAddr("demoPayer");

    // --- demo constants (IDENTICAL to script/DemoTree.s.sol) --------------
    uint256 internal constant PRICE_C = 0.001 ether;
    uint256 internal constant SHARE_C_TO_B = 5000; // 50%
    uint256 internal constant SHARE_B_TO_A = 4000; // 40%

    function setUp() public {
        cascade = new Cascade();
    }

    function _empty() internal pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _one(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    function _registerTree() internal returns (uint256 idA, uint256 idB, uint256 idC) {
        vm.prank(creatorA);
        idA = cascade.register(0, _empty(), _empty());
        vm.prank(creatorB);
        idB = cascade.register(0, _one(idA), _one(SHARE_B_TO_A));
        vm.prank(creatorC);
        idC = cascade.register(PRICE_C, _one(idB), _one(SHARE_C_TO_B));
    }

    /// @notice The whole demo: one invoke raises three balances proportionally, sums to
    ///         price exactly, and a creator can then claim — all with zero testnet funds.
    function test_demo_flow_one_invoke_raises_three_balances_then_claim() public {
        (,, uint256 idC) = _registerTree();

        // Depth-proportional split using the exact share math.
        uint256 toBSubtree = (PRICE_C * SHARE_C_TO_B) / 10000; // 0.0005 ether
        uint256 cCut = PRICE_C - toBSubtree; // 0.0005 ether
        uint256 toASubtree = (toBSubtree * SHARE_B_TO_A) / 10000; // 0.0002 ether
        uint256 bCut = toBSubtree - toASubtree; // 0.0003 ether
        uint256 aCut = toASubtree; // 0.0002 ether

        // Snapshot BEFORE.
        uint256 a0 = cascade.balances(creatorA);
        uint256 b0 = cascade.balances(creatorB);
        uint256 c0 = cascade.balances(creatorC);

        // ONE paid invoke of C.
        vm.deal(payer, PRICE_C);
        vm.prank(payer);
        cascade.invoke{value: PRICE_C}(idC);

        uint256 dA = cascade.balances(creatorA) - a0;
        uint256 dB = cascade.balances(creatorB) - b0;
        uint256 dC = cascade.balances(creatorC) - c0;

        // All three distinct creators rise in a single transaction.
        assertGt(dA, 0, "A delta should rise");
        assertGt(dB, 0, "B delta should rise");
        assertGt(dC, 0, "C delta should rise");

        // Deltas are depth-proportional per the declared shares.
        assertEq(dA, aCut, "A delta == leaf cut");
        assertEq(dB, bCut, "B delta == B remainder");
        assertEq(dC, cCut, "C delta == C remainder");

        // Conservation: every wei of the payment is assigned.
        assertEq(dA + dB + dC, PRICE_C, "sum of deltas == price");

        // A creator can then pull their accrued royalty.
        uint256 walletBefore = creatorA.balance;
        vm.prank(creatorA);
        uint256 claimed = cascade.claim();
        assertEq(claimed, aCut, "claim returns A's accrued cut");
        assertEq(creatorA.balance, walletBefore + aCut, "A wallet credited by claim");
    }
}
