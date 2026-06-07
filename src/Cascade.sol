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
    // --- Skeleton (Task 1): API + events declared, bodies are stubs so the
    //     project compiles but the end-to-end test fails (RED). ---

    event SkillRegistered(uint256 indexed id, address indexed creator, uint256 price);
    event Invoked(uint256 indexed skillId, address indexed payer, uint256 amount);
    event RoyaltyAccrued(uint256 indexed skillId, address indexed creator, uint256 amount);
    event Claimed(address indexed creator, uint256 amount);

    /// @notice Accrued, claimable balance per creator address.
    mapping(address => uint256) public balances;

    /// @notice Number of skills registered (also the highest valid id).
    function skillCount() public view returns (uint256) {
        revert("not implemented");
    }

    /// @notice Register an immutable skill.
    /// @param price Native-token price to invoke this skill (exact).
    /// @param depIds Dependency skill ids (each must be a strictly-smaller, registered id).
    /// @param depShares Share (bps, 0-10000) of this skill's payment routed into each dep's subtree.
    /// @return id The new monotonic skill id (starts at 1).
    function register(uint256 price, uint256[] calldata depIds, uint256[] calldata depShares)
        external
        returns (uint256 id)
    {
        price; depIds; depShares;
        revert("not implemented");
    }

    /// @notice Pay for and invoke a skill; fans `msg.value` up its declared tree.
    function invoke(uint256 skillId) external payable {
        skillId;
        revert("not implemented");
    }

    /// @notice Withdraw the caller's accrued balance.
    /// @return amount The amount transferred.
    function claim() external returns (uint256 amount) {
        revert("not implemented");
    }
}
