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

**Status:** ✅ **Verified** (RANK 1 — Blockscout verifier, no API key, first attempt). Confirmation basis: a second `forge verify-contract` submit returns the backend guard **"This contract is verified"** (status=0) — the standard SocialScan/Blockscout response for an already-verified address, which is the authoritative signal that the source is on file. NOTE: the SocialScan *read* command-API actions (`getabi`, `getsourcecode`) are broken/unsupported on this deployment (they return "not verified" / "the action is error" for every address), so they CANNOT be used to confirm status programmatically — the authoritative visual check is the pharosscan contract UI (Code tab). Treat the "already verified" submit-guard as the confirmation of record.

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

> **Residual check for submission (Phase 6):** Before submitting, a human should open the pharosscan contract UI Code tab and confirm the green "Verified" checkmark visually — the read command-API cannot confirm it programmatically. **VISUAL CHECK PENDING.**

---

## MAIN-02 Royalty Demo (live A→B→C recursive split)

**Status:** ✅ In progress — three creators funded; A→B→C register + single invoke recorded below.

The recursive-royalty killer demo, **live on Pharos mainnet** against the SAME Cascade from MAIN-01 (`0x31bE4C6B5711913D818e377ebd809d4397FF3c84`) — **no redeploy**. Three distinct creator EOAs register an A→B→C dependency tree, then one payer `invoke` of C fans real PROS up the tree so all three creator balances rise proportionally in a single transaction.

### Pre-flight gate (Task 1, before any funding broadcast)

| Check | Result |
|-------|--------|
| `cast chain-id --rpc-url mainnet` | `1672` ✅ |
| Deployer balance before funding | `1.994506190000000000` PROS (ample) |
| Estimated cost (3×0.02 stipend + 3 register + 1 invoke + 0.001 PRICE_C @ 10 gwei) | well under 0.1 PROS ✅ |

### Three creator EOAs

Keys derived as **three fresh `cast wallet new` keypairs**, stored only in a gitignored, `chmod 600` file outside the repo (`~/.demo-creators.env`). No private key or seed is written here. Fresh keys (not the public anvil test mnemonic) avoid the auto-sweep risk that well-known derived addresses face on a live chain.

| Creator | Address | Funding tx | Receipt | Balance after funding |
|---------|---------|------------|---------|----------------------|
| A (leaf) | `0x7ca05d52EB17833E802B7D2eC7f1Fc23950c56b8` | `0x4239efcf5e0b5d90b25538d04e165460fc6408d92b76a0e41097285cbc161be7` | status `1` | `0.02` PROS |
| B (dep A, 40%) | `0xD79F121Ac383e3e7f2aeEa6AEb3b700e2Fb6796b` | `0x0bb63d3efbe445b2141d6fbbc4bbf58a526e556a87cb80972cebb7c8e2ed6519` | status `1` | `0.02` PROS |
| C (dep B, 50%, price 0.001) | `0xECe4BBabd00c22E1baA1dE7f83E152D0eB6D12ef` | `0x62a85fa86100683649391fa08f2a781e2b2e9b58dc4db9cd2d61011ed2d99384` | status `1` | `0.02` PROS |

Each funded `0.02` PROS from the deployer via `cast send <creator> --value 0.02ether --rpc-url mainnet --legacy --gas-price 10000000000`. Deployer balance after the three stipends: `1.933876190000000000` PROS.

### Funding explorer links

- Fund A: https://www.pharosscan.xyz/tx/0x4239efcf5e0b5d90b25538d04e165460fc6408d92b76a0e41097285cbc161be7
- Fund B: https://www.pharosscan.xyz/tx/0x0bb63d3efbe445b2141d6fbbc4bbf58a526e556a87cb80972cebb7c8e2ed6519
- Fund C: https://www.pharosscan.xyz/tx/0x62a85fa86100683649391fa08f2a781e2b2e9b58dc4db9cd2d61011ed2d99384
- Creator A address: https://www.pharosscan.xyz/address/0x7ca05d52EB17833E802B7D2eC7f1Fc23950c56b8
- Creator B address: https://www.pharosscan.xyz/address/0xD79F121Ac383e3e7f2aeEa6AEb3b700e2Fb6796b
- Creator C address: https://www.pharosscan.xyz/address/0xECe4BBabd00c22E1baA1dE7f83E152D0eB6D12ef

### Pre-broadcast guard (Task 2, before any register/invoke broadcast)

This is the safeguard that prevents `DemoTree.s.sol`'s silent `if (existing == address(0)) new Cascade()` fresh-deploy fallback from ever firing on real money. All three checks passed **before** any spend:

