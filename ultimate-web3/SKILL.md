---
name: ultimate-web3
description: Architecture and protocol-design layer for production Web3. Covers chain selection (EVM L1/L2, Solana, Cosmos, TON), Solidity architecture (proxies, diamonds, factories), L2/rollup stack choice (OP Stack, Arbitrum Orbit, ZK stacks, EIP-4844), account abstraction (ERC-4337, EIP-7702, ERC-6900), bridges (LayerZero, CCIP, Wormhole, intents), oracles and indexers (Chainlink, Pyth, Ponder, Envio), MEV and order-flow, custody (multisig, MPC, Safe), privacy L1 (zk-SNARKs, stealth addresses), governance (Governor, timelocks), deployment ops (CREATE2, Tenderly, Defender), and architectural anti-patterns. Use when designing a protocol, choosing a chain or rollup, planning cross-chain or multi-chain systems, hardening custody, planning deployment and incident response, designing governance, or when the user mentions architecture, proxy, diamond, OP Stack, Arbitrum Orbit, ERC-4337, EIP-7702, LayerZero, CCIP, Chainlink, MEV, multisig, MPC, Safe, Tenderly, Defender, or "which chain should I use".
---

# Ultimate Web3 (Architecture & Strategy)

Architect-level skill for cross-chain, cross-discipline Web3 design decisions. The body is intentionally thin; depth lives in `reference/`. Open only the files you actually need.

## Companion skills (route to these first)

This skill is the **architecture layer**. Defer to companion skills for their domains:

| Domain | Use skill |
|--------|-----------|
| dApp frontend (wagmi, viem, RainbowKit, SIWE, Next.js dApps) | `web3-frontend` |
| Smart contract testing (Foundry, Hardhat, fuzz, invariants, fork) | `web3-testing` |
| Solidity vulnerability classes and secure coding patterns | `solidity-security` |
| Whitepaper / litepaper authoring | `whitepapers` |
| Public-facing token / staking / governance copy review | `legalizer` |

If the question is about **how to build** something at the implementation layer, route to the specialist skill above. Use **this** skill for **what to build, on which platform, with which architecture, and how to operate it**.

## Token economy rules for the agent

1. Do not paste back code the user already shared.
2. Read at most 2 reference files per turn. Choose by the routing table below.
3. Never inline content from a companion skill (frontend code, test code, vulnerability classes); link to the companion skill instead.
4. Prefer tables, decision trees, and matrices over prose.
5. Use `WebSearch` for L2 rankings, TVL, bridge security incidents, and active EIPs. Do not memorize dynamic facts.
6. When the user asks "which chain / which rollup / which bridge / which oracle", read `reference/chain-selection.md` first; do not improvise a recommendation.

## Routing table

| User intent or keyword | Open file |
|------------------------|-----------|
| "which chain", "EVM vs Solana", "L1 vs L2", "app-chain", platform tradeoffs | `reference/chain-selection.md` |
| Proxy, UUPS, transparent proxy, diamond, ERC-2535, factory, modular contracts, hooks | `reference/solidity-architecture.md` |
| OP Stack, Arbitrum Orbit, zkSync, Linea, Scroll, Base, app-chain vs general L2, EIP-4844, blob | `reference/l2-and-rollups.md` |
| Solana, Anchor, PDA, CPI, Cosmos, CosmWasm, IBC, app-chain SDK, TON, Tact, FunC | `reference/non-evm.md` |
| ERC-4337, EntryPoint, bundler, paymaster, EIP-7702, ERC-6900, session keys, gasless, smart account | `reference/account-abstraction.md` |
| Bridge, LayerZero, Wormhole, CCIP, Axelar, Across, intent-based, lock-and-mint, burn-and-mint | `reference/bridges-and-interop.md` |
| Oracle, Chainlink, Pyth, Redstone, UMA, TWAP, indexer, The Graph, Ponder, Envio, Goldsky | `reference/oracles-indexers.md` |
| MEV, sandwich, frontrun, private mempool, Flashbots, MEV-Boost, builder, OFA, CoW, UniswapX, 1inch Fusion | `reference/mev-and-flow.md` |
| Custody, multisig, Safe, Gnosis, MPC, Fireblocks, HSM, threshold signatures, deploy keys, hot wallet | `reference/custody-and-keys.md` |
| Privacy L1, zk-SNARK, zk-STARK, ring signature, stealth address, Bulletproof, Tornado, Aztec, Aleo, encrypted state | `reference/privacy-l1.md` |
| Governance, Governor, Snapshot, Tally, timelock, delegate, voting power, conviction voting, futarchy | `reference/governance.md` |
| Deployment, CREATE2, deterministic deploy, Etherscan verification, monitoring, Tenderly, Defender, Forta, incident response | `reference/deployment-ops.md` |
| "is this an anti-pattern", "footgun", architecture review, common mistakes | `reference/anti-patterns.md` |

## Golden rules (non-negotiable)

