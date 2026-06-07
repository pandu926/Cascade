---
phase: 03-smart-account-agents-erc-4337
plan: 01
subsystem: infra
tags: [erc-4337, account-abstraction, smart-account, create2, ecdsa, foundry, solidity]

# Dependency graph
requires:
  - phase: 01-recursive-royalty-core
    provides: "Cascade.sol (invoke(uint256) payable) — the account-agnostic target the smart account calls"
provides:
  - "src/aa/PackedUserOperation.sol — hand-written v0.7.0 PackedUserOperation struct (exact 9-field layout)"
  - "src/aa/IEntryPoint.sol — minimal v0.7 EntryPoint interface (handleOps, getUserOpHash, getNonce, depositTo, balanceOf)"
  - "src/aa/IAccount.sol — validateUserOp interface (0/1 return semantics)"
  - "src/aa/CascadeAccount.sol — minimal single-owner ECDSA smart account (validateUserOp + execute + executeBatch), 116 lines"
  - "src/aa/AccountFactory.sol — CREATE2 factory (idempotent createAccount + counterfactual getAddress)"
  - "test/SmartAccountUnit.t.sol — 16 zero-fund unit tests"
affects: [03-02-fork-test, 03-03-live-bundle, erc-4337, smart-account]

# Tech tracking
tech-stack:
  added: [none — hand-written interfaces, lib/ unchanged (forge-std only)]
  patterns:
    - "Hand-written minimal v0.7 interfaces instead of forge install eth-infinitism (zero supply-chain surface)"
    - "Proxy-free directly-deployed CREATE2 account (no UUPS/ERC1967, gas-lean)"
    - "Inline ECDSA recover with malleability guard (high-s, bad-v, zero-addr rejected) — no OZ ECDSA"

key-files:
  created:
    - "src/aa/PackedUserOperation.sol"
    - "src/aa/IEntryPoint.sol"
    - "src/aa/IAccount.sol"
    - "src/aa/CascadeAccount.sol"
    - "src/aa/AccountFactory.sol"
    - "test/SmartAccountUnit.t.sol"
  modified: []

key-decisions:
  - "Hand-wrote v0.7 interfaces (no forge install) — only the struct + 3 interfaces are needed; keeps lib/ at forge-std only, zero supply-chain surface"
  - "Inline ecrecover with EIP-2 malleability guard instead of OZ ECDSA — OZ is not in lib/ and only ~15 lines are needed for a single-owner account"
  - "validateUserOp returns 0/1 and never reverts on a signature mismatch — reverting would break EntryPoint simulation (v0.7 Helpers semantics)"
  - "Proxy-free CREATE2 account — CONTEXT mandates minimal/non-vendored and gas-lean; a UUPS proxy adds deploy gas + an OZ proxy dependency for no benefit"

patterns-established:
  - "Eth-signed-message prefix (\\x19Ethereum Signed Message:\\n32) for userOpHash — signer and validator must agree; locked here for the Wave 2 fork test"
  - "onlyEntryPointOrOwner auth gate on execute/executeBatch; msg.sender==entryPoint gate on validateUserOp"

requirements-completed: [AA-01, AA-02]

# Metrics
duration: 6min
completed: 2026-06-07
---

# Phase 3 Plan 01: Smart-Account Foundation (ERC-4337 v0.7) Summary

**Hand-written v0.7 interfaces + a 116-line proxy-free ECDSA `CascadeAccount` (validateUserOp/execute/executeBatch) + a CREATE2 `AccountFactory`, proven by a 16-test zero-fund unit suite — the account + batch machinery one self-bundled UserOp will use to pay multiple Cascade skills.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-07T20:11:35Z
- **Completed:** 2026-06-07T20:17:42Z
- **Tasks:** 3
- **Files modified:** 6 created

## Accomplishments
- Hand-written v0.7.0 `PackedUserOperation` (exact 9-field order), `IEntryPoint`, and `IAccount` — no `forge install`, lib/ still forge-std only
- `CascadeAccount` with owner-ECDSA `validateUserOp` (returns 0/1, never reverts on sig mismatch), exact-prefund payment, and `onlyEntryPointOrOwner`-gated `execute`/`executeBatch` for batching multiple skill invokes in one op
- Inline ECDSA recover with an EIP-2 malleability guard (rejects high-s, v∉{27,28}, zero-address recover) — no OpenZeppelin dependency
- `AccountFactory` with idempotent CREATE2 `createAccount` and a counterfactual `getAddress` that provably equals the deployed address
- 16 unit tests green; full suite 30/30 (14 existing Cascade + 16 new); `Cascade.sol` unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Hand-write v0.7 interfaces + PackedUserOperation struct** - `f38d812` (feat)
2. **Task 2: CascadeAccount (validateUserOp + execute + executeBatch) with unit tests** - `71ab6c1` (feat)
3. **Task 3: AccountFactory (CREATE2) with deterministic-address unit test** - `3aae797` (feat)

