---
phase: 04-contract-hardening
plan: 02
subsystem: contracts
tags: [fuzz, invariant, conservation, solvency, gas-snapshot, hardening]
requires:
  - "Cascade.sol + AA with NatSpec and named custom errors (frozen ABI) — 04-01"
provides:
  - "Property-based fuzz proofs of exact conservation + no-overpay across random valid trees"
  - "Stateful invariant suite (solvency, no-wei-created, accrued==paid) over a bounded handler"
  - "Committed deterministic .gas-snapshot baseline"
affects:
  - test/Cascade.fuzz.t.sol
  - test/Cascade.invariant.t.sol
  - test/handlers/CascadeHandler.sol
  - .gas-snapshot
tech-stack:
  added: []
  patterns:
    - "bound() against remaining slack for multi-share trees (never vacuous vm.assume)"
    - "handler ghost oracle (ghost_totalPaidIn/ghost_totalClaimed) reconciled against on-chain balance"
    - "depth-aware leaf fallback in handler keeps every fuzzed register/invoke/claim valid (fail-on-revert)"
    - "targetContract + targetSelector restricting invariant fuzzing to the bounded handler"
    - "forge snapshot --no-match-path 'test/*.fork.t.sol' for an offline-reproducible gas baseline"
key-files:
  created:
    - test/Cascade.fuzz.t.sol
    - test/Cascade.invariant.t.sol
    - test/handlers/CascadeHandler.sol
    - .gas-snapshot
    - .planning/phases/04-contract-hardening/04-02-SUMMARY.md
  modified: []
decisions:
  - "Refactored testFuzz_wide_tree_conserves to array-of-creators + block scoping to clear a Stack too deep without enabling via-ir (keeps the deterministic snapshot reproducible under the existing optimizer config)."
  - "Handler tracks priceOf/depthOf locally because Cascade exposes neither (internal mapping); this lets invoke pay msg.value==price exactly and lets register avoid DepthExceeded — so fail-on-revert can stay true and the invariants are proven non-vacuous (~16k executed calls/run, 0 reverts)."
  - "Gas snapshot scoped to non-fork tests so it is deterministic offline and does not require an RPC (threat T-04-05)."
metrics:
  duration: ~6m
  completed: 2026-06-07
  tasks: 3
  files: 4
---

# Phase 4 Plan 02: Fuzz + Invariant Tests + Gas Snapshot (HARD-02) Summary

Proved Cascade's core economic property — no wei is ever created or destroyed across arbitrary valid trees and arbitrary interleavings of register/invoke/claim — with four property-based fuzz tests and a three-property stateful invariant suite driven through a bounded handler, then committed a deterministic gas-snapshot baseline. All prior tests stay green; `src/Cascade.sol` is unchanged (tests-only wave).

## What Was Built

- **test/Cascade.fuzz.t.sol** (4 `testFuzz_` functions, 512/256 runs):
  - `testFuzz_wide_tree_conserves` — a node with three sibling leaf deps whose shares are clamped against remaining slack (running sum can never exceed 10000); asserts each leaf cut == `floor(price*share/BPS)`, the four balances sum to `price` exactly, and held balance == price pre-claim.
  - `testFuzz_linear_chain_conserves` — a fuzzed-depth chain (1..MAX_DEPTH) each level routing a fuzzed share into the prior; asserts no creator exceeds price and summed balances == price across every intermediate floor.
  - `testFuzz_no_overpay` — single-dep: `leaf == floor(price*share/BPS)`, `top == price - routed`, `leaf+top == price`, neither party over price (explicit no-overpay AND no-underpay).
  - `testFuzz_shared_creator_conserves` — same creator owning two nodes still aggregates to exact conservation (guards double-credit / lost-credit bugs).
- **test/handlers/CascadeHandler.sol** (`contract CascadeHandler`): a 5-actor bounded driver exposing `register`/`invoke`/`claim`. Maintains `ghost_totalPaidIn`, `ghost_totalClaimed`, `ghost_callCount`, the actor roster, and local `priceOf`/`depthOf` maps. `register` clamps price + share with `bound()` and falls back to a leaf when a dep would exceed MAX_DEPTH; `invoke` `vm.deal`s the exact price then prank-invokes; `claim` accumulates the returned amount. Every action is valid by construction, so `fail-on-revert` stays true and the invariants are non-vacuous.
- **test/Cascade.invariant.t.sol** (3 `invariant_` functions): `targetContract(address(handler))` + `targetSelector` to the three handler fns. `invariant_solvency` (held >= Σ outstanding claims), `invariant_no_wei_created` (held == paidIn - claimed), `invariant_accrued_equals_paid` (Σ outstanding + claimed == paidIn).
- **.gas-snapshot**: 35-entry deterministic baseline generated with `forge snapshot --no-match-path 'test/*.fork.t.sol'`; committed (not gitignored).

## Verification

- `forge test --match-path 'test/Cascade.fuzz.t.sol'`: 4 passed, 0 failed (512/256 runs).
- `forge test --match-path 'test/Cascade.invariant.t.sol'`: 3 passed, 0 failed — each invariant ran 256 runs × ~16,384 calls with **0 reverts** and calls evenly split across register/invoke/claim (non-vacuous; threat T-04-04 mitigated).
- `forge test --no-match-path 'test/*.fork.t.sol'`: 36 passed, 0 failed (4 suites: 13 Cascade unit + 16 SmartAccountUnit + 4 fuzz + 3 invariant). Prior 29-local + fork = the 34 baseline all remain green, plus 7 new.
- `forge test --fork-url atlantic_testnet --match-path 'test/*.fork.t.sol'`: 5 passed, 0 failed — real-EntryPoint integration unchanged.
- `.gas-snapshot`: 35 lines (>= 10), not present in .gitignore.
- `src/Cascade.sol`: untouched this wave (no diff).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stack too deep in testFuzz_wide_tree_conserves**
- **Found during:** Task 1
- **Issue:** The first draft of the wide-tree fuzz declared too many distinct locals (3 creators + 3 share vars + 3 ids + dep/share arrays + price), tripping `Stack too deep` under the project's non-via-ir optimizer config at the `vm.deal` line.
- **Fix:** Refactored to a fixed-size `address[4]` creator array, a single `shares` memory array populated via slack-clamped `bound()`, and a `{}` block scope around the registration loop so intermediate ids drop off the stack. No behavior change; avoided enabling via-ir, which would have changed gas numbers and undermined the deterministic snapshot.
- **Files modified:** test/Cascade.fuzz.t.sol
- **Commit:** 69eb956

No other deviations — the fuzz/invariant properties held on first green run; the conservation invariant the contract was designed around is proven exactly, so no contract bug surfaced.

## Known Stubs

None.

## Threat Flags

None — this wave adds tests + a committed gas artifact only. No new network endpoints, auth paths, or trust-boundary surface. The two threat-register items (T-04-04 vacuous invariants, T-04-05 non-deterministic snapshot) are both mitigated as designed: bound()-driven handler with 0 reverts across ~16k calls/run, and a fork-excluded offline snapshot.

## Self-Check: PASSED

All four created files exist (test/Cascade.fuzz.t.sol, test/Cascade.invariant.t.sol, test/handlers/CascadeHandler.sol, .gas-snapshot) and all three task commits (69eb956, 1dc72f0, 8f2ed46) are present in git history.
