# Phase 6: Visualization, Docs & Submission - Context

**Gathered:** 2026-06-08
**Status:** Ready for planning
**Mode:** Final phase. Build everything buildable (WOW viz + README + all submission materials + video script); the two genuine human actions (record video, submit to DoraHacks) are prepared-but-not-performed and surfaced as a checklist.

<domain>
## Phase Boundary

Turn the working, mainnet-deployed, source-verified Cascade system into a compelling, documented, submission-ready hackathon entry. Deliver: (1) a **WOW web visualization** of the dependency tree with money animating up it, driven by REAL Pharos MAINNET on-chain data; (2) a polished README; (3) a demo video SCRIPT/storyboard (recording is a human action — explicitly skipped per user); (4) a DoraHacks SUBMISSION.md checklist with all form fields pre-filled. Items 3 (recording) and 4 (actual submission + the prerequisite public-repo push) are HUMAN ACTIONS this phase cannot perform — it builds all materials and surfaces the human steps.
</domain>

<decisions>
## Implementation Decisions

### DEMO-03 — WOW Web Visualization (the headline; judge-impressing; buildable, zero funds)
- **Driven by REAL MAINNET data** (not testnet, not mocked). Source: the verified mainnet Cascade `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` and the two real txs below. Bake a committed JSON snapshot of the real event data so the page renders instantly offline (recording/judging never depends on RPC/CORS), AND display the real tx hashes + pharosscan links so it is verifiably real. Optionally attempt a live RPC fetch with graceful fallback to the snapshot.
- **The WOW moment (must be crisp + legible at video resolution):** an A→B→C dependency tree where ONE `invoke` sends an animated payment particle that travels UP the tree and SPLITS at each node, with each creator's balance ticking up in real time — A +0.0002, B +0.0003, C +0.0005 PROS, summing to 0.001. This single animation IS the project's core value made visible. Make it impossible to misread.
- **Show BOTH mainnet demos:** (a) the recursive royalty split (MAIN-02 invoke tx), and (b) the ERC-4337 batch — one self-bundled UserOp paying two skills (MAIN-03 handleOps tx). A toggle/section for each, or a sequenced story.
- **Design direction (anti-template, intentional):** dark "on-chain terminal / explorer" aesthetic — monospace data, a real node-graph (not a generic card grid), compositor-friendly motion (transform/opacity only), clear hierarchy, a replay/play control. Semantic HTML. It must look like a deliberate product, not a Bootstrap/shadcn default. At least 4 of: scale-contrast hierarchy, intentional motion that clarifies the money flow, depth/layering, real data visualization as a first-class element, designed hover/focus states, atmosphere/texture fitting the on-chain theme.
- **Tech:** single self-contained static page (HTML + CSS + vanilla JS, or one tiny vendored lib like a standalone SVG/canvas helper — NO build step). Opens with `open web/index.html` or a trivial static serve. Dependency-light so a judge runs it instantly.

### DEMO-04 — README (buildable)
- Real top-level README.md: what Cascade is (recursive skill royalties on Pharos — npm-but-every-package-earns-downstream), the killer idea, architecture (Cascade.sol recursive router + ERC-4337 AA layer + Anthropic Skill packaging), quickstart (install Foundry, `forge test` → 41 green, configure PRIVATE_KEY, run the demo), the VERIFIED MAINNET addresses + pharosscan links, the testnet history too, how it maps to the hackathon (Skill Hackathon track), links to SKILL.md + references + SECURITY.md + MAINNET_RESULT.md. Scrupulously honest: live+verified on mainnet, fuzz/invariant-tested, slither-clean, NOT an independent audit.

### DEMO-05 — Demo Video (HUMAN ACTION — script only, recording SKIPPED per user)
- Produce a committed shot-by-shot storyboard + narration script (≤ ~2-3 min) in docs/DEMO_VIDEO_SCRIPT.md: open on the WOW viz, show one invoke → three balances rise (with the real pharosscan tx open alongside), explain the recursive royalty idea, then the 4337 batch (one UserOp pays two skills). Mark "awaiting human recording — user opted to skip recording." Do NOT attempt to produce a video file.

