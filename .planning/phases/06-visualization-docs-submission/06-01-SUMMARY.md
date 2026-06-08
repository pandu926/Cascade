---
phase: 06-visualization-docs-submission
plan: 01
subsystem: web-visualization
tags: [visualization, demo, mainnet, svg, animation, erc-4337, royalties]
requires:
  - "MAINNET_RESULT.md (real Pharos mainnet event data — single source of truth)"
provides:
  - "web/ self-contained static WOW visualization (DEMO-03)"
  - "web/data.json committed snapshot of real mainnet events"
affects:
  - "DEMO-05 video script (opens on this viz)"
  - "DEMO-06 submission (demo link points here)"
tech-stack:
  added:
    - "vanilla JS + SVG (no build step, no framework, no node_modules)"
  patterns:
    - "fetch-with-inline-fallback for file:// offline rendering"
    - "BigInt wei math for exact-value balance interpolation"
    - "reusable TreeViz engine (multi-pass) shared by both demos"
    - "compositor-friendly motion (rAF + transform/opacity only)"
key-files:
  created:
    - "web/data.json"
    - "web/index.html"
    - "web/styles.css"
    - "web/app.js"
  modified: []
decisions:
  - "Stacked vertical node layout (C bottom -> A top) so the money particle visibly RISES up the tree"
  - "wei stored/animated as BigInt strings, never JS numbers, to avoid 1e15 float precision loss"
  - "batch demo reuses TreeViz with passes=2 so cumulative balances reach the real doubled on-chain values (no duplicated engine, no hardcoded literals)"
  - "inline #snapshot JSON block mirrors data.json so the page works opened directly via file:// (fetch CORS-blocked)"
metrics:
  duration: 14m
  completed: 2026-06-08
---

# Phase 6 Plan 01: WOW Web Visualization (DEMO-03) Summary

A self-contained static page under `web/` that renders the A→B→C dependency tree and animates ONE `invoke` sending a payment particle UP the tree, splitting at each node, with creator balances ticking to their exact real mainnet deltas (A +0.0002, B +0.0003, C +0.0005, Σ 0.001 PROS). It shows both the recursive royalty split (MAIN-02) and the ERC-4337 self-bundled batch (MAIN-03), surfaces every real tx hash + address as a clickable pharosscan link, and opens with `open web/index.html` — no build step, no node_modules, fully offline.

## What was built

- **web/data.json** — committed snapshot of the real mainnet events: network (chainId 1672, PROS, explorer, verified Cascade address), the A/B/C tree with wei deltas as strings, the royalty demo (invoke tx, sum), and the batch demo (handleOps tx, EntryPoint, factory, smart account, cumulative balances). Every value copied verbatim from MAINNET_RESULT.md.
- **web/index.html** — semantic HTML5 shell with two SVG tree stages, a demo toggle, balances panels with play/replay controls, an AA-contracts grid, and a footer linking the Cascade address + both tx hashes to pharosscan. Carries an inline `<script id="snapshot" type="application/json">` block (mirror of data.json) as the file:// fallback.
- **web/styles.css** — dark on-chain-terminal design system: CSS custom-property tokens (palette, mono/display type scale with clamp(), spacing, durations, easing), a real node-graph layout, grid/grain atmosphere, designed hover/focus states, and a `prefers-reduced-motion` block. All transitions target transform/opacity only.
- **web/app.js** — the `TreeViz` engine: renders the SVG tree + balances rows, animates the payment particle rising C→B→A with rAF, ticks balances via BigInt wei interpolation, lights edges and pops "splat" rings at each credited node, and exposes a play/replay control. Snapshot loaded via `fetch('./data.json')` with graceful inline-`#snapshot` fallback. The batch view reuses the same engine with `passes=2` so cumulative balances reach the real doubled values.

## Verification

- `node --check web/app.js` passes.
- `web/data.json` and the inline `#snapshot` block both parse as valid JSON.
- Automated grep checks confirm the verified Cascade address, both real tx hashes (royalty `0x5ba20c87…`, handleOps `0x1f3cec93…`), the EntryPoint, factory, and smart account are all present in the HTML and link to www.pharosscan.xyz.
- Offline logic test (run via node): royalty deltas format to exactly A 0.000200 / B 0.000300 / C 0.000500, Σ 0.001000 PROS; batch (2 passes) reaches A 0.000400 / B 0.000600 / C 0.001000 PROS — matching `batchDemo.cumulativeWei` exactly; midpoint interpolation of C lands on 0.000250 PROS (BigInt permille path is precise).
- No mocked numbers: every embedded value traces to MAINNET_RESULT.md.

## Deviations from Plan

None — plan executed exactly as written. One in-task cleanup: removed a dead `_creditNode` method that was superseded by `_creditWithTrack` (the sigma-tracking variant) before committing Task 2; not a behavior change.

## Known Stubs

None. The page is fully data-driven from the committed snapshot; there are no empty/placeholder data sources. (The live-RPC fetch path is intentionally optional per 06-CONTEXT — the snapshot is the source of truth and the page never depends on a reachable endpoint, satisfying threat T-06-03.)

## Threat Surface

All `<a>` external links use `target="_blank" rel="noopener"` (mitigates T-06-01 reverse-tabnabbing). No secrets, keys, or PII in `web/` — data is already-public verified on-chain mainnet data (T-06-02 accept). No mandatory network dependency — committed snapshot + inline fallback (T-06-03 mitigate). No new threat surface beyond the plan's threat_model.

## Self-Check: PASSED

All four web/ artifacts and SUMMARY.md exist on disk; all three task commits (581b36b, 24f1e98, ba99a0a) are present in git history.
