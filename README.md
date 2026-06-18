# Cascade

**The economic layer for composable AI skills on Pharos.**

One invoke — every creator in the dependency chain gets paid. Automatically. Recursively. In one transaction.

---

## Vision

AI agents compose skills to get things done. A translation skill is used by a summarizer, which is used by a research agent. The deeper the composition, the more powerful the system.

But today, there's no mechanism to reward the full stack. Only the top skill gets paid. The foundations — the skills that make everything else possible — earn nothing.

**Without economic incentives, nobody builds reusable skills.** Developers build monoliths instead. The ecosystem can't scale through composition.

Cascade solves this. Every skill you build becomes a permanent revenue source — as long as someone, somewhere, uses something built on top of yours.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   User pays 0.005 PROS to use Carol's Agent                    │
│                         │                                       │
│                         ▼                                       │
│              ┌─────────────────────┐                            │
│              │  SKILL C (Carol)    │  keeps 50% = 0.0025 PROS   │
│              │  price: 0.005 PROS  │                            │
│              │  dep: B (50%)       │                            │
│              └──────────┬──────────┘                            │
│                         │ 50% flows down                        │
│                         ▼                                       │
│              ┌─────────────────────┐                            │
│              │  SKILL B (Bob)      │  keeps 60% = 0.0015 PROS   │
│              │  dep: A (40%)       │                            │
│              └──────────┬──────────┘                            │
│                         │ 40% flows down                        │
│                         ▼                                       │
│              ┌─────────────────────┐                            │
│              │  SKILL A (Alice)    │  receives 0.0010 PROS      │
│              │  leaf (no deps)     │                            │
│              └─────────────────────┘                            │
│                                                                 │
│   Total: 0.0025 + 0.0015 + 0.0010 = 0.005 PROS ✓              │
│   Conservation: every wei accounted for. Zero leakage.          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**One transaction. Three creators paid. No middleman.**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cascade                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                   │
│  │  Layer 1: Recursive Royalty Router        │                   │
│  │  src/Cascade.sol                          │                   │
│  │                                           │                   │
│  │  • register(price, deps[], shares[])      │                   │
│  │  • invoke(skillId) payable                │                   │
│  │  • claim()                                │                   │
│  │  • Recursive _distribute (depth cap 8)    │                   │
│  │  • Pull-payment (reentrancy-safe)         │                   │
│  │  • Conservation invariant (Σ = price)     │                   │
│  └──────────────────────────────────────────┘                   │
│                                                                 │
│  ┌──────────────────────────────────────────┐                   │
│  │  Layer 2: ERC-4337 Account Abstraction    │                   │
│  │  src/aa/                                  │                   │
│  │                                           │                   │
│  │  • CascadeAccount (minimal smart account) │                   │
│  │  • AccountFactory (CREATE2)               │                   │
│  │  • Self-bundled via EntryPoint v0.7       │                   │
│  │  • Batch multiple invokes in 1 UserOp     │                   │
│  └──────────────────────────────────────────┘                   │
│                                                                 │
│  ┌──────────────────────────────────────────┐                   │
│  │  Layer 3: Agent Skill Interface           │                   │
│  │  SKILL.md + references/ + assets/         │                   │
│  │                                           │                   │
│  │  • Anthropic Agent Skills format          │                   │
│  │  • Natural language → on-chain actions    │                   │
│  │  • Works with Claude Code, Codex, etc.    │                   │
│  └──────────────────────────────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) v18+ (for SDK)
- [Foundry](https://getfoundry.sh/) (forge, cast) — only needed for contract development
- A Pharos wallet with PROS (for mainnet) or PHRS (for testnet)

### Setup

```bash
# Clone the repository
git clone https://github.com/pandu926/Cascade.git
cd Cascade

# Install SDK dependencies
npm install

# (Optional) Install Foundry deps for contract development
forge install

# Verify contracts — 41 tests should pass
forge test
```

### Configure wallet

```bash
cp .env.example .env
# Edit .env and set your private key:
# CASCADE_PRIVATE_KEY=0x...
```

Or pass directly via CLI:

```bash
export CASCADE_PRIVATE_KEY=0x...
export CASCADE_NETWORK=mainnet
```

### Network configuration

Networks are defined in [`assets/networks.json`](assets/networks.json):

| Network | Chain ID | RPC | Token | Explorer |
|---------|----------|-----|-------|----------|
| Atlantic Testnet (default) | 688689 | https://atlantic.dplabs-internal.com | PHRS | https://atlantic.pharosscan.xyz |
| Mainnet | 1672 | https://rpc.pharos.xyz | PROS | https://www.pharosscan.xyz |

---

## Usage

### SDK (Recommended)

The SDK provides a simple JavaScript/Node.js interface. No need to construct raw transactions.

```bash
# Register a leaf skill (free, no dependencies)
node sdk/cli.js register --network mainnet

# Register with price and dependencies
node sdk/cli.js register --price 0.005 --deps 7 --shares 4000 --network mainnet

# Invoke (pay for) a skill — price is auto-read from chain
node sdk/cli.js invoke --skill 9 --network mainnet

# Check accrued royalties
node sdk/cli.js balance 0xYourAddress --network mainnet

# Withdraw royalties
node sdk/cli.js claim --network mainnet

# View contract info
node sdk/cli.js skill-info --network mainnet
```

#### Use as a library

```javascript
import { createCascade } from "./sdk/index.js";

const cascade = createCascade({
  privateKey: process.env.CASCADE_PRIVATE_KEY,
  network: "mainnet"  // or "testnet"
});

// Register a skill with 0.005 PROS price, depending on skill 7 (40% share)
const { skillId, hash } = await cascade.register({
  price: "0.005",
  depIds: [7],
  depShares: [4000]
});

// Invoke — price is auto-fetched from chain
const result = await cascade.invoke({ skillId: 9 });
console.log(`Paid: ${result.paid} PROS`);

// Check balance
const balance = await cascade.getBalance("0x...");

// Claim all accrued royalties
const claim = await cascade.claim();
```

### Install as an Agent Skill

For AI agents (Claude Code, Codex, Cursor, etc.) — the agent reads `SKILL.md` and
understands how to register, invoke, and claim skills via natural language:

```bash
# Option 1: Clone into your project
git clone https://github.com/pandu926/Cascade.git
cd Cascade && npm install

# Option 2: Copy skill files into your agent's skill directory
cp -r SKILL.md references/ assets/ sdk/ package.json ~/.claude/skills/cascade/
cd ~/.claude/skills/cascade && npm install
```

Then tell your agent:
- "Register a translation skill on Pharos mainnet"
- "Invoke skill 9"
- "Check my Cascade royalty balance"
- "Claim my accrued royalties"

The agent reads `SKILL.md`, understands the context, and executes via the SDK.

### Use via cast (Foundry CLI)

For those who prefer raw contract interaction:

```
Mainnet:  0x31bE4C6B5711913D818e377ebd809d4397FF3c84
Testnet:  0xd41C32562D0BE20D354120E1De11A91abC340F50
```

#### Step 1: Register a skill

```bash
# Register a leaf skill (no dependencies, no price)
cast send 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 \
  "register(uint256,uint256[],uint256[])(uint256)" \
  0 "[]" "[]" \
  --rpc-url https://rpc.pharos.xyz \
  --private-key $PRIVATE_KEY \
  --legacy

# Register a skill with dependencies
# Price: 0.005 PROS, depends on skill id 7, gives 40% to its subtree
cast send 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 \
  "register(uint256,uint256[],uint256[])(uint256)" \
  5000000000000000 "[7]" "[4000]" \
  --rpc-url https://rpc.pharos.xyz \
  --private-key $PRIVATE_KEY \
  --legacy
```

**Parameters:**
- `price` — cost in wei to invoke this skill (0 = free, used as building block only)
- `depIds[]` — array of skill IDs this skill depends on
- `depShares[]` — basis points (0-10000) each dependency gets from the payment

**Rules:**
- Dependencies must already be registered (lower ID)
- Sum of shares ≤ 10000 (remainder is the creator's cut)
- Immutable once registered — no one can change terms later
- Depth cap: 8 levels maximum

#### Step 2: Invoke (pay) a skill

```bash
# Pay to use skill id 9, sending exactly 0.005 PROS
cast send 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 \
  "invoke(uint256)" 9 \
  --value 5000000000000000 \
  --rpc-url https://rpc.pharos.xyz \
  --private-key $PRIVATE_KEY \
  --legacy
```

**What happens:** The payment automatically cascades through the entire dependency tree. Every creator in the chain gets their declared share. One transaction.

#### Step 3: Check balances

```bash
# Check accrued royalties for any address
cast call 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 \
  "balances(address)(uint256)" \
  0xYOUR_ADDRESS \
  --rpc-url https://rpc.pharos.xyz
```

#### Step 4: Claim (withdraw)

```bash
# Withdraw all accrued royalties to your wallet
cast send 0x31bE4C6B5711913D818e377ebd809d4397FF3c84 \
  "claim()(uint256)" \
  --rpc-url https://rpc.pharos.xyz \
  --private-key $PRIVATE_KEY \
  --legacy
```

**Pull-payment:** Your royalties accrue in the contract. You withdraw on your schedule. No one can block your earnings — even if every other creator disappears.

---

## Complete Flow (Example)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Alice registers a translation skill (leaf, no deps)         │
│     → skill id 7                                                │
│                                                                 │
│  2. Bob registers a summarizer (depends on Alice, 40% share)    │
│     → skill id 8                                                │
│                                                                 │
│  3. Carol registers an AI agent (depends on Bob, 50% share)     │
│     price: 0.005 PROS → skill id 9                              │
│                                                                 │
│  4. Someone invokes Carol's agent, pays 0.005 PROS              │
│     → Carol gets 0.0025 (keeps 50%)                             │
│     → Bob gets 0.0015 (60% of the 50% that flowed down)        │
│     → Alice gets 0.0010 (40% of Bob's share)                   │
│     → Total = 0.005 PROS ✓ (exact conservation)                │
│                                                                 │
│  5. Alice calls claim() → 0.0010 PROS transferred to wallet    │
│     Balance after: 0 (all withdrawn)                            │
└─────────────────────────────────────────────────────────────────┘
```

All transactions above are real and verifiable on [pharosscan.xyz](https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84).

---

## Deployed Contracts

| Contract | Address | Network |
|----------|---------|---------|
| **Cascade** (source-verified) | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` | Mainnet |
| **AccountFactory** | `0x904935BA1417FC35591019A0fC54c670DA824c60` | Mainnet |
| **CascadeAccount** | `0xfe93754C8730f13257e9d733dDd7c9037f2e1Ef1` | Mainnet |
| **EntryPoint v0.7** | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | Mainnet |
| **Cascade** (testnet) | `0xd41C32562D0BE20D354120E1De11A91abC340F50` | Testnet |

Full deployment logs: [`MAINNET_RESULT.md`](MAINNET_RESULT.md)

---

## Testing

```bash
# Run all 41 tests
forge test

# Run with gas report
forge test --gas-report

# Run fork tests against real Pharos EntryPoint
forge test --fork-url https://atlantic.dplabs-internal.com
```

**Test coverage:**
- 13 unit tests (register/invoke/claim + revert paths)
- 4 fuzz tests (conservation across random trees)
- 3 stateful invariant tests (solvency, no-wei-created, accrued==paid)
- 4 fork tests (real EntryPoint v0.7, AA24 rejection, account-agnostic parity)
- 16 AA unit tests (account + factory)
- 1 demo fork test

---

## Security

- **NatSpec documentation** on every public function
- **Named custom errors** (7 in Cascade, 3 in CascadeAccount)
- **Slither static analysis** — 0 CRITICAL, 0 HIGH findings
- **Pull-payment** — no reentrancy possible in the invoke path
- **Depth cap 8** — bounds gas for recursive calls
- **Monotonic IDs** — cycles impossible by construction

Full review: [`SECURITY.md`](SECURITY.md)

> **Note:** This is hackathon-grade review-readiness, not an independent professional audit. An independent audit is the remaining step before these contracts should custody material user value.

---

## Project Structure

```
Cascade/
├── sdk/
│   ├── index.js                 # SDK library (createCascade)
│   ├── cli.js                   # CLI interface
│   └── abi.js                   # Contract ABI
├── src/
│   ├── Cascade.sol              # Core: recursive royalty router
│   └── aa/
│       ├── CascadeAccount.sol   # ERC-4337 smart account
│       ├── AccountFactory.sol   # CREATE2 factory
│       ├── IEntryPoint.sol      # v0.7 interface
│       ├── IAccount.sol         # Account interface
│       └── PackedUserOperation.sol
├── test/
│   ├── Cascade.t.sol            # Unit tests
│   ├── Cascade.fuzz.t.sol       # Fuzz tests
│   ├── Cascade.invariant.t.sol  # Stateful invariants
│   ├── SmartAccount.fork.t.sol  # Fork tests (real EntryPoint)
│   ├── SmartAccountUnit.t.sol   # AA unit tests
│   ├── Demo.fork.t.sol          # Demo flow test
│   └── handlers/
│       └── CascadeHandler.sol   # Invariant handler
├── script/
│   ├── Deploy.s.sol             # Deploy Cascade
│   ├── Register.s.sol           # Register a skill
│   ├── Invoke.s.sol             # Invoke a skill
│   ├── Claim.s.sol              # Claim royalties
│   └── DemoTree.s.sol           # Full A→B→C demo
├── SKILL.md                     # Agent Skill interface
├── references/
│   ├── register.md              # Register command templates
│   ├── invoke.md                # Invoke command templates
│   └── claim.md                 # Claim command templates
├── assets/
│   └── networks.json            # Network configuration
├── package.json                 # SDK dependencies
├── web/                         # Visualization (real mainnet data)
├── SECURITY.md                  # Security review
├── MAINNET_RESULT.md            # On-chain deployment proof
└── foundry.toml                 # Build configuration
```

---

## License

MIT-0 — free to use, modify, and redistribute. No attribution required.
