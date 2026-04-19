# Tokenomics Sharp Edges

Failure modes that have killed real protocols. Each entry follows the same shape:

- **ID** -- short identifier; cite this in audit reports.
- **Severity** -- CRITICAL / HIGH / MEDIUM.
- **Symptoms** -- how it looks from the outside before you understand the cause.
- **Root cause** -- why it happens.
- **Mitigation** -- specific design changes.

## Quick scan

| ID | Severity | One-line description |
|----|----------|----------------------|
| `securities-classification` | CRITICAL | Token reads as security under Howey; SEC / CFTC exposure |
| `high-fdv-low-float` | CRITICAL | Locked supply unlocks into thin float; predictable dump cliffs |
| `emission-exceeds-demand` | CRITICAL | Weekly emission value > weekly buy pressure; price-yield death spiral |
| `vesting-cliff-dump` | HIGH | Single date unlocks large cohort; predictable selling event |
| `governance-attack` | HIGH | Flash loans or whale accumulation execute hostile proposals |
| `liquidity-mining-exhaustion` | HIGH | Incentives end, mercenary LPs leave, liquidity collapses |
| `airdrop-dump` | HIGH | Free recipients sell instantly; chart cratered at claim event |
| `oracle-manipulation` | HIGH | Thin token liquidity manipulated to exploit DeFi integrations |
| `token-velocity-problem` | MEDIUM | Token is pass-through; no holding, no value capture |
| `whale-concentration` | MEDIUM | Top-N hold majority; governance and price both centralized |
| `forced-utility-friction` | MEDIUM | Required token gating churns users to tokenless competitors |
| `points-as-securities` | MEDIUM | Pre-launch points hint at investment returns |
| `buyback-without-revenue` | MEDIUM | Buyback funded by emissions, not real revenue |

## Failure modes

### `securities-classification`

**Severity**: CRITICAL

**Symptoms**:

- SEC / CFTC enforcement action.
- Exchange delistings (especially US-facing).
- Personal liability for founders and core contributors.

**Root cause**: Token sale and / or marketing satisfies the four prongs of Howey: (1) investment of money, (2) in a common enterprise, (3) with expectation of profits, (4) derived from the efforts of others.

Common red flags:

- Public copy: "earn", "yield", "ROI", "passive income", "appreciation", "value accrual", "stake to earn".
- Mechanism: dividend-like fee distribution to passive holders.
- Distribution: pre-launch sale to the public with marketing pitch.
- Centralization: visible team driving all protocol value, no operational decentralization.

**Mitigation**:

