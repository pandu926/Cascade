# Phase 3: Smart-Account Agents (ERC-4337) - Research

**Researched:** 2026-06-07
**Domain:** ERC-4337 v0.7 account abstraction — minimal smart account + factory, PackedUserOperation construction/signing, self-bundled `handleOps`, Foundry fork testing
**Confidence:** HIGH (interface layouts, packing, hashing, prefund, factory, handleOps all verified against eth-infinitism `v0.7.0` source and live testnet); MEDIUM on exact gas numbers

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Self-bundle, no external bundler:** an EOA calls `EntryPoint.handleOps([userOp], beneficiary)` directly. No public bundler exists on Pharos (verified).
- **Real EntryPoint v0.7:** `0x0000000071727De22E5E9d8BAf0edAc6f37da032` — VERIFIED deployed on atlantic-testnet. Use the v0.7 `PackedUserOperation` struct (packed `accountGasLimits`, `gasFees`; `initCode` = factory address ++ factory calldata; `paymasterAndData` empty).
- **Minimal custom smart account** (NOT a vendored SimpleAccount): tight account with `validateUserOp` (owner ECDSA check + pay prefund) + `execute(address,uint256,bytes)` + `executeBatch(...)` so one UserOp makes MULTIPLE `Cascade.invoke{value}()` calls. Plus a minimal `AccountFactory` with `createAccount(owner, salt)` (CREATE2, deterministic address).
- **Batch demo:** UserOp callData = `account.executeBatch([cascade, cascade], [v1, v2], [invoke(skillId1), invoke(skillId2)])`.
- **Account-agnostic proof:** Cascade.sol is UNCHANGED. A test asserts the smart-account invoke path credits creators identically to the EOA path.
- **Local-first / funding isolation:** ALL of it built+tested LOCALLY with ZERO funds via `forge test`, either against a forge-deployed EntryPoint copy OR a `--fork-url` of atlantic-testnet using the real deployed EntryPoint. Only a FINAL, gated live step spends PHRS.
- **Live step reuses the 3 existing live skills** (skillCount()==3 on `0xd41C…0F50`) — no re-registration. Live step = deploy factory + deploy account (via factory) + fund account minimally + ONE handleOps batching 2 invokes.
- **Funded step MUST use lowest accepted gas price + a pre-flight gate that STOPS cleanly** (reporting a top-up need on `0x67680b09bB422cC510669bd5208D947066D4aeaE`) rather than half-spending. If live is blocked, local fork proof is the deliverable and Phase 4 proceeds.

### Claude's Discretion
- Exact account/factory Solidity (kept minimal + gas-lean), how UserOp is constructed in forge script/test (cast or solidity helper), signature scheme details — implementer's choice guided by canonical v0.7 patterns from this research.

### Deferred Ideas (OUT OF SCOPE)
- Gasless / paymaster (sponsored UserOps) — v2 (GAS-01).
- Running a production bundler — self-bundle via `handleOps`.
- Web visualization, README, demo video, submission — Phase 4.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AA-01 | An agent can be a deployed smart account (via a simple factory) | §4 AccountFactory CREATE2 pattern, §2 minimal account |
| AA-02 | Invoke expressed as a UserOperation batching multiple skill payments into one op | §2 `executeBatch`, §5 callData encoding for 2× `invoke` |
| AA-03 | UserOps settle through the real Pharos EntryPoint (v0.7), self-bundled via `handleOps()` from an EOA | §1/§3/§5 packing+hashing+signing, §6 fork test pattern, §5 handleOps flow + revert table |
</phase_requirements>

## Summary

ERC-4337 v0.7 (the version live on Pharos) replaced the v0.6 `UserOperation` with the gas-packed `PackedUserOperation`: `verificationGasLimit`/`callGasLimit` are packed into one `bytes32 accountGasLimits`, and `maxPriorityFeePerGas`/`maxFeePerGas` into one `bytes32 gasFees` — high 128 bits first, low 128 bits second, in both cases. Getting this packing or the userOpHash domain wrong is the single biggest way to burn the tight gas budget on a reverting `handleOps`, so this research pins down the exact bit layout, the exact `keccak256(abi.encode(hash(userOp), entryPoint, chainId))` hashing, the canonical `validateUserOp`/prefund/`executeBatch` bodies, and the CREATE2 factory + `initCode` format — all verified line-for-line against the eth-infinitism `v0.7.0` tag.

The leanest correct path is to **hand-write minimal interfaces** (`PackedUserOperation` struct, `IEntryPoint` with just `handleOps`/`getUserOpHash`/`depositTo`/`balanceOf`/`getNonce`, `IAccount`) and a **non-proxy, directly-deployed account** (skip ERC1967Proxy/UUPS that SimpleAccount uses — it adds deploy gas and an OZ dependency for no benefit here). Build, sign, and self-bundle entirely inside a Foundry **fork test** (`--fork-url atlantic_testnet`) so the REAL deployed EntryPoint validates the op — this is the most faithful proof and needs zero funds because `vm.deal` funds the account and beneficiary on the fork.

**The headline risk is real and confirmed:** the testnet node currently reports a **gas price of 10 gwei**. At 10 gwei, ~0.0043 PHRS buys only ~430k gas total — less than a single account deployment. The live funded step will almost certainly NOT fit at the current network gas price. The local fork proof must be treated as the primary deliverable; the live step must be gated (pre-flight estimate × gas price vs. balance) and stop cleanly if it doesn't fit.

