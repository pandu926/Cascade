# Cascade — Pharos Recursive Skill Royalties

## What This Is

Cascade is a Pharos **Skill** (Anthropic Agent Skills format: `SKILL.md` + `references/` + `assets/` + smart contract) that adds a recursive royalty layer to the Skill ecosystem. Skill authors declare their dependencies and percentage splits at registration time; when an AI agent invokes and pays for a skill, an on-chain contract automatically splits the payment up the entire declared dependency tree — trustless, in a single transaction, via pull-payment. Built for the Pharos Skill-to-Agent Dual Cascade Hackathon, Phase 1 (Skill Hackathon track: 20,000 PROS, 40 winners).

Analogy: *npm, but every package earns a cut every time it's used downstream — automatically, instantly, recursively.*

## Core Value

One `invoke`, and every creator in the composition tree gets paid automatically, proportional to their depth in the tree. If everything else fails, the **trustless recursive royalty split must work on-chain** — that single demonstrable behavior is the whole idea.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Core contract (the innovation)**
- [ ] Skill authors can register a skill with a price and a declared list of dependencies + percentage shares
- [ ] Contract rejects dependency cycles and requires dependencies to be registered first (bottom-up)
- [ ] Agents can invoke + pay for a skill in one transaction; payment accrues up the entire dependency tree proportionally
- [ ] Recursion is depth-capped to bound gas
- [ ] Royalties use pull-payment (accrue balance, claim separately) — never push
- [ ] Each creator can claim accumulated royalties
- [ ] `Cascade.sol` is account-agnostic — works whether called by an EOA or a smart account

**ERC-4337 integration (the Pharos-native hook)**
- [ ] An agent can be a deployed smart account (via a simple factory)
- [ ] Invoke can be expressed as a UserOperation that batches multiple skill payments into one op
- [ ] UserOps settle through the real Pharos EntryPoint (v0.7), self-bundled via `handleOps()` from an EOA (no external bundler)

