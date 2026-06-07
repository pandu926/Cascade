# LIVE_RESULT.md — Phase 3 gated live ERC-4337 step

**Outcome: BLOCKED ON BUDGET (clean stop — no broadcast, no funds spent).**
**This is an EXPECTED, ACCEPTABLE outcome.** AA-01 / AA-02 / AA-03 are ALREADY satisfied by
the Wave 2 fork proof (`test/SmartAccount.fork.t.sol`) against the REAL EntryPoint v0.7. This
live step is bonus on-chain evidence only; it is blocked on budget, **not on correctness**.

Date: 2026-06-07 · Network: atlantic-testnet (chainId **688689**, verified) · RPC: `atlantic_testnet`

---

## Captured live state (pre-flight, read at runtime)

| Item | Value |
|------|-------|
| Funded EOA / top-up target | `0x67680b09bB422cC510669bd5208D947066D4aeaE` |
| EOA balance | `4317764000000000` wei = **0.004317764 PHRS** |
| Node gas price (`cast gas-price`) | `10000000000` wei = **10 gwei** |
| Real EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Live Cascade | `0xd41C32562D0BE20D354120E1De11A91abC340F50` |
| Live Cascade `skillCount()` | **3** (A→B→C — unchanged; NO re-registration occurred) |
| Target skills for the batch | id 1 (A, price 0) + id 3 (C, price 0.001 PHRS) |

`PRIVATE_KEY` was read from `.env` only and **never echoed**.

---

## Pre-flight budget gate result

The gate ran FIRST, before any broadcast. Cost model (upper-bound gas from 03-RESEARCH §8):

- account-deploy tx ≈ 500k gas + handleOps tx ≈ 600k gas (EOA out-of-pocket gas)
- required native value = EntryPoint prefund (680k op-gas × price) + invoke values (p1=0 + p2=0.001 PHRS)

### At the node's reported price — 10 gwei (authoritative)

| Component | wei | PHRS |
|-----------|-----|------|
| est EOA gas cost (1.1M gas × 10 gwei) | 11000000000000000 | 0.011 |
| required native value (prefund + p1 + p2) | 7800000000000000 | 0.0078 |
| **estimated TOTAL** | **18800000000000000** | **0.0188** |
| EOA balance | 4317764000000000 | 0.004317764 |
| **SHORTFALL** | **14482236000000000** | **≈ 0.01448 PHRS** |

Verdict: **estimated total (0.0188 PHRS) ≫ balance (0.004318 PHRS) → LIVE BLOCKED.** The script
reverted with `LIVE BLOCKED: top up 0x67680b09bB422cC510669bd5208D947066D4aeaE ...` and broadcast nothing.

### At the hoped-for 1 gwei (does NOT change the verdict)

At 1 gwei the *estimate* (2780000000000000 wei = 0.00278 PHRS) would fit the balance, and a
no-`--broadcast` simulation ran to "LIVE SETTLED". **But this was a dry-run simulation only —
no real funds moved (balance unchanged at 4317764000000000 wei).** 1 gwei is not a usable escape:

1. The node reports/charges **10 gwei** (`cast gas-price` = 10 gwei).
2. Phase 1 found `forge script --broadcast` **ignores `--gas-price`** (it sent a failed 10-gwei
   tx); only raw `cast send --legacy --gas-price` was reliable. So `forge script` cannot be
   trusted to actually submit at 1 gwei.
3. The lowest price empirically accepted on this node was **2 gwei** (Phase 1, 01-03). At 2 gwei
   the estimate is **0.00456 PHRS**, which still **exceeds** the 0.004318 PHRS balance by
   ≈ 0.000242 PHRS. So even at the best proven-acceptable price the budget does not fit.

Therefore the honest verdict is **BLOCKED** at the node's actual pricing.

---

## Top-up instruction (to run the bonus live step later)

Send PHRS to **`0x67680b09bB422cC510669bd5208D947066D4aeaE`** on atlantic-testnet:

- **Recommended:** top up by **≈ 0.0145 PHRS** (covers the full demo at the node's reported 10 gwei).
- **Minimum (aggressive):** top up by **≈ 0.0003 PHRS** to run at the Phase-1-proven 2 gwei via
  `cast send --legacy --gas-price 2000000000` (note: `forge script` ignores `--gas-price`, so the
  live submission would have to be driven by `cast send`, deploying the account first, then
  `handleOps`).

After topping up, re-run: `forge script script/LiveBundle.s.sol --rpc-url atlantic_testnet`
to re-check the gate; if it reports it fits, broadcast via the reliable `cast send` path.

---

## Requirement status

- **AA-01 (account deployed at deterministic addr):** ✅ proven on fork (Wave 2, `test_smartAccount_batches_two_invokes` deploys via initCode during validation).
- **AA-02 (one UserOp batches 2 invokes, 2 creator balances rise):** ✅ proven on fork against the real EntryPoint.
- **AA-03 (settles via real EntryPoint `handleOps`, self-bundled):** ✅ proven on fork (`test_handleOps_settles_via_real_entrypoint`).
- **This live step:** bonus on-chain evidence — **BLOCKED on budget**, not on correctness. No partial/half-spend occurred (balance unchanged).

**Phase 3 is complete either way:** the Wave 2 fork proof against the real EntryPoint already
satisfies AA-01/02/03. Topping up the EOA and re-running this script is optional extra evidence.
