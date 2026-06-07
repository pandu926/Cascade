<!-- GSD:project-start source:PROJECT.md -->
## Project

**Cascade — Pharos Recursive Skill Royalties**

Cascade is a Pharos **Skill** (Anthropic Agent Skills format: `SKILL.md` + `references/` + `assets/` + smart contract) that adds a recursive royalty layer to the Skill ecosystem. Skill authors declare their dependencies and percentage splits at registration time; when an AI agent invokes and pays for a skill, an on-chain contract automatically splits the payment up the entire declared dependency tree — trustless, in a single transaction, via pull-payment. Built for the Pharos Skill-to-Agent Dual Cascade Hackathon, Phase 1 (Skill Hackathon track: 20,000 PROS, 40 winners).

Analogy: *npm, but every package earns a cut every time it's used downstream — automatically, instantly, recursively.*

**Core Value:** One `invoke`, and every creator in the composition tree gets paid automatically, proportional to their depth in the tree. If everything else fails, the **trustless recursive royalty split must work on-chain** — that single demonstrable behavior is the whole idea.

### Constraints

- **Timeline**: ~8 days (2026-06-08 to 2026-06-15) — drives aggressive scoping; core royalty logic must never be at risk
- **Tech stack**: Solidity + Foundry (`cast`/`forge`), repo layout mirroring the official `pharos-skill-engine`; Node.js/TypeScript + viem for agent scripts (matching SVGM's proven approach)
- **Network**: atlantic-testnet (chainId 688689, PHRS) primary for dev/demo; mainnet (chainId 1672, PROS) supported in config, marked mainnet-ready
- **4337 infra**: self-bundle via `EntryPoint.handleOps()` — no public bundler exists on Pharos
- **Submission**: GitHub/GitLab/Bitbucket repo link + demo video both required by DoraHacks
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

Technology stack not yet documented. Will populate after codebase mapping or first phase.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
