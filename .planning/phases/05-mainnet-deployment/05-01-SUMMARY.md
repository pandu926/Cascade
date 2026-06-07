---
phase: 05-mainnet-deployment
plan: 01
subsystem: infra
tags: [foundry, forge, cast, pharos-mainnet, blockscout, socialscan, solidity, deployment, verification]

# Dependency graph
requires:
  - phase: 04-contract-hardening
    provides: hardened Cascade.sol (NatSpec, custom errors, 41 tests green, slither 0 CRIT/HIGH)
provides:
  - Cascade deployed + source-verified on Pharos mainnet at 0x31bE4C6B5711913D818e377ebd809d4397FF3c84
  - MAINNET_RESULT.md single source of truth (address, deploy tx, balances, gas, verification status, explorer links)
affects: [05-02-royalty-demo, 05-03-4337-demo, 06-visualization-docs-submission]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-flight gate (chainId==1672 + balance read) before any real-money broadcast"
    - "forge create --legacy --gas-price for mainnet deploy (forge script ignores --gas-price)"
    - "Key normalized into shell var PK=0x${PRIVATE_KEY#0x}, never echoed"

key-files:
  created: [MAINNET_RESULT.md]
  modified: []

key-decisions:
  - "Deployed via forge create (not forge script) with explicit --legacy --gas-price 10000000000 per prior-phase finding that forge script ignores --gas-price"
  - "RANK 1 verification (blockscout verifier, no API key) succeeded first try — no fallback needed"

patterns-established:
  - "Pre-flight real-money gate: cast chain-id MUST == 1672 + balance read BEFORE broadcast"
  - "Mainnet artifacts recorded to committed MAINNET_RESULT.md as single source of truth"

requirements-completed: [MAIN-01]

# Metrics
duration: 9min
completed: 2026-06-08
---

# Phase 5 Plan 01: Mainnet Deploy + Verify Cascade Summary

**Cascade deployed to Pharos mainnet at `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` and source-verified (green) on pharosscan via the SocialScan Blockscout command API — first-try RANK 1, no fallback.**

> **Deployed CASCADE address (for 05-02 / 05-03 `CASCADE` env var): `0x31bE4C6B5711913D818e377ebd809d4397FF3c84`**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-08
- **Completed:** 2026-06-08
- **Tasks:** 2
- **Files modified:** 1 (MAINNET_RESULT.md, created)

## Accomplishments
- Pre-flight gate passed: `cast chain-id` == 1672 confirmed and deployer balance (1.99961 PROS) read **before** broadcast — no half-spend risk.
- Cascade deployed to mainnet via `forge create --legacy --gas-price 10000000000`: tx `0x4fc8db37b7693412e76a6743b6335be8b4ceae079a99963e3924ee37875eee1d`, status `1`, gasUsed `510381`, cost `0.00510381` PROS.
- Post-deploy on-chain checks all pass: `cast code` non-empty (4231 hex chars), `skillCount()` == `0` (fresh registry), receipt status `1`.
- Source verified at RANK 1 (Blockscout verifier, no API key) → `Pass - Verified`; verified source live on pharosscan.
- MAINNET_RESULT.md created as the committed single source of truth (address, tx, before/after balances, gas, verification GUID, explorer links).

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-flight gate + deploy Cascade to mainnet** - `8191b77` (feat)
2. **Task 2: Verify Cascade source on the explorer (RANK 1)** - `a4d925f` (feat)

## Files Created/Modified
- `MAINNET_RESULT.md` - Single source of truth: deployed address, deploy tx, before/after deployer balance, gas, verification status (RANK 1 verified), explorer + SocialScan links.

## Decisions Made
- Used `forge create` with explicit `--legacy --gas-price 10000000000` rather than `forge script --broadcast`, because a prior phase found `forge script` silently ignored `--gas-price` and sent a failed CREATE. `forge create` honored the 10 gwei floor cleanly.
- Verification landed on RANK 1 (no API key needed) — the SocialScan command API accepted the keyless Blockscout submission and returned `Pass - Verified`, so no dummy key / URL-suffix / commit-version / flatten fallbacks were exercised.
- Build metadata confirmed compiler `0.8.24+commit.e11b9ed9`, matching the RESEARCH assumption (would have been needed only for RANK 4).

## Deviations from Plan

None - plan executed exactly as written. Both tasks completed on their primary path (RANK 1 verify), no auto-fixes required.

## Issues Encountered
None. `forge build` emitted mixed-case-variable lint *notes* (test files), which are advisory only and do not affect compilation or the deployed bytecode.

## Known Stubs
None — MAINNET_RESULT.md contains live on-chain data only (real address, tx hash, balances, verification record). No placeholders.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- **05-02 (royalty demo)** and **05-03 (4337 demo)** can reuse the deployed Cascade at `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` via the `CASCADE` env var — do NOT redeploy.
- Deployer balance after deploy: `1.994506190000000000` PROS — ample for the downstream creator stipends + invoke/UserOp values.
- EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) confirmed present on mainnet for 05-03.

---
*Phase: 05-mainnet-deployment*
*Completed: 2026-06-08*

## Self-Check: PASSED
- FOUND: MAINNET_RESULT.md
- FOUND: .planning/phases/05-mainnet-deployment/05-01-SUMMARY.md
- FOUND commit: 8191b77 (Task 1 deploy)
- FOUND commit: a4d925f (Task 2 verify)
