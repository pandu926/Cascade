# Phase 4: Contract Hardening & Security Review - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning
**Mode:** Auto-generated (hardening/quality phase — locked scope, no grey areas to question)

<domain>
## Phase Boundary

Bring `src/Cascade.sol` + the AA contracts (`src/aa/CascadeAccount.sol`, `AccountFactory.sol`, interfaces) to publish-ready, review-grade quality BEFORE any mainnet value flows through them (Phase 5). Add complete NatSpec, replace `require`-string reverts with named custom errors, expand the test suite with fuzz + invariant coverage, run `forge fmt`, commit a gas snapshot, run static analysis (slither if installable), and complete a security-reviewer agent pass — resolving or documenting every CRITICAL/HIGH finding. This phase does NOT add features and does NOT spend funds. It is non-breaking: external behavior/ABI already verified by Phase 1/3 tests must stay intact (the 34-test suite + the fork test must remain green throughout).
</domain>

<decisions>
## Implementation Decisions

### Scope (locked — publish-ready quality bar)
- **HARD-01 (docs + errors):** Full NatSpec (`@notice`/`@param`/`@return`/`@dev`) on every public/external function + event in Cascade.sol and the AA contracts. Replace all `require("string")` reverts with named **custom errors** (e.g. `error WrongValue(uint256 sent, uint256 expected); error DepNotRegistered(uint256 depId); error SharesExceedMax(uint256 sum); error DepthExceeded(uint256 depth); error UnknownSkill(uint256 id); error NothingToClaim();` — name per actual revert sites). `forge fmt` clean.
- **HARD-02 (tests + gas):** Expand to include forge **fuzz** tests (e.g. random valid trees conserve exactly; random shares ≤10000 never over/under-pay) and **invariant** tests (e.g. Σ balances ≤ total paid-in; no wei created/destroyed). Keep all existing unit + fork tests green. Commit a `.gas-snapshot` (via `forge snapshot`). Coverage target: meaningfully exercise every CORE + AA branch.
- **HARD-03 (static analysis + review):** Run `slither .` if installable (pip/pipx); if not installable in this env, document the attempt + run the manual SWC checklist instead. Then a **security-reviewer agent** pass over Cascade.sol + AA. Resolve every CRITICAL/HIGH; document any accepted MEDIUM/LOW with rationale in a committed SECURITY.md (or the phase SUMMARY).

### Non-breaking invariant (CRITICAL)
- Cascade.sol's external ABI/behavior is FROZEN where Phases 1/3 already verified it. Hardening must not change function signatures, event topics' meaning, the share/dust/depth semantics, or the pull-payment model.
- EXPECTED churn: swapping `require("msg")` → `revert CustomError()` changes revert *data* (string → 4-byte selector). Tests that assert `vm.expectRevert("string")` MUST be updated to `vm.expectRevert(Cascade.CustomError.selector)` in lockstep — this is intended, not a regression. After changes, the FULL suite (unit + fuzz + invariant + fork) must be green.
- Re-run the Phase 3 fork test (`forge test --fork-url atlantic_testnet`) after hardening to confirm the real-EntryPoint integration still passes byte-for-byte behavior.

### Claude's Discretion
- Exact custom-error names/params, which specific fuzz/invariant properties to encode, NatSpec wording, and whether findings live in SECURITY.md vs SUMMARY — implementer's choice within the bar above. Keep the contract gas-lean (don't regress deployment/runtime gas materially; the snapshot documents it).
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (the code being hardened)
- `src/Cascade.sol` (~139 lines) — register/invoke/claim + _distribute recursion, 4 events, monotonic-id cycle prevention, depth cap 8, pull-payment, per-level remainder conservation. Currently uses require-strings.
- `src/aa/CascadeAccount.sol` (~116 lines) — validateUserOp (inline ecrecover + malleability guard) + execute/executeBatch.
- `src/aa/AccountFactory.sol` — CREATE2 createAccount/getAddress.
- `src/aa/{IEntryPoint,IAccount,PackedUserOperation}.sol` — hand-written v0.7 interfaces.
- `test/Cascade.t.sol` (13 tests), `test/Demo.fork.t.sol` (1), `test/*Account*` unit tests (16), `test/SmartAccount.fork.t.sol` (4) — 34 total, all green. These guard against breakage.
- `foundry.toml` (optimizer on, atlantic_testnet + mainnet rpc endpoints).

### Established Patterns
- TDD throughout Phases 1/3. Apply the same: when adding custom errors, update the revert-asserting tests alongside; add new fuzz/invariant tests as their own files (e.g. test/Cascade.fuzz.t.sol, test/Cascade.invariant.t.sol).
- Foundry-only toolchain. lib/ = forge-std only (keep it that way — no new deps for hardening).

### Integration Points
- Cascade.sol is consumed by the AA layer (CascadeAccount calls invoke) and by all forge scripts — custom-error/NatSpec changes are internal and must not alter call sites' behavior.
- Phase 5 (mainnet) deploys whatever this phase finalizes; Phase 5 source-verification on pharosscan benefits from clean NatSpec + fmt.
</code_context>

<specifics>
## Specific Ideas

- The deliverable that matters for judging: a contract a reviewer can read top-to-bottom (NatSpec + named errors), backed by fuzz/invariant proofs of the conservation property (no wei created or destroyed across arbitrary valid trees), plus a documented security pass. This is the "industry-standard, tested proper" bar the user asked for.
- Be honest in SECURITY.md: this is hackathon-grade review-readiness, NOT an independent professional audit — flag audit as the one remaining step before custody of real user value.
- Zero funds spent in this phase; all local forge.
</specifics>

<deferred>
## Deferred Ideas

- Independent professional security audit — out of scope (documented as the remaining step).
- Mainnet deploy + verify + live demos — Phase 5.
- Visualization, README, video script, submission — Phase 6.
- Paymaster/gasless — v2 (GAS-01).
</deferred>
