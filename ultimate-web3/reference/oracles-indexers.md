# Oracles and Indexers

External data and historical state. Both are protocol-level decisions, not integration details.

## Oracles

### Decision tree

```text
What kind of data?
|
|-- Asset price
|   |-- Blue-chip asset, EVM chain          -> Chainlink Data Feeds (push)
|   |-- High-frequency, non-EVM, low cost   -> Pyth (pull)
|   |-- Long-tail asset / new market         -> Redstone (pull, modular)
|   `-- Slow-moving, dispute-tolerant         -> UMA optimistic oracle
|
|-- Volatility / rate / yield                 -> Chainlink, Pyth, RedStone
|
|-- Random number
|   |-- VRF (commit-reveal randomness)       -> Chainlink VRF v2.5
|   `-- On-chain randomness from L1           -> RANDAO + commit-reveal wrapper
|
|-- Off-chain data / API result               -> Chainlink Functions, UMA, Reality.eth
|
|-- Cross-chain price                         -> CCIP + Chainlink, Pyth multi-chain
|
`-- Custom computation                        -> Chainlink Automation, Gelato
```

### Push vs pull oracles

| Property | Push (Chainlink Data Feeds) | Pull (Pyth, Redstone) |
|----------|----------------------------|----------------------|
| Update mechanism | Oracle posts on a heartbeat or deviation threshold | Consumer transaction includes a signed price update |
| Gas cost | Ongoing, paid by oracle network | Per-read, paid by consumer |
| Latency | Bounded by deviation threshold (often 0.5%) and heartbeat (hours) | Sub-second; consumer reads the latest signed price |
| Best for | EVM L1/L2 with predictable read patterns | High-frequency DeFi, Solana, low-cost chains |

### Mandatory checks when reading an oracle

```solidity
(, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
require(answer > 0, "negative or zero price");
require(block.timestamp - updatedAt < HEARTBEAT_TOLERANCE, "stale price");
require(answer >= MIN_REASONABLE && answer <= MAX_REASONABLE, "out of band");
```

Always:

- Check for **stale data** (heartbeat + tolerance)
- Check for **zero / negative** values
- Apply **sanity bounds** for the expected range of the asset
- For oracles with sequencer dependency on L2 (Chainlink on Arbitrum/Optimism/Base), check the **L2 sequencer uptime feed** before trusting the price

### Manipulation resistance

| Threat | Defense |
|--------|---------|
| Spot price manipulation in low-liquidity DEX | Use Chainlink/Pyth, not Uniswap spot |
| TWAP manipulation via flash-loan liquidity changes | Long TWAP windows (>= 30 min), or aggregate multiple sources |
| Single oracle compromise | Aggregate at least two independent oracles (Chainlink + Pyth) for high-value assets |
| Sequencer downtime on L2 | Pause liquidations during sequencer outage (Aave pattern) |

For lending protocols and AMMs: use Chainlink for collateral pricing where available. For internal pricing of derivatives, prefer TWAPs with explicit windows over spot.

### Oracle anti-patterns

| Symptom | Fix |
|---------|-----|
| Reading Uniswap v3 spot for liquidation pricing | Use Chainlink or v3 TWAP with sufficient window |
| Trusting `priceFeed.latestAnswer()` without staleness check | Always use `latestRoundData` and validate `updatedAt` |
| Hardcoded `decimals = 8` assumption | Read `priceFeed.decimals()` per feed; not all are 8 |
| No fallback if oracle is paused | Pause your protocol or use a secondary feed |
| L2 deployment without sequencer uptime feed | Add the check for any Chainlink-based L2 integration |

## Indexers

### When you need an indexer

You need an indexer when any of:

- Your UI reads more than ~5 historical events per page load
- You need to query "all positions where X" or "leaderboard for Y"
- You need fast aggregations (TVL, volume, user count) without on-chain views
- You need to enrich on-chain data with off-chain data

If you only need current state, direct contract reads via viem multicall (see `web3-frontend/reference/reading.md`) are usually enough.

### Indexer choices

| Indexer | Model | When to use |
|---------|-------|-------------|
| **Ponder** | TS/Node, self-hosted, GraphQL or HTTP | Default for new EVM projects; tight types, hot reload, fast iteration |
| **Envio** | Self-hosted or hosted, ReScript / TS / JS, GraphQL | Multi-chain from one config, fastest indexing speeds |
| **Goldsky** | Hosted SaaS, subgraph-compatible | Drop-in subgraph hosting, Mirror pipelines, low ops |
| **The Graph (decentralized)** | Hosted by network indexers | Decentralized data needed; pay in GRT; production-stable |
| **Subsquid** | TS, hosted or self-hosted | Strong for high-throughput multi-chain |
| **Allium / Dune** | SQL warehouse | Analytics, not application-serving |
| **Custom (eth_getLogs + Postgres)** | Bespoke | Last resort; ops cost is high |

### Architectural decision

```text
Need decentralized indexing for trustlessness claim?
|-- Yes -> The Graph (decentralized network)
|
`-- No  -> Self-hosted or hosted SaaS
    |
    |-- Want lowest ops, default-grade quality   -> Goldsky (subgraph) or Envio (hosted)
    `-- Want full control, self-hosted          -> Ponder or Envio (self-hosted)
```

### Reorg handling

Indexers must handle reorgs (L1 ~6-12 minute economic finality; L2 reorgs rare but possible at the L1-confirmed level). Verify your indexer's reorg policy:

- Does it wait for N confirmations before serving data?
- Does it roll back state on reorg?
- Does it expose "finality" status per record?

For financial UIs, prefer indexers that wait for finality (or expose "pending" vs "final").

### Indexer + UI pattern

```text
Smart contract -> RPC (eth_getLogs / Solana getSignaturesForAddress / etc.)
                       |
                Indexer (Ponder, Envio, Goldsky)
                       |
                GraphQL / HTTP API
                       |
                Next.js RSC (cached) -> React Server Component
                       |
                Client Component (hydrated, with refetch)
```

Frontend integration patterns belong in `web3-frontend/reference/reading.md` and `web3-frontend/reference/ssr-caching.md`.

## On-chain analytics vs application data

Keep these separate in your stack:

- **Application data** (positions, balances, recent activity): Ponder / Envio / Goldsky, served via API to the dApp
- **Analytics** (TVL history, user funnels, cohort analysis): Dune, Allium, or your own warehouse

Do not run analytical queries against your application indexer in production; they will starve user-facing reads.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| dApp doing `eth_getLogs` from the browser | Move to indexer + cached API |
| Single subgraph for analytics + UI | Split: app indexer + warehouse |
| Indexer with no reorg policy | Wait for confirmations or expose finality status |
| Custom Postgres + scripts as indexer for serious project | Use Ponder / Envio; reinventing reorg + retry handling is a tar pit |
| Hosted indexer with no SLA in budget | Self-host or pay for SLA; do not deploy production on free tier |
| Querying The Graph (decentralized) without indexer redundancy | Pin multiple indexers; The Graph allocations change |
