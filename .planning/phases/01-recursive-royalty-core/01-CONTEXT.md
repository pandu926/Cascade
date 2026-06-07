# Phase 1: Recursive Royalty Core - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

A single on-chain `invoke` pays every creator in a declared dependency tree proportionally, demonstrable end-to-end on atlantic-testnet. This phase delivers `Cascade.sol` (the registry + recursive royalty router), forge scripts for register/invoke/claim, and a deployed A→B→C toy tree proving one paid invoke raises three creator balances. ERC-4337 is explicitly NOT in this phase — the contract must be account-agnostic so the 4337 layer (Phase 3) is purely additive.

</domain>

<decisions>
## Implementation Decisions

### Cascade.sol Core Design
- **Dependency "share" semantics:** A dependency's share is the fraction of the parent's payment that flows to that dependency's ENTIRE subtree (recursive). The remainder (100% − Σ shares) is the skill creator's own cut. "Proportional to depth" emerges naturally from recursion. Incentive-compatible: declaring fake deps only spends the declarer's own cut.
- **Payment currency:** Native PHRS via `msg.value`. No ERC20 approve flow — keeps the demo and invoke path simple.
- **Skill mutability:** Skills are IMMUTABLE once registered. Updating = registering a new version. Prevents royalty-rug on consumers and simplifies accounting.
- **Cycle prevention:** Monotonic skill IDs — a dependency must reference an already-registered skill with a strictly smaller ID. Cycles become impossible by construction (no runtime DFS needed; gas-free safety).

### Claude's Discretion (standard, documented in code)
- Shares expressed in **basis points** (0–10000); `register` reverts if Σ dependency shares > 10000.
- **Exact payment**: `invoke` requires `msg.value == price`, else revert (no overpay/refund logic in v1).
- **Pull-payment**: `invoke` only credits an internal `balances[creator]` mapping; creators call `claim()` to withdraw. No external calls during fan-out (reentrancy-safe, no payee can block the tree).
- **Depth cap = 8**, enforced at register time (a skill's depth = 1 + max(dep depths); reject if > 8). Bounds invoke gas to a known maximum.
- **Dust/rounding**: each skill's creator receives the exact remainder of its own level's split (`amount − Σ floor(routed to deps)`). Conservation holds exactly (Σ accrued == price) by construction — every wei is assigned. (Chosen over rolling dust to the top creator: simpler, gas-leaner, equally trustless. Matters given the tight ~0.01 PHRS demo budget.)
- Emit events (`SkillRegistered`, `Invoked`, `RoyaltyAccrued`, `Claimed`) so the Phase 4 web visualization can reconstruct money flow from chain logs.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Greenfield repo — no source yet. Reference implementation cloned at `/tmp/pharos-skill-engine` shows the canonical Skill layout (SKILL.md + references/ + assets/networks.json + forge scripts) to mirror in Phase 2.
- `assets/networks.json` from the official engine documents both networks: atlantic-testnet (chainId 688689, rpc https://atlantic.dplabs-internal.com, PHRS) and mainnet (chainId 1672, PROS).

### Established Patterns
- Official engine drives everything through Foundry `cast`/`forge` CLI — Phase 1 forge scripts (Register/Invoke/Claim) should follow that convention.

### Integration Points
- Foundry installed at ~/.foundry/bin (symlinked into /usr/local/bin). cast/forge 1.5.1 verified.
- Throwaway testnet wallet generated; key in `.env` (gitignored, mode 600). Address: 0x4B80622694fcC13A0d3F24d79dE27A9048984596 (funding pending).

</code_context>

<specifics>
## Specific Ideas

- Killer demo moment (drives DEMO-02 design): ONE invoke, and three distinct creator balances rise on-chain in a single transaction, proportional to their depth in the A→B→C tree. Build the demo script to print all three balances before/after.
- Contract must be fully unit-testable and tested locally via forge/anvil with NO testnet funds — only the final deploy + live demo consume PHRS.
- `Cascade.sol` account-agnostic by construction: it only reads `msg.sender`/`msg.value`, so an EOA and a (Phase 3) smart account hit the identical code path.

</specifics>

<deferred>
## Deferred Ideas

- ERC-4337 smart-account agents and batched UserOps — Phase 3 (AA-01..03).
- Skill packaging (SKILL.md, references/, networks.json) — Phase 2 (SKILL-01..03).
- Web visualization of money flow — Phase 4 (DEMO-03).
- ERC20 payment currency — out of scope (native PHRS only for v1).
- Gasless/paymaster — v2 (GAS-01).

</deferred>
