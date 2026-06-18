# Register Operation

## SDK (Recommended)

```bash
# Leaf skill (free, no dependencies)
node sdk/cli.js register --network mainnet

# With price and dependencies
node sdk/cli.js register --price 0.005 --deps 7 --shares 4000 --network mainnet
```

### As a library

```javascript
import { createCascade } from "./sdk/index.js";
const cascade = createCascade({ privateKey: process.env.CASCADE_PRIVATE_KEY, network: "mainnet" });

const { skillId, hash, explorer } = await cascade.register({
  price: "0.005",       // in PROS/PHRS (not wei)
  depIds: [7],          // depends on skill 7
  depShares: [4000]     // gives 40% to skill 7's subtree
});
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| price | string | Cost in native token to invoke. "0" = free leaf |
| depIds | number[] | IDs of dependency skills (must already exist, lower ID) |
| depShares | number[] | Basis points (0-10000) each dep receives. Sum ≤ 10000 |

## Rules

- Dependencies must be registered first (bottom-up: leaves before parents)
- Shares are basis points: 4000 = 40%, 10000 = 100%
- Creator keeps the remainder: 10000 - sum(depShares)
- Immutable once registered — cannot be changed
- Max depth: 8 levels
- Returned skill ID is monotonic (starts at 1)

## Errors

| Error | Cause | Fix |
|-------|-------|-----|
| LengthMismatch | depIds and depShares different lengths | Make arrays same length |
| BadDependency | dep ID is 0 or >= new ID | Register deps first |
| SharesExceedMax | sum of shares > 10000 | Reduce shares |
| DepthExceeded | tree deeper than 8 | Flatten chain |

## Raw cast (alternative)

```bash
export CASCADE=0x31bE4C6B5711913D818e377ebd809d4397FF3c84

# Leaf
cast send $CASCADE "register(uint256,uint256[],uint256[])" 0 "[]" "[]" \
  --private-key $PRIVATE_KEY --rpc-url https://rpc.pharos.xyz --legacy

# With deps (price 0.005 PROS, dep 7 at 40%)
cast send $CASCADE "register(uint256,uint256[],uint256[])" \
  5000000000000000 "[7]" "[4000]" \
  --private-key $PRIVATE_KEY --rpc-url https://rpc.pharos.xyz --legacy
```
