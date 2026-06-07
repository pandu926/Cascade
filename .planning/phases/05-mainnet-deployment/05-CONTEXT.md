# Phase 5: Mainnet Deployment & Live Demos - Context

**Gathered:** 2026-06-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Deploy the hardened Cascade + AA contracts to **Pharos mainnet (chainId 1672)** with **real PROS**, verify the source on pharosscan, and demonstrate BOTH the recursive royalty split and the ERC-4337 batch **live on mainnet**. Every spend is gated by a pre-flight balance/gas check, confirmed before broadcast, and recorded (addresses + tx hashes + explorer links) in a committed `MAINNET_RESULT.md`. This phase spends real (modest) money and is irreversible — the user explicitly authorized the "royalty + 4337" mainnet scope and funded the wallet generously (~2 PROS for ~0.04 PROS of expected cost).
</domain>

<decisions>
## Implementation Decisions

### Funding & wallet (locked)
- Deployer/payer EOA: `0x3306E846b5Dc7F890436955999CeE27a6abbCbe8`, key in gitignored `.env` as `PRIVATE_KEY` (the .env value may lack `0x` — prefix at runtime if forge/cast requires). Balance ~1.9996 PROS. NEVER print the key.
- Mainnet RPC `https://rpc.pharos.xyz`, chainId 1672, gas price ~10 gwei (confirmed). foundry.toml rpc_endpoints key: `mainnet`.
- "gak usah ngirit" — do NOT micro-optimize gas at the cost of a clean, correct, well-recorded demo. Budget is ample. Still: every broadcast confirms balance first and verifies chainId==1672 before sending (never accidentally hit testnet or burn on a misconfig).

### MAIN-01 — Deploy + verify
- Deploy `Cascade` (no constructor args — confirmed) to mainnet via `cast send`/`forge create` (prefer `cast`/explicit broadcast; a prior phase found `forge script --broadcast` ignored --gas-price). Record the address.
- Verify source on pharosscan using the RANKED commands from 05-RESEARCH.md (authoritative). Try in order:
  1. `forge verify-contract <ADDR> src/Cascade.sol:Cascade --chain-id 1672 --compiler-version 0.8.24 --num-of-optimizations 200 --verifier blockscout --verifier-url https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract --watch`
  2. add `--etherscan-api-key "verifyContract"` (dummy) if a key is demanded
  3. trailing `?` / full commit version `v0.8.24+commit.e11b9ed9` variants
  4. manual: `forge flatten src/Cascade.sol` → paste into pharosscan UI (optimizer 200, MIT, blank ctor args)
  5. last resort: deploy-anyway + verify-later — MAIN-01 partially met (deployed/functional), verification flagged best-effort + retryable without redeploy. Do NOT let a verify hiccup block MAIN-02/03.

### MAIN-02 — Live mainnet royalty demo (3 distinct creators)
- creator == msg.sender at register time, so the demo needs THREE distinct creator EOAs. Derive 3 deterministic creator keys (e.g. via env CREATOR_A/B/C_KEY, or a demo mnemonic) — the existing `script/DemoTree.s.sol` already supports CREATOR_A/B/C_KEY env overrides + a payer key.
- Fund each of the 3 creator EOAs with a small gas stipend from the deployer (e.g. ~0.02 PROS each via `cast send <creator> --value`) so each can send its own register tx. Record the funding txs.
- Run the A→B→C demo on mainnet: A registers (leaf, price 0), B registers (dep A, share), C registers (dep B, share, PRICE_C e.g. 0.001 PROS), payer invokes C once → assert three creator balances rise proportionally, Σ deltas == PRICE_C. Record every tx hash + before/after balances + explorer links.
- Reuse the SAME deployed Cascade from MAIN-01 (do NOT redeploy).

