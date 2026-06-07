---
phase: 01-recursive-royalty-core
plan: 03
subsystem: live-demo
tags: [solidity, foundry, cast, atlantic-testnet, royalties, on-chain-demo, pharos]

# Dependency graph
requires:
  - "src/Cascade.sol — register/invoke/claim/balances API (from 01-01)"
  - "script/{Deploy,Register,Invoke,Claim,DemoTree}.s.sol — broadcast surface (from 01-02)"
provides:
  - "Live Cascade deployment on atlantic-testnet at 0xd41C32562D0BE20D354120E1De11A91abC340F50 (DEMO-01)"
  - "On-chain A->B->C tree + one paid invoke fanning royalties to 3 creators + a claim (DEMO-02)"
  - ".planning/phases/01-recursive-royalty-core/DEMO_RESULT.md — all addresses, skill ids, tx hashes, before/after balances, explorer links"
affects:
  - "Phase 4 (Submission: the live contract address + tx hashes are the on-chain proof point for the DoraHacks submission)"
  - "README / demo video (can cite the live address + explorer links)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Live broadcast via cast send (--legacy --gas-price 2gwei) rather than forge script — forge script ignored --gas-price and produced a failed 10-gwei CREATE"
    - "Fresh per-creator wallets funded minimally from the payer so each creator signs its own register tx on a public testnet (the CREATOR_*_KEY override 01-02 designed)"
    - "0x-prefix the .env PRIVATE_KEY at runtime for forge vm.envUint compatibility; key value never printed"

key-files:
  created:
    - ".planning/phases/01-recursive-royalty-core/DEMO_RESULT.md"
  modified: []

key-decisions:
  - "Chose 2 gwei gas price (2x the 1 gwei base fee); at the 10 gwei cast-gas-price suggestion the ~1.2M-gas demo would have exceeded the 0.01 PHRS budget"
  - "Generated 3 fresh creator wallets instead of the script's anvil-default keys — the test-mnemonic accounts are shared by every user of that mnemonic on this public chain (racy), unsafe for an irreversible demo"
  - "Switched live broadcasts from forge script to cast send after forge script sent a failed CREATE at 10 gwei (ignored --gas-price)"

patterns-established:
  - "Pre-flight gates the spend: chainId/balance/gas-budget/green-suite confirmed before any funded tx; STOP-clean rule if budget short"
  - "Every live tx recorded with status, gasUsed, and an explorer link in DEMO_RESULT.md; PRIVATE_KEY value never echoed"

requirements-completed: [DEMO-01, DEMO-02]

# Metrics
duration: ~18min
completed: 2026-06-07
---

# Phase 1 Plan 03: Live Testnet Deploy + On-Chain A→B→C Demo Summary

**Cascade is live on atlantic-testnet at `0xd41C32562D0BE20D354120E1De11A91abC340F50`: the A→B→C tree (skillCount==3) is registered from three distinct funded creator wallets, and one paid `invoke(C)` of 0.001 ether fanned royalties up the whole tree in a single transaction — A +0.0002, B +0.0003, C +0.0005 ether, summing exactly to the price — after which creatorA claimed its accrued 0.0002 ether to its own wallet, all verifiable on the explorer. The Phase 1 milestone is now proven end-to-end on-chain (DEMO-01 + DEMO-02).**

## Performance

- **Duration:** ~18 min
- **Completed:** 2026-06-07
- **Tasks:** 3 (+ pending human-verify checkpoint)
- **Files created/modified:** 1 (DEMO_RESULT.md)

