# Walking Skeleton — Cascade

**Phase:** 1
**Generated:** 2026-06-07

## Capability Proven End-to-End

A single on-chain `invoke(skillId)` paid in native PHRS splits payment up a declared A→B→C dependency tree and raises three distinct creator balances, each independently claimable — deployed and demonstrated on atlantic-testnet.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Language / build | Solidity ^0.8.24 + Foundry (forge/cast 1.5.1) | Matches official `pharos-skill-engine`; checked arithmetic by default removes a whole class of overflow bugs; forge gives local zero-cost testing on its EVM. |
| Contract shape | Single `Cascade.sol` = registry + recursive royalty router | Whole innovation lives in one tight, gas-lean contract; no proxy/upgrade machinery (skills are immutable). |
| Cycle safety | Monotonic skill IDs; a dependency must reference a strictly smaller, already-registered ID | Cycles become impossible by construction — no runtime DFS, zero gas safety cost. |
| Payment model | Native PHRS via `msg.value`; pull-payment (`balances[creator]` + `claim()`) | No ERC20 approve flow; no external calls during fan-out → reentrancy-safe and no payee can block the tree. |
| Account-agnosticism | Contract reads only `msg.sender` / `msg.value`, never inspects caller code/type | EOA (Phase 1) and smart account (Phase 3) hit the identical code path with no contract change. |
| Network config | `assets/networks.json` (atlantic-testnet primary, mainnet supported); RPCs in `foundry.toml` | Mirrors official engine; demo runs on testnet, mainnet stays config-only. |
| Secrets | `PRIVATE_KEY` in gitignored `.env` (mode 600) | Throwaway funded testnet wallet; never committed. |
| Directory layout | `src/`, `test/`, `script/`, `assets/` at repo root (Foundry convention) | Standard Foundry layout, ready for Phase 2 Skill packaging to wrap around it. |

## Stack Touched in Phase 1

- [x] Project scaffold — `foundry.toml`, `src/`, `test/`, `script/`, forge-std
- [x] Contract — `Cascade.sol` with `register` / `invoke` / `claim` + 4 events
- [x] Local read AND write — full A→B→C tree exercised on forge EVM / anvil with zero funds
- [x] Forge scripts wired to the contract — Deploy / Register / Invoke / Claim
- [x] Deployment — `Cascade.sol` live on atlantic-testnet; one paid invoke + three claims demonstrated on-chain

## Out of Scope (Deferred to Later Slices)

- ERC-4337 smart accounts, factory, batched UserOps, EntryPoint self-bundling — Phase 3 (AA-01..03)
- `SKILL.md`, `references/`, agent-facing natural-language action layer — Phase 2 (SKILL-01..03)
- Web visualization of money flow, README, video, DoraHacks submission — Phase 4 (DEMO-03..06)
- ERC20 payment currency, overpay/refund logic, skill mutability/upgrades — out of scope for v1
- Gasless / paymaster-sponsored UserOps — v2 (GAS-01)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Wrap the deployed contract + forge scripts in `SKILL.md` + `references/` + `assets/networks.json` so an agent runtime can load register/invoke/claim as natural-language actions.
- Phase 3: A smart-account agent batches multiple invokes into one self-bundled UserOp through the real Pharos EntryPoint v0.7 — the unchanged `Cascade.sol` processes them identically to the EOA path.
- Phase 4: A web visualization animates real on-chain money flow up the tree; README + demo video; DoraHacks submission.
