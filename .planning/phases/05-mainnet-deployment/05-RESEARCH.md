# Phase 5: Mainnet Deployment — Research (Contract Verification on Pharos Mainnet)

**Researched:** 2026-06-08
**Domain:** Solidity source verification on Pharos mainnet (chainId 1672) block explorer
**Confidence:** HIGH (verify endpoint independently confirmed live + Blockscout-compatible; exact forge syntax MEDIUM-HIGH)

## Summary

Pharos mainnet's explorer at `https://www.pharosscan.xyz/` is a custom Astro/Vercel **frontend** — it is NOT a vanilla Blockscout deployment, and the site-wide HTTP 429 you saw is a Vercel "Security Checkpoint" challenge applied to the whole domain (including its `/api` paths), not a Blockscout rate-limiter. The earlier `pharosscan.xyz/api` 429 is therefore a red herring for verification purposes.

The **real verification backend is Hemera SocialScan** at `https://api.socialscan.io/pharos-mainnet/`, which runs a FastAPI service exposing a **Blockscout/Etherscan-compatible command API**. I independently confirmed the exact verify endpoint is live: a `GET` and `POST` to `https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` both return HTTP 422 `{"detail":[{"type":"missing","loc":["query"/"body","module"],...},{...,"action",...}]}` — i.e. the endpoint exists and demands `module` + `action` params, which is precisely the Blockscout Etherscan-compatible RPC shape. This matches what the Pharos docs query interface recommends verbatim.

**Sourcify is NOT a viable fallback:** chainId 1672 is absent from the live Sourcify chains list (`https://sourcify.dev/server/chains`, verified 2026-06-08), so `--verifier sourcify` will fail.

**Primary recommendation:** Run `forge verify-contract` with `--verifier blockscout` and `--verifier-url https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract`. No constructor args (Cascade has the default no-arg constructor). Try with no API key first; if rejected, retry with a dummy/empty key, then a real SocialScan Developer API key. If automated verify fails, fall back to `forge flatten` + manual UI upload, and as a last resort deploy-anyway + verify-later (MAIN-01 partially met).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAIN-01 | Deploy Cascade to Pharos mainnet and source-verify on the explorer | Verifier URL + forge command confirmed below; ranked fallbacks let the deploy agent satisfy "deployed" even if verification is best-effort |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Contract bytecode deploy | Pharos L1 (RPC `https://rpc.pharos.xyz`) | — | On-chain state; nothing client/server-side |
| Source verification submit | SocialScan backend (`api.socialscan.io/pharos-mainnet`) | — | Blockscout-compatible command API owns verify; pharosscan.xyz is only its render layer |
| Verified-source display | pharosscan.xyz (Astro/Vercel frontend) | SocialScan API | UI reads verified source from the SocialScan backend |

## Contract Facts (confirmed by reading `src/Cascade.sol`)

| Property | Value | Source |
|----------|-------|--------|
| Contract name | `Cascade` | `src/Cascade.sol:12` [VERIFIED: codebase] |
| Pragma | `^0.8.24` | `src/Cascade.sol:2` [VERIFIED: codebase] |
| Pinned solc | `0.8.24` | `foundry.toml` `solc = "0.8.24"` [VERIFIED: codebase] |
| Optimizer | on, `runs = 200` | `foundry.toml` [VERIFIED: codebase] |
| Constructor args | **NONE** — no explicit constructor; default no-arg | `grep constructor` returns nothing [VERIFIED: codebase] |
| Source path | `src/Cascade.sol` | [VERIFIED: codebase] |
| Imports | none (single self-contained file) | `src/Cascade.sol` has no `import` lines [VERIFIED: codebase] |

Because Cascade has **zero constructor arguments**, omit `--constructor-args` entirely. (If included, it would be the empty string.) Because there are no imports, flattening produces a trivially clean single file — the manual fallback is low-risk.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Foundry `forge` | 1.5.1-stable | deploy + `verify-contract` | Already installed [VERIFIED: `forge --version`] |
| SocialScan command API | live | Blockscout-compatible verify backend | Pharos' official explorer backend [VERIFIED: HTTP 422 probe] |