1. **Custody is design, not configuration.** Decide hot/warm/cold separation, multisig/MPC, deploy-key isolation, and rotation policy **before** writing the first line of contract code. See `reference/custody-and-keys.md`.
2. **Choose the rollup stack before the chain.** OP Stack vs Arbitrum Orbit vs ZK stacks affects bridges, gas economics, blob inclusion, and decentralization roadmap more than the brand name. See `reference/l2-and-rollups.md`.
3. **Bridges are your weakest link.** Cross-chain messaging has caused most of the largest exploits in Web3 history. If you can avoid bridging, do. If you must bridge, prefer canonical bridges or intent-based systems with explicit settlement guarantees. See `reference/bridges-and-interop.md`.
4. **Oracles are part of your trust model.** Push vs pull, single oracle vs aggregate, manipulation cost, staleness checks, and TWAP windows are protocol-level decisions, not integration details. See `reference/oracles-indexers.md`.
5. **Upgradeability is a liability.** Proxies are not free: storage layout, initializer races, admin compromise, and selector clashes are all real. Pin a clear upgrade strategy (none / UUPS / diamond / migrate-by-deploy) and document it. See `reference/solidity-architecture.md`.
6. **Deployment is a protocol moment, not a sysadmin task.** Multi-chain CREATE2, deterministic addresses, verification across explorers, post-deploy monitoring, and pause/freeze paths must exist on day one. See `reference/deployment-ops.md`.
7. **Verify before recommending.** Use `WebSearch` for current L2 stage classifications, TVL, bridge incidents, EntryPoint version, and active EIPs. Ecosystem facts change month-to-month.

## Default stack matrix

Defaults to use unless the user has different constraints. Document any deviation.

| Layer | Default | When to deviate |
|-------|---------|-----------------|
| Smart contract language (general) | Solidity, latest stable (>= 0.8.26) | Vyper for math-heavy DeFi, Yul for hot paths |
| EVM contract framework | Foundry | TypeScript-first team -> Hardhat 3 (route to `web3-testing`) |
| Solidity standard library | OpenZeppelin Contracts (audited release) | Solady for gas-critical primitives |
| Upgradeability (when needed) | UUPS via OpenZeppelin Upgrades | Diamond (ERC-2535) only when modular plugin extensibility is a real requirement |
| Multisig | Safe (formerly Gnosis Safe) | Custom only with a strong reason and an audit |
| Governance contracts | OpenZeppelin Governor + Timelock | Snapshot-only off-chain when no on-chain execution |
| Oracle (price) | Chainlink Data Feeds | Pyth for high-frequency / non-EVM, Redstone for low-cap assets, UMA for optimistic |
| Cross-chain messaging | Native L1<->L2 canonical bridges | LayerZero / CCIP only with explicit security analysis |
| Indexer | Ponder or Envio (TS, self-hosted) | The Graph for decentralized indexing requirements |
| Monitoring | OpenZeppelin Defender + Tenderly Web3 Actions | Forta detection bots for high-value protocols |
| L2 (consumer app, EVM) | Base | Arbitrum for DeFi composability, Optimism for OP Stack ecosystem |
| L2 (DeFi, EVM) | Arbitrum One | Base for Coinbase distribution |
| Non-EVM high-throughput | Solana (Anchor) | Aptos / Sui only with explicit ecosystem reason |
| App-chain (cosmos ecosystem) | Cosmos SDK + CosmWasm | Polkadot parachain only with cross-parachain requirement |
| Wallet for end users | Smart account (EIP-7702 enhanced EOA where supported, ERC-4337 otherwise) | Plain EOA only for power users / dev tooling |

## Chain decision shortcut

If you only have time to read one tree, read this. For depth, see `reference/chain-selection.md`.

```text
Constraint -> Default chain
|
|-- "EVM compatibility required"
|   |-- "Coinbase / consumer distribution"     -> Base
|   |-- "DeFi composability, deepest TVL"      -> Arbitrum One
|   |-- "ZK finality required"                 -> zkSync Era / Linea / Scroll / StarkNet
|   |-- "Need own chain, EVM"                  -> OP Stack rollup or Arbitrum Orbit
|   `-- "L1 only, conservative"                -> Ethereum mainnet
|
|-- "Highest throughput, lowest cost"
|   |-- "Rust team"                            -> Solana (Anchor)
|   `-- "Move team"                            -> Aptos or Sui (verify ecosystem fit first)
|
|-- "Sovereign chain, IBC interop"             -> Cosmos SDK + CosmWasm
|-- "Telegram-native distribution"             -> TON (Tact)
`-- "Privacy-first, novel L1"                  -> Custom design (read privacy-l1.md)
```

## When NOT to apply this skill

- **Frontend implementation**: `web3-frontend` (wagmi, viem, RainbowKit, SIWE, transaction UX).
- **Test writing**: `web3-testing` (Foundry, Hardhat, fuzz, invariants, fork).
- **Solidity vulnerability prevention at the function level**: `solidity-security`.
- **Whitepaper structure and citations**: `whitepapers`.
- **Public-facing token / governance copy review**: `legalizer`.
- **Pure cryptography research** (new ZK schemes, novel signature constructions): out of scope.

If the question fits one of the above, route there and stop reading this skill.
