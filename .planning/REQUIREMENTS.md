# Requirements: Cascade

**Defined:** 2026-06-07
**Core Value:** One `invoke`, and every creator in the composition tree gets paid automatically, proportional to their depth — the trustless recursive royalty split must work on-chain.

## v1 Requirements

### Core — Royalty Contract

- [x] **CORE-01**: Skill author can register a skill with a price and a declared list of dependencies + percentage shares
- [x] **CORE-02**: Contract rejects dependency cycles and requires dependencies to be registered first (bottom-up)
- [x] **CORE-03**: Agent can invoke + pay for a skill in one transaction; payment accrues up the entire dependency tree proportionally
- [x] **CORE-04**: Recursion is depth-capped to bound gas
- [x] **CORE-05**: Royalties use pull-payment (accrue balance, claim separately), not push
- [x] **CORE-06**: Each creator can claim accumulated royalties
- [x] **CORE-07**: `Cascade.sol` is account-agnostic — works whether called by an EOA or a smart account

### AA — ERC-4337 Integration

- [x] **AA-01**: An agent can be a deployed smart account (via a simple factory)
- [x] **AA-02**: Invoke can be expressed as a UserOperation that batches multiple skill payments into one op
- [x] **AA-03**: UserOps settle through the real Pharos EntryPoint (v0.7), self-bundled via `handleOps()` from an EOA (no external bundler)

### Skill — Packaging

- [x] **SKILL-01**: `SKILL.md` with YAML frontmatter exposing register / invoke / claim as natural-language agent actions
- [x] **SKILL-02**: `references/` files with command templates + error handling per action (mirrors official engine layout)
- [x] **SKILL-03**: `assets/networks.json` supporting both atlantic-testnet and mainnet
- [x] **SKILL-04**: Forge scripts for register / invoke / claim

### Demo — Proof

- [x] **DEMO-01**: 3 toy skills deployed to testnet forming a dependency tree (A→B→C)
- [x] **DEMO-02**: End-to-end demo script: one invoke, show 3 separate creator balances rise on-chain
- [ ] **DEMO-03**: Web visualization — dependency tree + animated money flowing up the tree
- [ ] **DEMO-04**: README with setup/usage instructions
- [ ] **DEMO-05**: Demo video
- [ ] **DEMO-06**: Submitted to DoraHacks (repo link + demo video)

## v2 Requirements

### Gasless

- **GAS-01**: Sponsored/gasless UserOperations via a paymaster (requires Pharos team access or self-deployed paymaster)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Running a production bundler | No public bundler on Pharos; self-bundle via `EntryPoint.handleOps()` (how the official 4337 test suite works) |
| Paymaster / gasless transactions | Stretch only; needs Pharos team access, not core to royalty innovation |
| Observed/runtime call tracking | Observation needs a trusted reporter (fragile); declared trees are trustless + incentive-compatible |
| Enforcing undeclared dependencies | Only "cheat" is failing to declare a real dep — a norms/licensing problem, not a contract exploit |
| Mainnet launch with real funds | Config supports mainnet, but dev + demo happen on testnet |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1 | Complete |
| CORE-02 | Phase 1 | Complete |
| CORE-03 | Phase 1 | Complete |
| CORE-04 | Phase 1 | Complete |
| CORE-05 | Phase 1 | Complete |
| CORE-06 | Phase 1 | Complete |
| CORE-07 | Phase 1 | Complete |
| AA-01 | Phase 3 | Complete |
| AA-02 | Phase 3 | Complete |
| AA-03 | Phase 3 | Complete |
| SKILL-01 | Phase 2 | Complete |
| SKILL-02 | Phase 2 | Complete |
| SKILL-03 | Phase 2 | Complete |
| SKILL-04 | Phase 1 | Complete |
| DEMO-01 | Phase 1 | Complete |
| DEMO-02 | Phase 1 | Complete |
| DEMO-03 | Phase 4 | Pending |
| DEMO-04 | Phase 4 | Pending |
| DEMO-05 | Phase 4 | Pending |
| DEMO-06 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20 ✓
- Unmapped: 0

---
*Requirements defined: 2026-06-07*
*Last updated: 2026-06-07 after roadmap creation (4 phases, 20/20 mapped)*
