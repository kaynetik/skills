# Bridges and Interop

Cross-chain messaging is the highest-risk surface area in Web3. Bridges have been responsible for the largest single-event losses in the industry's history (Ronin, Wormhole, Nomad, Multichain, Harmony Horizon). Treat every bridge as a trust assumption you must justify.

## Decision tree

```text
Does your design require cross-chain state?
|
|-- No  -> stay on one chain
|
`-- Yes -> what kind of cross-chain?
    |
    |-- Asset transfer only (token bridge)
    |   |-- L1 <-> L2 of same rollup family -> use canonical bridge
    |   |-- Same rollup stack family (Superchain, AggLayer)  -> use stack-native bridge
    |   |-- General cross-chain asset      -> intent-based (Across, deBridge) for fast UX, lock-and-mint (LayerZero OFT, Wormhole NTT) for long-tail
    |
    |-- Arbitrary message passing (call A on chain X from chain Y)
    |   |-- L1 <-> L2 same family          -> canonical messaging (OP CrossDomainMessenger, Arbitrum Inbox)
    |   |-- Cross-stack (OP <-> Arb, EVM <-> Solana, etc.)
    |       -> evaluate LayerZero / CCIP / Wormhole / Hyperlane / Axelar
    |
    `-- Cross-chain liquidity (single tx settles multi-chain swap)
        -> intent-based settlement (Across, Catalyst, Mayan, deBridge DLN)
```

## Bridge taxonomy

| Type | How it works | Trust |
|------|--------------|-------|
| **Canonical L1<->L2 bridge** | Operated by the rollup; deposits via L1 contract, withdrawals via fraud/validity proof | Rollup operator + Ethereum L1 |
| **Lock-and-mint** | Lock asset on chain A, mint wrapped asset on chain B | Bridge multisig / validator set |
| **Burn-and-mint** | Native token contract on each chain mints / burns based on cross-chain message | Messaging layer + token contract logic |
| **Liquidity-pool bridge** | Source pool releases asset on dest chain from LP capital, rebalanced async | LP solvency + messaging layer |
| **Intent-based bridge** | User signs intent; relayer fronts funds on dest chain, claims source funds later | Relayer + dispute mechanism |
| **Optimistic bridge** | Messages execute optimistically; can be challenged within a window | Relayer + watcher set |
| **Zero-knowledge bridge** | ZK proof verifies source-chain state on dest chain | Cryptography + circuit correctness |

## Major messaging providers

| Provider | Model | Notes |
|----------|-------|-------|
| **Chainlink CCIP** | Decentralized oracle network + risk management network | Strong guarantees; higher latency and cost; opinionated default for institutional |
| **LayerZero v2** | Source endpoint + dest endpoint + configurable DVNs (security stack) + executor | Configurable security; DVN choice is a real trust decision |
| **Wormhole** | Guardian set (19 validators); NTT (Native Token Transfer) for assets, generic messaging for calls | Large ecosystem; Solana, EVM, Cosmos, Aptos, Sui |
| **Axelar** | PoS validator set with light-client verification | Cosmos-native, EVM bridges; General Message Passing (GMP) |
| **Hyperlane** | Permissionless deployment; modular Interchain Security Modules (ISM) | You configure your own security; useful for app-chains |
| **Across** | Intent + UMA optimistic oracle settlement | Fast UX (seconds), strong for asset transfers |
| **deBridge** | Intent + signed orders | DLN order-flow for swaps |
| **IBC** | Light-client based, Cosmos-native | Permissionless, no trusted relayer; only between IBC-enabled chains |

## Risk model checklist

For any bridge or messaging layer, document explicitly:

- **Validator/oracle/DVN set size** and accountability mechanism
- **Slashing or punishment** for misbehavior (and who collects it)
- **Source-chain finality requirement** (does the bridge wait for L1 economic finality?)
- **Replay protection** across forks and chain reorgs
- **Censorship resistance**: can a single party block your message?
- **Liveness**: what happens if the bridge pauses or relayers stop running?
- **Upgrade authority**: who can change the bridge contract code?
- **Pause mechanism**: who can freeze the bridge, and is it announced?
- **Insurance / coverage**: is there a fund or coverage program?

If the answer to any of these is "we don't know", do not ship cross-chain on that bridge.

## Lock-and-mint vs burn-and-mint vs canonical

| Pattern | Token canonical address | Liquidity fragmentation | Risk |
|---------|------------------------|------------------------|------|
| Lock-and-mint (custodial bridge) | Original on source, wrapped on dest | High (each bridge mints its own wrapped) | Bridge custody |
| Burn-and-mint (NTT, OFT) | Same token contract on every chain, supply moves | Low | Messaging layer + token logic |
| Canonical (L1<->L2) | Token contract on each side, bridge mints L2 representation | Medium | Rollup operator |

For a new token launching multi-chain, **prefer burn-and-mint** (LayerZero OFT, Wormhole NTT, Axelar ITS, Hyperlane Warp Routes) over deploying multiple wrapped versions.

## Intent-based bridges

Intent-based design (Across, deBridge DLN, Catalyst, Mayan) decouples user UX from settlement:

```text
User signs intent ("send 100 USDC from Arbitrum to Base, willing to receive >= 99.5 USDC")
        |
Relayer fronts 99.5 USDC on Base                 [seconds, user is done]
        |
Relayer claims 100 USDC on Arbitrum after settlement proof  [hours, async]
```

Properties:

- User-perceived latency = relayer transfer time (seconds)
- User does not bear messaging delay
- Relayer bears finality + capital cost
- Settlement still uses an underlying messaging layer (LayerZero, UMA, etc.) for proof

This is the dominant pattern for consumer asset bridging in 2025-2026. Reserve generic message-passing bridges for state synchronization.

## Common pitfalls

| Symptom | Fix |
|---------|-----|
| User sees "wrapped USDC.e" and "USDC" as separate balances | Migrate to canonical or a single OFT/NTT representation |
| Bridge transaction stuck after L1 finality | Implement claim/refund UI; never assume "fire and forget" |
| Cross-chain governance call without reorg protection | Wait for source chain economic finality before relaying |
| Hardcoded LayerZero DVN config (defaults) | Choose your DVN stack explicitly; defaults are not always strong |
| Treating bridge fees as constant in UI | Quote fees just-in-time; gas + DVN fees vary |
| No emergency pause path on bridge integration | Add admin pause for the integration layer; do not assume bridge will pause for you |
| Storing user funds in a bridge's "in-flight" state | Design for stuck messages; implement refund logic |
| Multi-chain protocol with no cross-chain accounting reconciliation | Run an off-chain reconciler; alert on drift |

## When NOT to bridge

- **Latency requirement < bridge finality**: stay on one chain
- **Atomic multi-chain composability needed**: not possible; redesign
- **Small TVL**: bridge fees dominate; users will choose competitors who stayed on one chain
- **Regulatory ambiguity** about cross-chain wrapped assets: defer until legal review

## Reference reading

- L2BEAT bridge risk page (verify with WebSearch for current data)
- DeFiLlama bridge dashboards
- Rekt News for incident postmortems
- LayerZero, CCIP, Wormhole official security docs
