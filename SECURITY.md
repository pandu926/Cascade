# Security Policy & Review — Cascade

**Project:** Cascade — Pharos Recursive Skill Royalties
**Reviewed:** 2026-06-08 (Phase 4, HARD-03)
**Commit basis:** post Plan 04-01 (NatSpec + custom errors) and 04-02 (fuzz/invariant + gas snapshot)

---

## ⚠️ Honesty Caveat — Read This First

This document records **hackathon-grade review-readiness**, **NOT an independent
professional security audit**. The analysis below was produced by automated static
analysis (slither) plus a structured manual review against the SWC registry and OWASP
smart-contract categories. It is sufficient to demonstrate the contracts were checked
against known vulnerability classes — it is **not** a substitute for an independent audit.

**An independent professional audit is the one remaining step before these contracts
custody real user value.** Do not route material funds through Cascade on mainnet until
that audit is complete.

---

## Scope

| Contract | Role |
|----------|------|
| `src/Cascade.sol` | Recursive skill royalty registry + router (register / invoke / claim / `_distribute`) |
| `src/aa/CascadeAccount.sol` | Minimal ERC-4337 v0.7 single-owner smart account (validateUserOp / execute / executeBatch) |
| `src/aa/AccountFactory.sol` | CREATE2 deterministic deployer for `CascadeAccount` |
| `src/aa/IEntryPoint.sol`, `IAccount.sol`, `PackedUserOperation.sol` | Hand-written ERC-4337 v0.7 interfaces |

**Out of scope:** the canonical EntryPoint singleton (trusted external dependency), the
Pharos network, off-chain agent scripts.

---

## Methodology

1. **Static analysis (slither).** `slither-analyzer` 0.11.5 was installed in a Python venv
   (the system `pip` is locked under PEP 668; `pipx` was absent). `solc` 0.8.24 was
   provisioned via `solc-select`, and `slither .` ran cleanly over all 5 contracts with
   101 detectors, producing **14 results — none CRITICAL or HIGH** from slither's own
   severity model. Full raw output and the `--checklist` report are recorded in
   [`.planning/phases/04-contract-hardening/slither-attempt.log`](.planning/phases/04-contract-hardening/slither-attempt.log).

2. **Manual SWC checklist.** Each contract was walked through the SWC registry classes
   (SWC-101 arithmetic, 103 pragma, 104 unchecked calls, 105/106 access control,
   107 reentrancy, 113/128 DoS, 115 tx.origin, 117 signature malleability, plus
   force-fed-ether and weak-randomness), with a per-item conclusion in the same log.

3. **Security review pass.** A structured review covering reentrancy, access control,
   arithmetic, low-level call handling, signature handling, CREATE2 determinism, and DoS
   was captured in
   [`.planning/phases/04-contract-hardening/security-review.md`](.planning/phases/04-contract-hardening/security-review.md).
   The dedicated `security-reviewer` subagent was unavailable in the execution runtime, so
   the review was performed **inline to the same standard** (severity + `file:line` per
   finding, every class explicitly resolved) — this is disclosed for honesty.

4. **Regression gate.** The full local suite (41 tests: unit + fuzz + invariant) is green;
   the Phase 3 fork test against the real EntryPoint remains green. No contract logic was
   changed by this review (no CRITICAL/HIGH to fix), so the frozen ABI is intact.

---

## Findings

No CRITICAL, HIGH, or MEDIUM findings. All findings are LOW / informational and **Accepted**
by design with the rationale below.

