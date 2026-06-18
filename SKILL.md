---
name: cascade
description: >
  Cascade is the economic layer for composable AI skills on Pharos. It lets skill authors
  earn recursive royalties whenever their skill is used — directly or as a dependency of
  another skill. Use this skill when the user wants to: register a skill on Pharos,
  invoke/pay for a skill, check royalty balances, claim accrued royalties, or understand
  how recursive revenue sharing works on-chain. Works on Pharos mainnet (PROS) and
  Atlantic testnet (PHRS).
version: 1.0.0
requires:
  anyBins:
  - node
---

# Cascade — Recursive Skill Royalties on Pharos

## What It Does

Cascade is a smart contract that automatically splits payments up a skill's dependency
tree. When someone pays to use a skill, every creator in the composition chain gets their
declared share — recursively, in one transaction, with no intermediary.

**Example:** Carol's agent uses Bob's summarizer, which uses Alice's translator. When
someone pays Carol 0.005 PROS → Carol keeps 50%, Bob gets 30%, Alice gets 20%.
Automatically. Every time.

## Quick Start

```bash
# Clone and install
git clone https://github.com/pandu926/Cascade.git
cd Cascade && npm install

# Set your private key
export CASCADE_PRIVATE_KEY=0x...
export CASCADE_NETWORK=mainnet   # or "testnet"
```

## Commands

### Register a skill

```bash
# Leaf skill (building block, no price, no deps)
node sdk/cli.js register

# Skill with price and dependencies
node sdk/cli.js register --price 0.005 --deps 7,8 --shares 4000,2000
```

Parameters:
- `--price` — cost in native token (PROS/PHRS) to invoke this skill. Default: 0
- `--deps` — comma-separated IDs of skills this depends on
- `--shares` — comma-separated basis points (0-10000) each dep gets. Sum must be ≤ 10000

Rules:
- Dependencies must already exist (lower ID)
- Shares are in basis points: 4000 = 40%
- Remainder after all deps = creator's own cut
- Immutable once registered — cannot be changed
- Max depth: 8 levels

### Invoke (pay for) a skill

```bash
node sdk/cli.js invoke --skill 9
```

The SDK auto-reads the skill's price from chain. Payment cascades through the entire
dependency tree in one transaction.

### Check balance

```bash
node sdk/cli.js balance 0xYourAddress
```

### Claim (withdraw) royalties

```bash
node sdk/cli.js claim
```

Withdraws all accrued royalties to your wallet. Pull-payment: no one can block your
earnings.

### View contract info

```bash
node sdk/cli.js skill-info
```

## Use as a Library (for agents)

```javascript
import { createCascade } from "./sdk/index.js";

const cascade = createCascade({
  privateKey: process.env.CASCADE_PRIVATE_KEY,
  network: "mainnet"
});

// Register
const { skillId } = await cascade.register({
  price: "0.005",
  depIds: [7],
  depShares: [4000]
});

// Invoke (price auto-fetched)
await cascade.invoke({ skillId: 9 });

// Check balance
const balance = await cascade.getBalance("0x...");

// Claim
await cascade.claim();
```

## Networks

| Network | Token | Contract |
|---------|-------|----------|
| Mainnet (1672) | PROS | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` |
| Testnet (688689) | PHRS | `0xd41C32562D0BE20D354120E1De11A91abC340F50` |

## How Revenue Sharing Works

```
User pays 0.005 PROS to invoke Skill C
         │
         ▼
   ┌─────────────┐
   │  Skill C    │ keeps 50% = 0.0025
   │  dep: B@50% │
   └──────┬──────┘
          │ 50% flows down
          ▼
   ┌─────────────┐
   │  Skill B    │ keeps 60% of received = 0.0015
   │  dep: A@40% │
   └──────┬──────┘
          │ 40% flows down
          ▼
   ┌─────────────┐
   │  Skill A    │ receives 0.0010
   │  (leaf)     │
   └─────────────┘

Total: 0.0025 + 0.0015 + 0.0010 = 0.005 ✓ (exact conservation)
```

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| Share sum exceeds 10000 | dep shares add up to more than 100% | Reduce shares |
| Bad dependency | dep ID doesn't exist or >= new ID | Register deps first (bottom-up) |
| Depth exceeded | Tree deeper than 8 levels | Flatten dependency chain |
| Wrong value | Payment doesn't match skill price | SDK handles this automatically |
| Nothing to claim | Balance is 0 | Earn royalties first via invoke |

## Security Notes

- Private keys are never logged or stored by the SDK
- Pull-payment pattern: no reentrancy possible
- Immutable registration: no one can change terms after registration
- Depth cap 8: bounded gas for recursive distribution
