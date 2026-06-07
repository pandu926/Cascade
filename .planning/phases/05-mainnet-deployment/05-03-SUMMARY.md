---
phase: 05-mainnet-deployment
plan: 03
subsystem: account-abstraction
tags: [erc-4337, entrypoint-v0.7, foundry, forge-script, cast, pharos-mainnet, smart-account, handleops, packed-useroperation, live-demo]

# Dependency graph
requires:
  - phase: 05-mainnet-deployment
    provides: Cascade deployed + source-verified on mainnet at 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 (05-01); A→B→C skills id1/2/3 registered (05-02)
  - phase: 03-smart-account-agents-erc-4337
    provides: fork-proven v0.7 mechanics (CascadeAccount, AccountFactory, PackedUserOperation, IEntryPoint) + script/LiveBundle.s.sol testnet driver
provides:
  - Live mainnet ERC-4337 demo: AccountFactory 0x904935BA1417FC35591019A0fC54c670DA824c60 + CascadeAccount 0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1
  - ONE self-bundled handleOps (tx 0x1f3cec93…) batched TWO Cascade.invoke calls via the real EntryPoint v0.7; both creators rose, Σ == PRICE_C
  - script/LiveBundleMainnet.s.sol — mainnet-guarded (chainId 1672) 4337 batch driver
  - MAINNET_RESULT.md MAIN-03 section + Phase 5 complete summary (single source of truth for Phase 6)
affects: [06-visualization-docs-submission]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mainnet-guarded sibling driver (require(block.chainid==1672)) instead of weakening the frozen testnet LiveBundle.s.sol guard (688689)"
    - "Full forge-script dry-run against the mainnet fork (no --broadcast) as a final pre-broadcast safety check — runs the entire factory+account+handleOps flow through the real EntryPoint bytecode"
    - "Idempotent retry: reuse deployed FACTORY via env + shortfall-only account funding, so a re-run after a handleOps revert never double-deploys or double-funds"
    - "--gas-estimate-multiplier to clear the EntryPoint AA95 floor (outer bundler tx must forward verificationGasLimit+callGasLimit+preVerificationGas)"

key-files:
  created: [script/LiveBundleMainnet.s.sol]
  modified: [MAINNET_RESULT.md]

key-decisions:
  - "Factory-preferred deploy (AccountFactory + createAccount) rather than direct new CascadeAccount — budget ample, and it proves AA-01 live on mainnet"
  - "Batched invoke(B id2, value 0) + invoke(C id3, value 1e15): two Invoked events in one UserOp; C's fan-out raises A/B/C, both invoked skills' creators rise"
  - "New mainnet driver hard-guarded to 1672; testnet LiveBundle.s.sol (688689 guard) left byte-for-byte untouched"
  - "First handleOps hit AA95 out-of-gas (forge sized the bundler tx from eth_estimateGas, below the EntryPoint 680k forwarded-gas floor); fully rolled back (no half-spend), resolved with --gas-estimate-multiplier 500"

patterns-established:
  - "Pre-flight budget gate + full mainnet-fork dry-run BOTH run before any real-money 4337 broadcast"
  - "Diagnose-before-retry on a failed multi-step on-chain flow: confirm rollback (nonce/deposit/balance) on-chain before re-broadcasting"

requirements-completed: [MAIN-03]

# Metrics
duration: 16min
completed: 2026-06-08
---

# Phase 5 Plan 03: Live ERC-4337 Batch Demo on Mainnet Summary

**A live Pharos-mainnet `CascadeAccount` (deployed via an `AccountFactory`) batched TWO `Cascade.invoke` calls into ONE self-bundled `handleOps` through the real EntryPoint v0.7 — both invoked creators rose (B +0.0003, C +0.0005 PROS) with Σ == PRICE_C exactly, proving the account-agnostic claim with real money.**

> **4337 addresses (for Phase 6): factory `0x904935BA1417FC35591019A0fC54c670DA824c60`, account `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1`, handleOps tx `0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90`.**

## Performance

- **Duration:** ~16 min
- **Started / Completed:** 2026-06-08
- **Tasks:** 2 auto + 1 human-verify checkpoint
- **Files:** 1 created (`script/LiveBundleMainnet.s.sol`), 1 modified (`MAINNET_RESULT.md`)

## Accomplishments
- Pre-flight gate passed before any broadcast: `cast chain-id` == 1672, `cast code` non-empty on both CASCADE and the EntryPoint v0.7, deployer balance `1.9316` PROS vs estimated `0.0258` PROS.
- Created `script/LiveBundleMainnet.s.sol` — a NEW mainnet-guarded (`require(block.chainid == 1672)`) sibling that mirrors the frozen testnet `LiveBundle.s.sol` v0.7 mechanics verbatim; reads CASCADE/skills/factory/salt from env (no hardcoded mainnet Cascade). The testnet driver's 688689 guard was left untouched.
- Ran a full `forge script` dry-run against the mainnet fork (no broadcast) — the entire factory → createAccount → fund → handleOps flow settled clean through the real EntryPoint bytecode before spending a wei.
- Deployed live on mainnet: `AccountFactory` `0x9049…` (tx `0x0adbda11…`) and `CascadeAccount` `0xfe93…` via `createAccount` (tx `0x316dfbf8…`); CREATE2 determinism confirmed (`factory.getAddress` == deployed account).
- ONE self-bundled `handleOps` (tx `0x1f3cec93…`, status 1) batched `executeBatch([CASCADE,CASCADE],[0,1e15],[invoke(2),invoke(3)])`: 2 `Invoked` + 3 `RoyaltyAccrued` + 1 `UserOperationEvent` in a single tx; the smart account is the `msg.sender`/payer of both invokes.
- Creator deltas A +2e14, B +3e14, C +5e14; Σ == `1000000000000000` wei == PRICE_C exactly. Recorded all addresses, tx hashes, before/after balances, deltas, decoded events, and explorer links to MAINNET_RESULT.md, plus a Phase 5 complete summary table.

