# Tokenomics Patterns

Production patterns for token design. Each entry follows the same shape:

- **Use when** -- the scenario where this pattern fits.
- **Do not use when** -- where it backfires.
- **Sketch** -- the smallest concrete example that illustrates the mechanic.

For implementation safety (vesting wallet bugs, governor pitfalls), route to the `solidity-security` skill. For tests, route to `web3-testing`.

## Quick index

| Pattern | Primary purpose |
|---------|-----------------|
| [Progressive Decentralization Vesting](#progressive-decentralization-vesting) | Insider alignment + community fairness |
| [Vote-Escrow (ve-Token)](#vote-escrow-ve-token) | Reduce velocity, align governance with long holders |
| [ve(3,3) / Gauge Voting](#ve33--gauge-voting) | Direct emissions to productive pools |
| [Dual Token Model](#dual-token-model) | Separate stable utility from speculative governance |
| [Bonding Curve Distribution](#bonding-curve-distribution) | Permissionless, capital-efficient launch |
| [Emissions Halving Schedule](#emissions-halving-schedule) | Predictable, decreasing inflation |
| [Tail Emissions](#tail-emissions) | Fund security forever without uncapped supply |
| [Protocol-Owned Liquidity (POL)](#protocol-owned-liquidity-pol) | Replace mercenary LPs with permanent liquidity |
| [Real Yield Distribution](#real-yield-distribution) | Pay holders in non-native asset from actual revenue |
| [Dynamic Emissions](#dynamic-emissions-tied-to-revenue) | Throttle emissions when buy pressure is weak |
| [Points → Token Conversion](#points--token-conversion) | Pre-token engagement, defer launch decisions |
| [Vested Airdrop with Lock Boost](#vested-airdrop-with-lock-boost) | Reduce day-one dump pressure |
| [Retroactive Public Goods Funding (RPGF)](#retroactive-public-goods-funding-rpgf) | Reward proven contribution, avoid speculative grants |

## Patterns

### Progressive Decentralization Vesting

**Use when**: VC-backed protocol seeking long-term decentralization with credible insider alignment.

**Do not use when**: Fully community-launched fair launch (no insider buckets to vest).

**Sketch**:

```text
Total supply: 1,000,000,000 tokens

Community (60%)
  - Airdrop:                5%   no cliff, vested 6 months
  - Ecosystem grants:      25%   milestone-gated, 4 years
  - Liquidity mining:      20%   emission curve, 4 years
  - Treasury:              10%   governance-controlled, no vesting

Insiders (40%)
  - Team:                  20%   12 mo cliff, 36 mo linear after cliff
  - Investors (Seed):       8%   12 mo cliff, 24 mo linear
  - Investors (Series A):   7%   12 mo cliff, 24 mo linear
  - Advisors:               5%    6 mo cliff, 18 mo linear

Float at TGE:    ~5-10%
End of year 1:   ~25%
End of year 4:   100%
```

Stagger investor cliffs across rounds to avoid a single unlock cliff event.

### Vote-Escrow (ve-Token)

**Use when**: You need to reduce velocity, give long-term holders disproportionate governance weight, and direct emissions productively.

**Do not use when**: Token has no fee revenue or gauge-controlled emissions to distribute. ve without something to vote *for* is just a lockup.

**Sketch** (Curve-style):

```solidity
struct Lock { uint256 amount; uint64 unlockTime; }
mapping(address => Lock) public locks;

uint256 public constant MAX_LOCK = 4 * 365 days;
uint256 public constant MIN_LOCK = 7 days;

function lock(uint256 amount, uint256 duration) external {
    require(duration >= MIN_LOCK && duration <= MAX_LOCK, "duration");
    token.transferFrom(msg.sender, address(this), amount);
    locks[msg.sender] = Lock(amount, uint64(block.timestamp + duration));
}

// votingPower decays linearly toward zero as unlockTime approaches.
function votingPower(address u) external view returns (uint256) {
    Lock memory l = locks[u];
    if (block.timestamp >= l.unlockTime) return 0;
    uint256 remaining = l.unlockTime - block.timestamp;
    return l.amount * remaining / MAX_LOCK;
}
```

Voting power decays continuously; users must re-lock to maintain influence.

### ve(3,3) / Gauge Voting

**Use when**: A DEX or yield protocol needs to direct token emissions to the most-productive liquidity pools, with bribes from external protocols competing for emission share.

**Do not use when**: There are no external protocols willing to pay for emissions; the bribe market is the value source.

**Sketch**:

```text
Holders lock TOKEN -> veTOKEN (non-transferable, time-decaying weight).
Each epoch (1 week):
  1. veTOKEN holders vote weights across N gauges (pools).
  2. Emissions for the next epoch are distributed pro rata to gauge weight.
  3. External protocols deposit "bribes" (any ERC-20) on a gauge to attract votes.
  4. Voters who voted for that gauge claim the bribes pro rata to their vote weight.
  5. Trading fees from each pool flow to its voters (real yield).

Result: emissions chase the highest-bribe-paying pools, not arbitrary team picks.
```

ve(3,3) refers to Andre Cronje's variant where rebasing partly offsets dilution for lockers; (3,3) is the game-theoretic notation for cooperative locking.

### Dual Token Model

**Use when**: Protocol needs a stable internal unit of account for fees and a separate speculative governance asset; common in stablecoin protocols and games.

**Do not use when**: Single-token model can carry both roles without confusion. Most protocols.

**Sketch**:

```text
GOV: governance + value capture
  - Fixed supply
  - Vested per insider schedule
  - Used for: voting, fee-share claims, proposal escrow

UTIL: medium of exchange
  - Dynamic supply (mint/burn)
  - No vesting; freely available
  - Used for: in-protocol fees, internal pricing
  - Stability via collateral, algorithmic peg, or supply elasticity

Coupling:
  - Stake GOV -> earn share of UTIL fee inflow.
  - Burn UTIL -> consume protocol service.
  - GOV holders set UTIL monetary policy parameters.
```

Algorithmic peg variants of the UTIL leg have repeatedly failed (UST, IRON). Prefer over-collateralized or fee-backed designs.

### Bonding Curve Distribution

**Use when**: No VC round, community-first launch, want price discovery to be a deterministic function of supply.

**Do not use when**: Token must trade against deep liquidity from day one; bonding curves create thin secondary markets.

**Sketch**:

```solidity
// price = k * supply, integral form for buy/sell math.
function buy(uint256 amount) external payable {
    uint256 cost = (((supply + amount) ** 2) - (supply ** 2)) * K / 2;
    require(msg.value >= cost, "insufficient payment");
    supply += amount;
    reserve += cost;
    _mint(msg.sender, amount);
}

function sell(uint256 amount) external {
    uint256 refund = ((supply ** 2) - ((supply - amount) ** 2)) * K / 2;
    supply -= amount;
    reserve -= refund;
    _burn(msg.sender, amount);
    payable(msg.sender).transfer(refund);
}
```

The reserve must be locked or governed transparently; treasury raids on the reserve are the standard failure mode.

### Emissions Halving Schedule

**Use when**: You want a predictable, hard-decreasing supply schedule that converges to a cap.

**Do not use when**: Emission rate must respond to protocol revenue or usage; halvings are time-based and ignore demand.

**Sketch**:

```text
Initial annual emission: 1,000,000 tokens
Halving period:          every 2 years
Hard cap (asymptote):    sum of geometric series

Year 1-2   1,000,000/yr   cumulative   2,000,000
Year 3-4     500,000/yr                3,000,000
Year 5-6     250,000/yr                3,500,000
Year 7-8     125,000/yr                3,750,000
...
Asymptotic max ~ 4,000,000
```

### Tail Emissions

**Use when**: Protocol security or LP incentives need a permanent funding floor, but you also want diminishing dilution over time.

**Do not use when**: A pure cap is essential to the value proposition.

**Sketch**:

```text
Phase 1 (year 1-4):   primary halving emission   ~ 90% of eventual circulating
Phase 2 (year 5+):    constant tail emission     0.5-2% annual inflation forever

Tail rate is set so that staking yield > inflation rate for active stakers,
keeping passive holders mildly diluted but active participants net-positive.
```

Used by Monero and proposed for several PoS L1s. The ethical claim is that "ultra sound money" with zero issuance underfunds long-term security.

### Protocol-Owned Liquidity (POL)

**Use when**: You need a permanent liquidity floor and want to stop renting it from mercenary LPs.

**Do not use when**: Treasury cannot afford the upfront discount, or governance cannot manage LP positions safely.

**Sketch** (Olympus-style bonding):

```solidity
function bond(address lpToken, uint256 lpAmount, uint256 maxPrice)
    external returns (uint256 payout)
{
    IERC20(lpToken).transferFrom(msg.sender, address(this), lpAmount);
    uint256 price = bondPrice(lpToken);          // discounted vs spot
    require(price <= maxPrice, "slippage");
    payout = lpAmount * 1e18 / price;
    vesting[msg.sender] = Vest(payout, block.timestamp + 5 days);
}
```

Treasury permanently owns the LP position; trading fees accrue to the treasury and the protocol stops paying ongoing emissions for liquidity.

### Real Yield Distribution

**Use when**: Protocol generates revenue in a non-native asset (ETH, stablecoins) and you want value accrual that does not require token buyback narratives.

**Do not use when**: Revenue is too small or volatile to support meaningful distributions; signaling small payouts is worse than none.

**Sketch**:

```text
Sources:
  Trading fees, borrowing fees, perp funding, MEV redistribution.
  Denominated in: ETH, USDC, DAI, WBTC -- not the native token.

Routing each epoch:
  X% -> stakers / lockers (real yield)
  Y% -> protocol treasury (operational runway)
  Z% -> insurance fund or POL growth

Display:
  Yield is shown in USD or ETH terms, not "X% APR in TOKEN".
  This avoids the death-spiral framing where APR is propped up by emissions.
```

GMX, Synthetix, and dYdX v3/v4 are canonical examples. Run all yield-related public copy through `legalizer`.

### Dynamic Emissions Tied to Revenue

**Use when**: You want emissions to throttle automatically when buy pressure is weak, instead of relying on manual governance.

**Do not use when**: Revenue is unmeasurable on-chain; oracle dependence on revenue introduces manipulation risk.

**Sketch**:

```text
weekly_emission(t) = base_emission * f(revenue_ratio(t))

revenue_ratio(t) = trailing_4w_revenue / trailing_4w_emission_value

f(r):
  r >= 1.5  -> emission * 1.0   (healthy: keep paying)
  1.0 <= r < 1.5 -> emission * 0.7
  0.5 <= r < 1.0 -> emission * 0.4
  r < 0.5   -> emission * 0.1   (death spiral floor)
```

Couple with a hard cap so that even at maximum throttle the cap binds.

### Points → Token Conversion

**Use when**: You want to capture pre-launch engagement without committing to a token design or compliance posture; defer the legal and economic decisions.

**Do not use when**: You promise points are tokens, or imply a fixed conversion ratio. Either commitment binds you legally and economically.

**Sketch**:

```text
Pre-launch:
  - Points awarded for protocol usage (volume, deposits, referrals).
  - Points are non-transferable, off-chain, "no monetary value" in Terms.
  - No promise of conversion ratio, timing, or even existence of a token.

At TGE:
  - Snapshot point balances.
  - Convert via published formula (often vested airdrop with lock boost).
  - Cap per address; sybil filters applied.
```

Aggressively review all pre-launch communication through `legalizer`. Points programs that hint at investment returns are securities-pitch-by-another-name.

### Vested Airdrop with Lock Boost

**Use when**: You want broad distribution but expect immediate dump pressure from professional airdrop farmers.

**Do not use when**: You need broad sybil-resistant distribution but cannot enforce identity; consider POAP / Gitcoin-passport gating instead.

**Sketch**:

```text
Allocation per eligible address: A tokens

Claim modes (user picks one):
  - Immediate:        0.5 * A   (50% haircut for instant)
  - Lock 3 months:    0.8 * A
  - Lock 6 months:    1.0 * A
  - Lock 12 months:   1.5 * A   (boost for long alignment)

Vesting (for non-immediate modes):
  Linear after lock period over the lock period itself.
  Cancellation forfeits the boost back to treasury.

Anti-sybil:
  - Per-wallet cap.
  - Quadratic scaling above usage thresholds.
  - On-chain history filters (>= N days, >= M txns).
```

### Retroactive Public Goods Funding (RPGF)

**Use when**: Ecosystem has many small contributors (open-source devs, infrastructure providers, public goods) and you want to reward proven impact instead of speculative grants.

**Do not use when**: Contribution surface is small, well-known, and easily evaluated up-front. RPGF overhead exceeds the upside.

**Sketch**:

```text
Cycle (e.g. quarterly):
  1. Open nominations: any project that delivered measurable impact.
  2. Badge-holders (audited contributors, prior-round recipients) vote on impact.
  3. Voting weight may be quadratic to reduce whale influence.
  4. Top-N projects share a fixed budget allocated from treasury.
  5. Public retrospective: what was funded, what impact was claimed, what verified.

Properties:
  - Projects build first, get funded later. Filters speculation.
  - Funding is impact-weighted, not relationship-weighted.
  - Failed projects naturally lose future allocations; survivorship is encoded.
```

Optimism Collective is the largest live deployment.

## Anti-Patterns

### High TGE Unlock for Insiders

**Why it fails**: Insiders sell into illiquid launch order books and cap the chart at TGE.

**Instead**:

```text
Bad   investors: 25% TGE unlock
      -> dumped on day 1, -80% from open in 30 days

Good  investors: 0% TGE unlock
      cliff: 12 months
      vesting: 24-36 months linear after cliff
      community airdrop: separately, can be higher if broadly distributed
```

### Linear Vesting Without Cliff

**Why it fails**: Recipients sell from day 1; no commitment period; insiders take partial liquidity before product is shipped.

**Instead**:

```text
Bad   month 1: 2.5% unlocked, month 2: 5%, ...

Good  month 1-12: 0% (cliff)
      month 13: lump (12 months accrued at cliff release) OR begin linear
      month 13-48: linear vest of remaining 75%
```

### Unsustainable APY

**Why it fails**: Headline APY is funded entirely by emissions. As price drops, dollar APY drops, mercenary capital leaves, price drops more. Death spiral.

**Instead**:

```text
Bad   "earn up to 10,000% APY"
      pure emission farm with no revenue backing

Good  base real yield from protocol fees:    5-15% (denominated in ETH/USDC)
      emission boost (decreasing schedule):  10-20%
      total APY:                             15-35%, mostly stable, with floor
```

Route any yield-related public copy through `legalizer`.

### Complex Utility Without Demand

**Why it fails**: Burn-for-premium / stake-for-boost / lock-for-governance only matters if anyone uses the protocol. Stacked utility on top of zero usage is theater.

**Instead**:

```text
Bad   four utility mechanisms, each requiring separate user actions, with
      no single user actually performing any of them.

Good  one essential utility: token is required to pay protocol fees, full stop.
      add second utility only after first one shows real consumption.
```

### No Value Accrual

**Why it fails**: Token captures nothing from protocol success; price is pure narrative.

**Instead**: pick at least one of:

```text
Real yield:      protocol fees (in non-native asset) routed to stakers / lockers
Treasury growth: revenue grows DAO treasury, value backed by treasury per token
Lockup demand:   protocol features require time-locked tokens (Curve, Convex pattern)
Selective burn:  revenue used for buyback-and-burn (declare honestly; not value accrual unless revenue > emissions)
```

### Short Team Vesting

**Why it fails**: Team is fully liquid before the protocol matures. Mercenary teams exit at full vest, no continuity.

**Instead**:

```text
Bad   team: 12 mo cliff, 12 mo linear (24 months total)

Good  team: 12 mo cliff, 36 mo linear (48 months total)
      optional: extension grants (smaller cliffs, fresh 24-mo vest)
      optional: performance milestones unlock additional grants
```

### Forced Token Utility

**Why it fails**: Requiring the token for basic protocol access creates user friction without value capture; users churn to tokenless competitors.

**Instead**:

```text
Bad   "must hold X tokens to use protocol"
      "must pay all fees in TOKEN"

Good  protocol works without holding the token.
      holding/staking/locking the token earns discount, boost, or governance.
      friction is a feature for stakeholders, not a tax on users.
```

### Buyback-and-Burn as Headline Story

**Why it fails**: Burns can be credibly value-accreting only when revenue exceeds emissions. Otherwise, the protocol is buying back tokens with money it could have used to fund operations, while still net-issuing.

**Instead**:

```text
Bad   "all revenue goes to buyback and burn" while emitting 2% of supply per quarter

Good  publish (revenue, emissions, net flow) every quarter.
      buyback only when revenue > emission_value over trailing N weeks.
      otherwise route revenue to treasury or real yield.
```

### Pure 1-Token-1-Vote Governance with Live Treasury

**Why it fails**: Snapshotting voting power from the current block enables flash-loan governance attacks. Even without flash loans, mercenary token accumulation can drain a treasury.

**Instead**:

```text
Bad   Governor contract that reads current balance for voting power
      no timelock between proposal pass and execution
      treasury directly callable by Governor

Good  Snapshot voting (past-block balance) OR ve-locked voting power
      Timelock (>= 48h, 7d for treasury moves)
      Multisig veto / pause for emergency
      Quorum minimum (4-10% of circulating)
      Proposal threshold (small but non-zero, to prevent spam)
```
