# Cascade — Recursive Skill Royalties on Pharos

**npm, but every package earns a cut every time it's used downstream — automatically, instantly, recursively.**

Cascade is an on-chain registry + payment router for composable, priced "skills". A skill
is registered once with a price and a list of dependency skills (each with a basis-point
share). A single `invoke` payment then fans **up the entire dependency tree** in one
transaction, crediting every creator's balance proportional to their place in the
composition. Creators withdraw with `claim()` (pull-payment). Live and source-verified on
Pharos mainnet.

## The killer idea

Software is composed. A skill builds on another skill, which builds on another. Today the
authors below you in that tree earn nothing when your work gets used. Cascade fixes that:

- **One `invoke` pays the whole tree.** Pay skill C, and the payment routes a declared
  share into C's dependencies (B), then B's dependencies (A), recursively — every creator
  up the chain is credited in the **same transaction**.
- **Proportional to depth.** Each level keeps its own cut and forwards the declared
  basis-point share into the subtree below it. Conservation holds exactly — every wei of
  the payment is assigned across the tree, no dust, no leak.
- **Trustless and immutable.** A registered skill's price and dependency shares can never
  be changed. No intermediary holds the money; the contract routes it.
- **Pull-payment.** `invoke` only credits internal balances; creators withdraw on their
  own schedule via `claim()`. A single griefing payee can't block the fan-out for everyone.
- **Account-agnostic.** An EOA and an ERC-4337 smart account hit the identical code path.

A live mainnet example: one `invoke` of an A→B→C tree (priced at 0.001 PROS) paid three
distinct creators in a single transaction — A `0.0002`, B `0.0003`, C `0.0005`, summing
exactly to `0.001` PROS. See [Live on Pharos mainnet](#live-on-pharos-mainnet) below.

## Architecture

| Layer | What it is | Where |
|-------|-----------|-------|
| **Recursive royalty router** | `Cascade.sol` — the registry + payment router. `register` / `invoke` / `claim`, with a bounded recursive `_distribute` fan-out (depth cap 8), pull-payment accounting, and a conservation invariant. | [`src/Cascade.sol`](src/Cascade.sol) |
| **ERC-4337 AA layer** | A minimal v0.7 single-owner smart account (`CascadeAccount`) + a CREATE2 `AccountFactory`. One self-bundled `handleOps` can batch multiple `invoke` calls through the real EntryPoint v0.7 — no external bundler. | [`src/aa/`](src/aa/) |
| **Anthropic Agent Skill packaging** | `SKILL.md` + `references/` + `assets/networks.json` — packages Cascade as a callable Agent Skill so an AI agent can register, invoke, and claim against the live contract with the correct network config. | [`SKILL.md`](SKILL.md) |

## Quickstart

```bash
# 1. Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Run the test suite — 41 tests pass (unit + fuzz + stateful invariant + fork)
forge test

# 3. Configure your signing key for write operations
cp .env.example .env
#   then edit .env and set PRIVATE_KEY=0x...

# 4. See the visualization — open the WOW demo in a browser
open web/index.html        # or: python3 -m http.server -d web 8000
```

To run the three on-chain actions (**register** a skill, **invoke** / pay a skill, **claim**
your royalties), follow the per-action command templates in
[`references/`](references/) — [`register.md`](references/register.md),
[`invoke.md`](references/invoke.md), [`claim.md`](references/claim.md). Each shows both the
`forge script` and raw `cast` forms with the parameter tables and error handling.

Networks are read from [`assets/networks.json`](assets/networks.json): **atlantic-testnet
is the default** (chainId `688689`, native token `PHRS`); **mainnet** is supported
(chainId `1672`, native token `PROS`). Never invent RPC/explorer URLs — read them from that
file. Mainnet writes spend real value: confirm the network before any write.

## Live on Pharos mainnet

Everything below is **live and source-verified on Pharos mainnet** (chainId `1672`, native
token `PROS`, explorer https://www.pharosscan.xyz/). The full deployment log — every tx
hash, gas figure, balance delta, and decoded event — is in
[`MAINNET_RESULT.md`](MAINNET_RESULT.md).

| What | Address / tx | Explorer |
|------|--------------|----------|
| **Cascade** (source-verified) | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` | [view](https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84) |
| **Royalty demo** — one `invoke` paid 3 creators, Σ `0.001` PROS | `0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564` | [view tx](https://www.pharosscan.xyz/tx/0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564) |
| **4337 batch** — one UserOp batched 2 `invoke`s via the real EntryPoint v0.7 | `0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90` | [view tx](https://www.pharosscan.xyz/tx/0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90) |
| EntryPoint v0.7 (canonical) | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | [view](https://www.pharosscan.xyz/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032) |
| AccountFactory | `0x904935BA1417FC35591019A0fC54c670DA824c60` | [view](https://www.pharosscan.xyz/address/0x904935BA1417FC35591019A0fC54c670DA824c60) |
| CascadeAccount (smart account) | `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1` | [view](https://www.pharosscan.xyz/address/0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1) |

**Earlier proof — testnet history (Phase 1):** Cascade also ran live on Pharos
atlantic-testnet (chainId `688689`) at `0xd41C32562D0BE20D354120E1De11A91abC340F50` — the
earlier on-chain proof before the mainnet deployment above.

The web visualization at [`web/index.html`](web/index.html) renders this **real mainnet
data** (a committed snapshot of the actual events, with the live tx hashes shown and
linked) so you can watch one payment fan up the tree and see all three creator balances
tick up.

## Hackathon

Built for the **Skill-to-Agent Dual Cascade Hackathon (Pharos)** — **Skill Hackathon
track** (20,000 PROS, 40 winners). Cascade is packaged as an Anthropic Agent Skill
([`SKILL.md`](SKILL.md)) so an AI agent can drive the three on-chain actions against the
live, source-verified mainnet contract. Submission steps and the DoraHacks form fields are
prepared in [`SUBMISSION.md`](SUBMISSION.md).

## Honest scope

Cascade is **live + source-verified on Pharos mainnet**, **fuzz- and invariant-tested**
(41 tests pass, including a stateful conservation invariant), and **slither-clean**
(0 CRITICAL / 0 HIGH). It is **NOT** an independent professional security audit. An
independent audit is the one remaining step before these contracts should custody material
user value — see the full caveat and the per-finding review in [`SECURITY.md`](SECURITY.md).
Every number and address in this README comes from the on-chain record in
[`MAINNET_RESULT.md`](MAINNET_RESULT.md); nothing here is invented.

## Docs

- [`SKILL.md`](SKILL.md) — the Anthropic Agent Skill: capability index, network config, pre-checks.
- [`references/`](references/) — full command templates for [register](references/register.md), [invoke](references/invoke.md), [claim](references/claim.md).
- [`SECURITY.md`](SECURITY.md) — security review, methodology, findings, and the honest audit caveat.
- [`MAINNET_RESULT.md`](MAINNET_RESULT.md) — the single source of truth for all mainnet artifacts.
- [`web/index.html`](web/index.html) — the WOW visualization of the recursive royalty fan-out, driven by real mainnet data.
- [`SUBMISSION.md`](SUBMISSION.md) — the DoraHacks submission checklist with pre-filled form fields.
