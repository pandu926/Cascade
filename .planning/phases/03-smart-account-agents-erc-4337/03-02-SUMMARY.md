---
phase: 03-smart-account-agents-erc-4337
plan: 02
subsystem: testing
tags: [erc-4337, account-abstraction, fork-test, entrypoint-v0.7, handleops, foundry, aa24]

# Dependency graph
requires:
  - phase: 03-smart-account-agents-erc-4337
    plan: 01
    provides: "CascadeAccount + AccountFactory + v0.7 interfaces — the account/batch machinery the fork test drives"
  - phase: 01-recursive-royalty-core
    provides: "Cascade.sol (invoke(uint256) payable) — the account-agnostic target, unchanged"
provides:
  - "test/SmartAccount.fork.t.sol — 4 fork tests proving the self-bundled batch flow against the REAL EntryPoint v0.7"
  - "Primary zero-fund proof of AA-02 (batched UserOp) + AA-03 (settles via real EntryPoint, self-bundled) + CORE-07 parity"
affects: [03-03-live-bundle, erc-4337, smart-account]

# Tech tracking
tech-stack:
  added: [none — uses forge-std + Wave 1 first-party contracts + real on-chain EntryPoint/Cascade bytecode]
  patterns:
    - "Fork test against the REAL deployed EntryPoint v0.7 bytecode (most faithful 4337 proof; zero funds via vm.deal)"
    - "Register fresh skills on the REAL on-chain Cascade (price is internal/no getter) to control exact msg.value"
    - "Single shared _buildSignedOp helper packs gas fields + signs eth-signed getUserOpHash — no copy-paste across tests"

key-files:
  created:
    - "test/SmartAccount.fork.t.sol"
  modified: []

key-decisions:
  - "Registered our own skills on the live Cascade rather than reusing its 3 existing skills — Cascade.skills is internal (no public price getter), so reading a live price to set exact msg.value is impossible; register() is public and runs on the real on-chain bytecode, so this keeps the canonical EntryPoint + Cascade addresses while controlling exact prices"
  - "Matched FailedOp(0,'AA24 signature error') explicitly in the negative test (not a bare expectRevert) so a different revert code (AA21 prefund / AA13 initCode) fails loudly instead of masquerading as a pass"
  - "Set gasFees legacy-safe (maxFee == maxPriority, ≥2 gwei / 2×basefee) per RESEARCH Assumption A5 to clear the fork basefee"
  - "verificationGasLimit 600k covers the CREATE2 account deploy inside validation (RESEARCH Pitfall 4); the first op carries initCode, the account is deployed during validation"

patterns-established:
  - "ops[] wrapper + payable(address(this)) beneficiary for self-bundled handleOps in tests"
  - "Parity asserted via two structurally-identical sibling skills so the ONLY variable is caller type (smart account vs EOA)"

requirements-completed: [AA-02, AA-03]

# Metrics
duration: 4min
completed: 2026-06-07
---

# Phase 3 Plan 02: Self-Bundled Fork Test (real EntryPoint v0.7) Summary

**One self-bundled `handleOps` through the REAL Pharos EntryPoint v0.7 makes a counterfactual `CascadeAccount` pay two Cascade skills in a single batch — two creator balances rise summing exactly to the two prices — proven on a zero-fund fork against the canonical on-chain bytecode, plus a wrong-signer AA24 rejection and account-agnostic EOA parity.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-07T20:23:02Z
- **Completed:** 2026-06-07T20:27:00Z
- **Tasks:** 2
- **Files modified:** 1 created

## Accomplishments
- `test_smartAccount_batches_two_invokes`: a single self-bundled UserOp (with initCode) settles through the real EntryPoint `0x0000…da032`; the counterfactual account is deployed during validation (`sender.code.length > 0`) and two distinct creator balances rise summing exactly to `price1 + price2` (AA-02 + AA-03).
- `test_handleOps_settles_via_real_entrypoint`: named AA-03 settlement proof (single-skill op) — the artifact-contract test name the plan requires.
- `test_handleOps_rejects_wrong_signer`: an attacker-signed op reverts `FailedOp(0, "AA24 signature error")`; the account is NOT deployed and the target creator balance is unchanged (T-03-05 — wrong signer cannot settle).
- `test_account_agnostic_parity`: the smart-account invoke delta equals a direct EOA invoke delta for structurally-identical sibling skills (CORE-07; Cascade.sol unchanged).
- All 4 fork tests green against the real EntryPoint; full local suite 34/34; `Cascade.sol` byte-for-byte unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Happy-path fork test — one handleOps batches two invokes** - `c4066c2` (feat)
2. **Task 2: Negative AA24 wrong-signer + account-agnostic parity (+ named settlement test)** - `ccc63cc` (feat)

