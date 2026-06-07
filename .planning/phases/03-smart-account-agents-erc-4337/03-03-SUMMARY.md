---
phase: 03-smart-account-agents-erc-4337
plan: 03
subsystem: smart-account
tags: [erc-4337, account-abstraction, live-broadcast, budget-gate, entrypoint-v0.7, handleops, foundry]

# Dependency graph
requires:
  - phase: 03-smart-account-agents-erc-4337
    plan: 02
    provides: "Wave 2 fork proof (AA-01/02/03) + the exact op-build/sign flow this live script mirrors"
  - phase: 03-smart-account-agents-erc-4337
    plan: 01
    provides: "CascadeAccount + IEntryPoint + PackedUserOperation — the account/op machinery deployed + bundled live"
provides:
  - "script/LiveBundle.s.sol — gated live 4337 step: STOP-clean pre-flight budget gate + (only if it fits) direct account deploy + one handleOps batching 2 invokes of the existing live skills"
  - ".planning/phases/03-smart-account-agents-erc-4337/LIVE_RESULT.md — honest live outcome (BLOCKED on budget with top-up details; no half-spend)"
affects: [phase-04-submission, erc-4337]

# Tech tracking
tech-stack:
  added: [none — forge-std + Wave 1 first-party contracts + real on-chain EntryPoint/Cascade]
  patterns:
    - "Pre-flight budget gate that reverts (no broadcast) when (est gas × price + native value) > EOA balance — never a half-spend"
    - "Direct `new CascadeAccount` deploy (skip the factory) to shrink the live footprint per RESEARCH §8 mitigation 3 (factory path stays fork-proven)"
    - "Live broadcast factored into helpers (_broadcastLive/_buildSignedOp) to dodge stack-too-deep in a single run()"

key-files:
  created:
    - "script/LiveBundle.s.sol"
    - ".planning/phases/03-smart-account-agents-erc-4337/LIVE_RESULT.md"
  modified: []

key-decisions:
  - "Skill prices sourced from env (PRICE_1/PRICE_2 with the known live A→B→C demo defaults) rather than on-chain — Cascade.skills is internal with no price getter (same constraint 03-02 hit); Cascade still enforces msg.value==price on-chain as the fail-safe"
  - "Direct account deploy (new CascadeAccount) for the live step instead of the factory, cutting the heaviest ~600k–1.2M gas item; the factory path is already proven in the Wave 2 fork test"
  - "Gate uses upper-bound gas estimates (500k deploy + 600k handleOps) so it errs toward STOPPING rather than authorizing an over-budget spend"

requirements-completed: [AA-03]

# Metrics
duration: 9min
completed: 2026-06-07
---

# Phase 3 Plan 03: Gated Live ERC-4337 Batch Summary

**A STOP-clean pre-flight budget gate reads the funded EOA balance and the node gas price, estimates the full live 4337 cost, and (only if it fits) deploys a CascadeAccount directly and self-bundles ONE `handleOps` batching two invokes of the existing live skills through the real EntryPoint v0.7 — at the node's real 10 gwei the gate STOPPED cleanly (shortfall ≈ 0.0145 PHRS, no broadcast, balance unchanged), which is the expected acceptable outcome since AA-01/02/03 are already proven by the Wave 2 fork test.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-07T20:32:21Z
- **Completed:** 2026-06-07T20:41:00Z
- **Tasks:** 2 auto complete (+ 1 human-verify checkpoint pending)
- **Files:** 2 created

## Accomplishments
- `script/LiveBundle.s.sol`: a gated live step that runs a PRE-FLIGHT BUDGET GATE first — it compares `(account-deploy gas + handleOps gas) × gasPrice + (EntryPoint prefund + p1 + p2)` against the broadcaster EOA balance and `revert`s with a top-up message (broadcasting NOTHING) when it won't fit. Only on a fit does it deploy `new CascadeAccount` directly (factory skipped per §8), fund it minimally, build/sign the eth-signed `getUserOpHash`, and call `ep.handleOps(ops, payable(broadcaster))` once with a two-call `executeBatch` of the EXISTING live skills. No `register()` anywhere; chainId 688689 asserted before any broadcast.
- Ran the gate against the live node: at the reported **10 gwei** the estimate is **0.0188 PHRS** vs a **0.004318 PHRS** balance → **LIVE BLOCKED**, shortfall **≈ 0.01448 PHRS**, no broadcast, balance unchanged.
- `LIVE_RESULT.md`: records the captured balance, node gas price, full cost estimate, exact shortfall + top-up address/amount, the 1-gwei vs 2-gwei analysis (neither is a usable escape — `forge script` ignores `--gas-price` and the proven-acceptable 2 gwei still overshoots), and states plainly that AA-01/02/03 are already met by the Wave 2 fork proof.
- Confirmed live Cascade `skillCount()==3` after the run — no re-registration occurred.

