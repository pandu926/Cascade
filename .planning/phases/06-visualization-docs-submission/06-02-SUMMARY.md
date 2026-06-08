---
phase: 06-visualization-docs-submission
plan: 02
subsystem: docs
tags: [readme, documentation, hackathon, dorahacks, video-script, submission, pharos, mainnet]

# Dependency graph
requires:
  - phase: 05-mainnet-deployment-live-demos
    provides: verified mainnet Cascade address + royalty/4337 demo tx hashes (MAINNET_RESULT.md)
  - phase: 06-visualization-docs-submission (plan 01)
    provides: web/index.html WOW visualization linked from README + video script + submission
provides:
  - "Top-level README.md (real project entry point) replacing Foundry boilerplate"
  - "docs/DEMO_VIDEO_SCRIPT.md — recordable 5-shot storyboard + narration (awaiting human recording)"
  - "SUBMISSION.md — turnkey DoraHacks checklist with pre-filled form fields + push commands"
affects: [06-03 final human checkpoint (record video, push, submit)]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Docs cite only on-chain-proven values from MAINNET_RESULT.md (honesty bar)"]

key-files:
  created:
    - docs/DEMO_VIDEO_SCRIPT.md
    - SUBMISSION.md
  modified:
    - README.md

key-decisions:
  - "Verified the '41 tests' claim by running forge test before committing (13+4+3+1+4+16 = 41, all green)"
  - "README documents testnet history (0xd41C…0F50) as the earlier proof, sourced from SKILL.md"
  - "SUBMISSION.md added a pre-push secret-scan section (threat T-06-04 mitigation) beyond the plan's explicit fields"
  - "Used current branch name 'master' in push commands (repo is on master, not main)"

patterns-established:
  - "Every address/tx/number in docs traces to MAINNET_RESULT.md; no invented metrics"
  - "Human-action artifacts (video, submission) shipped as checkbox checklists the human ticks through"

requirements-completed: [DEMO-04]  # DEMO-05/06 are MATERIALS-only here; the recorded video + actual DoraHacks submission are human actions in Plan 06-03 — not marked complete to hold the honesty bar.

# Metrics
duration: 14min
completed: 2026-06-08
---

# Phase 6 Plan 02: README + Video Script + Submission Materials Summary

**Real top-level README (replacing Foundry boilerplate), a recordable 5-shot demo video storyboard, and a turnkey DoraHacks submission checklist — all citing the verified Pharos mainnet proof, honesty bar held.**

## Performance

- **Duration:** ~14 min
- **Completed:** 2026-06-08
- **Tasks:** 2
- **Files modified:** 3 (1 modified, 2 created)

## Accomplishments
- Replaced the default Foundry README with a real project README: npm-recursive-royalties killer idea, architecture (Cascade.sol router + ERC-4337 AA layer + Agent Skill packaging), runnable Quickstart, a verified-mainnet table with pharosscan links, hackathon mapping, honest "not an audit" scope, and relative links to SKILL.md / references / SECURITY.md / MAINNET_RESULT.md / web demo.
- Wrote `docs/DEMO_VIDEO_SCRIPT.md`: a 5-shot storyboard (~2.5 min) — hook on the viz → one invoke fans to three creators (Σ 0.001 PROS) → the real pharosscan invoke tx → the 4337 batch → verified-contract close — marked AWAITING HUMAN RECORDING.
- Wrote `SUBMISSION.md`: pre-push safety scan, public-remote push commands (no remote yet), pre-filled DoraHacks form fields, record-video step, the carried-over pharosscan "Verified" visual-check line, and the 2026-06-15 15:59 deadline — every item a checkbox.

## Task Commits

1. **Task 1: Top-level README (DEMO-04)** - `4f24784` (feat)
2. **Task 2: Demo video script + DoraHacks submission checklist (DEMO-05/06)** - `030b567` (feat)

**Plan metadata:** (final docs commit below)

## Files Created/Modified
- `README.md` - Real project README replacing Foundry boilerplate; what/why, architecture, Quickstart, verified mainnet table, hackathon mapping, honest scope, doc links.
- `docs/DEMO_VIDEO_SCRIPT.md` - Recordable 5-shot storyboard + narration, marked awaiting human recording.
- `SUBMISSION.md` - DoraHacks submission checklist: push commands, pre-filled fields, record-video step, Verified visual-check, deadline.

## Decisions Made
- **Test count verified, not assumed:** the plan and earlier docs disagreed (SECURITY.md said 36, the plan said 41). Ran `forge test` — 41 passed (13 unit + 4 fuzz + 3 invariant + 1 demo-fork + 4 SA-fork + 16 SA-unit), all green. Used the verified 41 in README.
- **Testnet history sourced from SKILL.md:** the earlier-proof testnet address `0xd41C32562D0BE20D354120E1De11A91abC340F50` (atlantic-testnet) is cited as the pre-mainnet proof.
- **Branch name:** push commands use `master` (the repo's actual current branch) with a `main` alternative shown.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added a pre-push secret-scan section to SUBMISSION.md**
- **Found during:** Task 2 (SUBMISSION.md)
- **Issue:** The threat model assigns T-06-04 (information disclosure on public push) a `mitigate` disposition — the human must confirm no `.env` / private keys leak before the repo goes public. The plan's prose mentioned `.gitignore` excludes `.env` but did not put a verification step in the checklist itself.
- **Fix:** Added a "Pre-push safety (do this FIRST)" section with explicit secret-scan checkboxes (git status clean, `.env` gitignored grep, a long-hex scan, clean working tree).
- **Files modified:** SUBMISSION.md
- **Verification:** Section renders as checkboxes; all Task 2 automated greps still pass.
- **Committed in:** `030b567` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical / threat-model mitigation)
**Impact on plan:** The secret-scan is a correctness/security requirement from the threat register; no scope creep. All other content followed the plan as written.

## Issues Encountered
None blocking. The only thing requiring judgment was the conflicting test-count figure, resolved by running `forge test` (authoritative: 41 green).

## User Setup Required
None for this plan. The human actions (record video, push to a public remote, submit to DoraHacks, confirm the pharosscan Verified checkmark) are deliberately deferred to Plan 06-03 and are fully scripted in `docs/DEMO_VIDEO_SCRIPT.md` and `SUBMISSION.md`.

## Next Phase Readiness
- All submission materials are complete and turnkey. Plan 06-03 (the final human-verify checkpoint) can proceed: a human records the video from the storyboard, runs the push commands, ticks the pharosscan Verified visual-check, and submits the BUIDL before 2026-06-15 15:59.
- No blockers.

## Self-Check: PASSED

All created files exist on disk (README.md, docs/DEMO_VIDEO_SCRIPT.md, SUBMISSION.md, 06-02-SUMMARY.md) and both task commits (`4f24784`, `030b567`) are present in git history.

---
*Phase: 06-visualization-docs-submission*
*Completed: 2026-06-08*
