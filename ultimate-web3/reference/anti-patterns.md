# Architectural Anti-Patterns

Cross-cutting architectural mistakes. Code-level vulnerabilities (reentrancy, missing access control, oracle staleness) belong in `solidity-security`. Per-domain anti-patterns are catalogued in each `reference/*.md` file.

This file catalogs **architecture-level footguns**: design decisions that doom a protocol regardless of code quality.

## Strategy and scope

| Symptom | Cause | Fix |
|---------|-------|-----|
| Building on a chain because of a grant | Treating runway as roadmap | Pick the chain on user fit; grants are bonus, not basis |
| Multi-chain from day one without cross-chain need | Conflating reach with adoption | Ship on one chain; expand on user pull |
| "We need our own L1 / L2" without throughput data | Architecture astronautics | Validate users on shared L2 first |
| Cloning a successful protocol without understanding why it works | Cargo-cult engineering | Identify the user need; design from there |
| Adding governance, staking, and a token before product-market fit | Token-first thinking | Build the product first; tokenize when there is something to govern |

## Custody and admin

| Symptom | Cause | Fix |
|---------|-------|-----|
| Production protocol owned by a single EOA | "We'll add multisig later" | Multisig from day one; see `reference/custody-and-keys.md` |
| Same key used for deploy and admin | Convenience | Separate keys; rotate deploy key after deployment |
| Admin transfer pushed to the same multisig as the protocol treasury | Role conflation | Separate roles, separate multisigs, separate quorums |
| Emergency pause gated on full governance vote | "Decentralization at all costs" | Guardian role with narrow powers, separate from governance |
| Multisig with all signers in the same time zone or jurisdiction | Hiring all friends | Geographic and operational diversity |
| Hot wallet with no rate limits | "It only holds gas money" | Rate limit + monitoring; gas wallets get drained |

## Upgradeability

| Symptom | Cause | Fix |
|---------|-------|-----|
| Diamond chosen for "future flexibility" with no plugin requirement | Pattern envy | Use UUPS or non-upgradeable; diamond complexity costs more than it earns |
| Upgrade authority is an EOA | "It's just for testnet" | Multisig + timelock from day one |
| No storage layout diff in CI | "We'll be careful" | Automate via OZ Upgrades plugin or `forge inspect` diff |
| Upgrade with no rollback path | Optimism | Keep previous implementation deployed; document rollback procedure |
| Mixing upgradeable and immutable contracts in the same system without clear boundaries | Unclear strategy | Pick one strategy per subsystem and document the boundary |

## Oracles

| Symptom | Cause | Fix |
|---------|-------|-----|
| Reading Uniswap spot price for liquidations | "Uniswap is decentralized" | Use Chainlink / Pyth, or v3 TWAP with sufficient window |
| Single oracle for high-value collateral | Cost-cutting | Aggregate at least two independent oracles |
| No staleness check on oracle reads | Forgot | Always check `updatedAt`; pause on staleness |
| L2 deployment without sequencer-uptime feed | Copy-paste from L1 deploy | Add the check on every L2 |
| Hardcoded oracle decimals | Assumption | Read `decimals()` per feed |

## Cross-chain

| Symptom | Cause | Fix |
|---------|-------|-----|
| Multi-chain protocol with different addresses per chain | Non-deterministic deploy | CREATE2 with consistent salt; address registry |
| Cross-chain governance via third-party bridge with no security analysis | "It works on testnet" | Use canonical bridges where possible; document the trust model otherwise |
| User-facing UI with multiple wrapped versions of the same asset | Bridge proliferation | Migrate to OFT / NTT canonical representation |
| Cross-chain message stuck in flight with no recovery path | Async ignored | Implement claim / refund UI; treat in-flight as a state |
| Assuming cross-chain calls are atomic | Mental model from same-chain dev | Design async-first; retries and reconciliation |
| Multi-chain protocol with no cross-chain accounting reconciler | "Bridges are reliable" | Run a reconciler off-chain; alert on drift |

## Order flow and MEV