| ID | Severity | Location | Class | Status | Disposition / Rationale |
|----|----------|----------|-------|--------|-------------------------|
| F-01 | LOW (info) | `src/Cascade.sol:146-148` | Reentrancy (event after call) | Accepted | `Claimed` event emitted after the transfer. Not exploitable: balance is zeroed (`:144`) before the call (strict CEI); no state follows the call. slither `reentrancy-events` is cosmetic. |
| F-02 | LOW | `src/aa/CascadeAccount.sol:97-98` | Unchecked call return (SWC-104) | Accepted | `_payPrefund` ignores call success **by design** — ERC-4337 v0.7 BaseAccount: the EntryPoint enforces the prefund, and the account must not revert here or it breaks validation. Documented in NatSpec (`:93-94`). |
| F-03 | LOW (info) | `src/aa/AccountFactory.sol:27-33` | CREATE2 front-running | Accepted | `createAccount` is permissionless by design (EntryPoint initCode path). Idempotent guard (`:29-31`) returns the existing account; a front-run deploy yields identical bytecode at the identical address with the same fixed owner — a no-op. |
| F-04 | info | `src/Cascade.sol:101,102,160` | Uninitialized local | Accepted | `shareSum`/`maxDepDepth`/`routedSum` rely on Solidity default-zero init — safe and idiomatic. |
| F-05 | LOW | `src/aa/CascadeAccount.sol:39,41` | Missing zero-check on `owner` | Accepted | A zero owner yields an unusable account (no recoverable signer). Factory callers control the arg; a defensive check adds deploy gas for no security gain in the agent-deploy flow. |
| F-06 | info | `src/aa/AccountFactory.sol:40` | Too-many-digits literal | Accepted | The `0xff` CREATE2 prefix — standard construction. |
| F-07 | LOW | all files | Floating pragma `^0.8.24` (SWC-103) | Accepted | Intentional for the hackathon build; forge pins solc 0.8.24 via `foundry.toml`. Pin to `=0.8.24` at mainnet-deploy time if reproducible-bytecode source verification requires it. |

**No CRITICAL/HIGH finding is left Open, Unresolved, or TODO.** No contract fix was required.

---

## Security Design Notes

These are deliberate, defended properties of the contracts (not findings):

- **Pull-payment over push.** `invoke` credits internal `balances` only; creators withdraw
  via `claim`. A single griefing payee cannot block the fan-out for everyone else.
- **Checks-Effects-Interactions in `claim`.** The balance is zeroed (`src/Cascade.sol:144`)
  before the external transfer (`:146`), so re-entry sees a zero balance and cannot double-pay.
- **Reentrancy-safe fan-out.** `_distribute` (`src/Cascade.sol:157-178`) makes **no external
  calls** — pure internal accounting, recursion bounded by `MAX_DEPTH = 8`.
- **Conservation invariant.** Per-level remainder is credited to the level's creator, so the
  sum of all credited wei equals the original payment exactly. Proven by the fuzz + invariant
  suites (no wei created or destroyed across arbitrary valid trees).
- **Monotonic-id cycle prevention.** A dependency id must be strictly smaller than the new
  skill's id (`src/Cascade.sol:107`), making cycles impossible by construction and enforcing
  bottom-up registration.
- **Depth cap.** `register` rejects trees deeper than `MAX_DEPTH = 8` (`:118-119`), bounding
  `invoke` recursion (and gas) to a known maximum.
- **`validateUserOp` never reverts on a signature mismatch.** It returns `0`/`1`
  (`src/aa/CascadeAccount.sol:59`) to preserve EntryPoint simulation semantics; only an
  unauthorized caller triggers a revert (`NotFromEntryPoint`, `:56`).
- **EIP-2 signature malleability guard.** `_recover` rejects high-s, non-`{27,28}` v,
  wrong length, and zero-address recovery (`src/aa/CascadeAccount.sol:115-131`).
- **Access control.** `execute`/`executeBatch` are `onlyEntryPointOrOwner`
  (`src/aa/CascadeAccount.sol:45-48`); `claim` only ever pays `msg.sender` its own balance.
- **Account-agnostic Cascade.** Cascade only reads `msg.sender`/`msg.value` and never
  inspects caller code or type — an EOA and a smart account hit the identical path.

---

## Reporting a Vulnerability

This is a hackathon project with no production deployment. For the submitted artifact,
open an issue in the repository. Before any mainnet custody of real value, the planned
independent audit (see caveat above) is the authoritative security gate.