## Accomplishments
- **Pre-flight (Task 1):** Confirmed chainId 688689 (testnet, never mainnet), payer balance 0.01 PHRS, and a green local suite (14/14 tests). Measured the demo gas path and chose **2 gwei** (2× the 1 gwei base fee) so the full ~1.2M-gas demo costs a small fraction of budget — at the 10 gwei `cast gas-price` suggestion it would have *exceeded* the 0.01 PHRS budget. Generated three fresh, fully-controlled creator wallets (keys in `/tmp` only, never committed/printed).
- **Deploy + register (Task 2, DEMO-01):** Deployed `Cascade` live (tx `0x5669ab…`, gas 545,837) at `0xd41C32562D0BE20D354120E1De11A91abC340F50`; `cast code` non-empty, `skillCount()` == 3. Registered A (id 1, leaf), B (id 2, dep [1]@4000bps), C (id 3, price 0.001e, dep [2]@5000bps), each broadcast from its own funded creator wallet.
- **Invoke + claim (Task 3, DEMO-02):** One `invoke{value:0.001 ether}(3)` (tx `0x67bfa7…`, gas 127,281) emitted one `Invoked` + three `RoyaltyAccrued` events and raised all three creator balances on-chain — deltas A +2e14 / B +3e14 / C +5e14 wei, **Σ == 1e15 wei == the invoke price exactly**, reproducing the local fork result on the live chain. creatorA then `claim()`-ed (tx `0xe90d8b…`): accrued balance `2e14 → 0`, the full 2e14 transferred out (wallet net rose by 2e14 minus the claim's own gas).
- **Full artifact trail:** `DEMO_RESULT.md` records the deployed address, three skill ids, every funding/deploy/register/invoke/claim tx hash with explorer links, and the before/after balance table. The funded `PRIVATE_KEY` value was never printed.

## Task Commits

1. **Task 1: Pre-flight (balance, gas budget, green suite)** - `97bf3f0` (chore)
2. **Task 2: Deploy Cascade + register A→B→C tree (DEMO-01)** - `85d1da0` (feat)
3. **Task 3: Live invoke fans royalties to 3 creators + claim (DEMO-02)** - `9e17095` (feat)

**Plan metadata:** see final docs commit.

## Files Created/Modified
- `.planning/phases/01-recursive-royalty-core/DEMO_RESULT.md` - Full on-chain demo record: deployed address, skill ids, all tx hashes + explorer links, before/after balances + deltas, gas/budget accounting, and the two diagnosed deviations.

## Decisions Made
- **Gas price 2 gwei (not 10):** The network base fee is 1 gwei; `cast gas-price` suggested a conservative 10 gwei which would have pushed the ~1.2M-gas demo over the 0.01 PHRS budget. 2 gwei (2× base fee) was accepted by the chain on every tx and kept total spend ~0.0042 PHRS.
- **Fresh creator wallets over the script's anvil-default keys:** On a public testnet each creator must sign its own `register` tx (needs gas), and the standard test-mnemonic accounts are shared/racy across all users of that mnemonic. Three fresh wallets were generated and minimally funded from the payer — exactly the `CREATOR_*_KEY` live-wave override that 01-02 designed (same contract code, only env differs).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `.env` PRIVATE_KEY missing `0x` prefix broke `forge` `vm.envUint`**
- **Found during:** Task 2 (first deploy attempt)
- **Issue:** `forge script` reverted with `vm.envUint: failed parsing $PRIVATE_KEY ... missing hex prefix ("0x")`. `cast` tolerates a bare hex key, `forge` does not.
- **Fix:** `0x`-prefix the key at runtime before passing to the env (value never printed). No code/.env change.
- **Files modified:** none (runtime only).

**2. [Rule 3 - Blocking] `forge script --broadcast` ignored `--gas-price`, sent a failed 10-gwei CREATE**
- **Found during:** Task 2 (deploy)
- **Issue:** The first deploy tx (`0x5c7ac69c…`) landed but **reverted (status 0, 21,000 gas)** at `0x30F710b2…` — `forge script` broadcast the CREATE at the RPC-suggested 10 gwei instead of the requested 2 gwei, and the creation failed at the intrinsic-gas boundary. Wasted ~0.0003 PHRS, produced no contract.
- **Fix:** Switched all live broadcasts from `forge script` to direct `cast send` (the reliable path the funding txs used) with explicit `--legacy --gas-price 2gwei --gas-limit`. Simulated the CREATE via `cast call --create` (clean) and gas-estimated (668K) before sending. The redeploy (`0x5669ab…`) succeeded at the new address. The forge script *contracts* are unchanged; only the broadcast mechanism differs.
- **Files modified:** none (broadcast mechanism only; documented in DEMO_RESULT.md).

## Issues Encountered
- The one wasted forge CREATE (item 2 above) cost ~0.0003 PHRS but did not threaten the budget; the remaining headroom absorbed it and the full demo still completed with ~0.0058 PHRS left.
- The deployed address from the successful run (`0xd41C3256…`) differs from the forge-script simulation print (`0x30F710b2…`, which is the address of the *failed* tx) — the recorded canonical address is the one with code and skillCount==3.

## User Setup Required
None — the demo is complete and live. To verify, open `DEMO_RESULT.md` and follow the explorer links (see the human-verify checkpoint below). The fresh creator wallet keys live only in `/tmp/cascade-demo/` and are intentionally not committed.

## Next Phase Readiness
- DEMO-01 and DEMO-02 are proven on the live atlantic-testnet — the core royalty innovation works on-chain, end-to-end. This is the submittable proof point for Phase 4.
- The live contract address and tx hashes are recorded and can be cited directly in the README and demo video.
- No blockers. (Pending: the human-verify checkpoint confirming the on-chain demo on the explorer.)

## Self-Check: PASSED

All claimed files exist (`DEMO_RESULT.md`, `01-03-SUMMARY.md`) and all three task commits are present (`97bf3f0`, `85d1da0`, `9e17095`). On-chain re-verification confirms `skillCount() == 3` and creatorA's accrued balance is `0` post-claim.

---
*Phase: 01-recursive-royalty-core*
*Completed: 2026-06-07*
