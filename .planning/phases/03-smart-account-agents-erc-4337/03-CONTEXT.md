# Phase 3: Smart-Account Agents (ERC-4337) - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the account-agnostic claim end-to-end: an agent can be an ERC-4337 smart account that pays multiple Cascade skills in a single self-bundled UserOperation through the REAL Pharos EntryPoint v0.7, with NO external bundler. Deliver a minimal smart-account implementation + factory, UserOp construction/signing, and a self-bundling path (EOA calls `EntryPoint.handleOps`). The unchanged `Cascade.sol` from Phase 1 must process smart-account-driven invokes identically to the EOA path. This phase is ADDITIVE — it does not modify Cascade.sol; Phases 1+2 already constitute a submittable Skill, so if the live funded step is blocked by budget, the locally-proven AA work still ships.
</domain>

<decisions>
## Implementation Decisions

### ERC-4337 approach (locked by PROJECT.md + verified facts)
- **Self-bundle, no external bundler:** an EOA calls `EntryPoint.handleOps([userOp], beneficiary)` directly — the same mechanism the official 4337 test suite uses. No public bundler exists on Pharos (verified).
- **Real EntryPoint v0.7:** `0x0000000071727De22E5E9d8BAf0edAc6f37da032` — VERIFIED deployed on atlantic-testnet (bytecode present, 32KB). Use the v0.7 `PackedUserOperation` struct (packed accountGasLimits, gasFees; initCode = factory address ++ factory calldata; paymasterAndData empty).
- **Minimal custom smart account** (NOT a vendored SimpleAccount): a tight account with `validateUserOp` (owner ECDSA signature check + pay prefund) and an `execute(address,uint256,bytes)` + `executeBatch(...)` so one UserOp can make MULTIPLE `Cascade.invoke{value}()` calls. Minimal = gas-lean (critical: only ~0.0043 PHRS left) and demonstrates real understanding. Plus a minimal `AccountFactory` with `createAccount(owner, salt)` (CREATE2, deterministic address).
- **Batch demo:** the UserOp's callData = `account.executeBatch([cascade, cascade], [v1, v2], [invoke(skillId1), invoke(skillId2)])` — "agent pays multiple skills in ONE UserOp."
- **Account-agnostic proof:** Cascade.sol is UNCHANGED. The smart account is just another `msg.sender`/`msg.value` source. A test asserts the smart-account invoke path credits creators identically to the EOA path.

### Local-first / funding isolation (mirror Phase 1)
- ALL of it (account, factory, UserOp packing, signing, handleOps) is built and tested LOCALLY with ZERO funds — via `forge test`, either against a forge-deployed EntryPoint copy or a `--fork-url` of atlantic-testnet using the real deployed EntryPoint. The technical risk lives here and is fully de-risked locally.
- Only a FINAL, minimal, gated live step spends PHRS. Gas-saving: REUSE the 3 skills already registered live by Phase 1 (skillCount()==3 on 0xd41C…0F50) — the smart account invokes EXISTING skills, so the live step is just: deploy factory + deploy account (via factory) + fund account minimally + ONE handleOps batching 2 invokes. No re-registration.

### Budget reality (HONEST — surfaced for the funded step)
- Remaining balance ~0.0043 PHRS. A live 4337 demo (factory deploy + account deploy + prefund + handleOps) is gas-heavier than Phase 1's demo. At ~1 gwei it should fit (~0.002-0.003 PHRS); at 10 gwei it will NOT. The funded plan MUST use the lowest accepted gas price and a pre-flight gate that STOPS cleanly (reporting a top-up need on address 0x67680b09bB422cC510669bd5208D947066D4aeaE) rather than half-spending. If live is blocked, local fork proof is the deliverable and Phase 4 proceeds.

### Claude's Discretion
- Exact account/factory Solidity (kept minimal + gas-lean), how UserOp is constructed in forge script/test (cast or solidity helper), signature scheme details — implementer's choice guided by canonical v0.7 patterns from research.
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/Cascade.sol` — UNCHANGED. API: `invoke(uint256 skillId) payable`, `register(...)`, `claim()`, `balances(address)`, `skillCount()`. The smart account calls `invoke{value}` on this.
- Live Cascade on atlantic-testnet: `0xd41C32562D0BE20D354120E1De11A91abC340F50`, skillCount()==3 (A→B→C tree already registered — REUSE for the live demo).
- `foundry.toml` (rpc_endpoints: atlantic_testnet), `assets/networks.json`, existing forge scripts/tests — patterns to follow.
- EntryPoint v0.7 (real, on testnet): `0x0000000071727De22E5E9d8BAf0edAc6f37da032`. SenderCreator v0.7: `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C`.

### Established Patterns
- Phase 1 TDD: write failing test → implement → edge tests. Apply the same to the account + UserOp flow (local fork test asserting balances rise via a self-bundled handleOps).
- Funding isolation: local build+test wave(s) zero-fund, then a gated funded live wave.

### Integration Points
- The UserOp flows: EOA → EntryPoint.handleOps → smart account.validateUserOp + executeBatch → Cascade.invoke (×N) → balances credited. Self-bundled (EOA is the bundler).
</code_context>

<specifics>
## Specific Ideas

- Killer proof for this phase: ONE self-bundled UserOperation makes the smart account pay TWO skills, and on-chain balances rise exactly as if an EOA had called invoke twice — proving Cascade is account-agnostic and 4337-compatible on real Pharos infra.
- May need a v0.7 EntryPoint interface/IEntryPoint + PackedUserOperation struct — research the exact canonical definitions (eth-infinitism v0.7) so packing is correct (getting accountGasLimits/gasFees packing wrong wastes the tight gas budget).
- Research target: canonical minimal v0.7 account `validateUserOp` (return 0 on valid sig, pay missingAccountFunds), factory CREATE2 pattern, and how to build+sign a PackedUserOperation in a forge script for self-bundled handleOps.
</specifics>

<deferred>
## Deferred Ideas

- Gasless / paymaster (sponsored UserOps) — v2 (GAS-01), explicitly out of scope.
- Running a production bundler — out of scope (self-bundle via handleOps).
- Web visualization, README, demo video, submission — Phase 4.
</deferred>
