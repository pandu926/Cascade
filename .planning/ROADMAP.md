# Roadmap: Cascade

## Overview

Cascade ships the trustless recursive royalty split first — the whole idea — then layers credibility around it. Phase 1 delivered `Cascade.sol` + forge scripts + a live testnet A→B→C demo (one invoke pays three creators). Phase 2 packaged it as a real Anthropic Skill. Phase 3 fork-proved ERC-4337 smart-account batching against the real Pharos EntryPoint v0.7. The project then escalated to a publish-ready mandate: Phase 4 hardens the contracts to review-ready quality (NatSpec, custom errors, fuzz/invariant tests, static analysis + security-reviewer pass). Phase 5 deploys to Pharos mainnet, verifies source on the explorer, and runs the royalty + 4337 demos live on mainnet. Phase 6 builds the visualization, README, and submission materials — all pointing at verified mainnet data.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Recursive Royalty Core** - Contract + forge scripts + toy tree so one invoke pays three creators on testnet (completed 2026-06-07)
- [x] **Phase 2: Skill Packaging** - SKILL.md, references, and networks.json make it a loadable, reusable Skill (completed 2026-06-07)
- [x] **Phase 3: Smart-Account Agents (ERC-4337)** - Agents batch skill payments into one self-bundled UserOp via the real EntryPoint (completed 2026-06-07)
- [x] **Phase 4: Contract Hardening & Security Review** - NatSpec, custom errors, fuzz/invariant tests, static analysis + security-reviewer pass — publish-ready quality (completed 2026-06-07)
- [x] **Phase 5: Mainnet Deployment & Live Demos** - Deploy + verify on Pharos mainnet; live royalty + 4337 demos recorded with explorer links (completed 2026-06-07)
- [ ] **Phase 6: Visualization, Docs & Submission** - Animated money-flow demo (real mainnet data), README, video, DoraHacks submission

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
- [x] 02-01-PLAN.md — SKILL.md entry point + references/{register,invoke,claim}.md wired to networks.json and the live testnet contract (SKILL-01/02/03)

