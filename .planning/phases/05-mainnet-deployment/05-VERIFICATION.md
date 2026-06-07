---
phase: 05-mainnet-deployment
verified: 2026-06-08T00:00:00Z
status: human_needed
score: 4/4 success criteria verified on-chain (1 residual human visual-check on source-verification UI)
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: none
human_verification:
  - test: "Open https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84 and click the Code/Contract tab"
    expected: "Green 'Verified' checkmark with readable Cascade.sol source (solc 0.8.24, optimizer runs 200, no constructor args)"
    why_human: "The SocialScan read command-API (getabi/getsourcecode) is broken/unsupported on this deployment and cannot confirm verification status programmatically. The authoritative confirmation is a visual check of the pharosscan UI. The forge verify SUBMIT returns the backend 'This contract is verified' guard (strong evidence), but the green-checkmark visual is the final submission-readiness confirmation. NOT a phase blocker — the on-chain deploy is unambiguous and verification is honestly recorded."
---

# Phase 5: Mainnet Deployment & Live Demos Verification Report

**Phase Goal:** Deploy the hardened contracts to Pharos mainnet, verify source on the explorer, and demonstrate both the royalty split and the 4337 batch live on mainnet.
**Verified:** 2026-06-08
**Status:** human_needed
**Re-verification:** No — initial verification
**Mode:** mvp

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria + merged PLAN must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Cascade deployed to Pharos mainnet (chainId 1672) at a recorded address with non-empty bytecode | ✓ VERIFIED | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84`, deploy tx `0x4fc8db37…` status 1, bytecode 4231 hex chars, `skillCount` callable. Orchestrator independently confirmed via read-only cast. |
| 2 | Cascade source is verified on the explorer OR honestly recorded as best-effort retryable without redeploy | ✓ VERIFIED (with residual visual-check) | forge verify SUBMIT returns backend guard "This contract is verified" (status=0 already-verified signal). PLAN truth is an OR — branch satisfied: MAINNET_RESULT.md records verification honestly, flags read-API is broken, and notes residual human UI visual-check. No false claim. |
| 3 | One live mainnet invoke of an A→B→C tree raises three distinct creator balances proportionally in one tx, Σ == PRICE_C | ✓ VERIFIED | invoke tx `0x5ba20c87…` status 1; deltas A +2e14 / B +3e14 / C +5e14, Σ == 1e15 (0.001 PROS) EXACTLY; 3 RoyaltyAccrued events; SAME Cascade reused (skillCount 0→3, no redeploy). Orchestrator confirmed. |
| 4 | One self-bundled handleOps via real EntryPoint v0.7 batches two Cascade.invoke calls in a single tx; both invoked skills' creators rise (account-agnostic parity) | ✓ VERIFIED | handleOps tx `0x1f3cec…375f90` status 1, to = real EntryPoint v0.7 `0x0000…da032`; ONE handleOps batched TWO invokes (2 Invoked + 3 RoyaltyAccrued in one tx); cumulative creator balances A 4e14 / B 6e14 / C 1e15 (exactly double MAIN-02 — smart-account path credits identically to EOA path). Factory `0x9049…` + account `0xfe93…` both have code, CREATE2 deterministic. Orchestrator confirmed. |
| 5 | Every spend pre-flight gated (chainId==1672, balance read, cost estimated) before broadcast; all results in MAINNET_RESULT.md | ✓ VERIFIED | Each of MAIN-01/02/03 documents a pre-flight gate (chain-id confirmed 1672, before-balance read, cost estimated) and a pre-broadcast guard. First MAIN-03 handleOps reverted AA95 out-of-gas and FULLY rolled back (no half-spend); retry settled clean — documented honestly. |

**Score:** 4/4 roadmap success criteria verified on-chain. One residual human visual-check on the source-verification UI (sub-item of SC1).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `MAINNET_RESULT.md` | Single source of truth: addresses, tx hashes, balances, verification status, RoyaltyAccrued, handleOps | ✓ VERIFIED | Present (343 lines). Contains Cascade address, deploy tx, verification section, 3 creators + funding/register/invoke txs, RoyaltyAccrued amounts, factory/account addresses, handleOps tx, before/after balances, explorer links throughout. Contains "Cascade", "RoyaltyAccrued", "handleOps". |
| `script/LiveBundleMainnet.s.sol` | Mainnet-guarded (chainId 1672) 4337 driver: factory deploy + handleOps of two invokes | ✓ VERIFIED | Exists. `require(block.chainid == MAINNET_CHAIN_ID, "wrong chainId...")` (1672), reads `CASCADE` from env (not hardcoded), `EP_ADDR = 0x0000…da032`, `_buildSignedOp`/`_batchInvoke`/`_pack` mirror LiveBundle verbatim, `executeBatch([cascade,cascade],[p1,p2],[invoke(id1),invoke(id2)])`, `ep.handleOps(ops, payable(broadcaster))`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| deployed Cascade address | pharosscan explorer | SocialScan command_api verify submit | ⚠ WIRED (best-effort) | Submit-guard "already verified" recorded; read-API confirmation broken → residual human visual-check. |
| payer invoke(idC) | three creator balances | recursive _distribute fan-out | ✓ WIRED | Σ deltas == PRICE_C exactly, 3 RoyaltyAccrued events. |
| EOA handleOps([userOp]) on EntryPoint v0.7 | two Cascade.invoke via executeBatch | PackedUserOperation callData = executeBatch | ✓ WIRED | 2 Invoked + 3 RoyaltyAccrued events in one tx. |

### Frozen-Guard Check (immutability requirement)

| File | Expected | Status |
|------|----------|--------|
| `script/LiveBundle.s.sol` (testnet) | LEFT UNTOUCHED, `require(block.chainid == ATLANTIC_CHAIN_ID)` (688689) intact | ✓ VERIFIED — guard at line 113, constant 688689 unchanged, last commit predates phase 5 mainnet work (3bbc8a5, a 04-01 commit) |
| `script/LiveBundleMainnet.s.sol` (mainnet) | NEW file guarding chainId 1672 | ✓ VERIFIED — new file, last commit cfd366d feat(05-03) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MAIN-01 | 05-01 | Cascade deployed to mainnet + source-verified on pharosscan | ✓ SATISFIED (residual visual-check) | Deploy unambiguous; verification honestly recorded with UI visual-check flag |
| MAIN-02 | 05-02 | Live royalty demo — one invoke pays three creators proportionally | ✓ SATISFIED | invoke tx `0x5ba20c87…`, Σ == 0.001 PROS exactly |
| MAIN-03 | 05-03 | Live 4337 demo — smart account batches two invokes in one handleOps via real EntryPoint v0.7 | ✓ SATISFIED | handleOps tx `0x1f3cec…`, 2 invokes in one UserOp |

No orphaned requirements. REQUIREMENTS.md maps exactly MAIN-01/02/03 to Phase 5; all claimed by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | No TBD/FIXME/XXX debt markers; "VISUAL CHECK PENDING" in MAINNET_RESULT.md is an honest residual-check disclosure (a deliberate human follow-up note), not a stub or unreferenced debt marker. |

### Behavioral Spot-Checks

Skipped — no local runnable entry point exercises mainnet state without broadcasting/reading live chain. All on-chain behavior was independently confirmed by the orchestrator via read-only `cast` against Pharos mainnet (treated as ground truth per verification notes).

### Human Verification Required

#### 1. Source-verification green checkmark on pharosscan

**Test:** Open https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84 and view the Code/Contract tab.
**Expected:** Green "Verified" checkmark with readable Cascade.sol source (solc 0.8.24, optimizer runs 200, no constructor args).
**Why human:** SocialScan read command-API (getabi/getsourcecode) is broken/unsupported and cannot confirm programmatically. The forge verify SUBMIT returns the "This contract is verified" backend guard (strong evidence), but the green-checkmark visual is the authoritative final confirmation. **This is NOT a phase blocker** — the deploy itself is unambiguous and verification is honestly recorded in MAINNET_RESULT.md.

### Gaps Summary

No gaps. All four ROADMAP success criteria are met and independently confirmed on-chain (real PROS spent, tx hashes status 1, balance conservation exact, EntryPoint v0.7 batch proven). All three MAIN requirements satisfied. The single residual item is a visual confirmation of the source-verification green checkmark on the pharosscan UI — a known limitation of the broken read-API, honestly recorded by MAINNET_RESULT.md, and a minor submission-readiness follow-up rather than a goal blocker. The frozen testnet driver guard (688689) is intact and the new mainnet driver correctly hard-guards chainId 1672.

---

_Verified: 2026-06-08_
_Verifier: Claude (gsd-verifier)_

## Residual handling (autonomous)

The single `human_needed` item — visually confirming the "Verified" checkmark on the pharosscan Code tab (read command-API can't confirm programmatically) — is a SUBMISSION-TIME human action. It is **CARRIED TO PHASE 6** as a line in the DoraHacks submission checklist (alongside the video recording + form submission, the other human actions). Phase goal is achieved on-chain; this residual does not block phase advancement.