**Primary recommendation:** Hand-write minimal v0.7 interfaces + a proxy-free ECDSA account + CREATE2 factory; prove the full self-bundled batch flow in a `--fork-url` Foundry test against the real EntryPoint; gate the live step behind a balance/gas pre-flight check and expect it to be blocked at 10 gwei.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Signature validation (owner ECDSA) | Smart account (`validateUserOp`) | — | EntryPoint delegates validation to the account per ERC-4337 |
| Prefund payment to EntryPoint | Smart account (`_payPrefund`) | EntryPoint deposit | Account must cover `missingAccountFunds` or op reverts AA21 |
| Batch routing of skill payments | Smart account (`executeBatch`) | Cascade | One UserOp → N `invoke{value}` calls; account is `msg.sender`/`msg.value` source |
| UserOp hashing / replay protection | EntryPoint (`getUserOpHash`) | account validation | Hash binds entrypoint addr + chainId; account just verifies sig over it |
| Bundling / op submission | EOA "bundler" (calls `handleOps`) | EntryPoint | No external bundler on Pharos; EOA self-bundles |
| Counterfactual address / deployment | AccountFactory (CREATE2) | EntryPoint (`getSenderAddress`) | Deterministic address; `initCode` triggers deploy on first op |
| Royalty distribution | Cascade (unchanged) | — | Account-agnostic; only reads `msg.sender`/`msg.value` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| eth-infinitism account-abstraction | `v0.7.0` (git tag) | Canonical reference for struct/interface/hash/packing semantics | The v0.7 EntryPoint on Pharos IS this code; matching it is mandatory for correctness |
| forge-std | already in `lib/` | Test/Script base, `vm.sign`, `vm.deal`, `vm.createSelectFork` | Already used by Phase 1 tests/scripts |
| Foundry forge/cast | `1.5.1` (installed, verified) | Build, fork test, sign, broadcast | Project toolchain |
| Solidity | `0.8.24` (foundry.toml) | Contract compilation | Project standard; ≥0.8.23 required by v0.7 libs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (hand-written) minimal interfaces | n/a | `PackedUserOperation`, `IEntryPoint`, `IAccount` | RECOMMENDED — leanest correct path; see §7 |
| OpenZeppelin `ECDSA`/`MessageHashUtils` | optional | Signature recovery + eth-signed-message prefix | Only if you don't want to inline ~15 lines of ecrecover; see §2 for inline alternative |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-written interfaces | `forge install eth-infinitism/account-abstraction@v0.7.0` | Pulls full dep tree (OZ, sample paymasters); heavier; remapping setup. Only the struct + 3 interfaces are actually needed. |
| Proxy-free direct-deploy account | Vendored `SimpleAccount` (ERC1967Proxy + UUPS + initialize) | Proxy adds deploy gas + OZ proxy dep; CONTEXT explicitly says NOT a vendored SimpleAccount and gas-lean. |
| Fork test (real EntryPoint) | Deploy a local EntryPoint copy | Local copy needs the full eth-infinitism dep tree compiled; fork uses the real bytecode (more faithful) and avoids that. See §6. |
| Inline ecrecover | OZ `ECDSA.recover` | OZ is safer (malleability checks) but adds a dep; inline is fine for a single-owner demo if you guard `s`/`v`. |

**Installation (recommended — no external packages):**
```bash
# No forge install needed. Hand-write src/aa/PackedUserOperation.sol, IEntryPoint.sol, IAccount.sol.
# If choosing the dependency route instead:
# forge install eth-infinitism/account-abstraction@v0.7.0
# then remappings: account-abstraction/=lib/account-abstraction/contracts/
```

