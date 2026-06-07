# Cascade — Pharos Mainnet Deployment Results

Single source of truth for the Phase 5 mainnet artifacts (chainId **1672**, native token **PROS**, explorer https://www.pharosscan.xyz/). Every spend below was pre-flight gated (balance read + chainId confirmed) before broadcast. The deployer private key is never recorded here.

---

## MAIN-01 Deployment (Cascade)

**Status:** ✅ Deployed and live on mainnet. Source ✅ **verified** (RANK 1) — see [Verification](#verification) below.

| Field | Value |
|-------|-------|
| Network | Pharos mainnet |
| Chain ID | `1672` (confirmed via `cast chain-id --rpc-url mainnet` **before** broadcast) |
| **Cascade address** | **`0x31bE4C6B5711913D818e377ebd809d4397FF3c84`** |
| Deploy tx hash | `0x4fc8db37b7693412e76a6743b6335be8b4ceae079a99963e3924ee37875eee1d` |
| Deployer / payer EOA | `0x3306E846b5Dc7F890436955999CeE27a6abbCbe8` |
| Block number | `9629425` |
| Receipt status | `1` (success) |
| Gas used | `510381` |
| Effective gas price | `10000000000` wei (10 gwei, `--legacy --gas-price`) |
| Deploy cost | `0.00510381` PROS |
| Deploy tool | `forge create src/Cascade.sol:Cascade --rpc-url mainnet --broadcast --legacy --gas-price 10000000000` |

### Balances (deployer)

| Point | PROS |
|-------|------|
| Before deploy | `1.999610000000000000` |
| After deploy | `1.994506190000000000` |
| Delta | `0.005103810000000000` (== gas used × gas price, exact) |

### Post-deploy on-chain checks

| Check | Command | Result |
|-------|---------|--------|
| Bytecode present | `cast code <ADDR> --rpc-url mainnet` | non-empty (4231 hex chars) |
| Fresh registry | `cast call <ADDR> "skillCount()(uint256)" --rpc-url mainnet` | `0` |
| Tx succeeded | `cast receipt <TXHASH> --rpc-url mainnet` | status `1` |

### Explorer links

- Address: https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84
- Deploy tx: https://www.pharosscan.xyz/tx/0x4fc8db37b7693412e76a6743b6335be8b4ceae079a99963e3924ee37875eee1d

### Contract facts (for verification)

| Property | Value |
|----------|-------|
| Contract name | `Cascade` (`src/Cascade.sol`) |
| Pragma / solc | `^0.8.24` / pinned `0.8.24` |
| Compiler (build metadata) | `0.8.24+commit.e11b9ed9` |
| Optimizer | on, `runs = 200` |
| Constructor args | none (no-arg) |
| Imports | none (single self-contained file) |

---

## Verification

**Status:** ✅ **Verified** on the first attempt (RANK 1 — Blockscout verifier, no API key). Not a fallback; source is confirmed `Pass - Verified` on the SocialScan command API backing pharosscan.

| Field | Value |
|-------|-------|
| Rank reached | **RANK 1** (primary, no API key) |
| Endpoint probe | `422` (route live) at `https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` |
| Verifier | `blockscout` |
| Verifier URL | `https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract` |
| Compiler | `0.8.24`, optimizer runs `200`, no constructor args |
| Backend response | `Contract successfully verified` → status `OK` / `Pass - Verified` |
| Verify GUID | `969638ddc7d55625563ac988076b8e82cf02fe5c22fcddc3fd828909f7851874` |

### Verify command used (RANK 1)

```bash
forge verify-contract 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 src/Cascade.sol:Cascade \
  --chain-id 1672 \
  --compiler-version 0.8.24 \
  --num-of-optimizations 200 \
  --verifier blockscout \
  --verifier-url https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract \
  --watch
```

### Verified-source links

- Contract (verified source): https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84
- SocialScan API record: https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/address/0x31be4c6b5711913d818e377ebd809d4397ff3c84

Verification spent no PROS (submit-only, public source) and did not alter the deployed contract.
