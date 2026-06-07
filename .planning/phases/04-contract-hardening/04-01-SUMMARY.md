---
phase: 04-contract-hardening
plan: 01
subsystem: contracts
tags: [natspec, custom-errors, hardening, aa, fmt]
requires: []
provides:
  - "Cascade.sol + AA contracts with full NatSpec and named custom errors (frozen ABI)"
  - "Selector-based revert assertions across the unit suites"
affects:
  - src/Cascade.sol
  - src/aa/CascadeAccount.sol
  - src/aa/AccountFactory.sol
  - src/aa/IEntryPoint.sol
tech-stack:
  added: []
  patterns:
    - "require(\"string\") -> if (!cond) revert NamedError(args)"
    - "vm.expectPartialRevert(selector) for arg-carrying custom errors under forge-std 1.16.1"
    - "[fmt] ignore to freeze the integration fork test byte-for-byte while keeping forge fmt --check clean"
key-files:
  created:
    - .planning/phases/04-contract-hardening/04-01-SUMMARY.md
  modified:
    - src/Cascade.sol
    - src/aa/CascadeAccount.sol
    - src/aa/AccountFactory.sol
    - src/aa/IEntryPoint.sol
    - test/Cascade.t.sol
    - test/SmartAccountUnit.t.sol
    - foundry.toml
decisions:
  - "Kept parameterized custom errors (WrongValue(sent,expected), BadDependency(depId), etc.) per CONTEXT.md review-quality intent; used vm.expectPartialRevert for selector-only matching because forge-std 1.16.1 makes expectRevert(bytes4) a full-data exact match."
  - "Excluded test/SmartAccount.fork.t.sol from forge fmt (via [fmt] ignore in foundry.toml) so the frozen Phase 3 integration proof stays byte-for-byte while forge fmt --check remains clean tree-wide."
metrics:
  duration: ~11m
  completed: 2026-06-07
  tasks: 4
  files: 7
---

# Phase 4 Plan 01: NatSpec + Named Custom Errors (HARD-01) Summary

Replaced every `require("string")` in Cascade.sol (7 sites) and CascadeAccount.sol (3 sites) with named custom errors, added complete NatSpec across Cascade + all five AA contracts, flipped the revert-asserting unit tests to selector-based assertions in lockstep, and held the external ABI + the real-EntryPoint fork behavior byte-for-byte unchanged.

## What Was Built

- **Cascade.sol:** 7 named custom errors (`LengthMismatch`, `BadDependency(depId)`, `SharesExceedMax(sum)`, `DepthExceeded(depth)`, `UnknownSkill(id)`, `WrongValue(sent,expected)`, `TransferFailed`), each with NatSpec. All 7 `require` sites converted to `if (!cond) revert Err(args)` preserving exact branch reachability. All 4 events documented (`@notice`/`@param`). Function signatures, event topics, storage layout, and `_distribute` math unchanged.
- **CascadeAccount.sol:** 3 named custom errors (`NotAuthorized`, `NotFromEntryPoint`, `LengthMismatch`) with NatSpec. The 3 `require` sites (auth modifier, validateUserOp guard, executeBatch length check) converted; the assembly `revert(add(result,0x20), mload(result))` bubble-up in `_call` left byte-for-byte. Constructor, modifier, `execute`/`executeBatch` params, and `receive()` documented.
- **AccountFactory.sol / IEntryPoint.sol:** filled remaining `@param`/`@return` NatSpec gaps (constructor, createAccount, getAddress, getUserOpHash, getNonce, depositTo, balanceOf).
- **Tests:** `test/Cascade.t.sol` — 9 selector-based assertions (1 `expectRevert` for the no-arg error, 8 `expectPartialRevert` for arg-carrying errors). `test/SmartAccountUnit.t.sol` — 3 `expectRevert(CascadeAccount.*.selector)`. `test/SmartAccount.fork.t.sol` untouched (AA24 FailedOp assertion is the EntryPoint's own, not ours).

## Verification

- `forge fmt --check`: clean.
- `forge build`: compiler run successful.
- `forge test` (local): 34 passed, 0 failed (4 suites).
- `forge test --fork-url atlantic_testnet --match-path 'test/*.fork.t.sol'`: 5 passed, 0 failed — real-EntryPoint behavior unchanged.
- `grep -nE 'require\(' src/Cascade.sol src/aa/CascadeAccount.sol`: nothing (all converted; assembly revert preserved).
- `test/SmartAccount.fork.t.sol` git hash `8db92ee...` == phase-start hash (byte-for-byte unchanged).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Toolchain: expectRevert(bytes4) is full-data exact-match, not selector-only**
- **Found during:** Task 1
- **Issue:** The plan assumed `vm.expectRevert(Cascade.Err.selector)` matches on selector only. Under the installed forge-std 1.16.1 / forge 1.5.1, `expectRevert(bytes4)` compares the FULL revert data, so the 8 arg-carrying custom errors (e.g. `WrongValue(999..., 1000...)`) failed against a bare 4-byte selector. No-arg errors passed.
- **Fix:** Kept the parameterized errors (CONTEXT.md explicitly wants them for review quality) and switched the 8 arg-carrying assertions to `vm.expectPartialRevert(selector)`, which matches on selector only and is robust to arg values — exactly the plan's stated intent. The single no-arg `LengthMismatch` stays on `expectRevert`. All `.selector` assertions count = 9, suite green.
- **Files modified:** test/Cascade.t.sol
- **Commit:** d8f613c

**2. [Rule 3 - Blocking] Conflict: mandated `forge fmt` rewraps the frozen fork test**
- **Found during:** Task 3
- **Issue:** `forge fmt` (a hard requirement) reformatted `test/SmartAccount.fork.t.sol` (line-wrapping only; AA24 logic intact). The success criteria require that file byte-for-byte unchanged. A whole-tree fmt and a frozen file cannot both hold via fmt alone.
- **Fix:** Restored the fork file to its original bytes and added `[fmt] ignore = ["test/SmartAccount.fork.t.sol"]` to foundry.toml, so `forge fmt --check` stays clean tree-wide while the integration proof is preserved verbatim.
- **Files modified:** foundry.toml, test/SmartAccount.fork.t.sol (restored)
- **Commit:** 3bbc8a5

Note: `script/DemoTree.s.sol` and `script/LiveBundle.s.sol` were also normalised by the mandated `forge fmt` (in-scope: fmt was required across the tree) and committed with Task 3.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary surface introduced. Changes are revert-data (string -> selector) + documentation + formatting only.

## Self-Check: PASSED

All claimed files exist (SUMMARY, Cascade.sol, CascadeAccount.sol, test files, foundry.toml) and all three task commits (d8f613c, 159c9f1, 3bbc8a5) are present in git history.
