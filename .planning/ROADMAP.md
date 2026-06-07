# Roadmap: Cascade

## Overview

Cascade ships the trustless recursive royalty split first — the whole idea — then layers credibility around it. Phase 1 delivers the `Cascade.sol` contract plus forge scripts and a deployed A→B→C toy tree on testnet, so that a single `invoke` visibly pays three creators on-chain (a valid, submittable Skill on its own). Phase 2 packages it as a real Anthropic Skill (`SKILL.md`, `references/`, `networks.json`) so agent runtimes can load and use it. Phase 3 adds ERC-4337 smart-account agents that batch payments into one self-bundled UserOp through the real Pharos EntryPoint — additive, never blocking the core. Phase 4 makes the demo compelling and gets it out the door: web visualization of money flowing up the tree, README, demo video, and DoraHacks submission.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Recursive Royalty Core** - Contract + forge scripts + toy tree so one invoke pays three creators on testnet (completed 2026-06-07)
- [ ] **Phase 2: Skill Packaging** - SKILL.md, references, and networks.json make it a loadable, reusable Skill
- [ ] **Phase 3: Smart-Account Agents (ERC-4337)** - Agents batch skill payments into one self-bundled UserOp via the real EntryPoint
- [ ] **Phase 4: Visualization, Docs & Submission** - Animated money-flow demo, README, video, DoraHacks submission

## Phase Details

### Phase 1: Recursive Royalty Core
**Goal**: A single on-chain invoke pays every creator in a declared dependency tree proportionally, demonstrable end-to-end on atlantic-testnet.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, SKILL-04, DEMO-01, DEMO-02
**Success Criteria** (what must be TRUE):
  1. An author can register a skill with price, declared dependencies, and percentage shares via a forge script; registering a skill whose deps don't yet exist, or that would form a cycle, reverts
  2. Running the demo invoke script performs one paid invoke and three distinct creator balances rise on-chain in proportion to their depth in the A→B→C tree
  3. Each creator can independently claim their accrued royalty to their own wallet (pull-payment), and claiming twice does not double-pay
  4. Invoke gas stays bounded — a tree deeper than the depth cap reverts rather than running unbounded
  5. The same `Cascade.sol`, unchanged, accepts an invoke from a plain EOA (account-agnostic by construction)
**Plans**: 3 plans
- [x] 01-01-PLAN.md — Cascade.sol registry + recursive royalty router, proven by local test suite (CORE-01..07)
- [x] 01-02-PLAN.md — register/invoke/claim forge scripts + A→B→C demo driver, run locally zero-funds (SKILL-04, DEMO-01/02 local)
- [x] 01-03-PLAN.md — live atlantic-testnet deploy + on-chain A→B→C invoke/claim demo (DEMO-01, DEMO-02)

### Phase 2: Skill Packaging
**Goal**: Cascade is a real Anthropic Skill that an agent runtime can load and act on, not just a deployed contract.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: SKILL-01, SKILL-02, SKILL-03
**Success Criteria** (what must be TRUE):
  1. An agent runtime can load `SKILL.md` and surface register / invoke / claim as natural-language actions from its YAML frontmatter
  2. `references/` files give copy-paste command templates plus error handling for each of register, invoke, and claim, mirroring the official engine layout
  3. `assets/networks.json` defines both atlantic-testnet and mainnet, and the forge scripts resolve their target network from it
**Plans**: 1 plan
- [ ] 02-01-PLAN.md — SKILL.md entry point + references/{register,invoke,claim}.md wired to networks.json and the live testnet contract (SKILL-01/02/03)

### Phase 3: Smart-Account Agents (ERC-4337)
**Goal**: An agent can be a smart account that pays multiple skills in a single self-bundled UserOperation through the real Pharos EntryPoint — proving the account-agnostic claim end-to-end.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: AA-01, AA-02, AA-03
**Success Criteria** (what must be TRUE):
  1. A smart account can be deployed via a simple factory and hold/spend funds on testnet
  2. A single UserOperation batches multiple skill invokes/payments into one op
  3. The UserOp settles through the real Pharos EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`), self-bundled via `handleOps()` from an EOA with no external bundler, and the tx is visible on the testnet explorer
  4. The unchanged `Cascade.sol` processes the smart-account-driven royalties identically to the EOA path, confirming account-agnostic behavior
**Plans**: TBD

### Phase 4: Visualization, Docs & Submission
**Goal**: Turn the working system into a compelling, documented, submitted entry.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: DEMO-03, DEMO-04, DEMO-05, DEMO-06
**Success Criteria** (what must be TRUE):
  1. A web visualization renders the dependency tree and animates money flowing up it, driven by real on-chain state from a testnet invoke
  2. The README lets a fresh reader set up the repo and run register / invoke / claim against testnet
  3. A demo video shows one invoke fanning royalties to three creators (and, if shipped, the batched smart-account UserOp)
  4. The repo link and demo video are submitted to DoraHacks before the deadline
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Recursive Royalty Core | 3/3 | Complete   | 2026-06-07 |
| 2. Skill Packaging | 0/1 | Not started | - |
| 3. Smart-Account Agents (ERC-4337) | 0/TBD | Not started | - |
| 4. Visualization, Docs & Submission | 0/TBD | Not started | - |