### Verifier target (the load-bearing fact)
| Field | Value | Provenance |
|-------|-------|------------|
| `--verifier` | `blockscout` | [CITED: docs.pharos.xyz query interface] + endpoint shape [VERIFIED: 422 module/action] |
| `--verifier-url` | `https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` | [CITED: docs.pharos.xyz] + [VERIFIED: live, returns 422 demanding module/action on GET and POST] |
| `--chain-id` | `1672` | [VERIFIED: provided facts] |
| `--rpc-url` | `https://rpc.pharos.xyz` | [VERIFIED: foundry.toml `mainnet` endpoint] |
| `--compiler-version` | `0.8.24` (let forge resolve commit, or `v0.8.24+commit.e11b9ed9`) | solc pin [VERIFIED: foundry.toml]; commit hash [ASSUMED] |
| optimizer runs | `200` | [VERIFIED: foundry.toml] |
| API key | likely **not required** (Blockscout); dummy/empty accepted; real SocialScan Developer API key exists as escalation | [CITED: docs.pharos.xyz — verify command shown without a key flag] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `--verifier blockscout` (SocialScan) | `--verifier sourcify` | **Not available** — chainId 1672 absent from Sourcify chains list [VERIFIED 2026-06-08]. Do not attempt. |
| Automated forge verify | Manual flattened upload via pharosscan UI | Works but manual; Vercel challenge may gate the UI in headless contexts |

## Package Legitimacy Audit

N/A — no external packages are installed in this phase. `forge`/`cast` (Foundry 1.5.1) are pre-installed and already used throughout the project. No npm/PyPI/crates installs required for verification.

## EXACT Commands (ranked, ready-to-run)

> Placeholders: replace `<ADDRESS>` with the deployed Cascade address. All other values are concrete.

### Step 0 — (optional) deploy, capturing the address
The deploy itself is out of this research's read-only scope, but for context the address comes from your deploy step (e.g. `forge create` / `forge script --broadcast`). Verification below is independent and can be re-run any time after deploy.

### RANK 1 — Primary: Blockscout verifier, no API key

```bash
forge verify-contract \
  <ADDRESS> \
  src/Cascade.sol:Cascade \
  --chain-id 1672 \
  --compiler-version 0.8.24 \
  --num-of-optimizations 200 \
  --verifier blockscout \
  --verifier-url https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract \
  --watch
```

Notes:
- No `--constructor-args` (Cascade is no-arg). `--watch` polls until the backend returns a verdict.
- `forge` reads `solc 0.8.24` + optimizer from `foundry.toml`, so `--compiler-version`/`--num-of-optimizations` are belt-and-suspenders; keep them explicit to avoid surprises.

### RANK 2 — If RANK 1 errors with "missing/!invalid API key": add a dummy key

```bash
forge verify-contract \
  <ADDRESS> \
  src/Cascade.sol:Cascade \
  --chain-id 1672 \
  --compiler-version 0.8.24 \
  --num-of-optimizations 200 \
  --verifier blockscout \
  --verifier-url https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract \
  --etherscan-api-key "verifyContract" \
  --watch
```

(Blockscout-compatible backends typically ignore the key value; any non-empty string works. If a real key is mandated, obtain a SocialScan **Developer API Key** and substitute it.)

### RANK 3 — If forge rejects the `/contract` suffix: try the explicit query-style base

Some forge builds append `?module=...&action=...`; the endpoint already accepts that (the 422 proves it parses `module`/`action`). If RANK 1/2 fail on URL parsing, retry with a trailing `?`:

```bash
  --verifier-url "https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract?"
```

### RANK 4 — If full-version commit hash is demanded

```bash
  --compiler-version v0.8.24+commit.e11b9ed9
```

(The `e11b9ed9` commit for 0.8.24 is `[ASSUMED]`. Confirm the exact string from the build metadata: `cat out/Cascade.sol/Cascade.json | python3 -c "import json,sys;print(json.load(sys.stdin)['metadata'])"` and read `compiler.version`, or `solc --version`.)

