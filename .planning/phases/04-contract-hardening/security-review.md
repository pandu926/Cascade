# Security Review — Cascade + AA Layer (HARD-03)

**Reviewed:** 2026-06-08
**Scope:** `src/Cascade.sol`, `src/aa/CascadeAccount.sol`, `src/aa/AccountFactory.sol`,
`src/aa/IEntryPoint.sol`, `src/aa/IAccount.sol`, `src/aa/PackedUserOperation.sol`
**Method:** Structured manual security review (OWASP/SWC categories), cross-checked against
the slither 0.11.5 run captured in `slither-attempt.log`.

> **Runtime note (honesty):** The dedicated `security-reviewer` subagent (Task/Agent tool)
> was NOT available in this execution runtime — only file/Bash tooling was exposed. This
> review was therefore performed **inline by the executor to the same standard**: every
> finding carries a severity and a `file:line` reference, and the same vulnerability classes
> a security-reviewer agent would enumerate (reentrancy, access control, arithmetic,
> low-level calls, signature handling, CREATE2 determinism, DoS) are covered below, each
> explicitly resolved with a finding **or** a recorded "no finding" per class.

---

## Finding List (severity + file:line)

### Reentrancy

- **F-01 (LOW, informational) — Event emitted after external call in `claim`.**
  `src/Cascade.sol:146-148`. The `Claimed` event is emitted after the `.call`. slither's
  `reentrancy-events` detector flags this. **No exploit:** the balance is zeroed at
  `src/Cascade.sol:144` BEFORE the call (strict CEI), and no state mutation follows the
  call. A re-entrant `claim` sees a zero balance. Disposition: **ACCEPTED** — event ordering
  is cosmetic; reordering would not change security and would cost a stack juggle.

- **No finding — fan-out path.** `Cascade._distribute` (`src/Cascade.sol:157-178`) performs
  **zero external calls**; it only credits the internal `balances` mapping. The recursive
  royalty split is reentrancy-safe by construction and no payee can block the tree.

### Access Control

- **No finding — Cascade.** `register`/`invoke`/`claim` are intentionally permissionless
  (anyone may register a skill, pay to invoke, or withdraw their own accrued balance).
  `claim` (`src/Cascade.sol:142-150`) pays only `msg.sender` its own balance — no
  cross-account withdrawal path exists.

- **No finding — CascadeAccount.execute / executeBatch.** Both are gated by
  `onlyEntryPointOrOwner` (`src/aa/CascadeAccount.sol:45-48, 68, 80`). Only the trusted
  EntryPoint or the immutable owner can route calls. Confirmed against the threat register
  entry T-04-08 (elevation of privilege) — no gap.

- **No finding — validateUserOp caller gate.** `src/aa/CascadeAccount.sol:56` reverts with
  `NotFromEntryPoint` unless `msg.sender == entryPoint`, so only the EntryPoint can drive
  validation/prefund.

### Arithmetic

- **No finding.** Pragma `^0.8.24` gives checked arithmetic. The remainder identity
  `creatorCut = amount - routedSum` (`src/Cascade.sol:172`) cannot underflow: `routedSum`
  is a sum of `floor(amount*share/BPS)` terms whose shares are bounded `<= BPS` at register
  time (`src/Cascade.sol:116`), so `routedSum <= amount`. The fuzz + invariant suites
  (`test/Cascade.fuzz.t.sol`, `test/Cascade.invariant.t.sol`) prove the conservation
  property (no wei created or destroyed) across random valid trees.

### Low-level Call Return Handling

- **F-02 (LOW, by-design) — `_payPrefund` ignores call success.**
  `src/aa/CascadeAccount.sol:97-98`. The prefund `.call` return is intentionally discarded
  `(ok);`. Disposition: **ACCEPTED** — ERC-4337 v0.7 `BaseAccount` semantics: the EntryPoint
  verifies the prefund itself, and the account MUST NOT revert here or it breaks validation.
  Documented in NatSpec at `src/aa/CascadeAccount.sol:93-94`.

