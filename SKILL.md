---
name: cascade
description: >
  Cascade is the Pharos recursive skill-royalty registry + payment router. Use this skill
  whenever the user mentions "pharos royalties", "skill registry", "recursive royalty",
  "register a skill", "invoke" or "pay a skill", "claim royalties", or wants to "split a
  payment up a dependency tree" on Pharos. It exposes three on-chain actions against the
  live Cascade contract — register an immutable priced skill with declared dependency
  shares, invoke (pay) a skill so its payment fans up the whole dependency tree crediting
  every creator, and claim accrued royalties (pull-payment). Requires the `cast` and
  `forge` (Foundry) CLIs and targets Pharos atlantic-testnet (default) or mainnet. Do not
  attempt Cascade on-chain operations without this skill — you will use the wrong network
  config or the wrong contract address.
version: 0.1.0
requires:
  anyBins:
  - cast
  - forge
---

# Cascade — Recursive Skill Royalties on Pharos

Cascade is a registry + router for composable, priced "skills". Each skill is registered
once (immutable) with a native-token price and a declared list of dependency skills plus
the basis-point share routed into each dependency's subtree. A single `invoke` payment
fans up the entire declared tree, crediting each creator's internal balance. Creators
withdraw via `claim()` (pull-payment). The contract is account-agnostic: an EOA and a
smart account hit the identical code path.

Three actions, driven through Foundry (`cast` / `forge`):

- **register** — create a priced skill with optional dependency shares.
- **invoke** — pay a skill's exact price; royalties fan up its dependency tree in one tx.
- **claim** — withdraw your accrued royalty balance.

## Prerequisites

1. **Install Foundry** (MANDATORY — MUST be done before ANY other action):
   - The Agent MUST first run `which cast` to check if Foundry is installed.
   - If `cast` is NOT found, the Agent MUST immediately run the following installation
     commands. **Do NOT skip installation. Do NOT fall back to curl/JSON-RPC as a
     workaround. Do NOT proceed with any other task until Foundry is installed.**
     ```bash
     curl -L https://foundry.paradigm.xyz | bash
     ```
     Then run:
     ```bash
     source ~/.zshenv && foundryup
     ```
     Then verify with:
     ```bash
     cast --version
     ```
   - If installation fails, inform the user and STOP. Do not attempt alternative approaches.
2. **Configure Private Key**: Write operations (`register`, `invoke`, `claim`) require a
   private key, provided via one of the following:
   - Command argument: `--private-key <your_private_key>`
   - Environment variable: `$PRIVATE_KEY` (then pass `--private-key $PRIVATE_KEY`)

   Read-only queries (`balances`, `skillCount`) need no key.

## Network Configuration

Network information is stored in `assets/networks.json`, containing both the Atlantic
testnet and mainnet chains. Never invent RPC URLs, chain IDs, or explorer URLs — always
read them from this file.

- **Default Network**: Atlantic testnet (`atlantic-testnet`, chainId `688689`). Used when
  the user does not specify a network.
- **Switching Networks**: When the user specifies `mainnet` (chainId `1672`), read the
  corresponding entry's `rpcUrl` from `assets/networks.json`.
- **Usage**: Read `assets/networks.json` and fill the target network's `rpcUrl` into each
  command's `--rpc-url` parameter.

```bash
# Example: reading network configuration
RPC_URL=$(jq -r '.networks[] | select(.name=="atlantic-testnet") | .rpcUrl' assets/networks.json)
EXPLORER_URL=$(jq -r '.networks[] | select(.name=="atlantic-testnet") | .explorerUrl' assets/networks.json)
```

The Foundry config (`foundry.toml`) also defines `--rpc-url` aliases that resolve to the
same endpoints: `atlantic_testnet` and `mainnet`. Either the alias or the literal
`rpcUrl` from `assets/networks.json` works.

### Live Deployed Contract

A live Cascade instance is already deployed on **atlantic-testnet** — interact with it
immediately, no deployment needed:

```
CASCADE = 0xd41C32562D0BE20D354120E1De11A91abC340F50   (atlantic-testnet, chainId 688689)
```

Export it once and reuse across all commands:

```bash
export CASCADE=0xd41C32562D0BE20D354120E1De11A91abC340F50
```

View it on the explorer: `<explorerUrl>/address/0xd41C32562D0BE20D354120E1De11A91abC340F50`
(read `explorerUrl` from `assets/networks.json`).

## Capability Index

Load the corresponding reference file based on user needs to get full command templates
(both `forge script` and raw `cast` forms), parameter tables, output parsing, and
per-operation error handling.