### RANK 5 — Manual fallback: flatten + UI upload

```bash
forge flatten src/Cascade.sol > Cascade.flat.sol
```

Then on `https://www.pharosscan.xyz/` open the deployed address → Contract tab → "Verify & Publish":
- Compiler type: Solidity (single file)
- Compiler version: `v0.8.24+commit.e11b9ed9`
- Optimization: Yes, runs `200`
- License: MIT
- Paste `Cascade.flat.sol`
- Constructor args ABI-encoded: leave blank
- (If the Vercel "Security Checkpoint" blocks a headless agent, this step needs an interactive browser.)

### RANK 6 — Last resort: deploy-anyway, verify-later

If every verify path fails at deploy time, MAIN-01 is **partially met**: the contract is deployed and functional on-chain; mark verification as best-effort and re-attempt RANK 1–5 later. Do not block the deploy on verification. Record the deployed address + tx hash so verification can be retried without redeploying.

## Common Pitfalls

### Pitfall 1: Treating pharosscan.xyz's 429 as a Blockscout rate-limit
**What goes wrong:** Assuming you must back off / find an API key for `pharosscan.xyz/api`.
**Why it happens:** The 429 carries `server: Vercel`, `x-vercel-mitigated: challenge` — it's a JS security challenge on the whole site, not a real API throttle.
**How to avoid:** Verify against `api.socialscan.io/pharos-mainnet/...` directly (no Vercel challenge there — it returned clean 422/404 JSON), not the pharosscan.xyz domain.

### Pitfall 2: Reaching for Sourcify because it's keyless
**What goes wrong:** `--verifier sourcify` fails; chainId 1672 isn't supported.
**How to avoid:** Confirmed absent from `https://sourcify.dev/server/chains`. Skip Sourcify entirely.

### Pitfall 3: Wrong API base path (`/api` or `/api/v2`)
**What goes wrong:** `/pharos-mainnet/api`, `/api/v2/...` all return `{"detail":"Not Found"}` (404).
**Why it happens:** SocialScan's command API lives under `/v1/explorer/command_api/contract`, not the classic Blockscout `/api` mount.
**How to avoid:** Use the exact `/v1/explorer/command_api/contract` path — the only one that returned 422 (i.e. matched a real route).

### Pitfall 4: Bytecode/metadata mismatch on verify
**What goes wrong:** Verify rejects with bytecode mismatch.
**Why it happens:** Compiler version / optimizer runs / file content differ from what was deployed.
**How to avoid:** Deploy and verify from the same checkout with the same `foundry.toml`. Don't edit `src/Cascade.sol` between deploy and verify. Keep optimizer `200` consistent.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `forge` / `cast` | deploy + verify | ✓ | 1.5.1-stable | — |
| Pharos mainnet RPC | deploy + chain checks | ✓ (configured) | `https://rpc.pharos.xyz` | — |
| SocialScan verify endpoint | source verification | ✓ (live, 422 on missing params) | `…/v1/explorer/command_api/contract` | manual flatten+UI |
| Sourcify (chain 1672) | keyless verify fallback | ✗ | — | none — chain unsupported |
| Interactive browser | manual UI upload (RANK 5) | unknown | — | RANK 6 verify-later |

**Missing with no fallback:** Sourcify support for 1672 (use Blockscout path instead — that IS the supported path, so not blocking).
**Missing with fallback:** Interactive browser for manual upload → covered by RANK 6 (deploy-anyway, verify-later).

## Validation Architecture

Verification is itself the validation gate for MAIN-01. Concrete checks the deploy agent should run:

| Check | Command | Pass condition |
|-------|---------|----------------|
| Endpoint reachable | `curl -s -o /dev/null -w '%{http_code}' https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` | `422` (route exists) |
| Verify success | RANK 1 command with `--watch` | forge prints `Contract successfully verified` |
| Explorer shows source | open `https://www.pharosscan.xyz/address/<ADDRESS>` Contract tab | green/verified source visible |
| Compiler metadata match | `out/Cascade.sol/Cascade.json` → `metadata.compiler.version` | matches `--compiler-version` used |