| Guard | Result |
|-------|--------|
| `cast chain-id --rpc-url mainnet` == 1672 | ✅ `1672` |
| `cast code 0x31bE…3c84 --rpc-url mainnet` non-empty (>2 chars) | ✅ `4231` hex chars |
| Deployer balance ≥ safe margin | ✅ `1.933876190000000000` PROS |
| `skillCount()` before demo | `0` (snapshot for the 0→3 reuse proof) |

Because the guard confirmed live bytecode at the address, the demo ran via discrete `cast send` calls against the **reused** Cascade (not `forge script`, per the prior-phase finding that `forge script` ignored `--gas-price` and risked a failed CREATE — the same finding that motivated `forge create` in MAIN-01). `CASCADE` was treated as the fixed reuse target; `skillCount` going `0 → 3` is the on-chain proof no redeploy occurred.

### A→B→C registration (each from its own creator EOA)

Tree shape (identical to `script/DemoTree.s.sol` constants): A leaf price 0 · B depends on A at 4000 bps (40%) · C depends on B at 5000 bps (50%), price `0.001` PROS.

| Skill | id | register call | signer | tx hash | receipt |
|-------|----|--------------|--------|---------|---------|
| A (leaf) | `1` | `register(0, [], [])` | CREATOR_A | `0x24deaf09ba46324fb1be0499faa349fb4c33bb769a3330627af63447e8a8e976` | status `1` |
| B (dep A 40%) | `2` | `register(0, [1], [4000])` | CREATOR_B | `0x11f9705b2f108bbf90e8eb03c692e56a2fc452d64afe6239e0a660a4f5afeb45` | status `1` |
| C (dep B 50%, price 1e15) | `3` | `register(1000000000000000, [2], [5000])` | CREATOR_C | `0x9411f8b5f4fcf53189591b7365e4ace768a0a05b1dbd319784c51dae60fd1da6` | status `1` |

**Reuse proof:** `skillCount()` went `0 → 3` on `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` — the MAIN-01 contract, NOT a redeploy.

### Single payer invoke of C (the recursive fan-out)

| Field | Value |
|-------|-------|
| Call | `invoke(3)` with `msg.value = 0.001 ether` (1e15 wei, exact — else `WrongValue` revert) |
| Signer | deployer/payer `0x3306E846b5Dc7F890436955999CeE27a6abbCbe8` |
| Invoke tx hash | `0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564` |
| Receipt status | `1` (success) |
| Gas used | `127275` |

### Creator balance deltas (one invoke → three creators paid)

`balances(creator)` read via `cast call` before and after the single invoke:

| Creator | id | before (wei) | after (wei) | delta (wei) | delta (PROS) | of PRICE_C |
|---------|----|-------------|-------------|-------------|--------------|-----------|
| A | 1 | `0` | `200000000000000` | `200000000000000` | `0.0002` | 20% |
| B | 2 | `0` | `300000000000000` | `300000000000000` | `0.0003` | 30% |
| C | 3 | `0` | `500000000000000` | `500000000000000` | `0.0005` | 50% |
| **Σ** | | | | **`1000000000000000`** | **`0.001`** | **100%** |

**Conservation holds exactly:** Σ(deltas) == `1000000000000000` wei == `PRICE_C` (0.001 PROS). All three balances rose; every wei of the payment was assigned across the tree (no dust, no leak).

Split math: C keeps 50% (`0.0005`); 50% routes into B's subtree. B keeps 60% of that slice (`0.0003`); 40% routes into A. A (leaf) absorbs the remainder (`0.0002`).

### RoyaltyAccrued events decoded from the invoke receipt

Three `RoyaltyAccrued(uint256 indexed skillId, address indexed creator, uint256 amount)` logs, one per credited tree level:

| skillId | creator | amount (wei) | amount (PROS) |
|---------|---------|--------------|---------------|
| `1` | `0x7ca05d52eb17833e802b7d2ec7f1fc23950c56b8` | `200000000000000` | `0.0002` |
| `2` | `0xd79f121ac383e3e7f2aeea6aeb3b700e2fb6796b` | `300000000000000` | `0.0003` |
| `3` | `0xece4bbabd00c22e1baa1de7f83e152d0eb6d12ef` | `500000000000000` | `0.0005` |

(topic0 = `keccak("RoyaltyAccrued(uint256,address,uint256)")` = `0xfb8f4e83813fe02fd9681ce96e86d71ecc921ea9aacaaa3760d4d78c9b2c0f69`.)

### Demo balances summary (deployer)

