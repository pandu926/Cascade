# Claim Operation Instructions

Detailed instructions for claiming accrued royalties and reading registry state on the
live Cascade contract.

> **Network Configuration**: The `<rpc>` parameter in all commands is read from the target
> network's `rpcUrl` field in `assets/networks.json` (or the equivalent `foundry.toml` alias
> `atlantic_testnet` / `mainnet`). Defaults to the Atlantic testnet.
>
> **Live Contract**: `CASCADE = 0xd41C32562D0BE20D354120E1De11A91abC340F50` on
> atlantic-testnet (chainId 688689). Export it: `export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50`.
>
> **Private Key**: `claim` is a write operation — complete the Write Operation Pre-checks in
> `SKILL.md` first. Read-only getters (`balances`, `skillCount`) need no key.

---

## Claim Royalties

Cascade uses a **pull-payment** model: an `invoke` credits each creator's internal
`balances[creator]` but never pushes funds. Each creator withdraws their own accrued
balance via `claim()`. The contract zeroes the balance **before** transferring
(checks-effects-interactions), so a re-entering or repeated claim sees a zero balance and
simply transfers `0` — **a double-claim pays zero and does NOT revert.**

Solidity signature:

```solidity
claim() returns (uint256 amount)
```

The caller (`msg.sender` = the `PRIVATE_KEY` signer) withdraws whatever has accrued to
their address. `amount` is the wei transferred (`0` if nothing was accrued).

**Command Template (forge script)**

The `script/Claim.s.sol` script reads `CASCADE` from the environment, logs the accrued
balance, then claims:

```bash
export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50

forge script script/Claim.s.sol \
  --rpc-url atlantic_testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Command Template (raw cast send)**

```bash
cast send $CASCADE \
  "claim()" \
  --private-key $PRIVATE_KEY \
  --rpc-url <rpc>
```

Concrete example:

```bash
cast send $CASCADE "claim()" \
  --private-key $PRIVATE_KEY --rpc-url https://atlantic.dplabs-internal.com
```

**Parameters**

| Parameter | Env Var | Type | Required | Description |
|-----------|---------|------|----------|-------------|
| (none) | — | — | — | `claim()` takes no arguments; it withdraws to `msg.sender` |
| `<rpc>` | — | string | Yes | RPC URL from `assets/networks.json` (or alias `atlantic_testnet`) |
| `$PRIVATE_KEY` | `PRIVATE_KEY` | string | Yes | Claimant key; pass via `--private-key $PRIVATE_KEY` |

**Output Parsing**

- Emits `Claimed(address indexed creator, uint256 amount)` **only when `amount != 0`**.
- The forge script logs `Accrued before claim (wei): <n>` then `Claimed (wei): <amount>`.
- A claim with nothing accrued succeeds, transfers `0`, and emits no `Claimed` event.
- Always check the accrued balance first (below) so you know whether a claim is worthwhile.
- Confirm on the explorer: `<explorerUrl>/tx/<tx_hash>` (read `explorerUrl` from `assets/networks.json`).

**Error Handling**

| Error Signature | Cause | Suggested Action |
|----------------|-------|-----------------|
| Claimed amount is `0` (no revert) | Nothing accrued to this address, or already claimed | Not an error — pull-payment double-claim pays zero; check `balances(<addr>)` first |
| `execution reverted: transfer failed` | Native transfer to the claimant failed | Rare; ensure the claimant can receive native value (relevant for contract claimants) |
| Command missing `--private-key` | Private key not configured | Set `$PRIVATE_KEY` and pass `--private-key $PRIVATE_KEY` |
| `insufficient funds` | Account cannot cover gas | Fund the account; check `cast balance <addr> --rpc-url <rpc> --ether` |

> **Agent Guidelines**: Always read `balances(<claimant>)` (below) before claiming — if it
> is `0`, tell the user there is nothing to withdraw rather than burning gas. Complete the
> Write Operation Pre-checks in `SKILL.md` first. After a successful claim, report the
> withdrawn amount (using the network's `nativeToken` symbol, `PHRS`/`PROS`) and the explorer
> tx link.

---

## Read Accrued Balance

Read a creator's claimable (accrued, not-yet-withdrawn) balance. Read-only, no key needed.

Solidity getter:

```solidity
balances(address) returns (uint256)
```

**Command Template (raw cast call)**

```bash
cast call $CASCADE "balances(address)(uint256)" <address> --rpc-url <rpc>
```

Concrete example:

```bash
cast call $CASCADE "balances(address)(uint256)" 0x1234...abcd \
  --rpc-url https://atlantic.dplabs-internal.com
```

**Parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `<address>` | string | Yes | Creator address to query (`0x` + 40 hex) |
| `<rpc>` | string | Yes | RPC URL from `assets/networks.json` |

**Output Parsing**

- Returns the claimable balance in **wei**. Convert to the native unit for display and use
  the network's `nativeToken` symbol (`PHRS` on atlantic-testnet, `PROS` on mainnet).
- A non-zero value means `claim()` will transfer that amount.

**Error Handling**

| Error Signature | Cause | Suggested Action |
|----------------|-------|-----------------|
| `invalid address` | Malformed address | Check format (`0x` + 40 hex characters) |
| Empty return value | Wrong contract address / no code | Confirm `CASCADE` = `0xd41C32562D0BE20D354120E1De11A91abC340F50` on the right network |

---

## Read Skill Count

Read the number of registered skills (also the highest valid skill id). Read-only.

Solidity getter:

```solidity
skillCount() returns (uint256)
```

**Command Template (raw cast call)**

```bash
cast call $CASCADE "skillCount()(uint256)" --rpc-url <rpc>
```

Concrete example:

```bash
cast call $CASCADE "skillCount()(uint256)" \
  --rpc-url https://atlantic.dplabs-internal.com
```

**Parameters**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `<rpc>` | string | Yes | RPC URL from `assets/networks.json` |

**Output Parsing**

- Returns a uint256: the total skills registered and the highest valid id. Valid skill ids
  are `1..skillCount()` (id `0` is reserved/invalid).
- Use this to validate a `skillId` before `invoke` (see `references/invoke.md`).

**Error Handling**

| Error Signature | Cause | Suggested Action |
|----------------|-------|-----------------|
| Empty return value | Wrong contract address / no code | Confirm `CASCADE` = `0xd41C32562D0BE20D354120E1De11A91abC340F50` on the right network |

> **Agent Guidelines**: Use `skillCount()` to bound valid skill ids before invoking, and
> `balances(address)` to decide whether a `claim()` is worthwhile. Both are read-only and
> need no private key. Always state which network the results came from.