- **No finding — `claim` and `_call`.** `claim` checks the return and reverts
  `TransferFailed` (`src/Cascade.sol:146-147`); `_call` checks `success` and bubbles the
  inner revert verbatim (`src/aa/CascadeAccount.sol:104-109`).

### Signature Handling

- **No finding — malleability.** `_recover` (`src/aa/CascadeAccount.sol:115-131`) enforces
  EIP-2 low-s (`src/aa/CascadeAccount.sol:127`), `v in {27,28}` (`:128`), a 65-byte length
  check (`:116`), and returns `address(0)` on any anomaly so `validateUserOp` reports
  `SIG_VALIDATION_FAILED` and **never reverts** on a bad signature
  (`src/aa/CascadeAccount.sol:59`) — preserving EntryPoint simulation semantics.

- **No finding — replay.** Replay protection is delegated to the EntryPoint's `userOpHash`
  (binds chainId + EntryPoint address + 2D nonce), which is correct for an ERC-4337 account;
  the account must not re-implement nonce tracking.

### CREATE2 / initCode Determinism

- **F-03 (LOW, informational) — `createAccount` is unguarded/permissionless.**
  `src/aa/AccountFactory.sol:27-33`. Anyone can call `createAccount(owner, salt)`. This is
  **intended** for ERC-4337 counterfactual deployment (the EntryPoint drives it via
  `initCode`). The deployed account trusts only the embedded `owner` key, so a front-runner
  deploying first yields the **identical** bytecode at the **identical** address — the
  idempotent guard at `src/aa/AccountFactory.sol:29-31` returns the existing account rather
  than reverting (AA10-safe). Disposition: **ACCEPTED** — front-running the deploy is a
  no-op; the address and owner are fixed by `getAddress` (`:39-43`).

- **No finding — address determinism.** `getAddress` recomputes the CREATE2 address from
  `type(CascadeAccount).creationCode` + `abi.encode(entryPoint, owner)` and the salt
  (`src/aa/AccountFactory.sol:40-42`), matching the deploy at `:32`. Counterfactual address
  == deployed address.

### DoS / Gas

- **No finding.** Pull-payment isolates payees (a failing creator cannot block others).
  `_distribute` recursion is bounded by `MAX_DEPTH = 8`, enforced at register time
  (`src/Cascade.sol:118-119`, `DepthExceeded`). `executeBatch` iterates caller-supplied
  arrays whose lengths are checked equal (`src/aa/CascadeAccount.sol:82`); the caller pays
  the gas. slither's `calls-loop` flag (`_call` inside `executeBatch`) is informational —
  intended batch-routing, ACCEPTED.

### Misc (slither informational)

- **F-04 (informational) — uninitialized-local** (`shareSum`/`maxDepDepth`/`routedSum`,
  `src/Cascade.sol:101,102,160`). Solidity zero-initializes locals; relying on default-zero
  is safe and idiomatic. **ACCEPTED.**
- **F-05 (LOW) — missing zero-check on `owner`** (`src/aa/CascadeAccount.sol:39,41`). A zero
  owner simply yields an unusable account (no valid signer can be recovered). Factory callers
  control the arg. **ACCEPTED** (defensive zero-check optional; adds deploy gas for no
  security gain in the agent-deploy flow).
- **F-06 (informational) — too-many-digits** (the `0xff` CREATE2 prefix,
  `src/aa/AccountFactory.sol:40`). Standard CREATE2 construction. **ACCEPTED.**
- **F-07 (LOW) — floating pragma `^0.8.24`** (SWC-103, all files). Intentional for the
  hackathon build (forge pins solc 0.8.24 via foundry.toml). **ACCEPTED**; pin to `=0.8.24`
  at mainnet-deploy time if reproducible-bytecode source verification requires it.

---

## Severity Summary

| Severity | Count | IDs |
|----------|-------|-----|
| CRITICAL | 0 | — |
| HIGH | 0 | — |
| MEDIUM | 0 | — |
| LOW / informational | 7 | F-01 … F-07 (all ACCEPTED with rationale) |

**No CRITICAL or HIGH findings.** No contract logic change is required. All LOW/informational
items are accepted by-design with rationale and carried into `SECURITY.md`.
