# Requirements: Cascade

**Defined:** 2026-06-07
**Core Value:** One `invoke`, and every creator in the composition tree gets paid automatically, proportional to their depth — the trustless recursive royalty split must work on-chain.

## v1 Requirements

### Core — Royalty Contract

- [ ] **CORE-01**: Skill author can register a skill with a price and a declared list of dependencies + percentage shares
- [ ] **CORE-02**: Contract rejects dependency cycles and requires dependencies to be registered first (bottom-up)
- [ ] **CORE-03**: Agent can invoke + pay for a skill in one transaction; payment accrues up the entire dependency tree proportionally
- [ ] **CORE-04**: Recursion is depth-capped to bound gas
- [ ] **CORE-05**: Royalties use pull-payment (accrue balance, claim separately), not push
- [ ] **CORE-06**: Each creator can claim accumulated royalties
- [ ] **CORE-07**: `Cascade.sol` is account-agnostic — works whether called by an EOA or a smart account

### AA — ERC-4337 Integration

- [ ] **AA-01**: An agent can be a deployed smart account (via a simple factory)
- [ ] **AA-02**: Invoke can be expressed as a UserOperation that batches multiple skill payments into one op
- [ ] **AA-03**: UserOps settle through the real Pharos EntryPoint (v0.7), self-bundled via `handleOps()` from an EOA (no external bundler)

### Skill — Packaging

- [ ] **SKILL-01**: `SKILL.md` with YAML frontmatter exposing register / invoke / claim as natural-language agent actions
- [ ] **SKILL-02**: `references/` files with command templates + error handling per action (mirrors official engine layout)
- [ ] **SKILL-03**: `assets/networks.json` supporting both atlantic-testnet and mainnet
- [ ] **SKILL-04**: Forge scripts for register / invoke / claim

### Demo — Proof

- [ ] **DEMO-01**: 3 toy skills deployed to testnet forming a dependency tree (A→B→C)
- [ ] **DEMO-02**: End-to-end demo script: one invoke, show 3 separate creator balances rise on-chain
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

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | — | Pending |
| CORE-02 | — | Pending |
| CORE-03 | — | Pending |
| CORE-04 | — | Pending |
| CORE-05 | — | Pending |
| CORE-06 | — | Pending |
| CORE-07 | — | Pending |
| AA-01 | — | Pending |
| AA-02 | — | Pending |
| AA-03 | — | Pending |
| SKILL-01 | — | Pending |
| SKILL-02 | — | Pending |
| SKILL-03 | — | Pending |
| SKILL-04 | — | Pending |
| DEMO-01 | — | Pending |
| DEMO-02 | — | Pending |
| DEMO-03 | — | Pending |
| DEMO-04 | — | Pending |
| DEMO-05 | — | Pending |
| DEMO-06 | — | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 20 ⚠️

---
*Requirements defined: 2026-06-07*
*Last updated: 2026-06-07 after initial definition*
