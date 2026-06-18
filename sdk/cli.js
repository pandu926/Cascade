#!/usr/bin/env node

import { createCascade } from "./index.js";
import { formatEther } from "viem";

const HELP = `
cascade-sdk — CLI for Cascade recursive skill royalties on Pharos

Usage:
  cascade register [options]    Register a new skill
  cascade invoke [options]      Invoke (pay for) a skill
  cascade claim                 Withdraw accrued royalties
  cascade balance [address]     Check accrued balance
  cascade skill-info            Show skill count and contract info

Options:
  --network <mainnet|testnet>   Network (default: mainnet)
  --key <private_key>           Private key (or set CASCADE_PRIVATE_KEY env)
  --price <ether>               Skill price in PROS/PHRS (default: 0)
  --deps <id,id,...>            Dependency skill IDs (comma-separated)
  --shares <bps,bps,...>        Shares in basis points (comma-separated)
  --skill <id>                  Skill ID to invoke

Examples:
  # Register a leaf skill (no deps, free)
  cascade register --key 0x... --network mainnet

  # Register with dependencies (price 0.005 PROS, depends on skill 7 at 40%)
  cascade register --price 0.005 --deps 7 --shares 4000

  # Invoke skill 9
  cascade invoke --skill 9

  # Check balance
  cascade balance 0xYourAddress

  # Claim all royalties
  cascade claim

Environment:
  CASCADE_PRIVATE_KEY    Private key (alternative to --key flag)
  CASCADE_NETWORK        Network (alternative to --network flag)
`;

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) {
      const key = argv[i].slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    } else if (!args._command) {
      args._command = argv[i];
    } else {
      args._positional = args._positional || [];
      args._positional.push(argv[i]);
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._command;

  if (!command || args.help || command === "help") {
    console.log(HELP);
    process.exit(0);
  }

  const privateKey = args.key || process.env.CASCADE_PRIVATE_KEY;
  const network = args.network || process.env.CASCADE_NETWORK || "mainnet";

  if (!privateKey && command !== "balance" && command !== "skill-info") {
    console.error("Error: Private key required. Use --key or set CASCADE_PRIVATE_KEY env.");
    process.exit(1);
  }

  const cascade = createCascade({ privateKey: privateKey || "0x0000000000000000000000000000000000000000000000000000000000000001", network });

  switch (command) {
    case "register": {
      const price = args.price || "0";
      const depIds = args.deps ? args.deps.split(",").map(Number) : [];
      const depShares = args.shares ? args.shares.split(",").map(Number) : [];

      console.log(`Registering skill on ${network}...`);
      console.log(`  Price: ${price} ${network === "mainnet" ? "PROS" : "PHRS"}`);
      if (depIds.length) console.log(`  Dependencies: [${depIds}] shares: [${depShares}]`);

      const result = await cascade.register({ price, depIds, depShares });
      console.log(`\n✓ Skill registered!`);
      console.log(`  Skill ID: ${result.skillId}`);
      console.log(`  Tx: ${result.hash}`);
      console.log(`  Explorer: ${result.explorer}`);
      break;
    }

    case "invoke": {
      const skillId = parseInt(args.skill);
      if (!skillId) {
        console.error("Error: --skill <id> required");
        process.exit(1);
      }

      console.log(`Invoking skill ${skillId} on ${network}...`);
      const result = await cascade.invoke({ skillId });
      console.log(`\n✓ Skill invoked!`);
      console.log(`  Paid: ${result.paid} ${network === "mainnet" ? "PROS" : "PHRS"}`);
      console.log(`  Tx: ${result.hash}`);
      console.log(`  Explorer: ${result.explorer}`);
      break;
    }

    case "claim": {
      const balanceBefore = await cascade.getBalance(cascade.account.address);
      console.log(`Claimable balance: ${formatEther(balanceBefore)} ${network === "mainnet" ? "PROS" : "PHRS"}`);

      if (balanceBefore === 0n) {
        console.log("Nothing to claim.");
        break;
      }

      console.log("Claiming...");
      const result = await cascade.claim();
      console.log(`\n✓ Claimed!`);
      console.log(`  Amount: ${result.amount} ${network === "mainnet" ? "PROS" : "PHRS"}`);
      console.log(`  Tx: ${result.hash}`);
      console.log(`  Explorer: ${result.explorer}`);
      break;
    }

    case "balance": {
      const address = (args._positional && args._positional[0]) || cascade.account.address;
      const balance = await cascade.getBalance(address);
      console.log(`Balance for ${address}:`);
      console.log(`  ${formatEther(balance)} ${network === "mainnet" ? "PROS" : "PHRS"}`);
      break;
    }

    case "skill-info": {
      const count = await cascade.getSkillCount();
      console.log(`Cascade on ${network}:`);
      console.log(`  Contract: ${cascade.contractAddress}`);
      console.log(`  Skills registered: ${count}`);
      console.log(`  Chain: ${cascade.chain.name} (${cascade.chain.id})`);
      break;
    }

    default:
      console.error(`Unknown command: ${command}`);
      console.log(HELP);
      process.exit(1);
  }
}

main().catch(err => {
  console.error(`\nError: ${err.shortMessage || err.message}`);
  process.exit(1);
});
