# Register Operation Instructions

Detailed instructions for registering a skill on the live Cascade contract.

> **Network Configuration**: The `<rpc>` parameter in all commands is read from the target
> network's `rpcUrl` field in `assets/networks.json` (or the equivalent `foundry.toml` alias
> `atlantic_testnet` / `mainnet`). Defaults to the Atlantic testnet.
>
> **Live Contract**: `CASCADE = 0xd41C32562D0BE20D354120E1De11A91abC340F50` on
> atlantic-testnet (chainId 688689). Export it: `export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50`.
>
> **Private Key**: Register is a write operation — complete the Write Operation Pre-checks
> in `SKILL.md` first. Never inline a literal key; always pass `--private-key $PRIVATE_KEY`.

---

## Register a Skill

Registers an immutable, priced skill. A skill declares a native-token `price` and an
optional list of dependency skill ids, each paired with a basis-point (bps) share of this
skill's payment that is routed into that dependency's subtree. The registering creator
absorbs the remainder (`10000 - Σ shares` bps) as their own cut.

Solidity signature:

```solidity
register(uint256 price, uint256[] depIds, uint256[] depShares) returns (uint256 id)
```

### Rules (enforced on-chain)

- `depIds.length == depShares.length` (1:1 aligned), else revert `len mismatch`.
- Each `depId` must be **non-zero and strictly smaller than the new id** — i.e. an
  already-registered skill. Register bottom-up (leaves first). Else revert `bad dep id`.
- `Σ depShares ≤ 10000` (≤ 100%). Else revert `shares > 10000`.
- Resulting tree `depth ≤ 8` (one deeper than the deepest dependency). Else revert `depth > 8`.
- `price` may be `0` (a free leaf skill). Price is in **wei**.
- The returned `id` is monotonic, starting at `1`.

**Command Template (forge script)**

The `script/Register.s.sol` script reads every parameter from the environment:

```bash
export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50
export PRICE=1000000000000000        # 0.001 PHRS in wei
export DEP_IDS=1,2                    # comma-separated dep ids (omit/empty for a leaf)
export DEP_SHARES=5000,4000           # comma-separated bps shares, 1:1 with DEP_IDS

forge script script/Register.s.sol \
  --rpc-url atlantic_testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

For a leaf skill (no dependencies), leave `DEP_IDS` / `DEP_SHARES` unset (they default to
empty) and set only `PRICE`.

**Command Template (raw cast send)**

```bash
cast send $CASCADE \
  "register(uint256,uint256[],uint256[])" \
  <price> "[<depIds>]" "[<depShares>]" \
  --private-key $PRIVATE_KEY \
  --rpc-url <rpc>
```

Concrete leaf example (price 0, no deps):

```bash
cast send $CASCADE "register(uint256,uint256[],uint256[])" \
  0 "[]" "[]" \
  --private-key $PRIVATE_KEY --rpc-url https://atlantic.dplabs-internal.com
```

Concrete example with two dependencies (50% to id 1, 40% to id 2; creator keeps 10%):

```bash
cast send $CASCADE "register(uint256,uint256[],uint256[])" \
  1000000000000000 "[1,2]" "[5000,4000]" \
  --private-key $PRIVATE_KEY --rpc-url https://atlantic.dplabs-internal.com
```

**Parameters**

| Parameter | Env Var | Type | Required | Description |
|-----------|---------|------|----------|-------------|
| `price` | `PRICE` | uint256 | Yes | Invoke price in **wei** (may be `0` for a leaf) |
| `depIds` | `DEP_IDS` | uint256[] | No | Dependency skill ids; each must be a strictly-smaller, registered id. Empty for a leaf |
| `depShares` | `DEP_SHARES` | uint256[] | No | Bps share (0–10000) routed into each dep's subtree, 1:1 with `depIds`; Σ ≤ 10000 |
| `<rpc>` | — | string | Yes | RPC URL from `assets/networks.json` (or alias `atlantic_testnet`) |
| `$PRIVATE_KEY` | `PRIVATE_KEY` | string | Yes | Signer key; pass via `--private-key $PRIVATE_KEY` |

**Output Parsing**

- Emits `SkillRegistered(uint256 indexed id, address indexed creator, uint256 price)`.
- The forge script logs `Registered skill id: <id>` plus the price and dependency count.
- To recover the new id from a raw `cast send`, read the tx receipt and decode the
  `SkillRegistered` event, or simply call `cast call $CASCADE "skillCount()(uint256)" --rpc-url <rpc>`
  immediately after — the new id equals the post-register `skillCount`.
- Confirm on the explorer: `<explorerUrl>/tx/<tx_hash>` (read `explorerUrl` from `assets/networks.json`).

**Error Handling**

| Error Signature | Cause | Suggested Action |
|----------------|-------|-----------------|
| `execution reverted: len mismatch` | `DEP_IDS` and `DEP_SHARES` differ in length | Ensure both arrays are the same length and 1:1 aligned |
| `execution reverted: bad dep id` | A dep id is `0` or ≥ the new id | Use only strictly-smaller, already-registered ids; register bottom-up (leaves first) |
| `execution reverted: shares > 10000` | Σ(depShares) exceeds 100% | Reduce shares so the total is ≤ 10000 bps |
| `execution reverted: depth > 8` | Dependency tree deeper than 8 levels | Flatten the tree; depth is capped at 8 |
| Command missing `--private-key` | Private key not configured | Set `$PRIVATE_KEY` and pass `--private-key $PRIVATE_KEY` |
| `insufficient funds` | Account cannot cover gas | Fund the account; check `cast balance <addr> --rpc-url <rpc> --ether` |

> **Agent Guidelines**: Skills are **immutable** — confirm `price`, `DEP_IDS`, and
> `DEP_SHARES` with the user before broadcasting. Register dependencies bottom-up: a parent
> can only reference ids that already exist and are smaller than its own. After a successful
> register, report the new skill id (from the script log or post-register `skillCount()`) and
> the explorer tx link. Always complete the Write Operation Pre-checks in `SKILL.md` (key
> check, address derivation, network confirmation, balance check) before broadcasting.
