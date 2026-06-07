# Invoke Operation Instructions

Detailed instructions for invoking (paying for) a skill on the live Cascade contract.

> **Network Configuration**: The `<rpc>` parameter in all commands is read from the target
> network's `rpcUrl` field in `assets/networks.json` (or the equivalent `foundry.toml` alias
> `atlantic_testnet` / `mainnet`). Defaults to the Atlantic testnet.
>
> **Live Contract**: `CASCADE = 0xd41C32562D0BE20D354120E1De11A91abC340F50` on
> atlantic-testnet (chainId 688689). Export it: `export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50`.
>
> **Private Key**: Invoke is a write operation that moves native value — complete the Write
> Operation Pre-checks in `SKILL.md` first. Always pass `--private-key $PRIVATE_KEY`.

---

## Invoke a Skill

Pays a skill's exact registered price and fans the payment up its entire declared
dependency tree in a single transaction. Each dependency receives `floor(amount * share / 10000)`
routed into its subtree; each skill's creator absorbs the per-level remainder as their own
royalty. Every wei is assigned — total accrued equals the original payment exactly. No
external calls happen during fan-out (reentrancy-safe; no payee can block the tree).

Solidity signature:

```solidity
invoke(uint256 skillId) payable
```

### Rules (enforced on-chain)

- `skillId` must be in `1..skillCount()`, else revert `no skill`.
- **Exact payment**: `msg.value` MUST equal `skills[skillId].price` exactly, else revert
  `wrong value`. Over- and under-paying both revert. Read the price first.

### Reading the price before invoking

The price lives in the skill struct. Read the current number of skills, and (if needed)
confirm the amount with the user before sending:

```bash
# Highest valid skill id
cast call $CASCADE "skillCount()(uint256)" --rpc-url <rpc>
```

If the user does not know the price, ask them for it (it was set at register time and is
echoed in the register tx's `SkillRegistered` event / script log). Send exactly that wei
amount via `--value`.

**Command Template (forge script)**

The `script/Invoke.s.sol` script reads parameters from the environment:

```bash
export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50
export SKILL_ID=3                     # id of the skill to invoke
export INVOKE_VALUE=1000000000000000  # exact wei = the skill's registered price

forge script script/Invoke.s.sol \
  --rpc-url atlantic_testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Command Template (raw cast send)**

```bash
cast send $CASCADE \
  "invoke(uint256)" <skillId> \
  --value <wei> \
  --private-key $PRIVATE_KEY \
  --rpc-url <rpc>
```

Concrete example (invoke skill id 3, price 0.001 PHRS = 1000000000000000 wei):

```bash
cast send $CASCADE "invoke(uint256)" 3 \
  --value 1000000000000000 \
  --private-key $PRIVATE_KEY --rpc-url https://atlantic.dplabs-internal.com
```

**Parameters**

| Parameter | Env Var | Type | Required | Description |
|-----------|---------|------|----------|-------------|
| `skillId` | `SKILL_ID` | uint256 | Yes | Id of the skill to invoke; must be in `1..skillCount()` |
| `--value` | `INVOKE_VALUE` | uint256 (wei) | Yes | Exact payment in wei; MUST equal the skill's registered price |
| `<rpc>` | — | string | Yes | RPC URL from `assets/networks.json` (or alias `atlantic_testnet`) |
| `$PRIVATE_KEY` | `PRIVATE_KEY` | string | Yes | Payer key; pass via `--private-key $PRIVATE_KEY` |

**Output Parsing**

- Emits `Invoked(uint256 indexed skillId, address indexed payer, uint256 amount)` once.
- Emits `RoyaltyAccrued(uint256 indexed skillId, address indexed creator, uint256 amount)`
  for **each** creator that receives a cut as the payment fans up the tree — a single
  invoke of a deep skill credits multiple distinct creators in one tx.
- The forge script logs `Invoked skill id: <id>` and `paid (wei): <value>`.
- Accrued royalties are **not** auto-transferred — each creator must `claim()` (see
  `references/claim.md`). To see balances move, read `balances(<creator>)` before and after.
- Confirm on the explorer: `<explorerUrl>/tx/<tx_hash>` (read `explorerUrl` from `assets/networks.json`).

**Error Handling**

| Error Signature | Cause | Suggested Action |
|----------------|-------|-----------------|
| `execution reverted: no skill` | `skillId` is 0 or greater than `skillCount()` | Verify the id; read `cast call $CASCADE "skillCount()(uint256)" --rpc-url <rpc>` |
| `execution reverted: wrong value` | `--value` ≠ the skill's registered price | Send the exact registered price in wei (no over/underpay) |
| Command missing `--private-key` | Private key not configured | Set `$PRIVATE_KEY` and pass `--private-key $PRIVATE_KEY` |
| `insufficient funds` | Account cannot cover price + gas | Fund the account; check `cast balance <addr> --rpc-url <rpc> --ether` |

> **Agent Guidelines**: Exact payment is mandatory — confirm the skill's registered price
> before sending and pass exactly that wei amount via `--value`. Sending the wrong amount
> burns gas on a guaranteed `wrong value` revert. After a successful invoke, report the
> `Invoked` tx link and note that royalties have accrued to each creator in the tree (they
> withdraw via `claim()`). Always complete the Write Operation Pre-checks in `SKILL.md`
> before broadcasting, and re-confirm with the user on mainnet.