### DEMO-06 — DoraHacks Submission (HUMAN ACTION — materials only)
- Repo has NO git remote yet; submission needs a PUBLIC repo link + DoraHacks login. Produce a committed SUBMISSION.md checklist: (a) push to a public remote (commands ready), (b) the DoraHacks form fields pre-filled per the hackathon's required format — Skill name (Cascade), short description, GitHub link, demo link (the web viz / video), instructions, supported framework (Anthropic Agent Skills + Foundry), dependencies/notes; (c) record+upload video using docs/DEMO_VIDEO_SCRIPT.md; (d) **visually confirm the pharosscan "Verified" checkmark on the Cascade Code tab** (the carried-over residual from Phase 5 — read API can't confirm programmatically); (e) submit before deadline 2026-06-15 15:59. This is the final human-verify checkpoint.

### Claude's Discretion
- Exact viz layout/animation implementation (SVG vs canvas), README prose, video-script wording, submission-text phrasing — implementer's choice within the WOW direction + honesty bar above. Put the web app under web/ (index.html + assets + a committed data.json snapshot).
</decisions>

<code_context>
## Existing Code Insights

### Real MAINNET data to render (from MAINNET_RESULT.md — single source of truth)
- Network: Pharos mainnet, chainId 1672, explorer https://www.pharosscan.xyz/.
- **Cascade (verified):** `0x31bE4C6B5711913D818e377ebd809d4397FF3c84`.
- **MAIN-02 royalty demo** — invoke tx `0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564`; tree A(id1)→B(id2)→C(id3); creators A `0x7ca05d52EB17833E802B7D2eC7f1Fc23950c56b8` (+0.0002), B `0xD79F121Ac383e3e7f2aeEa6AEb3b700e2Fb6796b` (+0.0003), C `0xECe4BBabd00c22E1baA1dE7f83E152D0eB6D12ef` (+0.0005); Σ 0.001 PROS; 3 RoyaltyAccrued events.
- **MAIN-03 4337 demo** — handleOps tx `0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90` via real EntryPoint v0.7 `0x0000000071727De22E5E9d8BAf0edAc6f37da032`; factory `0x904935BA1417FC35591019A0fC54c670DA824c60`, smart account `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1`; ONE UserOp batched TWO invokes (2 Invoked + 3 RoyaltyAccrued); cumulative creator balances doubled (A 0.0004, B 0.0006, C 0.001).

### Reusable Assets
- SKILL.md + references/{register,invoke,claim}.md (Phase 2) — README links these.
- src/Cascade.sol (hardened, NatSpec), src/aa/* (4337), test suite 41 green, SECURITY.md, .gas-snapshot, MAINNET_RESULT.md.
- assets/networks.json (mainnet + testnet config).
- Testnet history (Phase 1): also real, can be mentioned as the earlier proof.

### Established Patterns
- Repo is greenfield git, NO remote (relevant to DEMO-06 push).
- Pre-existing untracked HACKATHON_PHAROS_PHASE1.md (research notes — leave or fold into docs at discretion).
- Honesty discipline throughout: claim only what's proven; flag audit + the verification visual-check as the remaining items.

### Integration Points
- Viz reads a committed snapshot of the real mainnet events; README ties together contracts + SKILL.md + live verified addresses; SUBMISSION.md gates the human push+record+submit.
</code_context>

<specifics>
## Specific Ideas

- The viz's animated money-flow-up-the-tree, driven by a REAL verified-mainnet tx with clickable pharosscan links, is the centerpiece that should make a judge go "oh, it actually works on mainnet." Crisp + legible at video resolution.
- Everything in this phase is ZERO new funds — the real on-chain proof already exists from Phase 5.
- Carry the Phase 5 residual: SUBMISSION.md must include "visually confirm pharosscan Verified checkmark" as a checklist line.

## Mainnet identifiers (quick ref)
- Cascade: 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 (verified)
- Royalty invoke tx: 0x5ba20c87…dd3b1564
- 4337 handleOps tx: 0x1f3cec93…4375f90
- Explorer: https://www.pharosscan.xyz/
</specifics>

<deferred>
## Deferred Ideas

- Actually recording the video + actually submitting to DoraHacks + pushing to a public remote — HUMAN actions; this phase prepares everything but does not perform them (user explicitly: skip video recording).
- Paymaster/gasless — v2 (GAS-01).
- Independent professional audit — documented in SECURITY.md as the remaining step before custody of real user value.
</deferred>
