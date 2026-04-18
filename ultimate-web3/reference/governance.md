# Governance Design

Architectural decisions for protocol governance. Public-facing token / governance copy review belongs in `legalizer`. This file is about the system design.

## Decision tree: do you need on-chain governance?

```text
Is the protocol genuinely meant to be controlled by token holders?
|
|-- No  -> use multisig + timelock; do not pretend
|         (most "DAOs" are operationally a multisig with a vote ritual)
|
`-- Yes -> what kind of decisions?
    |
    |-- Parameter tuning (fees, caps, oracle config)
    |       -> Snapshot off-chain vote -> multisig executes (signal-only)
    |       OR Governor with low-quorum proposals
    |
    |-- Treasury allocation
    |       -> Governor + Timelock + multi-sig executor
    |
    |-- Protocol upgrades
    |       -> Governor + Timelock with long delay (>= 7 days)
    |
    `-- Emergency pause
            -> Separate guardian role with multisig; never gated on slow vote
```

## Default stack

| Concern | Default |
|---------|---------|
| Off-chain signaling | Snapshot |
| Vote indexing / UX | Tally, Boardroom |
| On-chain execution | OpenZeppelin `Governor` + `TimelockController` |
| Voting token | ERC-20Votes (snapshot-based, ERC-5805) |
| Delegation | ERC-5805 (`delegate` / `delegateBySig`) |
| Emergency pause | Separate guardian multisig with `pause()` permission |
| Multi-chain governance | Cross-chain message via canonical bridge or LayerZero / CCIP |

## Voting power schemes

| Scheme | Use case | Tradeoff |
|--------|----------|----------|
| **Token-weighted (1 token = 1 vote)** | Most DAOs default; simple to implement | Plutocracy; whales dominate |
| **Quadratic voting (cost = votes^2)** | Public-goods funding (Gitcoin) | Sybil-resistant identity required |
| **Conviction voting** | Continuous funding decisions (1Hive, Commons Stack) | Complex UX |
| **Delegation (liquid democracy)** | Lower voter overhead; expert representatives | Delegate concentration |
| **veToken (vote-escrowed, locked stake)** | Curve / Convex model; long-term alignment | Lockup illiquidity, gauge wars |
| **NFT-based (1 NFT = 1 vote)** | Fixed-membership organizations | Sybil if NFT is transferable |
| **Reputation-based (non-transferable)** | Working groups, Coordinape-style | Bootstrapping reputation is hard |
| **Futarchy (prediction markets)** | Research / experimentation | Largely untested in production |

For new protocols, **delegated token-weighted voting with a long timelock** is the safest default. Anything more exotic requires explicit justification.

## Timelock design

```text
Proposal -> Vote (3-7 days) -> Queue in Timelock -> Delay (>= 2 days, often 7) -> Execute
```

Timelock parameters:

- **Delay**: 2 days minimum for any non-emergency change; 7 days for upgrades; 14 days for high-value protocols
- **Admin**: the timelock itself, controlled by the governor; never an EOA
- **Cancellation role**: a guardian multisig that can cancel a queued proposal (defense against passed-but-malicious proposals)
- **Proposers**: the Governor contract only; no other proposers

OpenZeppelin's `TimelockController` is the standard. Do not write your own.

## Quorum and threshold

| Parameter | Typical range | Notes |
|-----------|---------------|-------|
| **Proposal threshold** (tokens to propose) | 0.1% - 1% of supply | Too low: spam; too high: capture |
| **Quorum** (% of supply that must vote) | 4% - 20% | Too low: minority control; too high: proposals fail from apathy |
| **Approval threshold** (% yes of votes cast) | 50% simple; 67% supermajority for upgrades | Match risk to threshold |
| **Voting period** | 3 - 7 days | Account for global time zones; avoid major holidays |
| **Voting delay** (proposal -> voting starts) | 1 - 3 days | Time for delegates to review |

