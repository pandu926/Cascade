# Claim Operation

## SDK (Recommended)

```bash
# Check accrued balance
node sdk/cli.js balance 0xYourAddress --network mainnet

# Withdraw all accrued royalties
node sdk/cli.js claim --network mainnet
```

### As a library

```javascript
import { createCascade } from "./sdk/index.js";
const cascade = createCascade({ privateKey: process.env.CASCADE_PRIVATE_KEY, network: "mainnet" });

// Check balance
const balance = await cascade.getBalance("0x...");
console.log(`Accrued: ${balance} wei`);

// Claim everything
const { hash, amount, explorer } = await cascade.claim();
console.log(`Claimed ${amount} PROS`);
```

## How Pull-Payment Works

- Royalties accrue in the contract as internal balances
- Each creator withdraws on their own schedule via `claim()`
- No one can block your earnings — even if other creators disappear
- Double-claim is safe: pays 0, no revert
- Balance is zeroed before transfer (reentrancy-safe)

## Parameters

**claim** — no parameters. Withdraws to the caller's address.

**balance** — takes an address to query (read-only, no key needed).

## Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Nothing to claim | Balance is 0 | Earn royalties first (someone must invoke a skill you're in the tree of) |
| TransferFailed | Native transfer failed | Rare — only if receiver contract rejects ETH |

## Raw cast (alternative)

```bash
export CASCADE=0x31bE4C6B5711913D818e377ebd809d4397FF3c84

# Check balance (read-only, no key needed)
cast call $CASCADE "balances(address)(uint256)" 0xYourAddress \
  --rpc-url https://rpc.pharos.xyz

# Claim
cast send $CASCADE "claim()" \
  --private-key $PRIVATE_KEY --rpc-url https://rpc.pharos.xyz --legacy
```

## Other Read Operations

```bash
# How many skills exist?
node sdk/cli.js skill-info --network mainnet
```