## Task Commits

1. **Task 1: LiveBundle script with STOP-clean pre-flight budget gate** — `ff91c62` (feat)
2. **Task 2: Run the gated live step / record the budget block** — `67dd960` (docs)

## Files Created/Modified
- `script/LiveBundle.s.sol` — env-driven (PRIVATE_KEY/GAS_PRICE_WEI/SKILL_ID_*/PRICE_* with live defaults); pre-flight gate → optional direct-deploy + minimal-fund + one self-bundled `handleOps`; mirrors the Wave 2 pack/sign flow.
- `.planning/phases/03-smart-account-agents-erc-4337/LIVE_RESULT.md` — the honest BLOCKED-on-budget outcome with top-up details.

## Decisions Made
- **Prices from env, not on-chain.** `Cascade.skills` is `internal` (no public price getter — exactly what 03-02 documented), so the two target prices come from env with the known live A→B→C defaults (id1=A price 0, id3=C price 0.001 PHRS). Cascade's on-chain `require(msg.value == price)` remains the fail-safe, so a wrong env price would revert rather than mispay.
- **Direct deploy, not factory.** Per RESEARCH §8 mitigation 3, the live step does `new CascadeAccount(ep, owner)` (empty initCode) to cut the heaviest gas item; the factory/initCode path stays proven on the Wave 2 fork.
- **Upper-bound gas in the gate.** 500k deploy + 600k handleOps so the gate biases toward STOPPING; a real over-budget spend is the failure mode to avoid.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Adaptation] Skill prices sourced from env rather than read on-chain**
- **Found during:** Task 1
- **Issue:** The plan's read_first suggested reading the two skill prices on-chain at runtime, but `Cascade.skills` is `internal` with no public price getter (the same blocker 03-02 surfaced), so a live price cannot be read.
- **Fix:** Read PRICE_1/PRICE_2 from env with the known live demo defaults; Cascade's on-chain exact-`msg.value` check stays as the fail-safe (a mismatch reverts before any settlement).
- **Files modified:** script/LiveBundle.s.sol
- **Commit:** ff91c62

**2. [Rule 3 - Blocking] Stack-too-deep in run()**
- **Found during:** Task 1
- **Issue:** Building + signing the op inline in `run()` (alongside all the gate locals) tripped solc "Stack too deep" without `--via-ir`.
- **Fix:** Factored the live path into `_broadcastLive` + `_buildSignedOp` helpers; `run()` now holds only the gate locals. Compiles cleanly.
- **Files modified:** script/LiveBundle.s.sol
- **Commit:** ff91c62

## Issues Encountered
None blocking. The pre-flight gate behaved exactly as designed — STOP-clean at the node's real 10 gwei. No funds were spent (balance verified unchanged at 4317764000000000 wei before and after).

## Threat Model Coverage
- **T-03-08 (DoS / self-inflicted over-spend):** gate STOPS before any broadcast when estimate × price + value > balance; account deployed directly (no factory) to shrink footprint; verified no half-spend (balance unchanged) — mitigated.
- **T-03-09 (Info disclosure / PRIVATE_KEY):** read from `.env` via `vm.envUint` only; never echoed (outputs were redacted at runtime); never hardcoded or committed — mitigated.
- **T-03-10 (Tampering / wrong msg.value):** prices env-driven with the live defaults; Cascade's on-chain `msg.value==price` reverts on mismatch (fail-safe) — mitigated.
- **T-03-SC (supply chain):** no installs; forge-std + Wave 1 first-party contracts + real on-chain EntryPoint/Cascade only — accepted.

## User Setup Required
To run the bonus live step later: top up `0x67680b09bB422cC510669bd5208D947066D4aeaE` by ≈ 0.0145 PHRS (full demo at 10 gwei), then re-run `forge script script/LiveBundle.s.sol --rpc-url atlantic_testnet` to re-check the gate. Otherwise no setup — the Wave 2 fork proof is the deliverable.

## Next Phase Readiness
- AA-01/02/03 fully proven on the Wave 2 fork against the real EntryPoint; this live step is bonus, currently budget-blocked (not correctness-blocked).
- Phase 3 can close on the fork proof; Phase 4 (submission) is unblocked. The live demo can be captured on-chain later with a small top-up using the recorded instructions.

---
*Phase: 03-smart-account-agents-erc-4337*
*Completed: 2026-06-07*

## Self-Check: PASSED

`script/LiveBundle.s.sol`, `LIVE_RESULT.md`, and `03-03-SUMMARY.md` all verified present on disk; both task commits (`ff91c62`, `67dd960`) verified in git log. `forge build` reports "Compiler run successful"; the pre-flight gate STOPPED cleanly at the node's real 10 gwei (no broadcast, balance unchanged at 4317764000000000 wei); live Cascade `skillCount()==3` (no re-registration).
