// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Cascade} from "../../src/Cascade.sol";

/// @title CascadeHandler — bounded actor for stateful invariant fuzzing
/// @notice Drives a single Cascade instance through randomized but always-VALID
///         sequences of register / invoke / claim, run from a small fixed roster of
///         actor addresses. Every call is clamped (bound / modulo / depth-aware
///         fallback) so it executes rather than reverting — this is what keeps the
///         invariants in CascadeInvariantTest non-vacuous (threat T-04-04). The
///         handler is the accounting oracle: `ghost_totalPaidIn` and
///         `ghost_totalClaimed` are accumulated from the real calls and the invariant
///         suite reconciles them against on-chain state.
contract CascadeHandler is Test {
    Cascade internal immutable cascade;

    /// @dev Mirrors Cascade's internal BPS / MAX_DEPTH so the handler can keep every
    ///      generated registration inside the contract's accepted bounds.
    uint256 internal constant BPS = 10000;
    uint256 internal constant MAX_DEPTH = 8;

    /// @dev Modest price ceiling: high enough to move real wei through deep trees,
    ///      low enough that `vm.deal` across many invokes never approaches supply.
    uint256 internal constant MAX_PRICE = 100 ether;

    /// @notice Fixed roster of actors that register, invoke, and claim. Both the
    ///         creator universe and the payer universe — so summing balances over
    ///         this roster captures every wei ever accrued.
    address[] public actors;

    /// @notice All skill ids registered so far (monotonic; index order == id order).
    uint256[] public ids;

    /// @dev Per-id price and depth, tracked locally because Cascade exposes neither
    ///      (price/depth live in an internal mapping). Lets invoke pay the exact
    ///      price and lets register pick deps that won't trip the depth cap.
    mapping(uint256 => uint256) public priceOf;
    mapping(uint256 => uint256) public depthOf;

    /// @notice Total native value paid into the contract via successful invokes.
    uint256 public ghost_totalPaidIn;

    /// @notice Total native value pulled back out via successful claims.
    uint256 public ghost_totalClaimed;

    /// @notice Count of state-changing handler calls that actually executed
    ///         (registers + invokes + claims) — a non-vacuity witness for the suite.
    uint256 public ghost_callCount;

    constructor(Cascade _cascade) {
        cascade = _cascade;
        // Five deterministic, distinct, codeless EOAs.
        for (uint256 i; i < 5; ++i) {
            actors.push(makeAddr(string(abi.encodePacked("actor_", vm.toString(i)))));
        }
    }

    // --- views for the invariant suite ------------------------------------

    /// @notice Number of actors in the roster.
    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    /// @notice Number of skills registered so far.
    function idCount() external view returns (uint256) {
        return ids.length;
    }

    // --- internal helpers --------------------------------------------------

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _one(uint256 v) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = v;
    }

    function _empty() internal pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    function _registerLeaf(address actor, uint256 price) internal returns (uint256 newId) {
        vm.prank(actor);
        newId = cascade.register(price, _empty(), _empty());
        priceOf[newId] = price;
        depthOf[newId] = 1;
        ids.push(newId);
    }

    // --- handler actions (targeted by the fuzzer) -------------------------

    /// @notice Register a new skill: a leaf, or a single-dep node routing a bounded
    ///         share into an already-registered, depth-safe id. Always valid, so it
    ///         never reverts and always advances state.
    function register(uint256 actorSeed, uint256 priceSeed, uint256 depSeed, uint256 shareSeed) external {
        address actor = _actor(actorSeed);
        uint256 price = bound(priceSeed, 0, MAX_PRICE);

        if (ids.length == 0) {
            _registerLeaf(actor, price);
            ghost_callCount++;
            return;
        }

        uint256 depId = ids[depSeed % ids.length];
        // If attaching to this dep would exceed the depth cap, fall back to a leaf
        // so the call still executes instead of reverting with DepthExceeded.
        if (depthOf[depId] >= MAX_DEPTH) {
            _registerLeaf(actor, price);
            ghost_callCount++;
            return;
        }

        uint256 share = bound(shareSeed, 0, BPS);
        vm.prank(actor);
        uint256 newId = cascade.register(price, _one(depId), _one(share));
        priceOf[newId] = price;
        depthOf[newId] = depthOf[depId] + 1;
        ids.push(newId);
        ghost_callCount++;
    }

    /// @notice Pay the exact price to invoke a registered skill, funding the chosen
    ///         actor with precisely that amount first. Accumulates into the paid-in
    ///         ghost so the suite can prove no wei is created.
    function invoke(uint256 idSeed, uint256 actorSeed) external {
        if (ids.length == 0) return;

        uint256 id = ids[idSeed % ids.length];
        uint256 price = priceOf[id];
        address actor = _actor(actorSeed);

        vm.deal(actor, price); // exact funding; pranked call debits `actor`
        vm.prank(actor);
        cascade.invoke{value: price}(id);

        ghost_totalPaidIn += price;
        ghost_callCount++;
    }

    /// @notice Withdraw a chosen actor's accrued balance, accumulating the amount
    ///         actually transferred into the claimed ghost.
    function claim(uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        vm.prank(actor);
        uint256 amount = cascade.claim();
        ghost_totalClaimed += amount;
        ghost_callCount++;
    }
}
