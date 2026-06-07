// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Cascade} from "../src/Cascade.sol";

/// @dev Property-based proofs of Cascade's core economic invariant — across
///      arbitrary VALID dependency trees and arbitrary in-range shares, a single
///      `invoke` creates and destroys exactly zero wei: the sum of every creator's
///      accrued balance equals the price paid, to the wei, at every depth. These
///      generalize the single-tree `testFuzz_conservation_holds_for_random_shares`
///      seed in Cascade.t.sol to wide trees, deep linear chains, and explicit
///      no-overpay bounds. Pure forge EVM; zero funds.
contract CascadeFuzzTest is Test {
    Cascade internal cascade;

    /// @dev Bounds for fuzzed prices: non-zero (so a cut actually accrues) and
    ///      capped well below the native supply so `vm.deal` always succeeds.
    uint256 internal constant MIN_PRICE = 1;
    uint256 internal constant MAX_PRICE = 1_000_000 ether;

    /// @dev Mirrors Cascade.BPS / Cascade.MAX_DEPTH (internal in the contract).
    uint256 internal constant BPS = 10000;
    uint256 internal constant MAX_DEPTH = 8;

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

    /// @dev Deterministic, distinct, codeless creator address from a label + index.
    function _creator(string memory tag, uint256 i) internal returns (address) {
        return makeAddr(string(abi.encodePacked(tag, "_", vm.toString(i))));
    }

    // --- wide tree: many sibling deps under one node ----------------------

    /// @notice A node with three sibling leaf deps, each with an independently
    ///         fuzzed share whose running sum is clamped to <= 10000 bps, conserves
    ///         exactly: leaf cuts + top remainder == price, no wei lost to floors.
    /// forge-config: default.fuzz.runs = 512
    function testFuzz_wide_tree_conserves(uint256 priceSeed, uint256 s1, uint256 s2, uint256 s3) public {
        uint256 price = bound(priceSeed, MIN_PRICE, MAX_PRICE);

        address[4] memory cs =
            [_creator("wideA", 0), _creator("wideB", 1), _creator("wideC", 2), _creator("wideTop", 3)];

        uint256[] memory shares = new uint256[](3);
        // Clamp each share against the remaining slack so the running sum can
        // never exceed 10000 — no run is discarded (bound, never vm.assume).
        shares[0] = bound(s1, 0, BPS);
        shares[1] = bound(s2, 0, BPS - shares[0]);
        shares[2] = bound(s3, 0, BPS - shares[0] - shares[1]);

        uint256 idTop;
        {
            // Three leaves (price 0, no deps), then a top routing into all three.
            uint256[] memory deps = new uint256[](3);
            for (uint256 i; i < 3; ++i) {
                vm.prank(cs[i]);
                deps[i] = cascade.register(0, _empty(), _empty());
            }
            vm.prank(cs[3]);
            idTop = cascade.register(price, deps, shares);
        }

        vm.deal(address(this), price);
        cascade.invoke{value: price}(idTop);

        // Each leaf is terminal, so its creator absorbs exactly the routed amount.
        assertEq(cascade.balances(cs[0]), (price * shares[0]) / BPS, "leaf A cut == floor(price*shareA)");
        assertEq(cascade.balances(cs[1]), (price * shares[1]) / BPS, "leaf B cut == floor(price*shareB)");
        assertEq(cascade.balances(cs[2]), (price * shares[2]) / BPS, "leaf C cut == floor(price*shareC)");

        // Conservation: every wei of the payment lands somewhere, exactly once.
        uint256 totalAccrued =
            cascade.balances(cs[0]) + cascade.balances(cs[1]) + cascade.balances(cs[2]) + cascade.balances(cs[3]);
        assertEq(totalAccrued, price, "wide tree conserves: sum accrued == price");

        // Contract holds exactly the price until claims drain it.
        assertEq(address(cascade).balance, price, "held balance == price pre-claim");
    }

    // --- deep linear chain -------------------------------------------------

    /// @notice A linear chain up to MAX_DEPTH, each level routing a fuzzed share
    ///         into the level below, conserves exactly across every intermediate
    ///         floor() division.
    /// forge-config: default.fuzz.runs = 512
    function testFuzz_linear_chain_conserves(uint256 depthSeed, uint256 priceSeed, uint256 shareSeed) public {
        uint256 depth = bound(depthSeed, 1, MAX_DEPTH);
        uint256 price = bound(priceSeed, MIN_PRICE, MAX_PRICE);
        // One share value reused per level; in [0, BPS] so every level is valid.
        uint256 share = bound(shareSeed, 0, BPS);

        address[] memory creators = new address[](depth);
        uint256 prevId;

        // Level 0 is the leaf (no deps); each higher level routes `share` into the
        // prior. The top (last) level carries the price.
        for (uint256 level; level < depth; ++level) {
            creators[level] = _creator("chain", level);
            uint256 levelPrice = (level == depth - 1) ? price : 0;

            vm.prank(creators[level]);
            if (level == 0) {
                prevId = cascade.register(levelPrice, _empty(), _empty());
            } else {
                prevId = cascade.register(levelPrice, _one(prevId), _one(share));
            }
        }

        // `prevId` is now the top of the chain.
        vm.deal(address(this), price);
        cascade.invoke{value: price}(prevId);

        uint256 totalAccrued;
        for (uint256 level; level < depth; ++level) {
            uint256 bal = cascade.balances(creators[level]);
            // No single creator can ever accrue more than the whole payment.
            assertLe(bal, price, "no creator over the price");
            totalAccrued += bal;
        }
        assertEq(totalAccrued, price, "linear chain conserves: sum accrued == price");
        assertEq(address(cascade).balance, price, "held balance == price pre-claim");
    }

    // --- explicit no-overpay / no-underpay --------------------------------

    /// @notice For a single dep with a fuzzed share, the routed-out amount plus the
    ///         top creator's remainder cut equals the input exactly (no under-pay),
    ///         and neither party ever receives more than the price (no over-pay).
    /// forge-config: default.fuzz.runs = 512
    function testFuzz_no_overpay(uint256 priceSeed, uint256 shareSeed) public {
        uint256 price = bound(priceSeed, MIN_PRICE, MAX_PRICE);
        uint256 share = bound(shareSeed, 0, BPS);

        address leaf = _creator("noOverpayLeaf", 0);
        address top = _creator("noOverpayTop", 1);

        vm.prank(leaf);
        uint256 idLeaf = cascade.register(0, _empty(), _empty());
        vm.prank(top);
        uint256 idTop = cascade.register(price, _one(idLeaf), _one(share));

        uint256 routed = (price * share) / BPS; // amount into the leaf subtree
        uint256 topCut = price - routed; // remainder the top absorbs

        vm.deal(address(this), price);
        cascade.invoke{value: price}(idTop);

        uint256 leafBal = cascade.balances(leaf);
        uint256 topBal = cascade.balances(top);

        // No over-pay: nobody exceeds the price, leaf gets exactly its routed share.
        assertLe(leafBal, price, "leaf never over the price");
        assertLe(topBal, price, "top never over the price");
        assertEq(leafBal, routed, "leaf accrues exactly floor(price*share/BPS)");

        // No under-pay: top absorbs the exact per-level remainder; the two sum to price.
        assertEq(topBal, topCut, "top cut == price - routed (exact remainder)");
        assertEq(leafBal + topBal, price, "routed + remainder == price (no under-pay)");
    }

    // --- a creator appearing at multiple nodes still conserves ------------

    /// @notice When the SAME creator owns several nodes in one tree, their balance
    ///         is the sum of every per-node cut, and total conservation still holds
    ///         exactly — guards against double-credit or lost-credit aggregation bugs.
    /// forge-config: default.fuzz.runs = 256
    function testFuzz_shared_creator_conserves(uint256 priceSeed, uint256 shareTop, uint256 shareMid) public {
        uint256 price = bound(priceSeed, MIN_PRICE, MAX_PRICE);
        uint256 sTop = bound(shareTop, 0, BPS);
        uint256 sMid = bound(shareMid, 0, BPS);

        address shared = _creator("shared", 0); // owns leaf AND mid
        address topOwner = _creator("topOwner", 1);

        // leaf (shared) <- mid (shared) <- top (topOwner)
        vm.prank(shared);
        uint256 idLeaf = cascade.register(0, _empty(), _empty());
        vm.prank(shared);
        uint256 idMid = cascade.register(0, _one(idLeaf), _one(sMid));
        vm.prank(topOwner);
        uint256 idTop = cascade.register(price, _one(idMid), _one(sTop));

        vm.deal(address(this), price);
        cascade.invoke{value: price}(idTop);

        uint256 total = cascade.balances(shared) + cascade.balances(topOwner);
        assertEq(total, price, "shared-creator tree conserves: sum accrued == price");
        assertLe(cascade.balances(shared), price, "shared creator never over the price");
    }

    /// @dev Accept native value so `invoke` can be called from this test contract.
    receive() external payable {}
}