| Point | PROS |
|-------|------|
| Before MAIN-02 (= after MAIN-01) | `1.994506190000000000` |
| After 3× 0.02 stipends | `1.933876190000000000` |
| After register×3 + invoke (incl. 0.001 PRICE_C value) | `1.931603440000000000` |

### MAIN-02 explorer links

- Register A: https://www.pharosscan.xyz/tx/0x24deaf09ba46324fb1be0499faa349fb4c33bb769a3330627af63447e8a8e976
- Register B: https://www.pharosscan.xyz/tx/0x11f9705b2f108bbf90e8eb03c692e56a2fc452d64afe6239e0a660a4f5afeb45
- Register C: https://www.pharosscan.xyz/tx/0x9411f8b5f4fcf53189591b7365e4ace768a0a05b1dbd319784c51dae60fd1da6
- **Invoke C (the recursive royalty split):** https://www.pharosscan.xyz/tx/0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564
- Cascade (reused, source-verified): https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84

**MAIN-02 status:** ✅ **Complete.** One live mainnet `invoke` of an A→B→C tree paid three distinct creators proportionally in a single transaction, summing exactly to PRICE_C, on the source-verified MAIN-01 Cascade (no redeploy). Skill ids for 05-03 reuse: **A=1, B=2, C=3** (creator C's skill id 3 has price 0.001 PROS).

---

## MAIN-03 4337 Demo (live self-bundled handleOps batching two invokes)

**Status:** ✅ **Complete.** A live Pharos-mainnet smart account (`CascadeAccount`, deployed via an `AccountFactory`) batched TWO `Cascade.invoke` calls into ONE self-bundled `handleOps` through the real EntryPoint v0.7 — both invoked skills' creators (B id2, C id3) rose, plus A via C's fan-out, summing exactly to PRICE_C. The smart account is the `msg.sender`/`payer` of both invokes, proving the account-agnostic claim with real money (parity with the MAIN-02 EOA path).

The flow reproduces the Phase 3 fork-proven ERC-4337 v0.7 mechanics LIVE: deploy factory → `createAccount` (CREATE2, owner = broadcaster EOA) → fund the account minimally → build + sign ONE `PackedUserOperation` (`callData = executeBatch([cascade,cascade],[0, 1e15],[invoke(2), invoke(3)])`) → EOA self-bundles via `ep.handleOps([op], beneficiary)`. No external bundler.

### Driver

`script/LiveBundleMainnet.s.sol` — a NEW, mainnet-guarded sibling of the FROZEN testnet `script/LiveBundle.s.sol` (the testnet guard `require(block.chainid == 688689)` is left untouched). Hard guard: `require(block.chainid == 1672, "wrong chainId: refusing to broadcast")`. Reads `CASCADE`, `SKILL_ID_1/2`, `PRICE_1/2`, `FACTORY`, `SALT`, `GAS_PRICE_WEI` from env (no hardcoded mainnet Cascade). Reuses LiveBundle's exact `_buildSignedOp` / `_batchInvoke` / `_pack` v0.7 mechanics verbatim. `PRIVATE_KEY` read from env only, never echoed.

### Pre-flight gate (ran FIRST, before any broadcast)

| Check | Result |
|-------|--------|
| `cast chain-id --rpc-url mainnet` | `1672` ✅ |
| `cast code <CASCADE>` non-empty | ✅ `4231` hex chars |
| `cast code <EntryPoint v0.7>` non-empty | ✅ `~16 KB` (32073 hex chars) |
| Deployer balance before MAIN-03 | `1.931603440000000000` PROS |
| Estimated TOTAL (factory+account+handleOps gas + prefund + 2 invoke values @ 10 gwei) | `0.0258` PROS ≤ balance ✅ |
| Full dry-run (`forge script` against mainnet fork, no broadcast) | `SIMULATION COMPLETE` — entire flow incl. handleOps settled clean against the real EntryPoint bytecode |

### Deployed 4337 contracts (live on mainnet)

| Artifact | Address |
|----------|---------|
| EntryPoint v0.7 (canonical, reused) | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| **AccountFactory** | **`0x904935BA1417FC35591019A0fC54c670DA824c60`** |
| **CascadeAccount (smart account)** | **`0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1`** |
| Account owner / signer / broadcaster EOA | `0x3306E846b5Dc7F890436955999CeE27a6abbCbe8` |

**CREATE2 determinism check:** `cast call <factory> "getAddress(address,uint256)(address)" 0x3306… 0` == `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1` (matches the deployed account) ✅. `cast code` non-empty on both: factory `6515` hex chars, account `4577` hex chars.

### Deploy + funding txs (all status 1)

| Step | tx hash | block | gasUsed | notes |
|------|---------|-------|---------|-------|
| Factory deploy | `0x0adbda11005db958e3f8a86681aab2188303efa8ba46d31094d9d19a4d2b5055` | `9631013` | `755099` | `contractAddress` == factory `0x9049…` |
| createAccount (CREATE2 account deploy) | `0x316dfbf86135e7ed5838125be06be6301bafb61819d74f43cc32c8bfbb5515f2` | `9631013` | `524320` | to factory; deploys account `0xfe93…` |
| Fund account (prefund + 2 invoke values) | `0x0966005d410f247ac0d1da967aa31985ec78784d88275080d890ca78d3ef3320` | `9631013` | `21055` | value `0.0078` PROS to account |

After funding, the account held `7800000000000000` wei (`0.0078` PROS) = EntryPoint prefund (`6.8e15`) + invoke value for C (`1e15`) + invoke value for B (`0`).

### Deploy explorer links

- Factory: https://www.pharosscan.xyz/address/0x904935BA1417FC35591019A0fC54c670DA824c60
- Smart account: https://www.pharosscan.xyz/address/0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1
- Factory deploy tx: https://www.pharosscan.xyz/tx/0x0adbda11005db958e3f8a86681aab2188303efa8ba46d31094d9d19a4d2b5055
- createAccount tx: https://www.pharosscan.xyz/tx/0x316dfbf86135e7ed5838125be06be6301bafb61819d74f43cc32c8bfbb5515f2
- Funding tx: https://www.pharosscan.xyz/tx/0x0966005d410f247ac0d1da967aa31985ec78784d88275080d890ca78d3ef3320

### The self-bundled handleOps (ONE tx settled TWO invokes)

ONE `PackedUserOperation` was built, signed (eth-signed-prefixed `ep.getUserOpHash`, owner ECDSA), and self-bundled by the EOA: `ep.handleOps([op], payable(0x3306…))`. Its `callData = executeBatch([CASCADE, CASCADE], [0, 1000000000000000], [invoke(2), invoke(3)])` — two `Cascade.invoke` calls in a single UserOp, sender = the smart account `0xfe93…`. `initCode` was empty (the account was already deployed via `createAccount`).

| Field | Value |
|-------|-------|
| **handleOps tx hash** | **`0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90`** |
| to | EntryPoint v0.7 `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Block number | `9631209` |
| Receipt status | `1` (success) |
| Gas used | `205868` |
| UserOp sender (payer of both invokes) | smart account `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1` |
| Beneficiary (fee recipient) | broadcaster EOA `0x3306E846b5Dc7F890436955999CeE27a6abbCbe8` |
| Batched skills | id `2` (B, price `0`) + id `3` (C, price `1000000000000000` = 0.001 PROS) |

**Events in the single handleOps receipt** (decoded from `cast receipt`): `1` EntryPoint `UserOperationEvent`, **`2` Cascade `Invoked`** (skillId 2 payer `0xfe93…` value 0; skillId 3 payer `0xfe93…` value 1e15), and **`3` `RoyaltyAccrued`** (C's fan-out crediting A/B/C). Two invokes settled in ONE transaction through the real EntryPoint — account-agnostic parity with the MAIN-02 EOA path, now via a smart account.

### Creator balance deltas (ONE UserOp → creators paid)

`balances(creator)` read via `cast call` before and after the single handleOps:

| Creator | id | before (wei) | after (wei) | delta (wei) | delta (PROS) |
|---------|----|-------------|-------------|-------------|--------------|
| A (leaf) | 1 | `200000000000000` | `400000000000000` | `200000000000000` | `0.0002` |
| B (dep A 40%) | 2 | `300000000000000` | `600000000000000` | `300000000000000` | `0.0003` |
| C (dep B 50%) | 3 | `500000000000000` | `1000000000000000` | `500000000000000` | `0.0005` |
| **Σ** | | | | **`1000000000000000`** | **`0.001`** |

Both invoked skills' creators rose: **B (id2) +0.0003 and C (id3) +0.0005**. A (+0.0002) rose via C's recursive fan-out. **Conservation holds:** Σ(deltas) == `1000000000000000` wei == `PRICE_C` (the value the account forwarded for `invoke(3)`); `invoke(2)` carried value 0 (B is a free skill), so it credited nothing new — its `Invoked` event is the on-chain proof the second batched call executed.

`RoyaltyAccrued` events decoded from the handleOps receipt:

| skillId | creator | amount (wei) |
|---------|---------|--------------|
| `1` | `0x7ca05d52eb17833e802b7d2ec7f1fc23950c56b8` | `200000000000000` |
| `2` | `0xd79f121ac383e3e7f2aeea6aeb3b700e2fb6796b` | `300000000000000` |
| `3` | `0xece4bbabd00c22e1baa1de7f83e152d0eb6d12ef` | `500000000000000` |

### Deployer balance (MAIN-03)

| Point | PROS |
|-------|------|
| Before MAIN-03 (= after MAIN-02) | `1.931603440000000000` |
| After factory + account + funding + failed handleOps (block 9631013) | `1.909581770000000000` |
| After successful retry (createAccount idempotent + handleOps, block 9631209) | `1.909707750000000000` |

(The deployer balance *rose* slightly on the successful retry because, as the `handleOps` beneficiary, the EOA was refunded the EntryPoint-collected gas fee from the account's prefund deposit — the account's `7.8e15` wei drained to `0`: `1e15` to Cascade for `invoke(3)`, the remainder consumed as gas/prefund.)

### First handleOps attempt — diagnosed and resolved (no half-spend)

The first broadcast's `handleOps` reverted with EntryPoint custom error **`AA95 out of gas`** (tx `0x48fce20a3975a177823de86700db82d20df8bfdda0947de4f827cbbfcfeb2b32`, status `0`, block `9631013`). Root cause: `forge script` sized the broadcast tx's gas from `eth_estimateGas` (~260k), below the EntryPoint's AA95 floor, which requires the outer bundler tx to forward at least `verificationGasLimit + callGasLimit + preVerificationGas` (200k + 400k + 80k = 680k) to the inner op. The op's *validation* succeeded (ecrecover returned the owner, prefund deposited) — only the outer gas ceiling tripped.

**Crucially, the failed tx fully rolled back** (verified on-chain post-failure): account nonce stayed `0`, EntryPoint deposit `0`, account balance intact at `7.8e15` wei — **no half-spend of any invoke value, creator balances unchanged.** The factory and account were already deployed (those txs succeeded independently). The fix was to force the bundler tx to carry enough gas via `--gas-estimate-multiplier 500` and re-run reusing the deployed factory (`FACTORY` env → idempotent `createAccount` returns the funded account, funding auto-skips). The retry settled cleanly (the successful handleOps above).

| First attempt | Value |
|---------------|-------|
| Failed handleOps tx | `0x48fce20a3975a177823de86700db82d20df8bfdda0947de4f827cbbfcfeb2b32` (status `0`, `AA95 out of gas`) |
| Rollback verified | nonce `0`, deposit `0`, account balance `7.8e15` intact — no half-spend |
| Fix | `--gas-estimate-multiplier 500` so the bundler tx clears the EntryPoint AA95 floor (~680k forwarded gas) |

### MAIN-03 explorer links

- **handleOps (the self-bundled 2-invoke batch):** https://www.pharosscan.xyz/tx/0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90
- Failed first attempt (AA95, rolled back): https://www.pharosscan.xyz/tx/0x48fce20a3975a177823de86700db82d20df8bfdda0947de4f827cbbfcfeb2b32
- EntryPoint v0.7: https://www.pharosscan.xyz/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032
- Smart account: https://www.pharosscan.xyz/address/0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1

**MAIN-03 status:** ✅ **Complete.** A live mainnet smart account batched two `Cascade.invoke` calls into ONE self-bundled `handleOps` through the real EntryPoint v0.7 (status 1); both invoked skills' creators rose, Σ deltas == PRICE_C exactly. The account is the `msg.sender` of both invokes — account-agnostic parity with the EOA path, with real money. Every spend was pre-flight gated; the one transient AA95 failure rolled back fully (no half-spend) and was resolved by raising the bundler tx gas.

---

## Phase 5 Complete — all three headline artifacts live on mainnet

| Req | Artifact | Key on-chain proof |
|-----|----------|--------------------|
| MAIN-01 | Cascade deployed + source-verified | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84`, deploy tx `0x4fc8db37…`, RANK-1 verified |
| MAIN-02 | Recursive royalty demo | invoke tx `0x5ba20c87…` — one invoke paid 3 creators, Σ == 0.001 PROS |
| MAIN-03 | Self-bundled 4337 batch | handleOps tx `0x1f3cec93…` — one UserOp batched 2 invokes via the real EntryPoint v0.7 |

This file (`MAINNET_RESULT.md`) is the single source of truth for Phase 6 (visualization / docs / submission).
