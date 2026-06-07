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

## Task 2 — Deploy + register the A→B→C tree live (DEMO-01)

### Funding the fresh creator wallets (gas for their own register txs)

Each creator funded with 0.001 PHRS from the payer wallet (`cast send --value 0.001ether --legacy --gas-price 2gwei`):

| Creator | Address | Funding tx |
|---------|---------|------------|
| A | `0xABB8D5027A214Ac339208583E2c963d7D42B11D0` | [`0xd7d1f4957154c8f6fa792d5922de30f6d00607e552ff85c67b0fecc610795d6a`](https://atlantic.pharosscan.xyz/tx/0xd7d1f4957154c8f6fa792d5922de30f6d00607e552ff85c67b0fecc610795d6a) |
| B | `0xF05df34Bec5c22072be68726F1154Cdff2A3d49b` | [`0x894541d8946f12f4d58e2fcd3f91f442011238566beb0fb757c52d82fa1c6b95`](https://atlantic.pharosscan.xyz/tx/0x894541d8946f12f4d58e2fcd3f91f442011238566beb0fb757c52d82fa1c6b95) |
| C | `0x869aA1d573e127a2dFeec02FA629F10dfd69A7e0` | [`0x52ba8383cb4d5334a8fc25426923919147a1a119dd63e5306049d580db11d96a`](https://atlantic.pharosscan.xyz/tx/0x52ba8383cb4d5334a8fc25426923919147a1a119dd63e5306049d580db11d96a) |

### Deployed contract

- **Cascade address:** `0xd41C32562D0BE20D354120E1De11A91abC340F50`
- **Deploy tx:** [`0x5669ab63166f7fd3ec5518c89c271b1cf784031500f07b6d960eb6cbba897851`](https://atlantic.pharosscan.xyz/tx/0x5669ab63166f7fd3ec5518c89c271b1cf784031500f07b6d960eb6cbba897851) — status 1, gasUsed 545,837
- **Explorer (contract):** https://atlantic.pharosscan.xyz/address/0xd41C32562D0BE20D354120E1De11A91abC340F50
- `cast code` returns non-empty bytecode (4558 chars). ✅

### Registered A→B→C tree (each from its own creator)

| Skill | id | Creator | price | deps / shares | Register tx |
|-------|----|---------|-------|---------------|-------------|
| A (leaf) | 1 | A | 0 | — | [`0x20838fb9039d4cb39fcaeffa8a009333eb3326c7a28f42bcb14a2de059fd5139`](https://atlantic.pharosscan.xyz/tx/0x20838fb9039d4cb39fcaeffa8a009333eb3326c7a28f42bcb14a2de059fd5139) |
| B | 2 | B | 0 | dep [1] @ 4000 bps | [`0x4142cf4caabc1fe61207fd34ccc21406a81cca37ddb3c3a1d27043b3abab9824`](https://atlantic.pharosscan.xyz/tx/0x4142cf4caabc1fe61207fd34ccc21406a81cca37ddb3c3a1d27043b3abab9824) |
| C (top) | 3 | C | 0.001 ether | dep [2] @ 5000 bps | [`0x6e9e9f7fbae14a116f049079c1e4657f52d00a37a39e9b4379d744ccfd42b4ce`](https://atlantic.pharosscan.xyz/tx/0x6e9e9f7fbae14a116f049079c1e4657f52d00a37a39e9b4379d744ccfd42b4ce) |

**`cast call skillCount()` → `3`** — DEMO-01 satisfied (three skills live on-chain). ✅

### Deviation (Rule 3 — blocking issue): `forge script` gas handling

The wave-2 `Deploy.s.sol`/`Register.s.sol` forge scripts could not broadcast cleanly here:
- `vm.envUint("PRIVATE_KEY")` reverts because `.env` stores the key without a `0x` prefix
  (`cast` tolerates it, `forge` does not). Worked around by `0x`-prefixing at runtime.
- More importantly, `forge script --broadcast` ignored the `--gas-price` flag and sent the
  CREATE at the RPC-suggested 10 gwei; that first deploy tx
  (`0x5c7ac69cf8432250ee395a4c19bba9e9fbe7476d3c63136af9f15f983876dd08`) **reverted on-chain
  (status 0, only 21,000 gas consumed)** at `0x30F710b2605CE531B576F6238482c7b3AFDE34e4` — no
  code deployed. That wasted ~0.0003 PHRS but produced no usable contract.

**Root-cause fix:** switched the live broadcasts from `forge script` to direct `cast send`
(the same reliable path the funding txs used) — explicit `--legacy --gas-price 2gwei` and an
explicit `--gas-limit`. The CREATE was first simulated via `cast call --create` (clean) and
gas-estimated (668K) before sending. The script *contracts* are unchanged; only the broadcast
mechanism differs. This keeps the demo within budget and deterministic.

---