| Symptom | Cause | Fix |
|---------|-------|-----|
| dApp uses public RPC for swaps | Default config | Switch default to Flashbots Protect or MEV Blocker |
| Liquidation bonus = 10% with no auction | Copying a 2020 protocol | Dutch auction; lower bonus over time |
| Building a custom OFA when CoW / UniswapX would integrate | Not-invented-here | Integrate; build only if OFA is the product |
| Frontrun protection only at the wallet RPC level | Protocol abdicates | Design protection into the protocol (commit-reveal, batch) |
| Sequencer trust assumption undocumented | Implicit assumption | Document explicitly; design escape hatches |

## Indexing and data

| Symptom | Cause | Fix |
|---------|-------|-----|
| Browser does `eth_getLogs` on a long range | Indexer skipped | Move to Ponder / Envio / Goldsky |
| Single subgraph for analytics + UI | Over-loaded | Split: app indexer + analytics warehouse |
| Production indexer on free tier with no SLA | Cost-cutting | Self-host or pay for SLA |
| No reorg policy in indexer | Forgot | Wait for confirmations or expose finality status |

## Governance

| Symptom | Cause | Fix |
|---------|-------|-----|
| "DAO" with no on-chain mechanism | Marketing | Call it a multisig; do not pretend |
| Governance with no timelock | Speed obsession | Add `TimelockController`; non-negotiable for production |
| Voting power from current balance, not snapshot | Custom implementation | Use ERC-20Votes / ERC-5805 |
| Quorum 1% on a $1B-TVL protocol | Pulled from a tutorial | Calibrate to actual distribution and risk |
| Treasury 100% in protocol token | "Stay aligned" | Diversify into stables and ETH |

## Account abstraction

| Symptom | Cause | Fix |
|---------|-------|-----|
| Targeting EntryPoint v0.6 for a new project | Outdated tutorial | Use v0.7 or v0.8 |
| Custom validator module without audit | NIH | Use Safe / ZeroDev / Rhinestone audited modules |
| Smart account with single-key validation and no recovery | "We'll add it later" | Recovery module from day one |
| Paymaster funded with $5k and no monitoring | Demo-grade ops | Per-user limits + alerting + auto-refill |

## Privacy

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Privacy chain" with no formal threat model | Marketing-led design | Write threat model first |
| Custom cryptographic construction without academic review | Confidence | Use audited primitives; novel crypto needs peer review |
| Transaction-layer privacy without network-layer | Half-measure | Integrate Dandelion, Tor, or mix network |
| TEE-based privacy claimed as cryptographic | Misunderstanding | TEEs have side-channel and supply-chain risks; do not equate to ZK |

## Deployment and ops

| Symptom | Cause | Fix |
|---------|-------|-----|
| Deploy via private key in `.env` checked into git | Sloppy | Hardware-wallet deploy; secrets scanning in CI |
| Source not verified on every chain | Forgot | Verify immediately after deploy on every chain |
| No monitoring on admin function calls | Underestimated risk | Add Defender Sentinel for every privileged call |
| Multi-chain launch on the same day | Marketing pressure | Stagger by at least a week per chain |
| Incident response improvised | No runbook | Write the runbook; rehearse on testnet |
| No bug bounty before mainnet | "We're audited" | Audit + bounty are complementary, not alternatives |
| Pause tx not pre-drafted | "We'll do it when needed" | Pre-circulate the tx; rehearse signing |

## Communication and trust

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Decentralized" claim with single multi-sig and no roadmap | Marketing | Be honest about current decentralization stage |
| Public copy implies investment, yield, or shared profits | Loose copy | Route through `legalizer` skill before publishing |
| Whitepaper claims unverifiable performance numbers | Hype | Cite or remove; route through `whitepapers` skill |
| Postmortems skipped or sanitized | PR-led | Publish honestly; trust compounds |
| Roadmap promises specific dates years out | Optimism | Soft commitments, hard delivery |

## When to stop and reconsider

Architectural smell tests. If any of these is true, pause the design:

- "We need a custom consensus mechanism" -> validate on existing chains first
- "Our token has 12 distinct mechanics" -> simplify
- "We need to bridge to 10 chains" -> start with 1
- "We can't be audited because the design is too novel" -> reconsider novelty
- "We can patch this with governance" without timelock -> add the timelock
- "Users will run their own indexer" -> they will not
- "Trust us, the multisig will not abuse this power" -> design out the abuse path

If any reviewer raises one of these and your answer is "yes, but...", treat it as a design problem, not a communication problem.
