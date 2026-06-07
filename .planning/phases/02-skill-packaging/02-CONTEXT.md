# Phase 2: Skill Packaging - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning
**Mode:** Auto-generated (packaging/infrastructure phase — format fully locked, no grey areas to question)

<domain>
## Phase Boundary

Turn the working Cascade contract + forge scripts (Phase 1) into a real, loadable **Anthropic Agent Skill** — the format the hackathon expects. Deliver `SKILL.md` (YAML frontmatter + body exposing register/invoke/claim as natural-language actions), a `references/` directory with per-action command templates + error handling, and ensure `assets/networks.json` is wired so the skill works on atlantic-testnet (and mainnet). Mirror the canonical layout of the official `pharos-skill-engine` (cloned at /tmp/pharos-skill-engine). This phase does NOT change contract logic and spends no funds — it is documentation/packaging only.
</domain>

<decisions>
## Implementation Decisions

### Skill Format (locked — mirror official pharos-skill-engine)
- Top-level `SKILL.md` with YAML frontmatter: `name` (e.g. `cascade`), `description` (see below), `version` (0.1.0), `requires: { anyBins: [cast, forge] }` — same shape as the reference engine's SKILL.md.
- Body: prerequisites (Foundry install check, PRIVATE_KEY config), network configuration (read from assets/networks.json), a Capability Index table mapping user needs → reference file sections, error-handling table, security reminders (key protection, exact-payment), and write-operation pre-checks (mirror the engine's structure).
- `references/` directory: one file per action group — `register.md`, `invoke.md`, `claim.md` — each with command templates (the forge scripts from Phase 1 + raw `cast` equivalents), parameters, output parsing, and an error-handling table. Mirror the engine's references/*.md structure (query.md/transaction.md/contract.md style).

### SKILL.md `description` field (highest-leverage line for judging)
- Must make an agent (and a judge) instantly understand WHEN to invoke: trigger on "pharos royalties", "skill registry", "recursive royalty", "register a skill", "invoke/pay a skill", "claim royalties", "split payment up a dependency tree". State it requires cast/forge and targets Pharos atlantic-testnet/mainnet. Keep it concrete and capability-led like the engine's description.

### networks.json
- Reuse the existing `assets/networks.json` (already added in Phase 1, byte-mirrors the official engine: atlantic-testnet chainId 688689 default + mainnet chainId 1672). Reference it from SKILL.md and references for RPC/explorer/chainId. The deployed Phase 1 contract address (0xd41C32562D0BE20D354120E1De11A91abC340F50 on atlantic-testnet) should be documented so an agent can interact with the live instance immediately.

### Claude's Discretion
- Exact wording/prose of SKILL.md and references, table formatting, and how much of the forge-script vs raw-cast guidance to include — all at implementer discretion, guided by the reference engine's style and the locked Cascade API (register(price, depIds[], depShares[]) / invoke(skillId) payable / claim()).
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/Cascade.sol` — final contract API to document: `register(uint256 price, uint256[] depIds, uint256[] depShares) returns (uint256 id)`, `invoke(uint256 skillId) payable`, `claim() returns (uint256)`, getters `balances(address)`, `skillCount()`, events SkillRegistered/Invoked/RoyaltyAccrued/Claimed.
- `script/Deploy.s.sol, Register.s.sol, Invoke.s.sol, Claim.s.sol, DemoTree.s.sol` — the exact commands references/ should document.
- `assets/networks.json` — already present, mirrors official engine.
- Reference implementation: /tmp/pharos-skill-engine/SKILL.md + references/*.md + assets/ — the canonical layout to mirror.
- Live deployed contract: 0xd41C32562D0BE20D354120E1De11A91abC340F50 (atlantic-testnet).

### Established Patterns
- Phase 1 drove everything through Foundry CLI (forge/cast); the skill docs should present both the forge scripts and raw cast equivalents per the engine's convention.

### Integration Points
- SKILL.md is the entry point an agent runtime (Claude Code/Codex/OpenClaw) loads; references are lazy-loaded per the Capability Index.
</code_context>

<specifics>
## Specific Ideas

- A judge or agent should be able to load SKILL.md and, with the documented commands, register a skill / invoke it / claim royalties against the live testnet contract without reading the Solidity source.
- Keep parity with the official engine's look-and-feel so it reads as a native Pharos skill.
</specifics>

<deferred>
## Deferred Ideas

- ERC-4337 smart-account usage docs — Phase 3 (AA-01..03) will extend the skill once the AA path exists.
- Web visualization, README polish, demo video, submission — Phase 4.
</deferred>
