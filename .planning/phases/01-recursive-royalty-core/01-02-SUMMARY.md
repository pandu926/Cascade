---
phase: 01-recursive-royalty-core
plan: 02
subsystem: scripts
tags: [solidity, foundry, forge-script, demo, royalties, anvil]

# Dependency graph
requires:
  - "src/Cascade.sol — register/invoke/claim/balances API (from 01-01)"
provides:
  - "script/{Deploy,Register,Invoke,Claim}.s.sol — agent-facing forge execution surface (SKILL-04)"
  - "script/DemoTree.s.sol — A->B->C register+invoke+balance-print driver (DEMO-02)"
  - "test/Demo.fork.t.sol — zero-fund local end-to-end proof of the demo flow"
  - ".env.example — documented env vars, no secrets"
affects:
  - "01-03 (live testnet deploy: same scripts + --broadcast --rpc-url atlantic_testnet, zero code change)"
  - "Phase 2 (Skill packaging wraps these scripts as natural-language actions)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Thin forge Scripts read all params via vm.envUint/envAddress/envOr; secrets never logged"
    - "RPC resolved at run time via --rpc-url flag (alias or URL); no hardcoded endpoint"
    - "Demo numbers shared verbatim between DemoTree.s.sol and Demo.fork.t.sol for reproducibility"
    - "Creator/payer keys default to anvil mnemonic (vm.deriveKey) so local runs are pre-funded; env overrides for live"

key-files:
  created:
    - "script/Deploy.s.sol"
    - "script/Register.s.sol"
    - "script/Invoke.s.sol"
    - "script/Claim.s.sol"
    - "script/DemoTree.s.sol"
    - "test/Demo.fork.t.sol"
    - ".env.example"
  modified: []

key-decisions:
  - "Register.s.sol parses DEP_IDS/DEP_SHARES via vm.envOr(name, \",\", default) so a leaf skill needs no array env vars"
  - "DemoTree keys default to the standard anvil mnemonic (idx 0-2 creators, idx 3 payer) — local runs fully funded with zero testnet funds; env (CREATOR_*_KEY/PRIVATE_KEY) overrides for the live wave"
  - "Demo price set to 0.001 ether (PRICE_C) to fit the ~0.01 PHRS live budget"
  - "Exact-payment surfaced as INVOKE_VALUE env in Invoke.s.sol (must equal registered price)"

patterns-established:
  - "Per-script run() returns the salient value (deployed address / skill id / claimed amount) and console2.logs a human-readable line"
  - "Demo proven two ways locally: forge EVM fork test (vm.deal) + live anvil broadcast (pre-funded mnemonic)"

requirements-completed: [SKILL-04, DEMO-01, DEMO-02]

# Metrics
duration: ~12min
completed: 2026-06-07
---

# Phase 1 Plan 02: Forge Scripts + A→B→C Demo Driver Summary

**Five thin forge scripts (Deploy/Register/Invoke/Claim/DemoTree) give Cascade its agent-facing execution surface, and a zero-fund local fork test plus a live anvil run both prove the killer demo: one `invoke` of C raises three creator balances (A +0.0002, B +0.0003, C +0.0005 ether) summing exactly to the 0.001-ether price, after which a creator claims — leaving 01-03 nothing but a `--broadcast --rpc-url atlantic_testnet` flag flip.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-06-07
- **Tasks:** 2
- **Files created/modified:** 7

