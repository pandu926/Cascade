---
phase: 05-mainnet-deployment
plan: 02
subsystem: payments
tags: [cast, pharos-mainnet, solidity, royalty, recursive-split, RoyaltyAccrued, live-demo]

# Dependency graph
requires:
  - phase: 05-mainnet-deployment
    provides: Cascade deployed + source-verified on mainnet at 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 (skillCount 0)
provides:
  - Live mainnet recursive-royalty demo: one invoke pays 3 distinct creators proportionally (Σ == PRICE_C exactly)
  - Three registered skills on the mainnet Cascade for 05-03 reuse — A=id1 (leaf), B=id2 (dep A 40%), C=id3 (dep B 50%, price 0.001 PROS)
  - MAINNET_RESULT.md MAIN-02 section: 3 creators, funding/register/invoke tx hashes, before/after balances, 3 RoyaltyAccrued amounts, explorer links
affects: [05-03-4337-demo, 06-visualization-docs-submission]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-broadcast guard: chainId==1672 + cast code <CASCADE> non-empty asserted BEFORE any spend — neutralizes DemoTree's silent fresh-deploy fallback"
    - "Discrete cast send per signer (3 creators + payer) with --legacy --gas-price 10 gwei, reading new id from skillCount() after each register"
    - "Fresh cast wallet keypairs (not public test mnemonic) for live-chain demo creators; keys gitignored chmod 600 outside repo, never written to records"

key-files:
  created: []
  modified: [MAINNET_RESULT.md]

key-decisions:
  - "Used discrete cast send (not forge script DemoTree) for the live run — the prior-phase finding that forge script ignores --gas-price, combined with DemoTree's chainid-less fresh-deploy fallback, made the explicit cast path the safer reuse-guaranteed choice"
  - "Generated 3 fresh keypairs instead of the public anvil test mnemonic — well-known derived addresses risk auto-sweep on a live chain; fresh keys eliminate that"
  - "skillCount 0->3 on the MAIN-01 address is the on-chain proof of reuse (no redeploy)"

patterns-established:
  - "Pre-broadcast guard (chainId + bytecode-present assertion) gates every real-money broadcast batch independently"
  - "Conservation check on-chain: Σ(creator balance deltas) == PRICE_C exactly proves no wei created or lost in the fan-out"

requirements-completed: [MAIN-02]

# Metrics
duration: 11min
completed: 2026-06-08
---

# Phase 5 Plan 02: Live Mainnet Recursive Royalty Demo Summary

**One live Pharos-mainnet `invoke` of an A→B→C tree on the source-verified MAIN-01 Cascade paid three distinct creators 0.0002 / 0.0003 / 0.0005 PROS in a single tx — Σ == 0.001 PROS exactly, with no redeploy (skillCount 0→3).**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-06-08
- **Completed:** 2026-06-08
- **Tasks:** 2
- **Files modified:** 1 (MAINNET_RESULT.md)

## Accomplishments
- Pre-flight + pre-broadcast guards passed: `cast chain-id` == 1672 and `cast code 0x31bE…3c84` non-empty (4231 hex) confirmed **before** any spend, so DemoTree's silent `if (existing == address(0)) new Cascade()` fresh-deploy fallback could never fire.
- Three fresh creator EOAs derived (keys gitignored, never recorded) and funded 0.02 PROS each from the deployer — all 3 funding receipts status 1.
- A→B→C registered on the **reused** MAIN-01 Cascade from three distinct creators: A=id1 (leaf, price 0), B=id2 (dep A 40%), C=id3 (dep B 50%, price 0.001 PROS). `skillCount()` went 0→3 — on-chain proof of reuse, no redeploy.
- One payer `invoke(3)` with `msg.value == 0.001 PROS` (status 1) fanned royalties up the tree: A +0.0002, B +0.0003, C +0.0005 PROS; all three balances rose; Σ deltas == `1000000000000000` wei exactly (conservation holds).
- Decoded the three `RoyaltyAccrued` events from the invoke receipt and recorded every funding/register/invoke tx hash + before/after balances + explorer links to MAINNET_RESULT.md.

## Task Commits

Each task was committed atomically:

1. **Task 1: Derive + fund three creator EOAs (pre-flight gated)** - `3b78666` (feat)
2. **Task 2: Run live A→B→C register + single invoke, record deltas** - `7e33bd7` (feat)

## Files Created/Modified
- `MAINNET_RESULT.md` - New "MAIN-02 Royalty Demo" section: pre-flight + pre-broadcast guard results, three creator addresses + funding tx hashes, A→B→C register tx hashes + skill ids, the single invoke tx hash, before/after balances + three deltas, the three RoyaltyAccrued amounts with the exact Σ==PRICE_C conservation check, and explorer links for every tx.

## Decisions Made
- **Discrete `cast send` over `forge script DemoTree`** for the live run. The plan sanctioned this fallback explicitly; the prior-phase finding that `forge script` ignores `--gas-price` (sending a failed CREATE), combined with DemoTree having no chainid guard and a silent fresh-deploy branch, made per-signer `cast send` with `--legacy --gas-price 10000000000` the safer, reuse-guaranteed path. The on-chain numbers (split, ids, events) are identical to the DemoTree constants.
- **Fresh `cast wallet new` keypairs** rather than the public anvil test mnemonic. Well-known derived addresses can be auto-swept on a live chain; fresh keys eliminate that risk. Keys live only in a `chmod 600` gitignored file outside the repo and are never echoed or written to records.
- **`skillCount()` 0→3 as the reuse proof** — the cleanest on-chain signal that the MAIN-01 contract was reused and nothing was redeployed.

## Deviations from Plan

None - plan executed exactly as written. Both tasks completed on their primary intent (guards → fund → register → invoke → record). The `cast send` path was a plan-sanctioned alternative to `forge script`, not a deviation. No auto-fixes (Rules 1-3) were needed.

## Issues Encountered
- A throwaway shell helper persisted `cast call` output that included its human-readable `[2e14]` suffix into the keyfile, which broke an inline arithmetic step. Resolved by stripping the suffix and recomputing; the on-chain values were never in doubt (before-balances were all 0, after-balances read 2e14/3e14/5e14, and the decoded RoyaltyAccrued events independently confirmed the split). No on-chain impact.

## Known Stubs
None — MAINNET_RESULT.md contains live on-chain data only (real addresses, tx hashes, balances, decoded events). No placeholders.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- **05-03 (4337 demo)** can reuse the three skills registered here on the same Cascade: **A=id1, B=id2, C=id3** (C has price 0.001 PROS) — or register a fresh small pair. The batched UserOp would call `Cascade.invoke` twice.
- Deployer balance after MAIN-02: `1.931603440000000000` PROS — ample for the 05-03 account deploy + 2 invoke values + EntryPoint prefund.
- The three creator EOAs each still hold ~0.02 PROS (minus a register tx of gas for B and C) on mainnet; keys remain in the gitignored `~/.demo-creators.env` if a follow-up needs them.

---
*Phase: 05-mainnet-deployment*
*Completed: 2026-06-08*

## Self-Check: PASSED
- FOUND: .planning/phases/05-mainnet-deployment/05-02-SUMMARY.md
- FOUND: MAINNET_RESULT.md (contains 3 RoyaltyAccrued event records)
- FOUND commit: 3b78666 (Task 1 fund creators)
- FOUND commit: 7e33bd7 (Task 2 live royalty demo)
