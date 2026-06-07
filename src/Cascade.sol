// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Cascade — recursive skill royalty registry + router
/// @notice Skill authors register an immutable skill with a price and a declared
///         list of dependencies + shares (basis points). A single `invoke` fans the
///         payment up the entire declared dependency tree, crediting each creator's
///         internal balance (pull-payment). Creators withdraw via `claim()`.
/// @dev Account-agnostic by construction: only reads `msg.sender` / `msg.value`,
///      never inspects caller code or type — an EOA and a smart account hit the
///      identical code path.
contract Cascade {
    /// @dev Maximum dependency-tree depth. Bounds `invoke` recursion (and thus gas)
    ///      to a known maximum; enforced at register time.
    uint256 internal constant MAX_DEPTH = 8;

    /// @dev Total basis points (100%).
    uint256 internal constant BPS = 10000;

    struct Skill {
        address creator;
        uint256 price;
        uint256 depth;
        uint256[] depIds;
        uint256[] depShares;
    }

    event SkillRegistered(uint256 indexed id, address indexed creator, uint256 price);
    event Invoked(uint256 indexed skillId, address indexed payer, uint256 amount);
    event RoyaltyAccrued(uint256 indexed skillId, address indexed creator, uint256 amount);
    event Claimed(address indexed creator, uint256 amount);

    /// @notice Accrued, claimable balance per creator address.
    mapping(address => uint256) public balances;

    /// @dev Skills indexed by their monotonic id (id 0 reserved/invalid).
    mapping(uint256 => Skill) internal skills;

    /// @notice Number of skills registered (also the highest valid id).
    uint256 public skillCount;

    /// @notice Register an immutable skill.
    /// @param price Native-token price to invoke this skill (exact, may be 0 for a leaf).
    /// @param depIds Dependency skill ids (each must be a strictly-smaller, registered id).
    /// @param depShares Share (bps, 0-10000) of this skill's payment routed into each dep's subtree.
    /// @return id The new monotonic skill id (starts at 1).
    function register(uint256 price, uint256[] calldata depIds, uint256[] calldata depShares)
        external
        returns (uint256 id)
    {
        require(depIds.length == depShares.length, "len mismatch");

        id = ++skillCount;

        uint256 shareSum;
        uint256 maxDepDepth;
        for (uint256 i; i < depIds.length; ++i) {
            uint256 depId = depIds[i];
            // Strictly-smaller, already-registered id: makes cycles impossible by
            // construction and enforces bottom-up registration. id 0 is invalid.
            require(depId != 0 && depId < id, "bad dep id");

            shareSum += depShares[i];

            uint256 depDepth = skills[depId].depth;
            if (depDepth > maxDepDepth) {
                maxDepDepth = depDepth;
            }
        }
        require(shareSum <= BPS, "shares > 10000");

        uint256 depth = maxDepDepth + 1;
        require(depth <= MAX_DEPTH, "depth > 8");

        skills[id] = Skill({
            creator: msg.sender,
            price: price,
            depth: depth,
            depIds: depIds,
            depShares: depShares
        });

        emit SkillRegistered(id, msg.sender, price);
    }

    /// @notice Pay for and invoke a skill; fans `msg.value` up its declared tree.
    /// @dev Exact payment only. Credits internal balances exclusively — no external
    ///      calls during fan-out (reentrancy-safe; no payee can block the tree).
    function invoke(uint256 skillId) external payable {
        require(skillId != 0 && skillId <= skillCount, "no skill");
        require(msg.value == skills[skillId].price, "wrong value");

        _distribute(skillId, msg.value);

        emit Invoked(skillId, msg.sender, msg.value);
    }

    /// @notice Withdraw the caller's accrued balance.
    /// @dev Zeroes the balance BEFORE transferring (checks-effects-interactions),
    ///      so a re-entering claim sees a zero balance and cannot double-pay.
    /// @return amount The amount transferred.
    function claim() external returns (uint256 amount) {
        amount = balances[msg.sender];
        balances[msg.sender] = 0;
        if (amount != 0) {
            (bool ok,) = payable(msg.sender).call{value: amount}("");
            require(ok, "transfer failed");
            emit Claimed(msg.sender, amount);
        }
    }

    /// @dev Recursively splits `amount` at `skillId`: each declared dependency
    ///      receives floor(amount * share / 10000) routed into its subtree, and this
    ///      skill's creator absorbs the exact per-level remainder. Every wei is
    ///      assigned at each level, so total accrued == the original payment exactly.
    ///      Recursion depth is bounded by the register-time MAX_DEPTH cap.
    function _distribute(uint256 skillId, uint256 amount) internal {
        Skill storage s = skills[skillId];

        uint256 routedSum;
        uint256[] storage depIds = s.depIds;
        uint256[] storage depShares = s.depShares;
        for (uint256 i; i < depIds.length; ++i) {
            uint256 routed = (amount * depShares[i]) / BPS;
            if (routed != 0) {
                routedSum += routed;
                _distribute(depIds[i], routed);
            }
        }

        // Per-level remainder is this skill creator's own cut.
        uint256 creatorCut = amount - routedSum;
        if (creatorCut != 0) {
            address creator = s.creator;
            balances[creator] += creatorCut;
            emit RoyaltyAccrued(skillId, creator, creatorCut);
        }
    }
}
