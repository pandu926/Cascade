---
phase: 03-smart-account-agents-erc-4337
verified: 2026-06-07T00:00:00Z
status: passed
score: 9/9 must-haves verified
overrides_applied: 0
---

# Phase 3: Smart-Account Agents (ERC-4337) Verification Report

**Phase Goal:** An agent can be a smart account that pays multiple skills in a single self-bundled UserOperation through the real Pharos EntryPoint — proving the account-agnostic claim end-to-end.
**Verified:** 2026-06-07
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | One self-bundled UserOperation via the REAL EntryPoint v0.7 makes the smart account pay two skills in a single handleOps call | ✓ VERIFIED | `test_smartAccount_batches_two_invokes` calls `EP.handleOps` once; orchestrator confirms 4/4 fork tests PASSED |
| 2 | Two distinct creator balances rise after the batched op, summing exactly to the two skill prices | ✓ VERIFIED | Fork test lines 173-179: `assertEq(delta1, price1)`, `assertEq(delta2, price2)`, `assertEq(delta1+delta2, price1+price2)` |
| 3 | The op settles through the real EntryPoint at 0x0000000071727De22E5E9d8BAf0edAc6f37da032 (fork), self-bundled by an EOA — no external bundler | ✓ VERIFIED | `EP` constant hardcoded to canonical address (fork test line 24); `test_handleOps_settles_via_real_entrypoint` exercises this path |
| 4 | A UserOp signed by a non-owner reverts FailedOp(0, "AA24 signature error") — wrong signer is rejected | ✓ VERIFIED | `test_handleOps_rejects_wrong_signer` uses `vm.expectRevert(abi.encodeWithSignature("FailedOp(uint256,string)", 0, "AA24 signature error"))` |
| 5 | Smart-account invoke credits creators identically to a direct EOA invoke (account-agnostic; Cascade.sol unchanged) | ✓ VERIFIED | `test_account_agnostic_parity` asserts `saDelta == eoaDelta`; Cascade.sol confirmed byte-for-byte unchanged since Phase 1 |
| 6 | A factory deploys a smart account at a deterministic CREATE2 address (getAddress == deployed address) | ✓ VERIFIED | `test_factory_deterministic_address` passes; AccountFactory uses `bytes1(0xff)` CREATE2 formula with `type(CascadeAccount).creationCode` |
| 7 | execute/executeBatch are callable only by the EntryPoint or the owner | ✓ VERIFIED | `onlyEntryPointOrOwner` modifier applied to both in CascadeAccount.sol; `test_execute_reverts_for_unauthorized_caller` asserts the gate |
| 8 | validateUserOp returns 0 for owner's signature and 1 (not a revert) for a wrong signature | ✓ VERIFIED | Unit tests `test_validateUserOp_returns_zero_for_owner_signature` and `test_validateUserOp_returns_one_for_wrong_signer_without_reverting` both pass |
| 9 | Pre-flight gate stops cleanly on budget block; LIVE_RESULT.md records the honest outcome; skillCount stays 3 | ✓ VERIFIED | LiveBundle.s.sol lines 87-96 revert with LIVE BLOCKED message; LIVE_RESULT.md records balance 0.004317764 PHRS, shortfall 0.01448 PHRS, skillCount==3, balance unchanged |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/aa/PackedUserOperation.sol` | v0.7 struct, exact 9-field order | ✓ VERIFIED | All 9 fields present in correct order (sender, nonce, initCode, callData, accountGasLimits, preVerificationGas, gasFees, paymasterAndData, signature) |
| `src/aa/IEntryPoint.sol` | handleOps, getUserOpHash, getNonce | ✓ VERIFIED | All three function declarations confirmed |
| `src/aa/IAccount.sol` | validateUserOp interface | ✓ VERIFIED | Interface with correct v0.7.0 signature |
| `src/aa/CascadeAccount.sol` | validateUserOp + execute + executeBatch; <120 lines | ✓ VERIFIED | 116 lines; inline ecrecover with malleability guard (high-s reject, bad-v reject, zero-addr return); no OZ import |
| `src/aa/AccountFactory.sol` | createAccount + getAddress CREATE2 | ✓ VERIFIED | Idempotent createAccount; getAddress uses bytes1(0xff) formula |
| `test/SmartAccountUnit.t.sol` | Unit suite; test_factory_deterministic_address | ✓ VERIFIED | 15 tests covering all behavior cases including malleability guard, prefund, auth gates, batch ordering, factory determinism |
| `test/SmartAccount.fork.t.sol` | Fork proof; test_handleOps_settles_via_real_entrypoint | ✓ VERIFIED | 4 tests (batches-two-invokes, settles-via-real-entrypoint, rejects-wrong-signer, account-agnostic-parity); all 4 PASSED per orchestrator ground truth |
| `script/LiveBundle.s.sol` | Pre-flight budget gate; handleOps; no register() | ✓ VERIFIED | Gate at lines 87-96 reverts cleanly; `handleOps` at line 134; no `register(` call in file |
| `.planning/phases/03-smart-account-agents-erc-4337/LIVE_RESULT.md` | Honest outcome record with EntryPoint reference | ✓ VERIFIED | Records BLOCKED outcome, balance, gas price, shortfall, skillCount==3, requirement status |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AccountFactory.sol` | `CascadeAccount.sol` | `new CascadeAccount{salt: bytes32(salt)}(entryPoint, owner)` | ✓ WIRED | Line 27; CREATE2 deploy with correct salt casting |
| `CascadeAccount.sol` | `IAccount.sol` | `validateUserOp` implementation | ✓ WIRED | Contract declares `is IAccount`; implements the full interface |
| `test/SmartAccount.fork.t.sol` | EntryPoint 0x0000000071727De22E5E9d8BAf0edAc6f37da032 | `EP.getUserOpHash(op)` + `EP.handleOps(ops, beneficiary)` | ✓ WIRED | Constant at line 24; handleOps called 3× across tests |
| `test/SmartAccount.fork.t.sol` | Cascade 0xd41C32562D0BE20D354120E1De11A91abC340F50 | executeBatch callData → Cascade.invoke{value}×2 | ✓ WIRED | `_batchInvoke` helper encodes two `invoke` selectors; cascade balance asserts confirm execution |
| `script/LiveBundle.s.sol` | Funded EOA balance + node gas price | Pre-flight estimate × accepted gas price vs balance → proceed or STOP | ✓ WIRED | `broadcaster.balance` read at line 67; gate comparison at line 87 |
| `script/LiveBundle.s.sol` | EntryPoint 0x0000000071727De22E5E9d8BAf0edAc6f37da032 | `ep.handleOps(ops, beneficiary)` live broadcast (only if gate passes) | ✓ WIRED | Line 134 in `_broadcastLive` (only reached when gate passes) |

---

### Data-Flow Trace (Level 4)

The fork test registers skills on the real Cascade (not a mock), reads no hardcoded prices — `price1` and `price2` are local constants set before the op is built, and the `invoke` calls forward exact `msg.value`. Cascade's on-chain `require(msg.value == skills[skillId].price)` acts as a fail-fast guard: if any value were wrong, the call reverts and the test fails. The balance deltas are read from `CASCADE.balances(creator)` against the live state, confirming real on-chain state mutation.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `test/SmartAccount.fork.t.sol` | `delta1`, `delta2` | `CASCADE.balances(creator)` on forked atlantic-testnet state | Yes — live Cascade contract storage | ✓ FLOWING |
| `script/LiveBundle.s.sol` | `balance` | `broadcaster.balance` read from live node | Yes — real EOA balance | ✓ FLOWING |

---

### Behavioral Spot-Checks

Orchestrator-confirmed ground truth (trusted as per instructions):

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Fork suite: batches two invokes, settles via real EntryPoint, rejects wrong signer (AA24), account-agnostic parity | `forge test --fork-url atlantic_testnet --match-path test/SmartAccount.fork.t.sol` | 4/4 PASSED | ✓ PASS |
| Full local suite including unit tests | `forge test` | 34/34 PASSED | ✓ PASS |
| Build | `forge build` | Compiler run successful | ✓ PASS |

---

### Probe Execution

No `probe-*.sh` scripts declared or present. Verification relies on the `forge test` results confirmed by the orchestrator.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AA-01 | 03-01 | Agent can be a deployed smart account via a simple factory | ✓ SATISFIED | AccountFactory CREATE2 deploy proven in unit tests + exercised via initCode in fork tests |
| AA-02 | 03-01, 03-02 | Invoke expressible as a UserOperation batching multiple skill payments into one op | ✓ SATISFIED | `test_smartAccount_batches_two_invokes` — one handleOps, two invokes, two balances rise |
| AA-03 | 03-02, 03-03 | UserOps settle through the real Pharos EntryPoint v0.7, self-bundled via handleOps() | ✓ SATISFIED | Fork test drives the canonical EntryPoint bytecode via `--fork-url atlantic_testnet`; Wave 3 live step budget-blocked (not a correctness gap per plan design) |
| CORE-07 | 03-02 | Cascade.sol is account-agnostic | ✓ SATISFIED | `test_account_agnostic_parity` proves equal credit for EOA and smart-account callers; Cascade.sol unchanged |

No orphaned requirements — all AA-01/02/03 are claimed and verified.

---

### Anti-Patterns Found

Scanned: `src/aa/CascadeAccount.sol`, `src/aa/AccountFactory.sol`, `test/SmartAccount.fork.t.sol`, `test/SmartAccountUnit.t.sol`, `script/LiveBundle.s.sol`.

No `TODO`, `FIXME`, `XXX`, `TBD`, `HACK`, or `PLACEHOLDER` markers found in any file modified by this phase. No stub implementations, no empty return bodies, no hardcoded empty arrays passed to rendering paths.

One notable intentional pattern: `(ok);` on line 81 of CascadeAccount.sol silences the unused `bool ok` from `_payPrefund`. This is correct ERC-4337 behavior (EntryPoint verifies the prefund itself) and is documented in the comment.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

---

### Human Verification Required

None. All truths are mechanically verifiable through the fork test results. The budget-blocked Wave 3 live step is an expected, documented outcome that does not require human confirmation — the plan explicitly designates it as optional bonus evidence.

---

### Gaps Summary

No gaps. All 9 must-have truths are VERIFIED. All required artifacts exist, are substantive, and are correctly wired. The Wave 3 live step is budget-blocked by design with a clean stop; this was anticipated and explicitly framed as bonus on-chain evidence that does not gate AA-01/02/03 (those are satisfied by the Wave 2 fork proof).

The phase goal — "an agent can be a smart account that pays multiple skills in a single self-bundled UserOperation through the real Pharos EntryPoint, proving the account-agnostic claim end-to-end" — is demonstrably true in the codebase.

---

_Verified: 2026-06-07_
_Verifier: Claude (gsd-verifier)_
