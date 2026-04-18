---
name: web3-frontend
description: Production-grade dApp frontend engineering in Next.js 16 (App Router) with wagmi v2, viem, and RainbowKit. Covers Server vs Client Component boundaries, SSR-safe wagmi config with cookie hydration, on-chain reads (single, multicall, server-side), transaction lifecycle UX, ENS, network guards, SIWE auth, ABI codegen, Next.js 16 cache directives ('use cache', cacheLife, cacheTag), account abstraction, and Web3 anti-patterns. Use when building dApps, wallet integrations, DeFi or NFT interfaces, transaction flows, multi-chain UIs, or any blockchain-connected Next.js frontend, or when the user mentions wagmi, viem, RainbowKit, ConnectKit, SIWE, MetaMask, WalletConnect, useReadContract, useWriteContract, ERC-20, ERC-721, ERC-4337, or dApp UX.
---

# Web3 Frontend (Next.js 16 + wagmi v2)

Routing-first skill. The body is intentionally thin; depth lives in `reference/`. Open only the files you actually need to answer the question.

## Token economy rules for the agent

Read these before doing anything else. They cut answer cost by 3-5x without losing quality.

1. **Do not inline boilerplate the user already has access to.** Cite the reference path (e.g. `reference/setup.md#wagmi-config`) and write only the diff or the new logic.
2. **Read at most 2 reference files per turn.** Use the routing table to pick. If a task spans more, ask the user which surface matters first.
3. **Never reproduce ABIs in chat.** Tell the user to run `wagmi generate` (see `reference/abi.md`) and import typed ABIs.
4. **Never paste full provider trees.** Show only the lines that change.
5. **Prefer tables and bullet lists over prose** when explaining choices, lifecycles, or trade-offs.
6. **Verify version-specific APIs via Context7** for wagmi, viem, Next.js, RainbowKit, ConnectKit, and SIWE before quoting hook names or directives. Treat any pre-2026 syntax in your training data as suspect.

## Routing table

| Task | File |
| :--- | :--- |
| Install, providers, wagmi config, SSR cookie storage | [reference/setup.md](reference/setup.md) |
| `useReadContract`, multicall, server-side viem reads, event watching | [reference/reading.md](reference/reading.md) |
| Transactions: signature -> mining -> receipt, error parsing, gas, AA | [reference/writing.md](reference/writing.md) |
| Connect button, ENS, network guard, account-change handling | [reference/wallet-ux.md](reference/wallet-ux.md) |
| Next.js 16 cache directives, hydration boundary, prefetching on-chain data | [reference/ssr-caching.md](reference/ssr-caching.md) |
| SIWE login, session cookies, NextAuth integration | [reference/auth.md](reference/auth.md) |
| `wagmi cli` codegen, address tables per chainId, typed ABIs | [reference/abi.md](reference/abi.md) |
| Footguns: hydration, FOUC, RPC leaks, infinite renders, race conditions | [reference/anti-patterns.md](reference/anti-patterns.md) |

## Golden rules (non-negotiable)

These prevent the most common production failures. Internalize before reading anything else.

1. **Never import `wagmi`, `viem` browser primitives, or any wallet connector inside a Server Component.** Wrap any wallet-aware UI under a `'use client'` boundary.
2. **Use cookie-based wagmi storage in SSR Next.js apps.** Default `localStorage` storage causes hydration mismatches. See `reference/setup.md`.
3. **Render disconnected state by default on SSR.** Never branch on `isConnected` server-side; defer wallet checks to a client effect or a guarded client component.
4. **Never leak server-only RPC URLs through `NEXT_PUBLIC_*` envs.** Public RPC endpoints belong in `NEXT_PUBLIC_*`; private keyed RPCs belong in non-prefixed envs and are used only on the server (route handlers, Server Actions, RSC fetches that proxy to viem).
5. **Always parse errors via wagmi's typed error classes.** Show `error.shortMessage` to users; never raw revert bytes or raw RPC strings.
6. **Always link confirmed tx hashes to a block explorer scoped to the active `chainId`.** Hardcoded explorer URLs are a multi-chain bug.
7. **Use `as const` on every ABI literal you do not import from `viem`.** Type inference for `useReadContract` / `useWriteContract` collapses without it.

## Default stack (one choice, one escape hatch)

| Concern | Default | Escape hatch |
| :--- | :--- | :--- |
| Wallet connection | wagmi v2 + viem | -- |
| Connect UI | RainbowKit | ConnectKit when you need a minimal headless flow |
| Chain config | `viem/chains` | Custom chain object for L2s not yet in viem |
| Indexing / history | The Graph | Ponder or Envio for self-hosted indexers |
| Real-time events | viem `watchContractEvent` (client) | WebSocket transport via `webSocket()` |
| Auth | SIWE + signed cookie session | NextAuth + SIWE provider for full session orchestration |
| ABI typing | `wagmi cli` codegen | Hand-curated `as const` ABI literals |

If the user explicitly chose another stack, do not argue; help them with what they have.

## Decision matrix: where does this code go?

| Need | Component type | Why |
| :--- | :--- | :--- |
| Static layout, metadata, server-fetched REST/GraphQL | Server Component | No wallet involvement |
| Public, address-agnostic on-chain read (e.g. token total supply) | Server Component using viem `createPublicClient` | Cacheable, no wallet, runs on the edge or Node |
| Anything that reads `useAccount`, `useChainId`, signer, or balances of the connected wallet | Client Component | Browser-only state |
| Transaction submit / sign | Client Component | Requires injected provider |
| Hybrid (server-prefetched, client-interactive) | Server Component prefetches via viem; passes data to a Client Component child | See `reference/ssr-caching.md` for hydration boundary pattern |

## When NOT to apply this skill

- Smart contract authoring, security review, or audits -> use `solidity-security` or `ultimate-web3-engineer`.
- Smart contract testing (Hardhat/Foundry) -> use `web3-testing`.
- Pure design tokens, typography, color systems -> use `frontend-design`.
- Generic Next.js questions with no wallet/chain involvement -> use base Next.js knowledge; do not load this skill's reference files.

## Companion skills

- `frontend-design` -- visual design tokens, motion, typography
- `ultimate-web3-engineer` -- contract architecture and audits
- `web3-testing` -- contract test suites
- `solidity-security` -- contract-side hardening
