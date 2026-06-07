---
phase: 02-skill-packaging
plan: 01
subsystem: infra
tags: [anthropic-skill, foundry, cast, forge, pharos, documentation, cascade]

# Dependency graph
requires:
  - phase: 01-recursive-royalty-core
    provides: Cascade.sol API (register/invoke/claim), forge scripts, deployed testnet contract, assets/networks.json
provides:
  - SKILL.md entry point exposing register/invoke/claim as natural-language agent actions
  - references/register.md, references/invoke.md, references/claim.md command templates + error tables
  - Documented live CASCADE address (0xd41C32562D0BE20D354120E1De11A91abC340F50) so agents act on the live instance
affects: [phase-03-smart-account-agents, phase-04-visualization-docs-submission]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Anthropic Agent Skill layout mirroring pharos-skill-engine (top-level SKILL.md + references/ + assets/)"
    - "Dual command templates per action: forge script (env-var driven) + raw cast send/call equivalent"
    - "Network values resolved only from assets/networks.json (no invented endpoints)"

key-files:
  created:
    - SKILL.md
    - references/register.md
    - references/invoke.md
    - references/claim.md
  modified: []

key-decisions:
  - "Mirrored pharos-skill-engine SKILL.md/references structure for native look-and-feel"
  - "Documented both forge-script and raw cast forms per action so agents can copy-paste either"
  - "Surfaced double-claim-pays-zero (no revert) explicitly as expected behavior, not an error"

patterns-established:
  - "Per-operation reference structure: Command Template (forge + cast) → Parameters table → Output Parsing (events) → Error Handling table → Agent Guidelines"
  - "Every reference cross-links assets/networks.json for --rpc-url and the canonical live CASCADE address"

requirements-completed: [SKILL-01, SKILL-02, SKILL-03]

# Metrics
duration: 9min
completed: 2026-06-07
---

# Phase 2 Plan 01: Skill Packaging Summary

**Cascade packaged as a loadable Anthropic Agent Skill — SKILL.md frontmatter exposing register/invoke/claim plus three reference files with forge + cast command templates wired to the live atlantic-testnet contract.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-07
- **Completed:** 2026-06-07
- **Tasks:** 2
- **Files modified:** 4 (all created)

## Accomplishments
- SKILL.md entry point with valid YAML frontmatter (name=cascade, trigger-rich description, version=0.1.0, requires.anyBins=[cast,forge]) and a six-section body: Prerequisites, Network Configuration (with live address), Capability Index, General Error Handling, Security Reminders, Write Operation Pre-checks
- references/register.md, invoke.md, claim.md each document the real Cascade API with both forge-script and raw cast command templates, parameter tables, event-based output parsing, and revert-string error tables
- Live deployed contract 0xd41C32562D0BE20D354120E1De11A91abC340F50 documented across all docs so an agent can act on the live instance without reading Cascade.sol
- Verified assets/networks.json contains both atlantic-testnet (688689, default) and mainnet (1672); reused unmodified

## Task Commits

Each task was committed atomically:

1. **Task 1: SKILL.md entry point + network wiring** - `48773a2` (docs)
2. **Task 2: references/ command templates + error tables** - `63fc0ea` (docs)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `SKILL.md` - Skill entry point: frontmatter + Prerequisites, Network Configuration, Capability Index, error table, Security Reminders, Write Op Pre-checks
- `references/register.md` - register(uint256,uint256[],uint256[]) forge + cast templates, dep/share/depth rules, SkillRegistered event, revert table
- `references/invoke.md` - invoke(uint256) payable templates, exact-payment rule, Invoked/RoyaltyAccrued events, revert table
- `references/claim.md` - claim() pull-payment template, balances(address)/skillCount() getters, Claimed event, double-claim-pays-zero behavior

## Decisions Made
- Mirrored the official pharos-skill-engine layout (top-level SKILL.md + references/ + reused assets/) for parity with native Pharos skills
- Provided both forge-script (env-var driven, matching script/*.s.sol) and raw cast send/call forms per action, giving agents two interchangeable paths
- Documented the `foundry.toml` rpc aliases (atlantic_testnet/mainnet) alongside the literal rpcUrl from networks.json
- Surfaced the double-claim-pays-zero (no revert) behavior explicitly in claim.md's error table as expected, not a failure

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Verified the live contract responds (skillCount() == 3, matching the Phase 1 A→B→C demo tree) and that no 64-hex private-key string appears anywhere in the docs (only the 40-hex contract address).

## User Setup Required
None - pure documentation/packaging phase. No external service configuration, no funds spent, no contract changes.

## Next Phase Readiness
- Cascade is now a loadable Anthropic Skill: an agent runtime can load SKILL.md and follow the Capability Index into each reference to register/invoke/claim against the live testnet contract.
- Phase 3 (ERC-4337 smart-account agents) can extend this skill with an AA path once it exists; the account-agnostic Cascade core needs no doc changes for EOA usage.

---
*Phase: 02-skill-packaging*
*Completed: 2026-06-07*

## Self-Check: PASSED

- SKILL.md — FOUND
- references/register.md — FOUND
- references/invoke.md — FOUND
- references/claim.md — FOUND
- .planning/phases/02-skill-packaging/02-01-SUMMARY.md — FOUND
- Commit 48773a2 (Task 1) — FOUND
- Commit 63fc0ea (Task 2) — FOUND
