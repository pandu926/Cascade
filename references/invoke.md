# Invoke Operation

## SDK (Recommended)

```bash
# Invoke skill 9 — price is auto-read from chain
node sdk/cli.js invoke --skill 9 --network mainnet
```

### As a library

```javascript
import { createCascade } from "./sdk/index.js";
const cascade = createCascade({ privateKey: process.env.CASCADE_PRIVATE_KEY, network: "mainnet" });

// Price is fetched automatically from the contract
const { hash, paid, explorer } = await cascade.invoke({ skillId: 9 });
console.log(`Paid ${paid} PROS — royalties distributed to all creators in the tree`);
```

## What Happens

One transaction triggers recursive distribution:
1. Payment enters skill 9
2. Skill 9's declared deps each receive their share
3. Each dep's deps receive their share (recursively)
4. Every creator in the tree gets credited
5. Creators withdraw later via `claim`

The SDK reads the skill's price from on-chain storage — no need to know it in advance.

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| skillId | number | ID of the skill to invoke (1 to skillCount) |

## Errors

| Error | Cause | Fix |
|-------|-------|-----|
| UnknownSkill | ID is 0 or above skillCount | Check skill-info first |
| WrongValue | Payment doesn't match price | SDK handles this automatically |
| Insufficient funds | Wallet can't cover price + gas | Fund wallet |

## Raw cast (alternative)

```bash
export CASCADE=0x31bE4C6B5711913D818e377ebd809d4397FF3c84

# Must know exact price in wei (skill 9 = 0.005 PROS = 5000000000000000 wei)
cast send $CASCADE "invoke(uint256)" 9 \
  --value 5000000000000000 \
  --private-key $PRIVATE_KEY --rpc-url https://rpc.pharos.xyz --legacy
```