| User Need | Capability | Detailed Instructions |
|-----------|------------|----------------------|
| Register a new priced skill (with optional dependency shares) | `register(uint256,uint256[],uint256[])` via `forge script` / `cast send` | → `references/register.md#register-a-skill` |
| Invoke / pay a skill (fan royalties up its dependency tree) | `invoke(uint256)` payable via `forge script` / `cast send` | → `references/invoke.md#invoke-a-skill` |
| Claim accrued royalties (withdraw your balance) | `claim()` via `forge script` / `cast send` | → `references/claim.md#claim-royalties` |
| Read accrued claimable balance for an address | `balances(address)` via `cast call` | → `references/claim.md#read-accrued-balance` |
| Read number of registered skills (highest valid id) | `skillCount()` via `cast call` | → `references/claim.md#read-skill-count` |

## General Error Handling

Before executing commands, the Agent should perform the Write Operation Pre-checks below;
when commands fail, surface a user-friendly message based on the revert string in stderr.
Cascade's exact revert strings:

| Error Scenario | CLI Error Signature | Handling |
|---------------|--------------------|----------|
| `register`: dep ids / shares array length differ | `execution reverted: len mismatch` | DEP_IDS and DEP_SHARES must be the same length, 1:1 aligned |
| `register`: a dependency id is 0 or ≥ the new id | `execution reverted: bad dep id` | Each dep id must be a strictly-smaller, already-registered id (register bottom-up; id 0 is invalid) |
| `register`: dependency shares exceed 100% | `execution reverted: shares > 10000` | Σ(depShares) must be ≤ 10000 bps (the remainder is the registering creator's own cut) |
| `register`: tree too deep | `execution reverted: depth > 8` | Dependency tree depth is capped at 8; flatten the tree |
| `invoke`: skill id does not exist | `execution reverted: no skill` | skillId must be in `1..skillCount()`; check `skillCount()` |
| `invoke`: wrong payment amount | `execution reverted: wrong value` | `--value` MUST equal the skill's registered price exactly (no over/underpay) |
| Private key not configured | Command missing `--private-key` / `PRIVATE_KEY` unset | Prompt user to set `$PRIVATE_KEY` and pass `--private-key $PRIVATE_KEY` |
| Insufficient balance | `insufficient funds` | Prompt insufficient balance; show current balance via `cast balance` |
| Missing network config | `assets/networks.json` unreadable | Prompt that the config file is missing or malformed |
| Unsupported network | Network name not in config list | Only `atlantic-testnet` and `mainnet` are supported |

See each reference file for the full per-operation error table.

## Security Reminders

- **Private Key Protection**: Never expose private keys in logs, chat history, or version
  control. Store the key in the `$PRIVATE_KEY` environment variable and reference it
  explicitly via `--private-key $PRIVATE_KEY`. Note: `forge` / `cast` do not automatically
  read environment variables for signing — the key must be passed as a command argument.
- **Exact-Payment Warning**: `invoke` reverts unless `msg.value == skill price`. Always
  read the registered price first and send exactly that amount via `--value`. Over- or
  under-paying wastes gas on a guaranteed revert.
- **Immutability**: A registered skill (price + dependency shares) can never be changed.
  Double-check `price`, `DEP_IDS`, and `DEP_SHARES` before registering.
- **Network Confirmation**: Before any write operation, clearly inform the user of the
  target network. Mainnet operations require a prominent warning and user re-confirmation
  to prevent accidental spends.

## Write Operation Pre-checks (Required for All Write Operations)

For all operations requiring a private key (`register`, `invoke`, `claim`), the Agent must
complete the following before execution:

### 1. Private Key Check

```bash
# Check if the environment variable exists (without outputting the private key)
[ -n "$PRIVATE_KEY" ] && echo "PRIVATE_KEY is set" || echo "PRIVATE_KEY is not set"
```

- If **not set**: Prompt the user to configure via `export PRIVATE_KEY=<your_private_key>`,
  do not proceed.
- If **set**: Continue.

### 2. Derive Public Address and Confirm with User

```bash
cast wallet address --private-key $PRIVATE_KEY
```

### 3. Network Confirmation (Must Clearly Inform User)

Read the target network from `assets/networks.json` and display the network name + type.

- If the user did not specify a network, use `atlantic-testnet` and clearly inform the
  user: **Current operation targets the Atlantic testnet**.
- If the user specified `mainnet`, prominently warn: **Current operation targets mainnet,
  please confirm to proceed**.

Example confirmation:

```
Detected private key address: 0x1234...abcd
Target network: Atlantic Testnet (atlantic-testnet)
Contract: Cascade @ 0xd41C32562D0BE20D354120E1De11A91abC340F50
Proceed with this account on this network?
```

### 4. Automatic Balance Check

After confirming account + network, query the balance so the user knows they can cover
price + gas:

```bash
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url <rpc> --ether
```

Use the network's `nativeToken` (`PHRS` on atlantic-testnet, `PROS` on mainnet) when
displaying balances instead of the generic "ether".