No new unit tests are needed for this phase — the contract is already tested in prior phases. The phase gate is "deployed + verified (best-effort)".

## Security Domain

| Concern | Status |
|---------|--------|
| Secrets in verify command | None — Blockscout verify needs no real key; never hardcode a deployer private key in the verify step (use `--account`/keystore or env for the separate deploy step) |
| Endpoint trust | `api.socialscan.io` is the official Pharos explorer backend [CITED: docs.pharos.xyz]; verify sends only public source + bytecode, no secrets |
| Real-funds gate | Verification is read/submit-only and spends no PROS. Only the separate deploy tx spends gas — keep that as a distinct, explicitly-confirmed step |

No outbound transmission of secrets: the verify payload is public source code. Safe to run.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | solc 0.8.24 commit hash is `e11b9ed9` | RANK 4 | Low — only needed if forge demands full version; confirm from build metadata before using |
| A2 | Blockscout verifier accepts empty/dummy API key on SocialScan | RANK 1/2 | Low — RANK 2/escalation to real Developer API key covers it |
| A3 | forge appends params correctly to `…/command_api/contract` (vs needing `?` suffix) | RANK 1 vs 3 | Low — RANK 3 variant covers the URL-parsing edge case |
| A4 | The docs `?ask=` query interface answer reflects the maintained official guidance | Verifier target | Low — independently corroborated by the live 422 probe matching the exact URL |

## Open Questions

1. **Does the SocialScan verify backend require a real Developer API key?**
   - What we know: docs show the forge command without a key flag; Blockscout-compat backends usually ignore the key.
   - What's unclear: whether SocialScan enforces a key on the verify action specifically.
   - Recommendation: try keyless (RANK 1) → dummy (RANK 2) → real SocialScan Developer API key. Cheap to escalate.

2. **Exact full compiler-version string forge will require.**
   - Recommendation: let forge auto-resolve from `foundry.toml` first; if it asks for `v0.8.24+commit.<hash>`, read the hash from `out/Cascade.sol/Cascade.json` metadata rather than trusting A1.

## Sources

### Primary (HIGH confidence)
- Live probe `https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` — GET+POST return HTTP 422 demanding `module`/`action` (Blockscout-compatible command API, endpoint exists) [VERIFIED 2026-06-08]
- `https://sourcify.dev/server/chains` — chainId 1672 NOT present [VERIFIED 2026-06-08]
- `docs.pharos.xyz` query interface (`.md?ask=`) — recommends `--verifier blockscout` + the SocialScan command_api URL [CITED]
- `src/Cascade.sol`, `foundry.toml` — contract name, pragma, solc pin, optimizer 200, no constructor [VERIFIED: codebase]
- `forge --version` → 1.5.1-stable [VERIFIED]

### Secondary (MEDIUM confidence)
- pharosscan.xyz HTTP headers — `server: Vercel`, `x-vercel-mitigated: challenge` confirm Vercel frontend, not Blockscout (explains the 429) [VERIFIED via curl]

### Tertiary / unavailable
- Built-in WebSearch returned repeated HTTP 500 (server-side) during this session — ecosystem/community cross-verification could not be completed via search. Findings above rest on direct endpoint probes + docs query interface instead, which are stronger than search for this question.

## Metadata

**Confidence breakdown:**
- Verifier endpoint + verifier name: HIGH — endpoint independently confirmed live and Blockscout-shaped; matches official docs.
- Exact forge flag syntax: MEDIUM-HIGH — standard forge blockscout invocation; URL-suffix and API-key edge cases covered by ranked fallbacks.
- Sourcify unavailability: HIGH — direct chains-list check.
- Compiler commit hash: LOW — flagged ASSUMED, verify from build metadata.

**Research date:** 2026-06-08
**Valid until:** ~2026-07-08 (explorer backends and chain support can change; re-probe the endpoint before relying on it)