_TDD note: each implementation task was driven RED (failing/non-compiling tests) → GREEN (implement to pass). Tests and implementation were committed together per task._

## Files Created/Modified
- `src/aa/PackedUserOperation.sol` - v0.7.0 PackedUserOperation struct, exact 9-field layout (sender, nonce, initCode, callData, accountGasLimits, preVerificationGas, gasFees, paymasterAndData, signature)
- `src/aa/IEntryPoint.sol` - minimal v0.7 EntryPoint interface: handleOps, getUserOpHash, getNonce, depositTo, balanceOf
- `src/aa/IAccount.sol` - validateUserOp interface with 0/1 return semantics
- `src/aa/CascadeAccount.sol` - 116-line single-owner ECDSA smart account: validateUserOp, execute, executeBatch, inline malleability-guarded recover, exact prefund, receive()
- `src/aa/AccountFactory.sol` - CREATE2 factory: idempotent createAccount + counterfactual getAddress over type(CascadeAccount).creationCode ++ abi.encode(entryPoint, owner)
- `test/SmartAccountUnit.t.sol` - 16 zero-fund unit tests (caller gate, sig 0/1 semantics, malleability, prefund, auth gates, batch dispatch/value, factory determinism/idempotency/wiring)

## Decisions Made
- Hand-wrote the v0.7 interfaces rather than `forge install eth-infinitism/account-abstraction` — only the struct + 3 interfaces are actually used, so this keeps lib/ at forge-std only and the supply-chain surface at zero (matches threat T-03-SC disposition).
- Used inline ecrecover with an EIP-2 half-order high-s guard instead of OZ `ECDSA.recover` — OZ is not vendored and only ~15 guarded lines are needed; the guard mitigates T-03-03 (signature malleability/zero-addr recover).
- `validateUserOp` returns 1 (not a revert) on a wrong signer — a test asserts this explicitly, since reverting on a sig mismatch breaks EntryPoint simulation.
- Account is deployed directly via CREATE2 (no proxy) per CONTEXT's minimal/gas-lean mandate.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. RED phases were achieved by sequencing the test imports (CascadeAccount in Task 2, AccountFactory added in Task 3) so each implementation file's absence produced the expected compile failure before implementation.

## Threat Model Coverage
- **T-03-01 (EoP, execute/executeBatch):** `onlyEntryPointOrOwner` modifier on both — test `test_execute_reverts_for_unauthorized_caller` passes.
- **T-03-02 (Spoofing, validateUserOp):** `require(msg.sender == address(entryPoint))` — test `test_validateUserOp_reverts_when_not_from_entryPoint` passes.
- **T-03-03 (Tampering, ecrecover):** inline malleability guard (high-s, bad-v, zero-addr) — tests `test_validateUserOp_rejects_high_s_malleable_signature` and `test_validateUserOp_rejects_bad_v` pass.
- **T-03-04 (DoS, prefund):** accepted — pays only missingAccountFunds, ignores call success.
- **T-03-SC (supply chain):** zero installs — lib/ unchanged (forge-std only), no .gitmodules.

## User Setup Required
None - no external service configuration required. All work is local, zero-fund.

## Next Phase Readiness
- The exact signatures Wave 2 (03-02 fork test) depends on are locked: `CascadeAccount(IEntryPoint, address)`, `validateUserOp/execute/executeBatch`, `AccountFactory.createAccount/getAddress`.
- Eth-signed-message prefix scheme is fixed in the account, so the Wave 2 signer must sign `toEthSignedMessageHash(entryPoint.getUserOpHash(op))` to match.
- Ready for 03-02: self-bundled `handleOps` fork test against the real EntryPoint v0.7. No blockers.

---
*Phase: 03-smart-account-agents-erc-4337*
*Completed: 2026-06-07*

## Self-Check: PASSED

All 6 created files verified present on disk; all 3 task commits (`f38d812`, `71ab6c1`, `3aae797`) verified in git log.
