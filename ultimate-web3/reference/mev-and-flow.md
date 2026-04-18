# MEV and Order Flow

Maximal Extractable Value is a tax on naive transaction submission. Architectural choices determine whether your protocol or your users pay it.

## Threat model

| Attack | Target | Mitigation |
|--------|--------|-----------|
| **Sandwich** | DEX swap with slippage | Private mempool, tight slippage, limit orders, order-flow auction |
| **Frontrun** | Discoverable profitable action (oracle update, liquidation, mint) | Commit-reveal, batch auction, private submission |
| **Backrun** | Arbitrage after a price-moving transaction | Often benign (improves price); can be captured by builder |
| **Liquidation race** | Lending protocol liquidations | Dutch auction (Aave-style) or bot-friendly explicit incentive |
| **Long-tail MEV** (just-in-time liquidity, oracle MEV, NFT mint) | Various | Domain-specific design; see below |

## Where MEV is extracted

```text
User submits tx -> wallet -> RPC -> public mempool -> searcher sees it
                                            |
                                            |-- bundles with frontrun + backrun
                                            v
                             builder -> proposer -> block

Or:

User submits tx -> private RPC (Flashbots Protect, MEV Blocker) -> protected
```

## User-side protection

For wallets and dApp transaction submission:

| Tool | What it does |
|------|--------------|
| **Flashbots Protect** | Private RPC; only the chosen builder sees the tx; refund of backrun MEV to user (rebate) |
| **MEV Blocker** | Private RPC; multi-builder auction; rebates to user |
| **CoW Swap** | Off-chain order book + on-chain batch auction; uniform clearing price prevents sandwich |
| **UniswapX / 1inch Fusion** | Intent-based swap; solver competes to fill; user signs intent off-chain |

For consumer dApps, **default to a privacy-preserving RPC** (Flashbots Protect or MEV Blocker) for transaction submission. wagmi and RainbowKit support custom RPCs trivially.

## Protocol-side design

If your protocol creates extractable value, decide who captures it:

| Strategy | Who captures | Tradeoff |
|----------|--------------|----------|
| **Public mempool** (default) | Searcher / builder | Worst for users, simplest for protocol |
| **Private mempool integration** (Flashbots Protect bundle) | User (rebate) | Requires UX integration |
| **Order-flow auction** (CoW, UniswapX, 1inch Fusion) | Solver wins; user gets best-of-N | Requires off-chain solver network |
| **Commit-reveal** | Nobody (eliminates frontrun) | Two-tx UX, capital lock during commit window |
| **Batch auction** | Uniform price, no intra-batch ordering | Latency (batches every N seconds) |
| **Explicit incentive** (liquidation bonus) | Bot operators, by design | Predictable but capped revenue to MEV |
| **Internal MEV capture** (protocol-owned solver) | Protocol treasury | Centralization risk, regulatory questions |

## Builder / relay landscape (Ethereum L1)

```text
Searcher -> bundle -> Builder (constructs blocks)
                          |
                          v
                       Relay (validates bundles, runs MEV-Boost)
                          |
                          v
                       Proposer (validator) selects highest-bid block
```

Notable builders: Beaverbuild, Titan, Rsync, Flashbots. Notable relays: Flashbots, Ultrasound, Agnostic, BloxRoute. **Verify with WebSearch**; this landscape shifts frequently.

For an architecture-level decision: you do not interact with builders directly unless you are running a searcher operation. Default to user-side privacy via Flashbots Protect / MEV Blocker.

## L2 MEV

L2 sequencers see all incoming transactions (centralized sequencer). Implications:

- The sequencer can frontrun (most do not, but it is a trust assumption)
- No public mempool means no public-mempool searchers
- Some L2s (Arbitrum) have FCFS sequencing; others (Base) are working on encrypted mempools
- Once decentralized sequencing arrives, expect MEV economics similar to L1

For protocol design on L2: assume the sequencer is honest **today** but design for the future where it is not. Use commit-reveal or batch settlement for high-value actions.

## Order-flow auctions (OFA)

Pattern adopted by CoW, UniswapX, 1inch Fusion, and 0x Settler:

```text
User signs intent ("swap 1 ETH for >= 3500 USDC by deadline T")
        |
Solvers compete to fill the intent (off-chain auction)
        |
Winning solver submits the on-chain settlement
        |
User gets execution at >= the limit price
```

Properties:

- User has no slippage exposure beyond the limit price
- Sandwiching is impossible (solver bears any slippage)
- MEV is captured by the solver; competition compresses solver margin
- Latency: typically 1-12 seconds (auction window + L1 inclusion)

For consumer DEX UX, **OFA is the default in 2025-2026**, not naive AMM swaps with slippage tolerance.

## Domain-specific MEV

| Domain | MEV vector | Standard mitigation |
|--------|-----------|---------------------|
| AMM swap | Sandwich | Private RPC, tight slippage, OFA |
| Lending liquidation | Race for bonus | Dutch auction (lower bonus over time) or capped bonus |
| Oracle update | Frontrun the price change | Commit-reveal price update or use pull-based oracles in same tx |
| NFT mint | Frontrun the mint tx | Allowlist, commit-reveal, dutch auction mint |
| Arbitrage between DEXes | Backrun any liquidity-moving tx | Generally healthy; let it happen |
| New token launch | Sniping bots | Anti-bot mechanisms (max wallet, transfer cooldown) -- carefully, do not break composability |

## Tools and references

- `mev-inspect-py` (Flashbots): post-hoc MEV detection on a transaction or block
- Eden / EigenPhi / Libmev: dashboards for MEV activity
- Flashbots docs: searcher and builder primers
- CoW Protocol docs: batch auction design

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| dApp uses default public RPC for swap submission | Switch default RPC to Flashbots Protect or MEV Blocker |
| 0.5% slippage tolerance baked into UI without context | Show user expected vs max slippage; route via OFA when possible |
| Liquidation bonus = 10% with no auction | Dutch auction; start high, decrease over time |
| Commit-reveal with too-short reveal window | Allow at least N blocks; account for reorg risk |
| Protocol "captures MEV" with off-chain solver and no transparency | Publish auction results, solver list, fill rates |
| Building a custom OFA when CoW / UniswapX integration would suffice | Integrate, do not reinvent unless OFA is your product |
| Assuming L2 sequencer will never frontrun | Document the trust assumption; design escape hatches |
