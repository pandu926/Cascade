# Cascade — Demo Video Script & Storyboard

> **AWAITING HUMAN RECORDING — the user opted to skip recording in this phase.**
> This is a recordable shot-by-shot storyboard + narration. No video file is produced here.
> Record it by following the shots below, then upload and link the result in
> [`SUBMISSION.md`](../SUBMISSION.md).

**Target runtime:** ~2:00–2:30 (hard cap ~3:00). **Aspect:** 1920×1080, 60fps if possible
(the particle motion reads better at high frame rate). **Audio:** single voiceover track,
no music bed required (optional low ambient).

**What you need open before recording:**
1. The visualization — [`web/index.html`](../web/index.html) (open it, let it settle on the
   A→B→C tree at rest, balances at zero, the **Play** control visible).
2. A browser tab on the real invoke tx:
   https://www.pharosscan.xyz/tx/0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564
3. A browser tab on the real 4337 handleOps tx:
   https://www.pharosscan.xyz/tx/0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90
4. A browser tab on the verified Cascade contract (Code tab, "Verified" checkmark visible):
   https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84

Every figure narrated below is real and on-chain — see [`MAINNET_RESULT.md`](../MAINNET_RESULT.md).
Do not improvise numbers; read them exactly as written here.

---

## Shot list

### Shot 1 — Hook on the visualization (0:00–0:18, ~18s)

- **Visual:** Full-screen [`web/index.html`](../web/index.html) — the dark on-chain
  terminal aesthetic, the A→B→C node graph at rest, balances at 0, Play control glowing.
- **On-screen action:** Slow, still hold. Cursor hovers the Play control but does not click yet.
- **Narration:** "This is Cascade. Think npm — but every package earns a cut every time
  it's used downstream. Automatically. Recursively. On Pharos mainnet."

### Shot 2 — The one invoke fans up the tree (0:18–0:48, ~30s) — THE WOW MOMENT

- **Visual:** Click **Play**. A single payment particle rises from C, travels **up** the
  tree, and splits at each node. The three creator balances tick up in real time.
- **On-screen action:** Let the full animation play once, uninterrupted. The balances land on:
  **A 0.0002 · B 0.0003 · C 0.0005 · Σ 0.001 PROS.**
- **Narration:** "One person pays to invoke skill C — one transaction, 0.001 PROS. Watch
  the money travel up the dependency tree and split at every level. C keeps 0.0005. B, the
  thing C is built on, gets 0.0003. A, the thing B is built on, gets 0.0002. One payment,
  three creators paid — summing to exactly 0.001. Every wei accounted for."

### Shot 3 — Prove it's real on mainnet (0:48–1:18, ~30s)

- **Visual:** Cut (or split-screen) to the pharosscan tab on the invoke tx
  `0x5ba20c87…dd3b1564`. Scroll to the three `RoyaltyAccrued` events / the token transfers.
- **On-screen action:** Hover the three creator addresses and the `0.001` value so the
  viewer sees the same split the animation just showed, but on the live explorer.
- **Narration:** "That's not a mockup. Here's the actual transaction on Pharos mainnet —
  three RoyaltyAccrued events, the exact same split: 0.0002, 0.0003, 0.0005. One invoke,
  the whole tree paid, on-chain, in a single transaction."

### Shot 4 — The ERC-4337 batch (1:18–1:50, ~32s)

- **Visual:** Back to the viz — toggle to the **4337 batch** section. Then cut to the
  pharosscan tab on the handleOps tx `0x1f3cec93…4375f90`.
- **On-screen action:** Show the single handleOps tx containing **two** `Invoked` events
  and three `RoyaltyAccrued` events. Point out it went through the real EntryPoint v0.7.
- **Narration:** "Cascade is account-agnostic. Here a smart account batches two skill
  invokes into one self-bundled UserOperation — through the real ERC-4337 EntryPoint,
  version 0.7 — and pays both skills' creators in a single handleOps. No external bundler.
  Same recursive split, now from a smart account."

### Shot 5 — Verified + honest close (1:50–2:20, ~30s)

- **Visual:** Cut to the verified Cascade contract page
  (`0x31bE4C6B…3c84`) with the green "Verified" checkmark on the Code tab.
- **On-screen action:** Hold on the Verified checkmark and the address; optional quick
  cut to a terminal showing `forge test` — 41 passing.
- **Narration:** "The contract is deployed and source-verified on Pharos mainnet. Forty-one
  tests pass — unit, fuzz, and a stateful conservation invariant — and it's slither-clean.
  To be clear: that's not an independent audit, and we say so. But the recursive royalty
  engine is real, it's live, and you can run it today. That's Cascade."

---

## Coverage checklist (the script must hit all of these)

- [ ] The WOW viz ([`web/index.html`](../web/index.html)) opens the video.
- [ ] One `invoke` → three creators rise to A 0.0002 / B 0.0003 / C 0.0005, Σ 0.001 PROS.
- [ ] The real invoke tx `0x5ba20c87…dd3b1564` is shown on pharosscan to prove it's mainnet.
- [ ] The 4337 batch — one handleOps `0x1f3cec93…4375f90` via the real EntryPoint v0.7.
- [ ] Closes on the verified Cascade `0x31bE4C6B…3c84` + the honest "not an audit" note.
- [ ] Total runtime ≤ ~3 minutes.
