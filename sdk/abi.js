export const CASCADE_ABI = [
  {
    type: "function",
    name: "register",
    inputs: [
      { name: "price", type: "uint256" },
      { name: "depIds", type: "uint256[]" },
      { name: "depShares", type: "uint256[]" }
    ],
    outputs: [{ name: "id", type: "uint256" }],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "invoke",
    inputs: [{ name: "skillId", type: "uint256" }],
    outputs: [],
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "claim",
    inputs: [],
    outputs: [{ name: "amount", type: "uint256" }],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "balances",
    inputs: [{ name: "", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "skillCount",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "event",
    name: "SkillRegistered",
    inputs: [
      { name: "id", type: "uint256", indexed: true },
      { name: "creator", type: "address", indexed: true },
      { name: "price", type: "uint256", indexed: false }
    ]
  },
  {
    type: "event",
    name: "Invoked",
    inputs: [
      { name: "skillId", type: "uint256", indexed: true },
      { name: "payer", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false }
    ]
  },
  {
    type: "event",
    name: "RoyaltyAccrued",
    inputs: [
      { name: "skillId", type: "uint256", indexed: true },
      { name: "creator", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false }
    ]
  },
  {
    type: "event",
    name: "Claimed",
    inputs: [
      { name: "creator", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false }
    ]
  }
];