## Accomplishments
- Four KISS forge scripts wrap the entire `Cascade` API: `Deploy` (logs the new address), `Register` (price + optional DEP_IDS/DEP_SHARES from env), `Invoke` (exact INVOKE_VALUE), `Claim` (withdraws + logs accrued). All read `PRIVATE_KEY` via `vm.envUint` and wrap calls in `vm.startBroadcast/stopBroadcast`; none hardcode an RPC (resolved via `--rpc-url`).
- `DemoTree.s.sol` is the DEMO-02 driver: deploys (or reuses `CASCADE`), registers the A→B→C tree from three distinct creators, prints before/after balances + deltas, and invokes C once. Verified end-to-end on a local anvil node (pre-funded default-mnemonic accounts) — deltas were exactly A +2e14, B +3e14, C +5e14, total 1e15 wei, zero testnet funds spent.
- `test/Demo.fork.t.sol` proves the identical flow on the bare forge EVM: one invoke raises all three balances, deltas are depth-proportional, Σ deltas == price, and a creator's `claim()` credits their wallet. Demo constants are byte-identical to the script so the live run reproduces the local result.
- `.env.example` committed documenting every env var (PRIVATE_KEY, RPC_URL, CASCADE, PRICE, DEP_IDS, DEP_SHARES, SKILL_ID, INVOKE_VALUE, CREATOR_*_KEY) with no secret values. Real `.env` never read or touched.
- Full suite green: 14/14 tests pass (13 from 01-01 + 1 demo fork test). Gas for the live demo path stays small (invoke 127K, register ~99–189K, claim 30K) — comfortably within the ~0.01 PHRS budget.

## Task Commits

1. **Task 1: Deploy/Register/Invoke/Claim scripts + .env.example** - `2256c5c` (feat)
2. **Task 2: DemoTree driver + local fork test** - `2c97fe1` (feat)

**Plan metadata:** see final docs commit.

## Files Created/Modified
- `script/Deploy.s.sol` - Deploys `new Cascade()`, logs the address.
- `script/Register.s.sol` - Registers a skill from env params; parses optional dep arrays via `vm.envOr(name, ",", default)`.
- `script/Invoke.s.sol` - Invokes a skill with exact `INVOKE_VALUE` (Cascade enforces `msg.value == price`).
- `script/Claim.s.sol` - Withdraws the caller's accrued balance, logs before/after.
- `script/DemoTree.s.sol` - A→B→C register + invoke + before/after balance print (DEMO-02 driver).
- `test/Demo.fork.t.sol` - Zero-fund local end-to-end proof of the demo flow + claim.
- `.env.example` - Documented env vars, no secrets.

## Decisions Made
- `Register.s.sol` uses `vm.envOr("DEP_IDS", ",", emptyArray)` so registering a leaf skill (no deps) needs no array env vars and never reverts on a missing var.
- `DemoTree.s.sol` defaults creator/payer keys to the standard Foundry anvil mnemonic (`vm.deriveKey`, indexes 0–2 for creators, 3 for payer) so a local `anvil` run is fully funded out of the box; the live wave overrides via `CREATOR_A_KEY`/`CREATOR_B_KEY`/`CREATOR_C_KEY`/`PRIVATE_KEY` — same code, only env/flags differ.
- Demo price fixed at `0.001 ether` to keep the single live invoke + three registers + deploy within the ~0.01 PHRS budget.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- A bare `forge script DemoTree` (pure simulation, no node) reverts at the invoke with `OutOfFunds`, because script simulation does not pre-fund derived accounts and scripts cannot use `vm.deal`. This is expected, not a bug: the zero-fund proof is the forge **test** (which uses `vm.deal`), and the **script** itself was verified end-to-end against a local `anvil` node whose default-mnemonic accounts are pre-funded — both paths spend zero testnet funds.
- `forge build` does not re-print "Compiler run successful" on a cached/unchanged build (same quirk noted in 01-01); ran `forge clean` before the verify to confirm a true clean compile.

## User Setup Required
None for this plan — everything runs locally (forge EVM + local anvil), zero testnet funds. The live wave (01-03) will require a funded `PRIVATE_KEY` in `.env` and `--broadcast --rpc-url atlantic_testnet`.

## Next Phase Readiness
- The agent-facing execution surface (SKILL-04) is complete and compiles; 01-03 reproduces the proven demo on testnet by adding only `--broadcast --rpc-url atlantic_testnet` to the same scripts — no code changes.
- DEMO-01/DEMO-02 logic is locked behind a green local test and a verified anvil run, fully de-risking the single funded step.
- No blockers.

## Self-Check: PASSED

All claimed files exist (script/Deploy.s.sol, script/Register.s.sol, script/Invoke.s.sol, script/Claim.s.sol, script/DemoTree.s.sol, test/Demo.fork.t.sol, .env.example) and both task commits are present (2256c5c, 2c97fe1).

---
*Phase: 01-recursive-royalty-core*
*Completed: 2026-06-07*