## Task Commits

1. **Task 1: Mainnet-guarded driver + deploy factory + account** - `cfd366d` (feat)
2. **Task 2: Self-bundle handleOps batching two invokes; record deltas** - `37f6ded` (feat)

## Files Created/Modified
- `script/LiveBundleMainnet.s.sol` *(created)* — mainnet-guarded 4337 batch driver: pre-flight gate, factory deploy/reuse, idempotent createAccount, shortfall-only funding, sign + self-bundle ONE `handleOps` of two invokes.
- `MAINNET_RESULT.md` *(modified)* — new "MAIN-03 4337 Demo" section (deploy txs, handleOps tx, creator deltas, decoded events, AA95 diagnosis, explorer links) + a "Phase 5 Complete" summary table.

## Decisions Made
- **Factory-preferred deploy** (vs direct `new CascadeAccount` used on the testnet footprint-shrink path): budget is ample on mainnet, and deploying through the factory proves AA-01 (an agent can be a deployed smart account via a simple factory) live.
- **Batched `invoke(2)` + `invoke(3)`**: two `Invoked` events in one UserOp; `invoke(3)`'s recursive fan-out credits A/B/C, so both invoked skills' creators (B, C) rise. `invoke(2)` carries value 0 (B is free) — its `Invoked` event is the proof the second batched call executed.
- **New mainnet driver, frozen testnet driver untouched**: don't weaken a safety guard; the 1672 guard lives in a separate file from the 688689 guard.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] `forge build` stack-too-deep in `run()`**
- **Found during:** Task 1 (first compile of the new driver)
- **Issue:** `run()` had too many local variables (env reads + gate math), tripping `Stack too deep` under the default (non-via-ir) pipeline.
- **Fix:** Assembled env inputs directly into a `LiveParams memory` struct and moved the budget gate into a `_gateAndBroadcast(p)` helper, shrinking `run()`'s stack. No behavior change.
- **Files modified:** `script/LiveBundleMainnet.s.sol`
- **Commit:** `cfd366d`

**2. [Rule 1 - Bug] First handleOps reverted `AA95 out of gas`**
- **Found during:** Task 2 (first real broadcast)
- **Issue:** `forge script` sized the `handleOps` broadcast tx from `eth_estimateGas` (~260k), below the EntryPoint's AA95 floor — the outer bundler tx must forward at least `verificationGasLimit + callGasLimit + preVerificationGas` (200k+400k+80k = 680k) to the inner op. Validation itself succeeded (ecrecover → owner, prefund deposited); only the outer gas ceiling tripped (tx `0x48fce20a…`, status 0).
- **Fix:** Confirmed the failed tx fully rolled back on-chain (nonce 0, EntryPoint deposit 0, account balance `7.8e15` intact — **no half-spend**), then re-ran with `--gas-estimate-multiplier 500` and `FACTORY` env set so the idempotent `createAccount` returned the funded account (funding auto-skipped). The retry settled clean (tx `0x1f3cec93…`, status 1).
- **Files modified:** none (runtime flag + record); MAINNET_RESULT.md documents the diagnosis.
- **Commit:** `37f6ded`

## Issues Encountered
- The `forge` broadcast JSON labeled tx hashes optimistically and the labels were scrambled (e.g. the failed handleOps was mislabeled as a transfer-to-account). Resolved by treating `cast receipt` ground truth (`to`/`contractAddress`/`status`) as authoritative for every hash rather than the JSON `function` field.

## Known Stubs
None — MAINNET_RESULT.md contains live on-chain data only (real addresses, tx hashes, balances, decoded events). No placeholders.

## User Setup Required
None.

## Next Phase Readiness
- **Phase 6 (visualization / docs / submission):** MAINNET_RESULT.md is the single source of truth. All three headline artifacts are live and recorded: MAIN-01 (Cascade deployed + verified), MAIN-02 (recursive royalty demo), MAIN-03 (self-bundled 4337 batch).
- The smart account `0xfe93…` is drained to 0 (prefund + invoke value consumed); the factory `0x9049…` remains usable for further `createAccount` calls if a future demo needs it.

---
*Phase: 05-mainnet-deployment*
*Completed: 2026-06-08*

## Self-Check: PASSED
- FOUND: script/LiveBundleMainnet.s.sol
- FOUND: .planning/phases/05-mainnet-deployment/05-03-SUMMARY.md
- FOUND: MAINNET_RESULT.md
- FOUND commit: cfd366d (Task 1 driver + deploy)
- FOUND commit: 37f6ded (Task 2 handleOps batch + deltas)
- ON-CHAIN: factory 0x9049… code 6515 hex chars; account 0xfe93… code 4577 hex chars
- ON-CHAIN: handleOps tx 0x1f3cec93… status 1 (success), 2 Invoked + 3 RoyaltyAccrued events
