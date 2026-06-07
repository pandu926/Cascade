---
phase: 01-recursive-royalty-core
plan: 01
subsystem: contracts
tags: [solidity, foundry, forge-std, royalties, pull-payment, evm]

# Dependency graph
requires: []
provides:
  - "src/Cascade.sol — registry + recursive royalty router (register/invoke/claim + 4 events)"
  - "Foundry project scaffold (foundry.toml, lib/forge-std, assets/networks.json)"
  - "Local zero-fund test suite proving CORE-01..07 incl. full A->B->C end-to-end invoke"
affects:
  - "01-02 (forge scripts wrap register/invoke/claim)"
  - "01-03 (live testnet deploy of Cascade.sol)"
  - "Phase 2 (Skill packaging around the contract + networks.json)"
  - "Phase 3 (account-agnostic invoke path reused by smart-account UserOps)"

# Tech tracking
tech-stack:
  added: [Foundry (forge/cast 1.5.1), forge-std, Solidity 0.8.24]
  patterns:
    - "Pull-payment (accrue balances + claim) — no external calls during fan-out"
    - "Monotonic skill ids; deps must be strictly-smaller registered ids (cycles impossible by construction)"
    - "Per-level remainder absorbed by that level's creator (exact wei conservation, no separate dust pass)"
    - "Register-time depth cap (8) bounds invoke recursion gas"
    - "Account-agnostic: contract reads only msg.sender/msg.value"

key-files:
  created:
    - "src/Cascade.sol"
    - "test/Cascade.t.sol"
    - "foundry.toml"
    - "assets/networks.json"
  modified:
    - ".gitignore"

key-decisions:
  - "Shares in basis points (0-10000); register reverts if Σ dep shares > 10000"
  - "Exact payment: invoke requires msg.value == price, else revert (no overpay/refund)"
  - "Per-level remainder credited to that level's creator (chosen over rolling dust to top creator)"
  - "claim() uses checks-effects-interactions: zero balance before the value-bearing call"

patterns-established:
  - "Recursive _distribute(skillId, amount): floor-routes shares into deps, creator absorbs remainder"
  - "AAA-structured forge tests with makeAddr/vm.prank/vm.deal/vm.expectRevert; fuzz invariant for conservation"

requirements-completed: [CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07]

# Metrics
duration: ~18min
completed: 2026-06-07
---

# Phase 1 Plan 01: Recursive Royalty Core Summary

**`Cascade.sol` recursive royalty router — one `invoke` fans native payment up a declared A→B→C tree crediting three creators proportionally, with exact wei conservation, depth-capped recursion, and reentrancy-safe pull-payment claims, all proven by a 13-test zero-fund forge suite.**

## Performance

- **Duration:** ~18 min
- **Completed:** 2026-06-07
- **Tasks:** 3
- **Files created/modified:** 5 (+ vendored forge-std)

## Accomplishments
- Foundry project scaffolded in repo root (solc 0.8.24, optimizer 200, atlantic-testnet + mainnet rpc endpoints) without clobbering existing planning files; Counter samples removed.
- `Cascade.sol` implements `register`/`invoke`/`claim` with recursive proportional accrual: monotonic ids + strictly-smaller dep refs (cycles impossible), Σ-shares ≤ 10000 bps cap, depth cap 8, per-level remainder conservation, and the only value transfer living in `claim` (pull-payment, zero-before-send).
- 13-test suite (12 unit + 1 fuzz) is green: full A→B→C end-to-end invoke raises three balances summing exactly to price, plus all revert paths (cycle/forward-ref, dep id 0, unregistered dep, shares > 10000, depth > 8, length mismatch, wrong msg.value, unknown skill), double-claim no-double-pay, per-level dust conservation, codeless-EOA account-agnostic path, and a 256-run conservation fuzz invariant.
- Gas headroom confirmed for the live demo: deployment ~546K gas, `claim` ~30K — comfortably within the ~1M / ~0.01 PHRS budget.

## Task Commits

Each task was committed atomically (TDD RED → GREEN → edge tests):

1. **Task 1: Scaffold + failing end-to-end test (RED)** - `854ceeb` (test)
2. **Task 2: Implement Cascade.sol (GREEN)** - `fde9151` (feat)
3. **Task 3: Edge-case + invariant tests** - `9d447e5` (test)

**Plan metadata:** see final docs commit.

## Files Created/Modified
- `src/Cascade.sol` - Registry + recursive royalty router: `register`/`invoke`/`claim`, 4 events, `_distribute` recursive split helper.
- `test/Cascade.t.sol` - Zero-fund local suite: end-to-end A→B→C flow + 12 edge/invariant/fuzz tests.
- `foundry.toml` - solc 0.8.24, optimizer 200, `[rpc_endpoints]` for atlantic_testnet + mainnet.
- `assets/networks.json` - Byte-matches the reference engine config (atlantic-testnet default, mainnet supported).
- `.gitignore` - Preserves `.env`, adds `out/`, `cache/`, `broadcast/`.

## Decisions Made
- None beyond the locked CONTEXT.md design. Implemented exactly: basis-point shares, exact payment, per-level remainder dust handling, depth cap 8, pull-payment with checks-effects-interactions.

## Deviations from Plan

None - plan executed exactly as written.

## TDD Gate Compliance
- RED gate present: `854ceeb` `test(...)` — failing end-to-end test before implementation.
- GREEN gate present: `fde9151` `feat(...)` — implementation makes the test pass.
- No REFACTOR commit needed (implementation was already KISS/gas-lean).

## Issues Encountered
- The plan's RED verify command (`grep "Compiler run successful"`) initially returned non-zero because forge's build cache suppresses that message on an unchanged build. Resolved by running `forge clean` before the verify — RED-OK confirmed. No code impact.

## User Setup Required
None - all work is local on the forge EVM; no external service configuration and no testnet funds spent.

## Next Phase Readiness
- `Cascade.sol` is feature-complete and locked behind a green local suite — ready for 01-02 (forge register/invoke/claim scripts + A→B→C demo driver) and 01-03 (live testnet deploy).
- Account-agnostic invoke path is proven, de-risking the Phase 3 ERC-4337 layer.
- No blockers.

## Self-Check: PASSED

All claimed files exist (src/Cascade.sol, test/Cascade.t.sol, foundry.toml, assets/networks.json, 01-01-SUMMARY.md) and all task commits are present (854ceeb, fde9151, 9d447e5).

---
*Phase: 01-recursive-royalty-core*
*Completed: 2026-06-07*