**Skill packaging (so it's a real Skill, not just a contract)**
- [ ] `SKILL.md` with YAML frontmatter exposing register / invoke / claim as natural-language agent actions
- [ ] `references/` files with command templates + error handling per action (mirrors official engine layout)
- [ ] `assets/networks.json` supporting both atlantic-testnet and mainnet
- [ ] Forge scripts for register / invoke / claim

**Demo + proof**
- [ ] 3 toy skills deployed to testnet forming a dependency tree (A→B→C)
- [ ] End-to-end demo script: one invoke, show 3 separate creator balances rise on-chain
- [ ] Web visualization: dependency tree + animated money flowing up the tree
- [ ] README with setup/usage instructions
- [ ] Demo video
- [ ] Submitted to DoraHacks (repo link + demo video)

### Out of Scope

- **Running a production bundler** — no public bundler exists on Pharos; we self-bundle via `EntryPoint.handleOps()` instead (this is how the official 4337 test suite works)
- **Paymaster / gasless transactions** — stretch goal only; requires Pharos team access or a self-deployed paymaster, not core to the royalty innovation
- **Observed/runtime call tracking** — we use *declared* dependency trees, not observed runtime calls, because observation requires trusting a reporter; declaration is trustless and incentive-compatible (declaring fake deps wastes your own money)
- **Detecting/enforcing undeclared dependencies** — the only "cheat" is failing to declare a real dependency; that's a norms/licensing problem, not a contract exploit. Flagged as honest future work
- **Mainnet production launch with real funds** — config supports mainnet, but development and demo happen on testnet

## Context

- **Event:** Pharos Skill-to-Agent Dual Cascade Hackathon. Phase 1 = Skill Hackathon (20K PROS, 40 winners). Submission opens 2026-06-08, deadline 2026-06-15 15:59 (page has a date inconsistency: timeline says June 15, detail text says June 16 — we target the earlier date). Judging 17–22 June.
- **Skill format:** Anthropic Agent Skills standard — a `SKILL.md` (frontmatter: name, description, version, requires) plus `references/*.md` and `assets/`. Loaded by agent runtimes (Claude Code, Codex, OpenClaw). Invoked via `cast`/`forge`. Reference implementation: official `pharos-skill-engine` repo (cloned at `/tmp/pharos-skill-engine`).
- **Judging criteria (Phase 1 focus = quality + usability of Skill modules):** originality, technical quality/completeness, practical AI-agent use case, **reusability & composability** (most relevant to us), Pharos integration, UX/docs, alignment with Pharos AI-agent + on-chain economy vision.
- **Competitive landscape:** Sampled competitors (Reepatts reentrancy scanner, SVGM onchain SVG minter, Pharos Agent Evolution Lab) are all **human-facing tools or single-agent systems**. None touch the inter-agent economy. None are genuinely "only possible on Pharos." Cascade occupies open whitespace: economic infrastructure *between* agents.
- **Format lesson from competitors:** winners ship working code + clean demo (SVGM = full Hardhat project + GitHub Pages demo), not just a manifest. Execution bar is high.

### Verified Pharos primitives (from docs.pharos.xyz/llms-full.txt)

| Primitive | Status |
|-----------|--------|
| Sub-second finality (L1-Core) | ✅ Claimed in docs — supports "money flows instantly" UX argument |
| ERC-4337 EntryPoint v0.7 | ✅ Deployed testnet + mainnet: `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| ERC-4337 SenderCreator v0.7 | ✅ `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C` |
| ERC-4337 EntryPoint/SenderCreator v0.6 | ✅ Deployed (mainnet) |
| Parallel EVM | ❌ None — docs explicitly critique the approach |
| Cheap gas | ❌ Not proven — opcode pricing "fully aligned with Ethereum EVM" |
| Stated TPS / block time | ❌ Not published |
| Agent-native features (precompiles, identity) | ❌ None |
| Public bundler endpoint | ❌ None — docs say contact team (janesh@dplabs.xyz / TG @janesh_dani) |
| Paymaster service | ❌ None documented |

**Honest "why Pharos" positioning:** Cascade is not *technically* impossible elsewhere (it's EVM-portable). Its "why Pharos" rests on **ecosystem + economics + real AA integration + sub-second finality** — the first economic-composability primitive built *for* the Pharos agent ecosystem. Notably, **no competitor has a technical moat either**, so this is a level field where originality + vision-fit win.

## Constraints

- **Timeline**: ~8 days (2026-06-08 to 2026-06-15) — drives aggressive scoping; core royalty logic must never be at risk
- **Tech stack**: Solidity + Foundry (`cast`/`forge`), repo layout mirroring the official `pharos-skill-engine`; Node.js/TypeScript + viem for agent scripts (matching SVGM's proven approach)
- **Network**: atlantic-testnet (chainId 688689, PHRS) primary for dev/demo; mainnet (chainId 1672, PROS) supported in config, marked mainnet-ready
- **4337 infra**: self-bundle via `EntryPoint.handleOps()` — no public bundler exists on Pharos
- **Submission**: GitHub/GitLab/Bitbucket repo link + demo video both required by DoraHacks

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Declared dependency tree, not observed runtime calls | Observation needs a trusted reporter (fragile); declaration is trustless and incentive-compatible — fake deps only waste the declarer's own money | — Pending |
| Pull-payment (accrue + claim), not push | Prevents reentrancy, a single failing payee blocking the whole tree, and unbounded gas. (Ironic flex: competitor Reepatts scans for the reentrancy bug we avoid by design) | — Pending |
| `Cascade.sol` account-agnostic | Core royalty logic must not be hostage to 4337 infrastructure risk | — Pending |
| ERC-4337 via self-bundle (`handleOps` from EOA) | No public bundler on Pharos; self-bundling is how the official 4337 test suite operates — real AA, on-chain, without bundler infra | — Pending |
| Smart-account agents in scope (user choice) | Stronger Pharos-integration claim; demo "agent pays many skills in one UserOp" | — Pending |
| Web visualization required in v1 (user choice) | Makes the demo video visually compelling (money flowing up a tree) | — Pending |
| Both networks in config (user choice) | Demo on testnet, claim mainnet-ready credibly | — Pending |
| Gasless/paymaster = stretch, not v1 | Needs Pharos team access; not core to royalty innovation | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-07 after initialization*