- Frame token in terms of function, not financial outcome -- run all public copy through the `legalizer` skill.
- Decentralize operational control before token launch (ideally Stage 2 by Optimism's classification).
- Avoid token sales to retail; if a sale is necessary, prefer accredited-only or jurisdiction-restricted with documented controls.
- No promises of returns or appreciation in any document, ever.
- Replace fee-share narratives with neutral routing language ("fees fund treasury" / "fees compensate validators for computational work").
- Get a written legal opinion before launch.

**References**:

- SEC framework for investment-contract analysis of digital assets: <https://www.sec.gov/corpfin/framework-investment-contract-analysis-digital-assets>
- SEC / CFTC joint interpretive rule (digital commodity test).

### `high-fdv-low-float`

**Severity**: CRITICAL

**Symptoms**:

- Sharp price decline at every unlock cliff.
- Retail holders diluted with each unlock.
- Token never recovers to ATH despite protocol growth.

**Root cause**: Total supply (FDV) is large relative to currently circulating supply (float). The locked portion eventually unlocks into the order book; if buy pressure has not kept pace, the new supply finds its clearing price by collapsing the old.

Worked example:

```text
Float at TGE:      100M tokens at $10 = $1B market cap
FDV at TGE:        1,000M tokens                 = $10B FDV
FDV / MCap ratio:  10x

Six months later, 100M more tokens unlock (next cliff).
If even half of the new supply sells at any price:
  -> 50M sold into a market sized for 100M float
  -> price discovery collapses by 50-90% depending on depth.
```

**Mitigation**:

- Target FDV / MCap < 4x at launch.
- Stagger cliffs across cohorts; never align team and investor cliffs on the same date.
- Replace single cliff dump with linear (weekly or daily) unlocks after cliff.
- Offer lock extensions in exchange for additional allocation or boosted yield.
- Publish the unlock waterfall publicly, monthly resolution, before TGE.
- Consider buyback or token-burn from revenue specifically scheduled around unlock dates.

**References**:

- <https://token.unlocks.app/> for cross-protocol unlock-schedule benchmarks.

### `emission-exceeds-demand`

**Severity**: CRITICAL

**Symptoms**:

- Constant price decline despite "successful" usage metrics.
- Decreasing TVL even while emissions are being distributed.
- Yield-farming rewards collapse in dollar terms; APR looks high but USD value is falling.

**Root cause**: The protocol issues more token value per week than the market is willing to absorb. Stakers and farmers receive emissions, sell to realize gains, price drops, dollar APR drops, marginal farmer leaves, TVL drops, sell pressure remains. This is the death spiral.

Worked example:

```text
Weekly emission:      1,000,000 tokens
Token price:          $1
Weekly emission $:    $1,000,000

Weekly buy pressure budget needed:
  Protocol revenue:     $200,000   (real)
  New investment:       $500,000   (speculative)
  Organic demand:       $300,000   (varies)
  Total:              $1,000,000   (just to hold price)

If the actual buy pressure is $700K, price drops ~30% to clear.
After the drop, dollar emission is $700K, but mercenary capital
has already started to leave; buy pressure drops to $400K. Repeat.
```

**Mitigation**:

- Compute the **sustainability ratio** weekly: `buy_pressure / emission_value`. Target > 1.5; warn at < 1.0.
- Tie emissions to revenue (see `Dynamic Emissions` pattern) so the rate auto-throttles.
- Add token sinks: lockup demand (ve), service consumption (burn-for-feature), governance escrow.
- Reduce emissions on a published schedule; do not surprise farmers, but do reduce.
- Replace emission-funded yield with real-yield distribution where possible.

**References**:

- <https://tokenterminal.com/> for revenue and emission benchmarks across protocols.

### `vesting-cliff-dump`

**Severity**: HIGH

**Symptoms**:

- Sharp price decline on a single, predictable date.
- Pre-cliff derivatives markets price in the dump (perp funding goes negative).
- Community loses trust in the cap table.

**Root cause**: A meaningful share of supply unlocks on a single date, and recipients sell at the same time because the cliff itself signals their intent.

**Mitigation**:

- Stagger cliffs across cohorts by month or quarter.
- Replace cliff lump-sum with linear unlock (weekly or daily) after the cliff start date.
- Publish unlock schedule per cohort, with monthly resolution.
- Communicate proactively before each cliff; offer lock-extension incentives.

**Sketch** (post-cliff weekly unlock):

```solidity
// OpenZeppelin v5 has VestingWallet, VestingWalletCliff (cliff-aware).
// For staggered post-cliff unlocks, schedule weekly disbursements.
function vestedAmount(address beneficiary, uint64 timestamp)
    public view returns (uint256)
{
    if (timestamp < start + cliff) return 0;
    uint256 elapsed = timestamp - (start + cliff);
    uint256 totalDuration = duration - cliff;
    if (elapsed >= totalDuration) return allocation[beneficiary];
    // step the vesting weekly to align with disbursement cadence
    uint256 weeksVested = elapsed / 1 weeks;
    uint256 totalWeeks  = totalDuration / 1 weeks;
    return allocation[beneficiary] * weeksVested / totalWeeks;
}
```

**References**:

- OpenZeppelin v5 vesting contracts: <https://docs.openzeppelin.com/contracts/5.x/api/finance#VestingWallet>

### `governance-attack`

**Severity**: HIGH

**Symptoms**:

- Treasury drained via "legitimate" governance proposal.
- Protocol parameters manipulated (fees, oracle settings, allow-lists).
- Minority holders systematically overruled by acquired voting blocks.

**Root cause**: Voting power can be acquired or assembled faster than a defense can be mounted. Pure 1-token-1-vote with current-block balance is exploitable via flash loan; even without flash loans, mercenary accumulation over weeks can drain a treasury.

**Mitigation**:

```text
1. Snapshot voting power
   - Use balance from a past block (proposal-creation block).
   - Defeats single-block flash-loan attacks.

2. ve-locked voting power
   - Voting weight requires time-locked tokens.
   - Cannot be borrowed and returned; must commit capital.

3. Timelock
   - Proposal queue delay: 48h-7d depending on impact.
   - Treasury moves: 7d minimum.
   - Parameter changes: 48h minimum.

4. Quorum and threshold
   - Quorum: 4-10% of circulating supply for normal proposals.
   - Supermajority (>= 60-67%) for treasury moves and parameter changes.
   - Proposal threshold: small (e.g. 0.1%) to enable participation but block spam.

5. Emergency multisig
   - 4-of-7 or similar, geographically distributed, key separation enforced.
   - Pause / cancel power on queued proposals.
   - Cannot mint, transfer treasury, or upgrade contracts unilaterally.

6. Defense-in-depth
   - Monitoring on large delegations, anomalous voting patterns.
   - Off-chain dispute window (e.g. UMA-style optimistic execution).
```

**References**:

- OpenZeppelin Governor: <https://docs.openzeppelin.com/contracts/5.x/governance>
- Compound governance attack discussions and post-mortems.

### `liquidity-mining-exhaustion`

**Severity**: HIGH

**Symptoms**:

- Sharp drop in TVL at the moment incentives end (or are reduced).
- Slippage on protocol pairs increases dramatically.
- Protocol becomes effectively unusable for non-trivial trade sizes.

**Root cause**: LPs are renting liquidity. They were paid in emissions to provide capital; once payment stops, capital leaves. There is no reason for an opportunistic LP to remain.

**Mitigation**: phased liquidity strategy.

```text
Phase 1: Bootstrap (month 1-6)
  High emissions: 500K tokens / month
  Goal: attract enough TVL to enable user activity.

Phase 2: Transition (month 7-12)
  Reduce emissions: 250K tokens / month
  Begin protocol-owned liquidity (POL) accumulation via bonding.
  Begin trading-fee distribution to LPs.

Phase 3: Sustainable (year 2+)
  Minimal emissions: 50K tokens / month
  POL provides base liquidity floor.
  Trading fees compensate marginal LPs.
  No TVL cliff because POL anchors the depth.
```

Never go from high to zero emissions. Always announce the schedule in advance.

**References**:

- OlympusDAO writings on POL and bonding mechanics.

### `airdrop-dump`

**Severity**: HIGH

**Symptoms**:

- Price drops 30-70% at airdrop claim event.
- Real users get worse fills than they would have without the airdrop.
- Most claimed tokens are sold within the first week.

**Root cause**: Recipients have zero cost basis. The optimal individual strategy is to sell immediately, and most do.

**Mitigation**: see `Vested Airdrop with Lock Boost` pattern. Combine:

```text
1. Vesting on the airdrop itself
   - 10-50% immediate, remainder over 6-12 months.

2. Lock boost
   - Larger claim if recipient locks for N months.

3. Sybil filtering
   - On-chain history thresholds (>= N days, >= M txns).
   - Per-wallet caps.
   - Quadratic scaling above usage thresholds.

4. Usage-gated claim
   - Must use protocol once to unlock claim.
   - Partial claim per protocol interaction.
```

### `oracle-manipulation`

**Severity**: HIGH

**Symptoms**:

- Flash-loan attack drains a DeFi integration that uses your token as collateral.
- Liquidations execute at impossible prices.
- Arbitrage exploits across DEX <-> oracle prices.

**Root cause**: Token has thin liquidity, and a single source (often a single-block AMM spot price) is used as the price oracle. Spot can be moved within one block by a flash-loan-funded trade.

**Mitigation**:

- Use TWAP (time-weighted average price), 30-minute minimum window, ideally longer for low-liquidity tokens.
- Use multiple oracle sources; aggregate via median or volume-weighted.
- Set minimum liquidity thresholds; circuit-break when below threshold.
- Implement deviation checks against an external reference (Chainlink data feed, CEX index price).

```solidity
// price freshness + deviation check
require(block.timestamp - oracle.lastUpdate() <= 1 hours, "stale");
require(
    abs(oracle.price() - backup.price()) * 100 / oracle.price() < 5,
    "deviation > 5%"
);
```

**References**:

- Chainlink data feed best practices: <https://docs.chain.link/data-feeds/using-data-feeds>

### `token-velocity-problem`

**Severity**: MEDIUM

**Symptoms**:

- Token receives buy pressure from emissions or fees but does not retain holders.
- Constant net sell pressure even when usage grows.
- Token acts as a pass-through medium; no equilibrium price.

**Root cause**: Token is needed momentarily (to pay a fee, swap through a pair, claim a reward), then immediately sold for a stable asset. No reason to hold means no demand floor.

By the velocity equation `Token Value ~ Transaction Volume / Velocity`, high velocity collapses value.

**Mitigation**:

- Lockup demand: ve-locks, gauge voting, governance escrow.
- Time-weighted benefits: longer hold = better fee discount, boost, or rewards.
- Service sinks: burn or lock for premium features.
- Real-yield distribution to stakers, payable in non-native asset (ETH/USDC) so the staker is rewarded for holding the volatile token.

**References**:

- <https://multicoin.capital/2017/12/velocity-of-tokens/> (canonical analysis).

### `whale-concentration`

**Severity**: MEDIUM

**Symptoms**:

- A single wallet (or coordinated set) can crash the price.
- Governance is decided by a handful of votes.
- Retail is reluctant to enter; trust deficit.

**Root cause**: Initial distribution overweighted insiders, or post-launch dynamics (yield farming, gas costs) concentrated supply in large holders.

Healthy targets:

| Metric | Target | Warning |
|--------|--------|---------|
| Top-10 holders (excl. contracts) | < 40% | > 50% |
| Top-100 holders | < 70% | > 85% |
| Gini coefficient | < 0.8 | > 0.9 |

**Mitigation**:

- Per-address allocation cap on airdrops and community sales.
- Broad distribution mechanisms (Sybil-filtered, but wide).
- Liquidity mining over long windows (gradual distribution).
- Monitor: Etherscan / Solscan holder analysis, Dune dashboards.

### `forced-utility-friction`

**Severity**: MEDIUM

**Symptoms**:

- Users complain in support channels about the token requirement.
- Lower adoption than tokenless or token-optional competitors.
- Aggregators bypass the token entirely; users follow.

**Root cause**: The token is structurally required for basic protocol use. The token requirement is a tax on users; users route around taxes.

**Mitigation**:

```text
Bad   Token required to: open an account, place an order, claim revenue.

Good  Token optional. Holding/staking/locking gets:
        - fee discount
        - rate boost
        - governance voice
        - early access
      Protocol works for non-holders; holders get strictly better terms.
```

### `points-as-securities`

**Severity**: MEDIUM

**Symptoms**:

- Pre-launch points program drives engagement, but copy implies investment return.
- Regulatory inquiries about the points program before any token exists.
- Community expects fixed conversion ratio that the team did not promise.

**Root cause**: Points programs that hint at value, conversion, or economic upside satisfy enough Howey prongs to be analyzable as investment contracts even before a token exists.

**Mitigation**:

- Points are non-transferable, off-chain, "no monetary value" in Terms of Service.
- No promised conversion ratio, timing, or even existence of a token.
- All public copy passes `legalizer` -- particularly: no "earn", "rewards", "yield", "investment".
- Snapshot mechanics published only at TGE, not pre-announced.

### `buyback-without-revenue`

**Severity**: MEDIUM

**Symptoms**:

- "Buyback and burn" headlines, but supply still grows quarter over quarter.
- Treasury depleted faster than it grows.
- Eventual silent termination of the buyback program.

**Root cause**: Buybacks are funded by emissions or reserves rather than revenue. Net token issuance remains positive; the protocol is buying back tokens it just issued.

**Mitigation**:

- Publish (revenue, emissions, net flow) every quarter.
- Buyback only when `revenue >= emission_value` over the trailing window.
- Otherwise route revenue to treasury, real yield, or POL accumulation.
- Stop using "buyback and burn" as a value-accrual story; use it as a discretionary capital-allocation tool.