**Version verification:** EntryPoint at `0x0000000071727De22E5E9d8BAf0edAc6f37da032` confirmed live on atlantic-testnet (chainId `688689`) with **16,035 bytes** of runtime bytecode `[VERIFIED: cast code]` (note: the orchestrator's "32KB" figure counts hex characters; 16KB is the byte count — same canonical EntryPoint). Cascade at `0xd41C32562D0BE20D354120E1De11A91abC340F50` returns `skillCount()==3` `[VERIFIED: cast call]`. forge/cast `1.5.1` `[VERIFIED: forge --version]`.

## Package Legitimacy Audit

> This phase installs **no external packages** under the recommended hand-written-interfaces path. The only code added is first-party Solidity (account, factory, interfaces) plus the already-present `forge-std`.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| eth-infinitism/account-abstraction `v0.7.0` | GitHub (git submodule, optional) | est. ~2 yrs | n/a (git) | github.com/eth-infinitism/account-abstraction | n/a (not a registry pkg) | Reference only — recommend NOT installing; hand-write interfaces |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*No registry package install is recommended. If the planner chooses the `forge install` route instead, it pulls the canonical eth-infinitism repo at the pinned `v0.7.0` tag (well-known, the reference implementation) plus its OpenZeppelin submodule — both reputable. No slopcheck applies to git submodules.*

## Architecture Patterns

### System Architecture Diagram

```
                          ┌─────────────────────────────────────────────┐
  signs userOpHash        │  Build PackedUserOperation (off-chain/test)  │
  with owner key  ───────▶│  - sender = counterfactual account addr      │
  (vm.sign / cast)        │  - nonce  = entryPoint.getNonce(sender, 0)   │
                          │  - initCode = factory ++ createAccount calldata (only if not yet deployed)
                          │  - callData = account.executeBatch([cascade,cascade],[v1,v2],[invoke(s1),invoke(s2)])
                          │  - accountGasLimits = pack(verifGas, callGas) │
                          │  - gasFees = pack(maxPrio, maxFee)            │
                          │  - signature = sign(getUserOpHash(userOp))   │
                          └───────────────────────┬─────────────────────-┘
                                                  │ userOp[]
                                                  ▼
   EOA "bundler"  ── handleOps(ops, beneficiary) ──▶  EntryPoint v0.7 (real, on-chain)
   (self-bundle)                                       │
                                                       │ 1. (if initCode) SenderCreator → factory.createAccount → CREATE2 deploy
                                                       │ 2. account.validateUserOp(op, userOpHash, missingAccountFunds)
                                                       │       ├─ require msg.sender == entryPoint
                                                       │       ├─ ecrecover(ethSigned(userOpHash)) == owner ? 0 : 1
                                                       │       └─ if missingAccountFunds>0: pay it back to entryPoint (prefund)
                                                       │ 3. account.executeBatch(...)  (callData)
                                                       ▼
                                              Smart Account.executeBatch
                                                       │  ├─ Cascade.invoke{value:v1}(s1)
                                                       │  └─ Cascade.invoke{value:v2}(s2)
                                                       ▼
                                              Cascade._distribute → balances[creator] += cut (×tree)
                                                       │
                                  EntryPoint refunds unused prefund to account's deposit,
                                  pays actualGasCost to `beneficiary` (the EOA bundler)
```

### Recommended Project Structure
```
src/
├── Cascade.sol                 # UNCHANGED
└── aa/
    ├── PackedUserOperation.sol  # struct (hand-written, matches v0.7.0 exactly)
    ├── IEntryPoint.sol          # minimal: handleOps, getUserOpHash, getNonce, depositTo, balanceOf
    ├── IAccount.sol             # validateUserOp signature
    ├── CascadeAccount.sol       # minimal ECDSA account: validateUserOp + execute + executeBatch
    └── AccountFactory.sol       # createAccount(owner,salt) CREATE2 + getAddress(owner,salt)
test/
└── SmartAccount.fork.t.sol      # fork atlantic_testnet, real EntryPoint, assert balances rise
script/
└── LiveBundle.s.sol             # GATED funded step: deploy factory+account, fund, handleOps(2 invokes)
```

### Pattern 1: v0.7 gas-field bit packing (THE critical detail)
**What:** Two `uint128` values packed into one `bytes32`, high 128 bits = first field, low 128 bits = second field.
**When to use:** Every UserOp. Wrong packing → `validateUserOp` runs with wrong gas → AA-class revert, wasted gas.

```solidity
// Source: eth-infinitism v0.7.0 contracts/core/UserOperationLib.sol (unpack* functions)
// accountGasLimits: HIGH 128 = verificationGasLimit, LOW 128 = callGasLimit
// gasFees:          HIGH 128 = maxPriorityFeePerGas, LOW 128 = maxFeePerGas
function _pack(uint128 high, uint128 low) internal pure returns (bytes32) {
    return bytes32((uint256(high) << 128) | uint256(low));
}
bytes32 accountGasLimits = _pack(verificationGasLimit, callGasLimit);
bytes32 gasFees          = _pack(maxPriorityFeePerGas, maxFeePerGas);

// Verified inverse (how the EntryPoint reads them):
//   verificationGasLimit = uint128(bytes16(accountGasLimits))           // high
//   callGasLimit         = uint128(uint256(accountGasLimits))           // low
//   maxPriorityFeePerGas = uint256(gasFees) >> 128                      // high
//   maxFeePerGas         = uint128(uint256(gasFees))                    // low
```
Foundry helper equivalent: `bytes32(abi.encodePacked(uint128(high), uint128(low)))` produces the identical 32 bytes (high bytes first).

### Pattern 2: userOpHash (exact v0.7 domain)
**What:** The hash the account validates the signature against.
**When to use:** Signing and verifying every op.

```solidity
// Source: v0.7.0 EntryPoint.getUserOpHash + UserOperationLib.encode/hash
// inner hash binds all fields EXCEPT signature; outer binds entryPoint + chainId
function userOpHash(PackedUserOperation memory op, address entryPoint, uint256 chainId)
    internal pure returns (bytes32)
{
    bytes32 inner = keccak256(abi.encode(
        op.sender,
        op.nonce,
        keccak256(op.initCode),
        keccak256(op.callData),
        op.accountGasLimits,
        op.preVerificationGas,
        op.gasFees,
        keccak256(op.paymasterAndData)
    ));
    return keccak256(abi.encode(inner, entryPoint, chainId));
}
```
**In tests, prefer calling the real thing:** `bytes32 h = entryPoint.getUserOpHash(op);` (fork test) — guarantees you match on-chain semantics. Replicate locally only as a cross-check.

### Anti-Patterns to Avoid
- **Packing low-then-high.** Both packed fields are **high128 = first-named field**. Swapping verificationGasLimit/callGasLimit or maxPriority/maxFee order silently corrupts gas.
- **Forgetting the eth-signed-message prefix.** v0.7 SimpleAccount signs `MessageHashUtils.toEthSignedMessageHash(userOpHash)`, i.e. `keccak256("\x19Ethereum Signed Message:\n32" ++ userOpHash)`. The signer and the validator must agree. `vm.sign(pk, ethSignedHash)` and `cast wallet sign --no-hash <ethSignedHash>` must match the account's recover. Mismatch → AA24 signature error.
- **Hashing with `address(this)` from the wrong contract.** The hash domain is the **EntryPoint** address, not the account. Always use `entryPoint.getUserOpHash`.
- **Re-running `initCode` after deploy.** Once the account exists, `initCode` MUST be empty (`0x`) or the op reverts (`AA10 sender already constructed`). Only the first op carries initCode.
- **Using a UUPS proxy account.** Adds deploy gas + dependency; CONTEXT mandates minimal non-vendored. Deploy the account directly via CREATE2.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UserOp hashing | Custom field ordering | Replicate `UserOperationLib.encode` EXACTLY (or call `entryPoint.getUserOpHash`) | One wrong field/order = silent AA24; field set is fixed by spec |
| Gas-field packing | Ad-hoc byte math | `(uint256(high)<<128)\|low` per Pattern 1 | EntryPoint reads high/low at fixed offsets |
| Bundler | A mempool/relayer | EOA calling `handleOps` directly | No bundler on Pharos; this is exactly how the official 4337 test suite drives ops |
| EntryPoint | A reimplementation | The real deployed singleton on the fork | Canonical bytecode already on-chain; reimplementing risks divergence |
| Nonce management | A custom counter | `entryPoint.getNonce(sender, 0)` | EntryPoint's 2D nonce (192-bit key + 64-bit seq) is authoritative; key 0 is the default sequence |
| Signature recovery | Custom ecrecover without checks | OZ `ECDSA.recover` (or inline with malleability guard) | Malleable sigs / zero-address recover are classic footguns |

**Key insight:** In v0.7 the entire risk surface is *encoding fidelity*. The account logic is ~40 lines; the way an op fails is almost always a packing/hashing/prefix mismatch, not business logic. Match the reference byte-for-byte.

## Common Pitfalls

### Pitfall 1: Account has no funds to pay prefund (AA21)
**What goes wrong:** `handleOps` reverts `FailedOp(0, "AA21 didn't pay prefund")`.
**Why it happens:** The account must either hold native balance ≥ required prefund, OR have a prior `entryPoint.depositTo(account)`. `missingAccountFunds` is what EntryPoint asks the account to send back during validation.
**How to avoid:** Before the op, fund the account: in fork tests `vm.deal(address(account), 0.01 ether)`; live, send a small amount to the counterfactual address (or `depositTo`). Implement `_payPrefund` exactly as below (ignore the call's success — it's EntryPoint's job to verify):
```solidity
// Source: v0.7.0 BaseAccount._payPrefund
if (missingAccountFunds != 0) {
    (bool ok,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
    (ok); // ignore failure on purpose
}
```
**Warning signs:** `AA21` in the FailedOp string.

### Pitfall 2: Signature mismatch (AA24)
**What goes wrong:** `FailedOp(0, "AA24 signature error")`.
**Why it happens:** Signer and validator disagree on the prefix (eth-signed vs raw), on the hash domain (entrypoint/chainId), or on packing (which changes the hash).
**How to avoid:** Sign `toEthSignedMessageHash(entryPoint.getUserOpHash(op))`; validate with the same prefix. Build the op fully (all gas fields packed) BEFORE hashing — any field change after signing invalidates the sig.
**Warning signs:** `AA24`; or sig recovers to a non-owner address.

### Pitfall 3: initCode / factory failure (AA13 / AA10 / AA14)
**What goes wrong:** `AA13 initCode failed or OOG`, `AA10 sender already constructed`, `AA14 initCode must return sender`.
**Why it happens:** `initCode` bytes malformed (must be `factory(20 bytes) ++ createAccount calldata`), or the deployed address ≠ the `op.sender` you set, or you sent initCode for an already-deployed account.
**How to avoid:** Compute `sender` as `factory.getAddress(owner, salt)` and use that EXACT address as `op.sender`. `createAccount` must return that same address (idempotent if already deployed). Set `verificationGasLimit` high enough to cover deployment (deployment happens inside the validation phase).
**Warning signs:** `AA1x` codes.

### Pitfall 4: verificationGasLimit too low when deploying (AA13/AA40/OOG)
**What goes wrong:** Op reverts out-of-gas during validation because the account deploy + validateUserOp didn't fit in `verificationGasLimit`.
**How to avoid:** For the deploying op, set `verificationGasLimit` generously (e.g. 400k–600k). For non-deploying ops, ~80k–150k. `callGasLimit` must cover `executeBatch` + N `Cascade.invoke` (each invoke recurses up the tree, depth ≤ 8) — budget ~120k–250k for a 2-call batch.

### Pitfall 5: Gas price exceeds budget (THE live-step blocker)
**What goes wrong:** The funded step spends more PHRS than available, or half-spends.
**Why it happens:** Node reports **10 gwei** `[VERIFIED: cast gas-price]`. 0.0043 PHRS ÷ 10 gwei ≈ **430k gas total** — less than one account deploy.
**How to avoid:** Pre-flight gate (see §8). Try submitting at a lower `--gas-price` (e.g. 1 gwei) but expect possible rejection if the node enforces a floor. If estimate × price > balance, STOP and report top-up need on `0x67680b09bB422cC510669bd5208D947066D4aeaE`.

## Code Examples

### Minimal v0.7 account `validateUserOp` (gas-lean, owner ECDSA)
```solidity
// Source: distilled from v0.7.0 BaseAccount.validateUserOp + SimpleAccount._validateSignature
// SIG_VALIDATION_SUCCESS = 0, SIG_VALIDATION_FAILED = 1 (v0.7.0 Helpers.sol)
function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external returns (uint256 validationData) {
    require(msg.sender == address(entryPoint), "account: not from EntryPoint");

    // eth-signed-message prefix, then ecrecover; 0 if owner, else 1
    bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
    address recovered = ECDSA.recover(ethHash, userOp.signature); // or inline ecrecover w/ malleability guard
    validationData = (recovered == owner) ? 0 : 1;

    if (missingAccountFunds != 0) {
        (bool ok,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
        (ok); // ignore: EntryPoint verifies payment
    }
}
```

### Minimal execute / executeBatch (EntryPoint-or-owner gated)
```solidity
// Source: v0.7.0 SimpleAccount.execute/executeBatch/_call (trimmed)
modifier onlyEntryPointOrOwner() {
    require(msg.sender == address(entryPoint) || msg.sender == owner, "not authorized");
    _;
}
function execute(address dest, uint256 value, bytes calldata func) external onlyEntryPointOrOwner {
    _call(dest, value, func);
}
function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func)
    external onlyEntryPointOrOwner
{
    require(dest.length == func.length && value.length == func.length, "len mismatch");
    for (uint256 i; i < dest.length; ++i) _call(dest[i], value[i], func[i]);
}
function _call(address target, uint256 value, bytes memory data) internal {
    (bool success, bytes memory result) = target.call{value: value}(data);
    if (!success) assembly { revert(add(result, 32), mload(result)) }
}
receive() external payable {}
```

### CREATE2 factory (proxy-free, deterministic)
```solidity
// Source: pattern adapted from v0.7.0 SimpleAccountFactory (proxy removed; direct account deploy)
contract AccountFactory {
    IEntryPoint public immutable entryPoint;
    constructor(IEntryPoint _ep) { entryPoint = _ep; }

    function createAccount(address owner, uint256 salt) public returns (address) {
        address addr = getAddress(owner, salt);
        if (addr.code.length > 0) return addr;                 // idempotent
        CascadeAccount acct = new CascadeAccount{salt: bytes32(salt)}(entryPoint, owner);
        return address(acct);
    }

    function getAddress(address owner, uint256 salt) public view returns (address) {
        bytes32 codeHash = keccak256(abi.encodePacked(
            type(CascadeAccount).creationCode,
            abi.encode(entryPoint, owner)                       // constructor args
        ));
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff), address(this), bytes32(salt), codeHash
        )))));
    }
}
// initCode for the UserOp = abi.encodePacked(address(factory), abi.encodeWithSelector(
//     AccountFactory.createAccount.selector, owner, salt));
```

### Build + sign + self-bundle in a Foundry fork test
```solidity
// Source: composed from forge-std cheats + v0.7.0 handleOps/getUserOpHash semantics
function test_smartAccount_batches_two_invokes() public {
    vm.createSelectFork(vm.rpcUrl("atlantic_testnet"));   // REAL EntryPoint + REAL Cascade
    IEntryPoint ep = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
    Cascade cascade = Cascade(0xd41C32562D0BE20D354120E1De11A91abC340F50);

    (address owner, uint256 pk) = makeAddrAndKey("owner");
    AccountFactory factory = new AccountFactory(ep);
    address sender = factory.getAddress(owner, 0);

    // Fund the counterfactual account so it can pay value + prefund (zero real funds: vm.deal)
    vm.deal(sender, 1 ether);

    // initCode only because not yet deployed:
    bytes memory initCode = abi.encodePacked(
        address(factory),
        abi.encodeWithSelector(AccountFactory.createAccount.selector, owner, uint256(0))
    );

    // callData: executeBatch([cascade,cascade],[v1,v2],[invoke(s1),invoke(s2)])
    address[] memory dest = new address[](2); dest[0]=address(cascade); dest[1]=address(cascade);
    uint256[] memory val  = new uint256[](2); val[0]=price1; val[1]=price2;
    bytes[]   memory fn   = new bytes[](2);
    fn[0]=abi.encodeWithSelector(Cascade.invoke.selector, skillId1);
    fn[1]=abi.encodeWithSelector(Cascade.invoke.selector, skillId2);
    bytes memory callData = abi.encodeWithSelector(CascadeAccount.executeBatch.selector, dest, val, fn);

    PackedUserOperation memory op = PackedUserOperation({
        sender: sender,
        nonce: ep.getNonce(sender, 0),
        initCode: initCode,
        callData: callData,
        accountGasLimits: bytes32((uint256(uint128(600_000)) << 128) | uint128(300_000)), // verif|call
        preVerificationGas: 60_000,
        gasFees: bytes32((uint256(uint128(1 gwei)) << 128) | uint128(1 gwei)),             // prio|max
        paymasterAndData: "",
        signature: ""
    });

    bytes32 h = ep.getUserOpHash(op);                       // authoritative hash
    bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
    op.signature = abi.encodePacked(r, s, v);

    PackedUserOperation[] memory ops = new PackedUserOperation[](1); ops[0]=op;

    uint256 cBefore = cascade.balances(someCreator);
    ep.handleOps(ops, payable(address(this)));              // EOA self-bundles
    assertGt(cascade.balances(someCreator), cBefore);       // account-agnostic proof
}
```

### Signing with cast (script/manual path)
```bash
# getUserOpHash on the fork/live, then sign the eth-signed form:
H=$(cast call $ENTRYPOINT "getUserOpHash((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes))(bytes32)" "$OP_TUPLE" --rpc-url atlantic_testnet)
# eth-signed prefix is what the account checks; `cast wallet sign` (no --no-hash) applies EIP-191 prefix:
SIG=$(cast wallet sign --private-key $PK "$H")   # signs keccak("\x19Ethereum Signed Message:\n32"||H)
```
Note: `cast wallet sign <hash>` applies the EIP-191 personal-message prefix automatically; that matches the account's `toEthSignedMessageHash`. Use `--no-hash` only if your account validates the RAW userOpHash without prefix (then sign the raw 32 bytes). Pick ONE scheme and keep account + signer consistent.

## State of the Art

| Old Approach (v0.6) | Current Approach (v0.7) | When Changed | Impact |
|---------------------|--------------------------|--------------|--------|
| `UserOperation` with separate `callGasLimit`, `verificationGasLimit`, `preVerificationGas`, `maxFeePerGas`, `maxPriorityFeePerGas` uint256 fields | `PackedUserOperation` with `accountGasLimits` (bytes32) + `gasFees` (bytes32) packed | EntryPoint v0.7 (early 2024) | Must pack; v0.6 examples found online won't compile/validate against the Pharos EntryPoint |
| `initCode`/`paymasterAndData` loosely formatted | `paymasterAndData` has fixed offsets (addr/verifGas/postOpGas); `initCode` = factory++calldata | v0.7 | Empty paymaster = `0x`; don't put placeholder bytes |
| EntryPoint `0x5FF137...` (v0.6 addr) | EntryPoint `0x0000000071727De22E5E9d8BAf0edAc6f37da032` (v0.7) | v0.7 | Pharos has the v0.7 address — verified |

**Deprecated/outdated:**
- Any tutorial using `UserOperation` (unpacked) or the v0.6 EntryPoint address: WRONG for Pharos.
- `validateUserOp` returning a bool or reverting on bad sig: v0.7 returns `0`/`1` (and packs time-range in upper bytes); reverting on a *signature* mismatch breaks simulation — return `1`.

## Runtime State Inventory

> This is an ADDITIVE phase (new contracts), not a rename/refactor. Included for the live-step state that exists outside git.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Live Cascade `0xd41C…0F50`, `skillCount()==3` (A→B→C). Smart account will INVOKE these existing skills — needs their exact `skillId`s and `price`s. | Read prices on-chain (`cast call cascade "..."`) to set `val[i]` exactly (invoke requires `msg.value==price`). No migration. |
| Live service config | Real EntryPoint v0.7 `0x0000000071727De22E5E9d8BAf0edAc6f37da032`, SenderCreator `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C` — on-chain, not in git. | Hardcode/config in script + networks; no change to those contracts. |
| OS-registered state | None — no schedulers/daemons involved. | None — verified (project is forge scripts only). |
| Secrets/env vars | `PRIVATE_KEY` (existing pattern in scripts) for the self-bundling EOA `0x67680b09bB422cC510669bd5208D947066D4aeaE`. | Reuse existing env pattern; do NOT echo key. |
| Build artifacts | New `src/aa/*` compiles into `out/`; no stale artifacts (additive). | Normal `forge build`. |

**The canonical question:** After all files exist, what runtime state still matters? → The **live skill prices** (invoke needs exact `msg.value`) and the **funded EOA balance** (~0.0043 PHRS). Both must be read at runtime before the live step.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Live skill `price`s are small enough that 2 invokes + gas fit the batch value budget | §8, Runtime State | If a skill price is large, the account needs more native funding; live step value cost rises |
| A2 | Pharos node may accept a `--gas-price` below the reported 10 gwei | §8, Pitfall 5 | If node enforces a 10 gwei floor, live step is hard-blocked regardless of pre-flight |
| A3 | Gas estimates (factory ~0.6–1.2M, account deploy ~0.3–0.5M, handleOps 2-batch ~0.3–0.5M) | §8 | If higher, budget gate trips sooner; doesn't affect local proof |
| A4 | Pharos EntryPoint enforces standard EIP-7702/validation rules identically to canonical v0.7 (no chain-specific patches) | all | Low — bytecode size matches canonical; verify by a successful fork `handleOps` |
| A5 | `block.basefee` behaves normally on the fork so `gasPrice()` (min(maxFee, prio+basefee)) is sane | §1, §6 | If basefee is 0/odd on fork, set maxFee==maxPriority (legacy mode) to be safe |

## Open Questions

1. **Does the Pharos node enforce a gas-price floor at 10 gwei?**
   - What we know: `cast gas-price` returns 10 gwei; budget only fits at ~1 gwei.
   - What's unclear: whether a manually-set lower `--gas-price` tx is accepted/mined.
   - Recommendation: In the live script, attempt at 1 gwei; if the tx is rejected or stuck, treat live as blocked and ship the fork proof. Pre-flight must compute `estGas * actualAcceptedPrice`.

2. **Exact live skill prices / ids for the batch.**
   - What we know: skillCount==3 (A→B→C). The batch invokes 2 of them.
   - What's unclear: the precise `price` of each (invoke requires exact `msg.value`).
   - Recommendation: Read each skill's price on-chain at runtime before building `val[]`. Likely the demo will invoke the same priced skill twice or two specific ids — planner should parametrize via env.

3. **Prefix scheme: eth-signed vs raw userOpHash.**
   - What we know: SimpleAccount uses the eth-signed prefix; both schemes are valid if account + signer agree.
   - Recommendation: Use the eth-signed prefix (matches `cast wallet sign` default and `vm.sign` on the prefixed hash) to avoid `--no-hash` confusion. Lock this in the account and the signer identically.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| forge/cast | build, fork test, sign, broadcast | ✓ | 1.5.1 | — |
| atlantic_testnet RPC | fork test + live step | ✓ | chainId 688689 | mainnet config exists but out of scope |
| Real EntryPoint v0.7 | AA-03 settlement | ✓ | `0x0000…da032`, 16KB bytecode | local EntryPoint copy (needs eth-infinitism dep) — less faithful |
| Live Cascade | live batch demo | ✓ | `0xd41C…0F50`, skillCount 3 | local Cascade deploy (fork test uses real) |
| Funded EOA balance | live step ONLY | ⚠ ~0.0043 PHRS | — | **Gate + stop**; local fork proof needs zero funds |
| solc 0.8.24 | compile | ✓ | via foundry | — |

**Missing dependencies with no fallback:**
- Sufficient PHRS for the live step at 10 gwei. No fallback for funds — the gate must stop cleanly and report the top-up address. Local fork proof is the deliverable.

**Missing dependencies with fallback:**
- None blocking the local proof. A local EntryPoint copy is a (less faithful) fallback to the fork, but the fork against the real EntryPoint is recommended and available.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Foundry `forge` 1.5.1 (forge-std in `lib/`) |
| Config file | `foundry.toml` (rpc_endpoints.atlantic_testnet present) |
| Quick run command | `forge test --match-path test/SmartAccount.fork.t.sol -vv` |
| Full suite command | `forge test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AA-01 | Factory deploys account at deterministic addr; `getAddress`==deployed addr | unit/fork | `forge test --mt test_factory_deterministic_address` | ❌ Wave 0 |
| AA-02 | One UserOp `executeBatch` makes 2 `invoke` calls; 2 separate creator balances rise | fork | `forge test --mt test_smartAccount_batches_two_invokes` | ❌ Wave 0 |
| AA-03 | Full op settles via real EntryPoint `handleOps` (fork); validateUserOp accepts owner sig, rejects wrong sig | fork | `forge test --mt test_handleOps_settles_via_real_entrypoint` | ❌ Wave 0 |
| CORE-07 | Smart-account invoke credits creators identically to EOA path | fork | `forge test --mt test_account_agnostic_parity` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `forge test --match-path test/SmartAccount.fork.t.sol`
- **Per wave merge:** `forge test`
- **Phase gate:** Full suite green (incl. fork test against real EntryPoint) before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `test/SmartAccount.fork.t.sol` — covers AA-01/02/03 + CORE-07 parity (fork-based)
- [ ] `src/aa/CascadeAccount.sol`, `src/aa/AccountFactory.sol`, `src/aa/PackedUserOperation.sol`, `src/aa/IEntryPoint.sol`, `src/aa/IAccount.sol`
- [ ] A signed-userop builder helper (inline in test or a small lib) — `vm.sign` over eth-signed `getUserOpHash`
- [ ] Negative test: wrong signer ⇒ `handleOps` reverts `FailedOp(0,"AA24...")` (use `vm.expectRevert`)

*Fork tests require network access to atlantic_testnet RPC during `forge test`. If CI lacks egress, also add a local-EntryPoint variant; but the primary proof is the fork.*

## Security Domain

> `security_enforcement` config not located in `.planning/config.json` (treated as enabled). ASVS mapped to this on-chain/account-abstraction context.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Owner ECDSA in `validateUserOp`; only owner key authorizes ops |
| V3 Session Management | no | Stateless on-chain ops; nonce via EntryPoint prevents replay |
| V4 Access Control | yes | `execute`/`executeBatch` gated `onlyEntryPointOrOwner`; `validateUserOp` gated `msg.sender==entryPoint` |
| V5 Input Validation | yes | `executeBatch` array-length checks; Cascade enforces `msg.value==price` |
| V6 Cryptography | yes | Use OZ `ECDSA.recover` (malleability-safe) or guarded inline ecrecover — never raw `ecrecover` without checks |

### Known Threat Patterns for ERC-4337 accounts

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Anyone calls `execute` directly | Elevation of Privilege | `onlyEntryPointOrOwner` modifier (require entrypoint or owner) |
| `validateUserOp` called by non-EntryPoint | Spoofing | `require(msg.sender == address(entryPoint))` |
| Signature malleability / zero-addr recover | Tampering | OZ `ECDSA.recover` (rejects high-s, zero addr) |
| Replay of a signed UserOp | Tampering/Replay | EntryPoint 2D nonce; never reuse; hash binds chainId+entrypoint |
| Prefund griefing (account drained via prefund) | DoS | Pay only `missingAccountFunds`; fund account minimally; pull-payment in Cascade unaffected |
| Hardcoded private key in script | Info Disclosure | Read `PRIVATE_KEY` from env; never commit; don't echo |
| Sending value to wrong skill price | (correctness) | Read live `price` at runtime; `invoke` reverts on mismatch (fail-safe) |

## Gas Reality (§8 — the budget decision)

| Operation | Rough gas (est., `[ASSUMED]`) | At 10 gwei (current) | At 1 gwei (hoped) |
|-----------|------------------------------|----------------------|-------------------|
| Factory deploy (proxy-free) | ~600k–1.2M | 0.006–0.012 PHRS | 0.0006–0.0012 PHRS |
| Account deploy via `createAccount` (CREATE2) | ~300k–500k | 0.003–0.005 PHRS | 0.0003–0.0005 PHRS |
| `handleOps` w/ 2-call `executeBatch` (incl. validation + 2× invoke tree) | ~300k–550k | 0.003–0.0055 PHRS | 0.0003–0.00055 PHRS |
| Minimal account funding (prefund + 2× skill value) | skill prices + prefund | depends on prices | depends on prices |
| **Live total (factory+account+handleOps)** | **~1.2M–2.2M gas** | **~0.012–0.022 PHRS — EXCEEDS 0.0043** | **~0.0012–0.0022 PHRS — fits** |

**Verdict (HIGH confidence on the risk, MEDIUM on exact numbers):** At the **currently reported 10 gwei**, the live funded step does **NOT fit** ~0.0043 PHRS — the factory deploy alone (~600k–1.2M gas = 0.006–0.012 PHRS) already exceeds the balance. It only fits if (a) the node accepts ~1 gwei txs AND (b) the EOA can deploy factory+account+handleOps within budget. **Mitigations the planner MUST bake in:**
1. **Pre-flight gate** in the live script: read `cast balance <EOA>`, `forge`-estimate each tx's gas, multiply by the lowest accepted gas price; if `total > balance`, **STOP** and print "Top up `0x67680b09bB422cC510669bd5208D947066D4aeaE` by X PHRS" — never half-spend.
2. **Try 1 gwei** explicitly (`--gas-price 1000000000`); if rejected, declare live blocked.
3. **Shrink the live footprint:** the factory deploy is the heaviest item. Option — deploy the account *directly* (one CREATE2 deploy or even a plain `new CascadeAccount`) and skip the factory for the live step, proving the factory path only in the fork test. This still satisfies AA-01 (account deployed) while cutting ~600k–1.2M gas. Planner's call.
4. **Local fork proof is the primary deliverable** (zero funds). The live step is a gated bonus per CONTEXT.

## Project Constraints (from CLAUDE.md / global rules)

No project-local `./CLAUDE.md` found. Global rules in effect that shape this phase:
- **Immutability / no mutation, KISS/DRY/YAGNI** — account stays ~40–80 lines, no speculative features.
- **Files <800 lines, functions <50 lines** — `src/aa/*` split per concern (struct, interfaces, account, factory separate files).
- **80% test coverage, TDD (RED→GREEN)** — write the failing fork test first (mirror Phase 1's `Demo.fork.t.sol` style).
- **No hardcoded secrets** — `PRIVATE_KEY` from env; never echo.
- **Security review triggers** (auth, ecrecover, external calls) — use OZ `ECDSA`; gate `execute`/`validateUserOp`.
- **Input validation at boundaries** — `executeBatch` length checks; rely on Cascade's `msg.value==price`.

## Sources

### Primary (HIGH confidence)
- eth-infinitism/account-abstraction `v0.7.0` — `contracts/interfaces/PackedUserOperation.sol` (struct layout), `IAccount.sol` (validateUserOp sig + return semantics), `IEntryPoint.sol` (handleOps/getUserOpHash/getNonce/depositTo/balanceOf), `core/UserOperationLib.sol` (encode/hash + pack/unpack), `core/EntryPoint.sol` (getUserOpHash domain), `core/BaseAccount.sol` (_payPrefund), `core/Helpers.sol` (SIG_VALIDATION_SUCCESS/FAILED), `samples/SimpleAccount.sol` (execute/executeBatch/_validateSignature/_call), `samples/SimpleAccountFactory.sol` (createAccount/getAddress CREATE2). [VERIFIED: raw.githubusercontent.com @ v0.7.0 tag]
- Live atlantic-testnet: chainId `688689`, EntryPoint `0x0000…da032` 16,035 bytes, gas-price 10 gwei, Cascade `0xd41C…0F50` skillCount 3. [VERIFIED: cast chain-id / code / gas-price / call]

### Secondary (MEDIUM confidence)
- AA-prefixed FailedOp revert codes (AA10/13/14/21/22/23/24/40) — convention from EntryPoint `FailedOp` reason strings ("AAmn": m=1 factory, 2 account, 3 paymaster). [CITED: IEntryPoint.sol FailedOp docstring]

### Tertiary (LOW confidence)
- Gas magnitude estimates (§8) — `[ASSUMED]` from typical 4337 deploys; not measured on Pharos. Validate via `forge test --gas-report` on the fork before any live spend.

## Metadata

**Confidence breakdown:**
- Standard stack / interfaces / packing / hashing / prefund / factory: **HIGH** — verified line-for-line against the v0.7.0 tag and the EntryPoint is confirmed on-chain.
- Architecture / test pattern: **HIGH** — fork-against-real-EntryPoint is the canonical 4337 test method; matches Phase 1 fork-test style.
- Gas numbers / live feasibility: **MEDIUM** — risk is HIGH-confidence (10 gwei blocks it); exact gas is estimated, must be measured on the fork.

**Research date:** 2026-06-07
**Valid until:** ~2026-07-07 (v0.7 is stable; re-check the live gas price right before any funded step — it's the deciding variable).