### Phase 3: Smart-Account Agents (ERC-4337)
**Goal**: An agent can be a smart account that pays multiple skills in a single self-bundled UserOperation through the real Pharos EntryPoint — proving the account-agnostic claim end-to-end.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: AA-01, AA-02, AA-03
**Success Criteria** (what must be TRUE):
  1. A smart account can be deployed via a simple factory and hold/spend funds on testnet
  2. A single UserOperation batches multiple skill invokes/payments into one op
  3. The UserOp settles through the real Pharos EntryPoint v0.7 (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`), self-bundled via `handleOps()` from an EOA with no external bundler
  4. The unchanged `Cascade.sol` processes the smart-account-driven royalties identically to the EOA path, confirming account-agnostic behavior
**Plans**: 3 plans
- [x] 03-01-PLAN.md — hand-written v0.7 interfaces + minimal CascadeAccount + CREATE2 AccountFactory, proven by TDD unit suite (AA-01, AA-02 machinery)
- [x] 03-02-PLAN.md — fork test: one self-bundled handleOps batches two invokes via the REAL EntryPoint v0.7, +negative AA24 +account-agnostic parity (AA-02, AA-03; primary proof)
- [x] 03-03-PLAN.md — GATED optional live step: budget-blocked on testnet, clean stop recorded in LIVE_RESULT.md (AA-03 bonus; superseded by Phase 5 mainnet demo)

### Phase 4: Contract Hardening & Security Review
**Goal**: Bring Cascade.sol + the AA contracts to publish-ready, review-grade quality before any mainnet value flows through them.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: HARD-01, HARD-02, HARD-03
**Success Criteria** (what must be TRUE):
  1. Every public/external function + event has complete NatSpec; `require` strings are replaced with named custom errors; `forge fmt` is clean
  2. The test suite gains fuzz + invariant coverage across Cascade and the AA layer, all green, with a committed `.gas-snapshot`
  3. Static analysis (slither if installable) plus a security-reviewer agent pass are complete, and every CRITICAL/HIGH finding is resolved or documented with explicit rationale
  4. `Cascade.sol`'s external behavior/ABI is unchanged where already verified by Phases 1/3 tests (hardening is non-breaking — all prior tests still pass)
**Plans**: 3 plans
- [x] 04-01-PLAN.md — NatSpec + named custom errors across Cascade + AA, revert-asserting tests flipped to selectors, forge fmt clean, full+fork suite green (HARD-01)
- [x] 04-02-PLAN.md — fuzz (conservation/no-overpay) + stateful invariant (solvency/no-wei-created) suites + committed .gas-snapshot (HARD-02)
- [x] 04-03-PLAN.md — slither attempt (documented fallback + SWC checklist) + security-reviewer pass + SECURITY.md with resolved/accepted findings (HARD-03)

### Phase 5: Mainnet Deployment & Live Demos
**Goal**: Deploy the hardened contracts to Pharos mainnet, verify source on the explorer, and demonstrate both the royalty split and the 4337 batch live on mainnet.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: MAIN-01, MAIN-02, MAIN-03
**Success Criteria** (what must be TRUE):
  1. Cascade is deployed to Pharos mainnet (chainId 1672) and its source is verified on pharosscan (green checkmark / readable code)
  2. A live mainnet invoke of an A→B→C tree raises three distinct creator balances proportionally in one tx; tx hashes + explorer links recorded
  3. A live mainnet smart account batches two invokes in one self-bundled `handleOps` via the real EntryPoint v0.7; tx hashes + explorer links recorded
  4. Every spend is gated by a pre-flight balance/gas check and confirmed before broadcast; all results captured in a MAINNET_RESULT.md
**Plans**: 3 plans
- [x] 05-01-PLAN.md — pre-flight gated mainnet deploy of Cascade + ranked source-verify on pharosscan, recorded in MAINNET_RESULT.md (MAIN-01)
- [x] 05-02-PLAN.md — live A→B→C royalty demo: fund 3 creators, one invoke pays three proportionally (Σ==PRICE_C), recorded (MAIN-02)
- [x] 05-03-PLAN.md — live 4337 demo: factory+account deploy, one self-bundled handleOps batches two invokes via real EntryPoint v0.7 + final human-verify (MAIN-03)

### Phase 6: Visualization, Docs & Submission
**Goal**: Turn the working, mainnet-deployed system into a compelling, documented, submitted entry.
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: DEMO-03, DEMO-04, DEMO-05, DEMO-06
**Success Criteria** (what must be TRUE):
  1. A web visualization renders the dependency tree and animates money flowing up it, driven by real mainnet on-chain state
  2. The README lets a fresh reader set up the repo and run register / invoke / claim against Pharos, and documents the verified mainnet addresses
  3. A demo video shows one invoke fanning royalties to three creators (and the batched smart-account UserOp)
  4. The repo link and demo video are submitted to DoraHacks before the deadline
**Plans**: 3 plans
- [x] 06-01-PLAN.md — WOW web visualization: A→B→C money-flow animated from real mainnet data, both demos, pharosscan links (DEMO-03)
- [x] 06-02-PLAN.md — README + docs/DEMO_VIDEO_SCRIPT.md + SUBMISSION.md materials (DEMO-04; DEMO-05/06 materials)
- [ ] 06-03-PLAN.md — final human-verify checkpoint: record video, push + submit to DoraHacks, confirm pharosscan Verified checkmark (DEMO-05, DEMO-06)
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Recursive Royalty Core | 3/3 | Complete   | 2026-06-07 |
| 2. Skill Packaging | 1/1 | Complete   | 2026-06-07 |
| 3. Smart-Account Agents (ERC-4337) | 3/3 | Complete   | 2026-06-07 |
| 4. Contract Hardening & Security Review | 3/3 | Complete   | 2026-06-07 |
| 5. Mainnet Deployment & Live Demos | 3/3 | Complete   | 2026-06-07 |
| 6. Visualization, Docs & Submission | 2/3 | In Progress|  |
