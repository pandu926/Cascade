# Cascade — Live On-Chain Demo Result (atlantic-testnet)

This file records the live deployment + A→B→C royalty demo on atlantic-testnet
(chainId **688689**, token **PHRS**, explorer https://atlantic.pharosscan.xyz/).
This is the only plan that spent real testnet PHRS. The funded `PRIVATE_KEY`
value is never printed here — only its derived address.

---

## Task 1 — Pre-flight (funding, gas budget, green suite)

**Network confirmed:** chainId `688689` (atlantic-testnet) — mainnet never targeted.

**Funded wallet (payer / deployer):**
- Address: `0x67680b09bB422cC510669bd5208D947066D4aeaE`
- Balance before demo: `10000000000000000` wei = **0.01 PHRS**

**Local suite:** `forge test` → **14 passed; 0 failed** (13 core + 1 demo fork). Green before any live tx.

**Gas measured locally (`forge test --gas-report` + `forge inspect`):**

| Op       | Gas (max) |
|----------|-----------|
| deploy   | 456,091   |
| register | 188,624   |
| invoke   | 127,281   |
| claim    | 29,925    |
| transfer | 21,000    |

**Network base fee:** `1 gwei` (1000000000). `cast gas-price` suggested 10 gwei (conservative).

**Chosen gas price: `2 gwei`** (2× base fee — safely accepted, sent `--legacy`).
At 10 gwei the ~1.2M-gas demo would cost ~0.012 PHRS (OVER the 0.01 budget); at 2 gwei
the full demo costs a small fraction of budget.

**Budget plan (2 gwei):**
- My-wallet gas (deploy + invoke + 3 funding transfers ≈ 646K gas): ~0.00129 PHRS
- Invoke value: 0.001 PHRS
- Funding 3 fresh creators @ 0.001 PHRS each: 0.003 PHRS
- **Total my-wallet spend ≈ 0.0053 PHRS** vs 0.01 budget → **~0.0047 PHRS headroom**. ✅

**Demo skill tree + prices/shares (identical to local proof in 01-02):**
- Skill A (leaf): price 0, no deps
- Skill B: price 0, dep [A] share 4000 bps (40%)
- Skill C (top): price `0.001 ether`, dep [B] share 5000 bps (50%)
- Expected deltas from one invoke of C @ 0.001 ether:
  A `+0.0002`, B `+0.0003`, C `+0.0005` ether; Σ = `0.001` ether (== price).

**Why fresh creator wallets (deviation from the anvil-default keys the script ships with):**
On a real public testnet each "creator" must send its own `register` tx and therefore
needs gas. The standard Foundry test-mnemonic accounts (idx 0–2) are shared by every
user of that mnemonic on this public chain (racy nonces / balances), which is unsafe for
an irreversible, fund-spending demo. So three fresh, fully-controlled creator wallets were
generated and minimally funded from the payer wallet via the `CREATOR_*_KEY` env override
that 01-02 explicitly designed for the live wave (same code, only env differs).
Their private keys live only in `/tmp/cascade-demo/` (never committed, never printed).

- creatorA: `0xABB8D5027A214Ac339208583E2c963d7D42B11D0`
- creatorB: `0xF05df34Bec5c22072be68726F1154Cdff2A3d49b`
- creatorC: `0x869aA1d573e127a2dFeec02FA629F10dfd69A7e0`

**Pre-flight verdict:** Funding, gas budget, and a green local suite confirmed — safe to spend testnet PHRS.

---
