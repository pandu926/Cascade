# Phase 4: Visualization, Docs & Submission - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the working, fork-proven Cascade system into a compelling, documented, submitted hackathon entry. Deliver: (1) a web visualization of the dependency tree with money animating up it, driven by REAL on-chain state; (2) a README that lets a fresh reader set up the repo and run register/invoke/claim against testnet; (3) a demo video; (4) the DoraHacks submission. Critically — items 3 and 4 (video recording + DoraHacks submission + the prerequisite public-repo push) are HUMAN ACTIONS that cannot be automated; this phase builds everything buildable (viz + README + all submission materials/scripts) and surfaces the human steps as explicit, ready-to-execute checklists.
</domain>

<decisions>
## Implementation Decisions

### DEMO-03 — Web Visualization (buildable, zero new funds)
- **Driven by REAL on-chain data with no new spend:** Phase 1 already performed a live invoke (tx 0x67bfa70481cd8fce39de58e4bd563da6af1707f8013a4ccee95ba7af07b39d93) on the live Cascade (0xd41C32562D0BE20D354120E1De11A91abC340F50, atlantic-testnet) emitting 1 Invoked + 3 RoyaltyAccrued events (A +0.0002 / B +0.0003 / C +0.0005, Σ=0.001). The viz renders THIS real data.
- **Robustness for video recording:** bake the real Phase 1 event data into a committed JSON snapshot the page renders by default (so recording never depends on RPC/CORS availability), AND display the real tx hashes + explorer links so it's verifiably real, not mocked. Optionally attempt a live RPC fetch with graceful fallback to the snapshot.
- **Tech:** single self-contained static page (plain HTML + CSS + vanilla JS or a tiny dependency) — no build step, opens with `open index.html` or a trivial static serve. Keep it dependency-light so a judge can run it instantly.
- **Design direction (anti-template, fits the subject):** dark technical/"on-chain terminal" aesthetic — monospace accents, a clear A→B→C node graph, and an ANIMATED payment flowing UP the tree from the invoker to the three creators with amounts ticking up. The animated money-flow up the composition tree is the single wow-moment that mirrors the project's core value. Intentional motion (compositor-friendly transform/opacity), clear hierarchy, semantic HTML. NOT a generic card grid or stock hero.

### DEMO-04 — README (buildable)
- A real top-level README.md: what Cascade is (recursive skill royalties on Pharos), the killer idea, architecture (Cascade.sol + AA layer + Skill packaging), quickstart (install Foundry, configure PRIVATE_KEY, run forge test, run the demo against testnet), the live deployed addresses + explorer links, how it maps to the hackathon (Skill Hackathon track), and pointers to SKILL.md + references. Honest about what's proven (recursive royalties live on-chain; 4337 fork-proven; live 4337 budget-gated).
- NOTE: there is a pre-existing untracked README.md stub in the tree — replace/flesh it out into the real thing.

### DEMO-05 — Demo Video (HUMAN ACTION — prepare materials only)
- I CANNOT record a video. Produce a tight shot-by-shot storyboard + narration script (≤ ~2-3 min) in a committed file (e.g. docs/DEMO_VIDEO_SCRIPT.md): show the one-invoke→three-balances-rise moment (via the web viz + the real explorer tx), the recursive royalty idea, and optionally the fork-proven 4337 batch. Mark as awaiting human recording.

### DEMO-06 — DoraHacks Submission (HUMAN ACTION — prepare materials only)
- I CANNOT submit (requires DoraHacks login) and the repo has NO git remote yet — submission needs a PUBLIC repo link, so a human must push to GitHub/GitLab first. Produce a committed SUBMISSION.md checklist: (a) push repo to a public remote (commands ready), (b) record + upload the video, (c) DoraHacks form fields filled in (skill name, description, GitHub link, demo link, instructions, framework, dependencies) using the exact required format from the hackathon page, (d) submit before deadline 2026-06-15 15:59. Surface this as the final human-verify checkpoint.

### Claude's Discretion
- Exact viz layout/styling/animation implementation, README prose, and the precise wording of the video script + submission text — all implementer's choice within the design direction above.
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets / Real Data to Render
- Live Cascade: 0xd41C32562D0BE20D354120E1De11A91abC340F50 (atlantic-testnet, chainId 688689, explorer https://atlantic.pharosscan.xyz/).
- Phase 1 live demo: invoke tx 0x67bfa70481cd8fce39de58e4bd563da6af1707f8013a4ccee95ba7af07b39d93, claim tx 0xe90d8b2f28a3207134786111b45369cc584c4bb9467f9827b5751c2b54c57120. A→B→C tree: A +0.0002, B +0.0003, C +0.0005 ether (Σ 0.001 = invoke price). See .planning/phases/01-recursive-royalty-core/DEMO_RESULT.md for full data.
- SKILL.md + references/{register,invoke,claim}.md (Phase 2) — README links to these.
- src/Cascade.sol, src/aa/* (the system the README documents).
- assets/networks.json (network config). .env is gitignored (never reference its contents in docs).

### Established Patterns
- Repo is greenfield git, NO remote configured (relevant to DEMO-06 — human must add remote + push).
- Pre-existing untracked: README.md (stub — flesh out), HACKATHON_PHAROS_PHASE1.md (research notes; leave or fold into docs at discretion).

### Integration Points
- Viz reads committed snapshot of real on-chain events; README ties together SKILL.md + contracts + live addresses; SUBMISSION.md gates the human push+submit.
</code_context>

<specifics>
## Specific Ideas

- The web viz's animated money-flow-up-the-tree is the visual centerpiece of the demo video — make that one moment crisp and legible at video resolution.
- Everything here is zero-new-funds: the real on-chain proof already exists from Phase 1. No testnet spend needed in this phase.
- Be scrupulously honest in README about what is live vs fork-proven vs budget-blocked (judges value accurate claims).
</specifics>

<deferred>
## Deferred Ideas

- Actually recording the video and submitting to DoraHacks — explicitly HUMAN actions; this phase prepares everything but cannot perform them.
- Live on-chain 4337 demo — remains budget-blocked from Phase 3 (optional top-up + re-run documented in LIVE_RESULT.md); not required for submission.
</deferred>