### MAIN-03 — Live mainnet 4337 demo
- Deploy `AccountFactory` (or deploy the account directly — implementer's choice; direct deploy shrinks footprint, factory proves AA-01 on mainnet — prefer factory for completeness since budget is ample). Record addresses.
- Fund the smart account minimally for prefund + the 2 invoke values. Build + sign ONE PackedUserOperation whose callData = executeBatch of TWO `Cascade.invoke` calls (reuse skills registered in MAIN-02, or register a fresh small pair), EOA calls real EntryPoint v0.7 `0x0000000071727De22E5E9d8BAf0edAc6f37da032` `handleOps`. Assert balances rise; record tx hashes + explorer links. This reproduces the Phase 3 fork-proven flow on live mainnet.
- EntryPoint v0.7 confirmed deployed on mainnet (orchestrator verified, 32KB bytecode).

### Safety (real money)
- Per-wave pre-flight: read balance, confirm chainId==1672, estimate cost, confirm sufficient — STOP cleanly + record if not (don't half-spend). Confirm before each broadcast batch.
- Record EVERYTHING to `MAINNET_RESULT.md` (committed): deployed addresses, all tx hashes, before/after balances, explorer links (https://www.pharosscan.xyz/tx/<hash>, /address/<addr>), verification status.
- Final human-verify checkpoint: present the recorded mainnet artifacts for explorer confirmation (auto-approved in autonomous mode, but orchestrator independently verifies on-chain via cast).

### Claude's Discretion
- Exact creator key derivation, stipend amounts (generous within reason), whether MAIN-03 reuses MAIN-02 skills or registers fresh, plan/wave decomposition. Keep MAINNET_RESULT.md as the single source of truth.
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/Cascade.sol` (hardened: NatSpec + custom errors, 41 tests green, slither 0 CRIT/HIGH) — the contract to deploy + verify.
- `src/aa/CascadeAccount.sol`, `AccountFactory.sol`, interfaces — fork-proven on testnet; deploy to mainnet for MAIN-03.
- `script/Deploy.s.sol`, `Register.s.sol`, `Invoke.s.sol`, `Claim.s.sol`, `DemoTree.s.sol` (supports CREATOR_A/B/C_KEY + payer env overrides), `script/LiveBundle.s.sol` (the gated 4337 live driver from Phase 3, with pre-flight gate) — point these at mainnet via --rpc-url mainnet.
- `assets/networks.json` — mainnet entry (chainId 1672, rpc, PROS, explorer https://www.pharosscan.xyz/).
- `.planning/phases/03-smart-account-agents-erc-4337/03-RESEARCH.md` — the v0.7 UserOp build/sign/handleOps mechanics (reuse).
- `.planning/phases/05-mainnet-deployment/05-RESEARCH.md` — the ranked verification commands (authoritative for MAIN-01).

### Established Patterns
- Prior live wave (Phase 1 testnet) used `cast send` with explicit `--legacy --gas-price` because `forge script --broadcast` ignored --gas-price. Apply the same on mainnet.
- Pre-flight gate + record-to-RESULT.md + human-verify checkpoint pattern from Phase 1's 01-03 and Phase 3's 03-03.

### Integration Points
- Phase 6 (viz/docs) will render the MAIN-02 royalty event data + cite the verified mainnet address — so record event-level detail (Invoked + 3 RoyaltyAccrued amounts) cleanly in MAINNET_RESULT.md.
</code_context>

<specifics>
## Specific Ideas

- The headline artifact for judging: a SOURCE-VERIFIED Cascade on Pharos mainnet + a real mainnet tx where one invoke pays three creators + a real mainnet UserOp batching two invokes. All linkable on pharosscan. This is the "live on mainnet, verified, tested proper" bar the user asked for.
- Budget is ample (~2 PROS vs ~0.04 needed) — prioritize correctness, clean records, and a verified contract over saving fractions of a PROS.
- Honesty in MAINNET_RESULT.md: if verification lands on the best-effort fallback (RANK 5), say so plainly and note it's retryable.

## Mainnet identifiers (for reference)
- Deployer/payer: 0x3306E846b5Dc7F890436955999CeE27a6abbCbe8
- EntryPoint v0.7 (mainnet, verified present): 0x0000000071727De22E5E9d8BAf0edAc6f37da032
- Explorer: https://www.pharosscan.xyz/
</specifics>

<deferred>
## Deferred Ideas

- Web visualization, README, video script, DoraHacks submission — Phase 6.
- Paymaster/gasless — v2 (GAS-01).
- Independent professional audit — documented in SECURITY.md as the remaining step before custody of real user value (this demo uses tiny amounts).
</deferred>
