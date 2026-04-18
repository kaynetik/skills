# Chain Selection

How to choose a base chain or rollup for a new protocol or app. This is a **design** decision, not a tooling preference. Once shipped, migrating chains is expensive and damages composability.

## Inputs to the decision

Collect these before recommending anything:

| Input | Why it matters |
|-------|----------------|
| Target users (geo, wallet ownership, custody comfort) | Drives chain familiarity and onboarding flow |
| Required throughput (TPS, peak vs sustained) | Eliminates Ethereum L1 below ~$10 average tx value |
| Required latency / finality | Real-time apps need sub-second; settlement apps tolerate minutes |
| Composability requirements | Atomic composability requires same chain; cross-chain breaks atomicity |
| Cost sensitivity per user action | Sub-cent ops require Solana, low-fee L2, or app-chain |
| Programming language preference | Rust -> Solana, Move -> Aptos/Sui, Solidity -> EVM, Cairo -> StarkNet |
| Regulatory posture | Some chains (privacy L1s, certain L2s) carry compliance friction |
| Distribution channel | Telegram -> TON; Coinbase app -> Base; institutional -> Ethereum L1 |
| Existing liquidity / TVL dependency | If you need Aave/Uniswap/Curve liquidity, you need where they are |

## EVM L1 vs L2 vs non-EVM

```text
Need EVM compatibility (Solidity, MetaMask, existing tooling)?
|
|-- Yes -> EVM track
|   |
|   |-- Need maximum security / decentralization, willing to pay gas
|   |       -> Ethereum L1
|   |
|   |-- Need low fees + composability with existing DeFi
|   |       -> Arbitrum One (largest TVL) or Base (Coinbase distribution)
|   |
|   |-- Need ZK finality (no 7-day withdrawal delay)
|   |       -> zkSync Era / Linea / Scroll / StarkNet (Cairo, not Solidity)
|   |
|   `-- Need own chain with custom logic (sequencer, gas token, precompiles)
|           -> OP Stack rollup (Superchain) or Arbitrum Orbit chain
|
`-- No -> Non-EVM track (see reference/non-evm.md)
    |
    |-- Highest TPS, lowest fees, Rust ecosystem
    |       -> Solana
    |
    |-- Sovereign chain + IBC interop
    |       -> Cosmos SDK app-chain (CosmWasm or native modules)
    |
    `-- Telegram-native consumer apps
            -> TON
```

## EVM L2 differentiation matrix

For comparing rollups on a like-for-like basis. Read `reference/l2-and-rollups.md` for stack-level depth.

| L2 | Stack | Proof type | Native AA | Gas token | Key strength |
|----|-------|-----------|-----------|-----------|--------------|
| Arbitrum One | Nitro (Arbitrum Orbit base) | Optimistic (interactive fraud proofs) | No (use 4337/7702) | ETH | Largest DeFi TVL, mature tooling |
| Base | OP Stack | Optimistic (fault proofs live) | No (use 4337/7702) | ETH | Coinbase distribution + onramp |
| Optimism | OP Stack | Optimistic (fault proofs live) | No (use 4337/7702) | ETH | Superchain, public-goods funding |
| zkSync Era | ZK Stack (proprietary) | ZK validity | Yes (native, every account) | ETH | Native AA, fast finality |
| Linea | Linea (Consensys) | ZK validity | No | ETH | MetaMask alignment |
| Scroll | Scroll | ZK validity | No | ETH | EVM-equivalent ZK rollup |
| StarkNet | Starknet (proprietary) | ZK validity (STARKs) | Yes (native) | ETH or STRK | Cairo language, native AA |
| Polygon zkEVM | Polygon CDK | ZK validity | No | ETH | CDK app-chain stack |

> **Verify before recommending.** L2 stage classifications (Stage 0/1/2 per L2BEAT), TVL, fault-proof status, and decentralization roadmap change. Use `WebSearch` for current data.

## Cost vs latency vs trust tradeoff

```text
                    high cost
                        |
              Ethereum L1
                        |
                        |
                Optimistic L2 (Base, Arbitrum, Optimism)
                        |
high latency  -------- ZK L2 (zkSync, Linea, Scroll, StarkNet)
                        |
                Sovereign chain (Cosmos, app-chain)
                        |
                Solana
                        |
                    low cost
```

- **Optimistic rollups**: 7-day canonical withdrawal (third-party fast bridges shorten this with their own trust assumptions).
- **ZK rollups**: minutes to hours canonical withdrawal once proofs settle.
- **L1**: instant from L1's perspective, ~12 seconds per slot, ~6-12 minute economic finality post-Merge.
- **Solana**: ~400ms slot, ~12s economic finality.
- **Cosmos chains**: instant finality (Tendermint BFT), typically 5-7s.

## Composability rules

| Pattern | Composability |
|---------|--------------|
| Same L2, same chain | Atomic, synchronous |
| Same L1, different L2s | Async, requires bridge or shared sequencer |
| Same rollup stack (OP Superchain, Arbitrum Orbit cluster) | Native message passing, sub-day finality between chains |
| Different L1s (Ethereum + Solana) | Async, third-party bridge required |

If your protocol depends on calling another protocol synchronously (flash loan, oracle read, swap-in-the-same-tx), you must be on the **same chain** as that protocol. Cross-chain is only viable for state synchronization, not composition.

## App-chain decision

Build your own chain (OP Stack rollup, Arbitrum Orbit, Cosmos SDK, Polkadot parachain) only if at least one of:

- Throughput exceeds what shared L2s deliver at your peak load
- Custom precompiles or VM modifications are required
- Custom gas token is a product requirement (not a marketing wish)
- Sequencer policy must differ from shared L2 sequencer
- Privacy or compliance requires isolated state

App-chain costs: sequencer infra, security council, bridge to Ethereum, indexer, RPC, monitoring, validator coordination (Cosmos), and reduced composability with mainnet DeFi.

## Migration cost

Switching chains after launch is expensive. Plan for it only if:

- The chain you want does not exist or is not yet production-ready
- Your design genuinely cannot work on existing chains (rare)

A common alternative is **multi-deploy**: deploy the same contracts on multiple chains via deterministic CREATE2, treat each as an isolated instance, and bridge state explicitly when needed. See `reference/deployment-ops.md`.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| "Build on chain X because it's hot right now" | Demand a user-need or technical justification |
| "We need our own L1 / L2" without throughput data | Start on a shared L2; graduate later if real load demands it |
| "Multi-chain from day one" without cross-chain need | Pick one chain, ship, then expand based on user pull |
| "Use whatever the team knows" without users in mind | Team velocity matters, but distribution and ecosystem fit matter more |
| Picking based on a grant program | Grants pay once; chain quality determines runway |
