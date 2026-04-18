# ABI and address management

Read when: pulling contract types into the dApp, configuring `wagmi cli`, or organizing address tables across chains.

## Why codegen, not hand-written ABIs

| Approach | Cost | Risk |
| :--- | :--- | :--- |
| Paste ABI JSON inline | Bloats source files; agent will spend tokens reproducing it | Drift when contract changes |
| Hand-typed `as const` ABI literal | Verbose; easy to typo argument types | Inference breaks silently |
| `wagmi cli` codegen from artifact / Etherscan / Foundry | One-line generation | Almost none |

Default to codegen. Recommend `wagmi cli` to the user instead of pasting any ABI longer than ~5 functions.

## wagmi cli setup

```bash
npm i -D @wagmi/cli
```

```ts
// wagmi.config.ts
import { defineConfig } from '@wagmi/cli'
import { foundry, etherscan } from '@wagmi/cli/plugins'

export default defineConfig({
  out: 'lib/contracts/generated.ts',
  contracts: [],
  plugins: [
    foundry({
      project: '../contracts',
      include: ['Vault.json', 'Token.json'],
    }),
    etherscan({
      apiKey: process.env.ETHERSCAN_API_KEY!,
      chainId: 1,
      contracts: [
        { name: 'Uniswap', address: '0x...' },
      ],
    }),
  ],
})
```

```bash
npx wagmi generate
```

Output is a single file with typed ABIs and (optionally) typed React hooks per function. Import from there everywhere.

| Plugin | Source | When |
| :--- | :--- | :--- |
| `foundry` | Local Foundry artifact dir | Monorepo with the contracts beside the frontend |
| `hardhat` | Local Hardhat artifact dir | Same, Hardhat-based |
| `etherscan` | Verified contract on a block explorer | External / third-party contracts |
| `react` (extra) | Generates `useReadVaultBalanceOf` etc. hooks | Optional ergonomic boost; some prefer plain hooks for flexibility |

## Address tables (chain-aware)

Never hardcode an address inline. Centralize per-chain mappings:

```ts
// lib/contracts/addresses.ts
import { mainnet, base, arbitrum } from 'viem/chains'
import type { Address } from 'viem'

export const VAULT_ADDRESS = {
  [mainnet.id]: '0x...' as const,
  [base.id]: '0x...' as const,
  [arbitrum.id]: '0x...' as const,
} as const satisfies Record<number, Address>

export type SupportedChainId = keyof typeof VAULT_ADDRESS
```

Usage:

```tsx
const chainId = useChainId()
if (!(chainId in VAULT_ADDRESS)) return <UnsupportedChainNotice />
const address = VAULT_ADDRESS[chainId as SupportedChainId]
```

The `satisfies` clause forces type-checking without widening, so missing chains are compile errors.

## ABI literals (when codegen is overkill)

For ad-hoc reads where you do not want a generation step:

```ts
import { parseAbi } from 'viem'

export const ERC20_PARTIAL = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function transfer(address, uint256) returns (bool)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
])
```

`parseAbi` accepts human-readable Solidity-style signatures and produces a fully typed ABI. No `as const` gymnastics, no JSON.

For common standards, viem ships pre-baked ABIs:

```ts
import { erc20Abi, erc721Abi, erc4626Abi } from 'viem'
```

Use these instead of generating your own ERC-20 ABI.

## Type extraction

For shared types across the app:

```ts
import type { AbiParametersToPrimitiveTypes, ExtractAbiFunction } from 'abitype'
import { VAULT_ABI } from './generated'

type DepositArgs = AbiParametersToPrimitiveTypes<
  ExtractAbiFunction<typeof VAULT_ABI, 'deposit'>['inputs']
>
```

`abitype` powers wagmi/viem's inference; you can use it directly to type forms, validators, and DTOs against the contract surface.

## Multi-version contracts

If different chains run different versions of your contract:

```ts
import { VAULT_V1_ABI } from './generated/v1'
import { VAULT_V2_ABI } from './generated/v2'

const vaultAbiByChain = {
  [mainnet.id]: VAULT_V2_ABI,
  [optimism.id]: VAULT_V1_ABI,
} as const
```

Then use the right ABI per chain. Never use a v2 ABI against a v1 deployment -- function selectors collide silently for changed signatures.

## Verification checklist

- [ ] All ABIs longer than ~5 functions come from `wagmi cli` codegen
- [ ] Standard ABIs (ERC-20, ERC-721, ERC-4626) imported from `viem`
- [ ] Address tables are `chainId` -> `Address` records with `as const satisfies`
- [ ] ABI literals (where used) go through `parseAbi`, not raw JSON
- [ ] Per-chain version differences modeled explicitly
- [ ] Generated file is checked in (or generated in CI) so type-checking works for everyone
