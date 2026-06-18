import { createPublicClient, createWalletClient, http, parseEther, formatEther, defineChain, getAddress } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { CASCADE_ABI } from "./abi.js";

const CONTRACTS = {
  mainnet: "0x31bE4C6B5711913D818e377ebd809d4397FF3c84",
  testnet: "0xd41C32562D0BE20D354120E1De11A91abC340F50"
};

const pharosMainnet = defineChain({
  id: 1672,
  name: "Pharos",
  nativeCurrency: { name: "PROS", symbol: "PROS", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.pharos.xyz"] } },
  blockExplorers: { default: { name: "PharosScan", url: "https://www.pharosscan.xyz" } }
});

const pharosTestnet = defineChain({
  id: 688689,
  name: "Pharos Atlantic Testnet",
  nativeCurrency: { name: "PHRS", symbol: "PHRS", decimals: 18 },
  rpcUrls: { default: { http: ["https://atlantic.dplabs-internal.com"] } },
  blockExplorers: { default: { name: "PharosScan", url: "https://atlantic.pharosscan.xyz" } }
});

const CHAINS = { mainnet: pharosMainnet, testnet: pharosTestnet };

export function createCascade({ privateKey, network = "mainnet" }) {
  const chain = CHAINS[network];
  if (!chain) throw new Error(`Unknown network: ${network}. Use "mainnet" or "testnet".`);

  const contractAddress = CONTRACTS[network];
  const account = privateKeyToAccount(privateKey.startsWith("0x") ? privateKey : `0x${privateKey}`);

  const publicClient = createPublicClient({ chain, transport: http() });
  const walletClient = createWalletClient({ account, chain, transport: http() });

  async function register({ price = "0", depIds = [], depShares = [] }) {
    const priceWei = parseEther(price);

    if (depIds.length !== depShares.length) {
      throw new Error("depIds and depShares must have same length");
    }
    const shareSum = depShares.reduce((a, b) => a + b, 0);
    if (shareSum > 10000) {
      throw new Error(`Share sum ${shareSum} exceeds 10000 bps`);
    }

    const hash = await walletClient.writeContract({
      address: contractAddress,
      abi: CASCADE_ABI,
      functionName: "register",
      args: [priceWei, depIds.map(BigInt), depShares.map(BigInt)]
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    const log = receipt.logs.find(l => l.topics[0] === "0x545099cf086c31875eed66faa41489d4d78a6503e9798a5b112e0a98e76830f7");
    const skillId = log ? parseInt(log.topics[1], 16) : null;

    return { hash, skillId, explorer: `${chain.blockExplorers.default.url}/tx/${hash}` };
  }

  async function getSkillPrice(skillId) {
    // Read price from storage: skills mapping is at slot 2
    // mapping(uint256 => Skill) where Skill starts with (address creator, uint256 price, ...)
    // slot of skills[skillId] = keccak256(abi.encode(skillId, 2))
    // price is at base_slot + 1
    const { keccak256, encodePacked, encodeAbiParameters, pad, toHex } = await import("viem");
    const baseSlot = keccak256(encodeAbiParameters(
      [{ type: "uint256" }, { type: "uint256" }],
      [BigInt(skillId), 1n]
    ));
    const priceSlot = toHex(BigInt(baseSlot) + 1n, { size: 32 });
    const raw = await publicClient.getStorageAt({ address: contractAddress, slot: priceSlot });
    return BigInt(raw);
  }

  async function invoke({ skillId }) {
    const priceResult = await getSkillPrice(skillId);

    const hash = await walletClient.writeContract({
      address: contractAddress,
      abi: CASCADE_ABI,
      functionName: "invoke",
      args: [BigInt(skillId)],
      value: priceResult
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    return {
      hash,
      paid: formatEther(priceResult),
      explorer: `${chain.blockExplorers.default.url}/tx/${hash}`
    };
  }

  async function claim() {
    const balance = await getBalance(account.address);
    if (balance === 0n) return { hash: null, amount: "0", message: "Nothing to claim" };

    const hash = await walletClient.writeContract({
      address: contractAddress,
      abi: CASCADE_ABI,
      functionName: "claim",
      args: []
    });

    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    return {
      hash,
      amount: formatEther(balance),
      explorer: `${chain.blockExplorers.default.url}/tx/${hash}`
    };
  }

  async function getBalance(address) {
    const addr = getAddress(address || account.address);
    const result = await publicClient.readContract({
      address: contractAddress,
      abi: CASCADE_ABI,
      functionName: "balances",
      args: [addr]
    });
    return result;
  }

  async function getSkillCount() {
    return await publicClient.readContract({
      address: contractAddress,
      abi: CASCADE_ABI,
      functionName: "skillCount",
      args: []
    });
  }

  return {
    register,
    invoke,
    claim,
    getBalance,
    getSkillCount,
    getSkillPrice,
    account,
    contractAddress,
    chain
  };
}