_TDD note: Task 1 was written and run against the fork first; it passed on the first real-EntryPoint run because the Wave 1 packing/prefix scheme was already locked. Task 2's negative test was driven by the exact `FailedOp` AA24 revert shape surfaced by the real EntryPoint._

## Files Created/Modified
- `test/SmartAccount.fork.t.sol` - 4 fork tests + shared `_buildSignedOp` / `_initCode` / `_batchInvoke` / `_singleInvoke` / `_ops` helpers; forks `atlantic_testnet`, binds the real EntryPoint + real Cascade, registers fresh skills for exact `msg.value`, signs the eth-signed-prefixed `getUserOpHash`, and self-bundles via `handleOps`.

## Decisions Made
- **Registered our own skills on the live Cascade** instead of reusing its 3 existing skills: `Cascade.skills` is `internal` with no public price getter, so reading a live price to match `invoke`'s exact-`msg.value` requirement is impossible. `register()` is public and executes against the real on-chain Cascade bytecode on the fork, so this keeps the canonical EntryPoint + Cascade addresses (the faithful path) while giving exact, known prices. The key_links to both real addresses are preserved.
- **Explicit AA24 reason match** in the negative test (`abi.encodeWithSignature("FailedOp(uint256,string)", 0, "AA24 signature error")`) rather than a bare `expectRevert`, so an unintended revert (AA21 prefund / AA13 initCode) fails loudly instead of passing as a false negative.
- **Legacy-safe gasFees** (`maxFee == maxPriority`, ≥ 2 gwei or 2×basefee) per RESEARCH Assumption A5 to clear the fork basefee deterministically.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Adaptation] Skill prices sourced via on-chain register() rather than reading live skill prices**
- **Found during:** Task 1
- **Issue:** The plan suggested reading each live skill's price at runtime to set `val[i]`, but `Cascade.skills` is `internal` with no public price getter, so a live price cannot be read on-chain.
- **Fix:** Register fresh leaf skills on the REAL on-chain Cascade (`register()` is public) with known prices, then invoke those. This still runs against the canonical Cascade + EntryPoint bytecode on the fork and keeps `msg.value` exact (no hardcoded value mismatching a live price — the price IS what we registered).
- **Files modified:** test/SmartAccount.fork.t.sol
- **Commit:** c4066c2

## Issues Encountered
None blocking. The fork RPC (`https://atlantic.dplabs-internal.com`) was reachable; the real EntryPoint validated and settled every positive op and rejected the wrong-signer op with the expected AA24 reason on the first run.

## Threat Model Coverage
- **T-03-05 (Spoofing/Tampering, UserOp signature):** `test_handleOps_rejects_wrong_signer` asserts a non-owner-signed op reverts FailedOp AA24 and does not settle — mitigated.
- **T-03-06 (Tampering, encoding fidelity):** the hash is taken from the real `ep.getUserOpHash`; every positive op settles on the fork, proving packing/prefix fidelity against the canonical bytecode — mitigated (a packing/prefix error would have reverted handleOps before any spend).
- **T-03-07 (Replay, nonce):** accepted — nonce read via `ep.getNonce(sender, 0)`; each op is single-use on an ephemeral fork.
- **T-03-SC (supply chain):** accepted — no installs; only forge-std + Wave 1 first-party contracts + real on-chain EntryPoint bytecode.

## User Setup Required
None — zero-fund, fork-based. Requires network egress to `atlantic_testnet` RPC during `forge test` (available and verified).

## Next Phase Readiness
- AA-01 (factory deploy via initCode), AA-02 (batched UserOp), AA-03 (settles via real EntryPoint, self-bundled), and CORE-07 (account-agnostic parity) are all proven locally with zero funds.
- 03-03 (live funded bundle) is now a gated bonus only — the primary technical risk (v0.7 packing/hashing/prefund/handleOps fidelity) is fully de-risked against the real on-chain EntryPoint.

---
*Phase: 03-smart-account-agents-erc-4337*
*Completed: 2026-06-07*

## Self-Check: PASSED

`test/SmartAccount.fork.t.sol` and `03-02-SUMMARY.md` verified present on disk; both task commits (`c4066c2`, `ccc63cc`) verified in git log. All 4 fork tests pass against the real EntryPoint v0.7; full local suite 34/34 green; `Cascade.sol` unchanged.
