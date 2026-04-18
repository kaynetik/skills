# L2s and Rollups

Architectural depth on Ethereum L2s and rollup stacks. Use this when choosing **which stack to build on or with**, not only which chain to deploy to.

## Rollup stacks (you choose a stack, not a chain)

| Stack | Examples | Proof | Sequencer | Notes |
|-------|----------|-------|-----------|-------|
| **OP Stack** | Optimism, Base, Worldcoin, Mode, Zora, INK | Optimistic + fault proofs | Single (per-chain), Superchain shared sequencer in roadmap | Most adopted L2 stack; cross-chain messaging via Superchain interop in development |
| **Arbitrum Orbit / Nitro** | Arbitrum One, Arbitrum Nova, Apechain, Xai | Optimistic + interactive fraud proofs (BoLD) | Single (Offchain Labs), permissionless validators | Strongest fraud-proof system in production |
| **ZK Stack (Matter Labs)** | zkSync Era, Abstract, Cronos zkEVM | ZK validity (PLONK) | Single | Native account abstraction at every account |
| **Polygon CDK** | Polygon zkEVM, X Layer (OKX), Astar zkEVM | ZK validity | Single | App-chain stack with shared bridge (AggLayer) |
| **Linea** (Consensys) | Linea | ZK validity | Single (Consensys) | MetaMask alignment |
| **Scroll** | Scroll | ZK validity | Single | EVM-equivalent at bytecode level |
| **Starknet stack** | Starknet, Paradex, Madara app-chains | ZK validity (STARKs) | Single (StarkWare) | Cairo language, not Solidity |

> Stage classification (Stage 0 / 1 / 2) per L2BEAT measures decentralization of upgrade authority and fraud-proof readiness. Verify current stages with `WebSearch`; they change.

## When to build your own L2 (app-chain)

Build a custom rollup only if:

- Throughput on shared L2s is insufficient at peak load (verify with measurements, not guesses)
- You need a custom gas token as a product requirement
- You require modified VM behavior (custom precompiles, gas accounting)
- You need an isolated, controllable sequencer policy (e.g. for compliance or MEV capture)
- You need a permissioned validator set or custom data availability

Costs to budget for:

- Sequencer infrastructure (HA, monitoring, MEV policy)
- Bridge to Ethereum (canonical or third-party)
- Block explorer (Etherscan, Blockscout instance)
- Indexer infrastructure (cannot rely on The Graph or Ponder for an unknown chain initially)
- Validator/proposer key management
- Security council (multisig for emergency upgrades / pauses)
- DA decision: Ethereum blobs (most secure, most expensive) vs alt-DA (Celestia, EigenDA, Avail)

## EIP-4844 blobs (proto-danksharding)

Live since Dencun (March 2024). Key facts:

- Blobs are ephemeral data (~18 days), separate from calldata
- Cost: blob gas, priced independently from execution gas
- Each blob: 128KB; up to 6 per block (target 3, max 6 today)
- Rollups post compressed batches as blob data; KZG commitment on-chain
- Blob fee market is independent: rollup costs decouple from L1 base fee for data

Architectural implication: rollup gas costs to users are now dominated by **execution gas** on the rollup, not L1 data costs. This makes high-frequency DeFi viable on optimistic L2s.

## Data availability options

| Option | Trust | Cost | Use case |
|--------|-------|------|----------|
| Ethereum blobs (EIP-4844) | Ethereum L1 | Highest | All "true" rollups; required for Stage 1+ |
| EigenDA | Restaked ETH | Low | App-chains willing to trust EigenLayer operators |
| Celestia | Celestia validator set | Low | Sovereign rollups, modular stacks |
| Avail | Avail validator set | Low | Polygon CDK chains |
| In-house / centralized | The chain operator | Lowest | Validium / "rollup" not actually a rollup |

Anything not posting to Ethereum L1 is **not a true rollup**; it is a validium or optimium with weaker security guarantees. Be explicit when describing the system.

## Cross-L2 messaging

```text
Source L2 -> L1 -> Destination L2

Latency = source L2 finality + L1 settlement + dest L2 inclusion
       = optimistic L2: 7 days canonical
       = ZK L2: hours (proof generation + L1 inclusion)
```

Faster paths:

- **Same-stack interop**: Superchain (OP Stack) and AggLayer (Polygon CDK) plan sub-day cross-chain messaging within their ecosystems
- **Third-party messaging**: LayerZero, CCIP, Hyperlane (see `reference/bridges-and-interop.md`)
- **Intent-based bridges**: Across, deBridge -- relayers front the funds, settle later (seconds for user, hours for relayer)

## Sequencer decentralization

Most L2s today have a **single sequencer** operated by the rollup team. Implications:

- Censorship risk (sequencer can refuse a transaction)
- MEV capture (sequencer sees the mempool)
- Liveness risk (sequencer outage = no L2 transactions)

Mitigations:

- **Force-include path**: every credible rollup has an L1 escape hatch (typically 12-24 hour delay)
- **Shared sequencer**: Espresso, Astria, Nodekit (research-stage to early production)
- **Decentralized sequencer set**: in roadmap for Optimism, Arbitrum, others

If you build on an L2 and your design assumes the sequencer is honest, document that as a trust assumption.

## L2 onboarding / offboarding UX

Canonical bridges from L1 are slow. Real users use third-party bridges. Architectural choice:

| Option | Latency | Trust |
|--------|---------|-------|
| Canonical bridge (deposit) | Minutes (L1 inclusion + L2 indexing) | Rollup operator |
| Canonical bridge (withdraw, optimistic L2) | 7 days | Rollup operator |
| Canonical bridge (withdraw, ZK L2) | Hours (proof time) | Rollup operator |
| Third-party fast bridge (Hop, Across, Stargate) | Seconds-minutes | Bridge operator + LP |
| Centralized exchange | Minutes | CEX |

For consumer apps, integrate a bridging widget (e.g. LI.FI, Socket, Squid) rather than asking users to find bridges themselves.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| "We're a rollup" but data is not on Ethereum | Call it a validium / optimium; do not claim rollup security |
| Building app-chain to "capture sequencer revenue" with no users | Validate users first on shared L2 |
| Hardcoding L2 chain ID without considering testnet/mainnet split | Use `block.chainid` and a chain-aware config |
| Assuming cross-L2 calls are atomic | They are not; design async-first |
| Ignoring force-include path in trust analysis | Document it; it is a real censorship-resistance guarantee |
| Picking L2 by TVL screenshot | Measure user fit, not vanity metrics |