Adjust based on token distribution. A protocol with 70% of tokens in 5 wallets needs higher quorum to mean anything.

## Emergency response

Slow governance is incompatible with incident response. Standard pattern:

| Action | Authority | Latency |
|--------|-----------|---------|
| **Pause** (stop new deposits / actions) | Guardian multisig (3 of 5) | Immediate |
| **Parameter freeze** | Guardian multisig | Immediate |
| **Migration / unpause** | Governor + timelock | Days |
| **Guardian rotation** | Governor only | Standard timelock |

The guardian is a **separate multisig** from the protocol treasury. Its authority is narrow (pause, freeze) and bounded (cannot drain funds, cannot upgrade).

## Multi-chain governance

A protocol deployed on N chains needs consistent governance state. Patterns:

- **Home chain governance + cross-chain execution**: vote on Ethereum L1, execute on L2/other chains via canonical bridge or messaging layer
- **Mirrored governance**: separate governance on each chain (rare; coordination nightmare)
- **Snapshot off-chain + executors per chain**: signal off-chain, multisig executes on each chain

Default: **home chain governance + cross-chain execution via canonical bridge** where possible. Avoid third-party messaging for governance unless the chain has no canonical bridge to the home chain.

## Delegation UX

Most token holders never vote directly. Delegation is the dominant participation model.

For protocol design:

- Use **ERC-5805** (standardized delegation) so wallets and tools can interop
- Support **delegation by signature** (gasless delegation via wallet signing)
- Display delegate platforms (Tally, Boardroom) prominently in UX
- Publish a delegate directory with statements of intent

For delegate UX:

- Show voting history with rationale
- Show participation rate (proposals voted in / total)
- Show conflicts of interest disclosures

## Treasury management

Once the DAO holds funds, treasury operations are an ongoing problem:

| Tool | Use |
|------|-----|
| **Safe** | Custody and execution |
| **Llama** | Treasury reporting |
| **Karpatkey, Avantgarde** | Active treasury management services |
| **Aragon, Tally** | Proposal -> execution coordination |
| **Sablier, Superfluid** | Continuous payments to contributors |
| **Hats Protocol** | Role-based permissions over Safe modules |

A common failure mode: DAO holds 90% of treasury in its own token. Diversify into stablecoins (USDC, DAI) and ETH for runway resilience.

## Governance attacks

| Attack | Defense |
|--------|---------|
| **Flash-loan governance attack** (borrow tokens, vote, repay) | Use snapshot-based voting (ERC-20Votes); voting power locked at proposal block |
| **Vote buying / bribing** | Public; mitigated socially. Some protocols (Curve via Convex/Votium) institutionalize it. |
| **Proposal spam** | Proposal threshold + cooldown |
| **Time-zone attacks** (proposal at low-attention time) | Long voting period; minimum proposal lead time |
| **Malicious upgrade through governance** | Timelock with cancellation role; on-chain monitoring of queued proposals |
| **Quorum gaming** (split-vote to prevent quorum) | Choose quorum thresholds carefully; expect adversarial behavior |
| **Multi-sig collusion of guardians** | Diverse guardian set; rotation; geographic separation |

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| "DAO" with no on-chain mechanism, only a multisig | Call it a multisig; do not market it as governance |
| Governance with no timelock | Add `TimelockController` immediately |
| Single vote can both approve and execute (no queue) | Separate proposal -> queue -> execute |
| Governor is also the emergency pause role | Separate guardian role with narrow powers |
| Cross-chain governance via third-party bridge with no audit | Use canonical bridge or evaluate the risk explicitly |
| Quorum 1% on a protocol with $1B TVL | Raise quorum or accept that 1% controls the protocol |
| Voting power calculated from current balance (not snapshot) | Use ERC-20Votes / ERC-5805 (snapshot at proposal block) |
| Timelock cancellation role held by the same multisig as proposer | Separate roles; cancellation is defensive |
| Treasury 100% in protocol token | Diversify into stables and ETH for runway |
