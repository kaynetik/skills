# Tokenomics Validations

Hard rules for reviewing a tokenomics spec. Each row is a check; cite the **ID** in audit reports.

Severities:

- **error** -- must be fixed before sign-off.
- **warning** -- requires written justification if intentionally violated.
- **info** -- worth flagging; not blocking.

## Allocation and supply

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `alloc-sums-100` | error | Allocation table must sum to exactly 100.000% | `sum(buckets.percent) == 100.000` (six decimal tolerance) |
| `alloc-bucket-named` | error | Every allocation bucket has a named recipient class (team / investors / advisors / treasury / community / ecosystem / liquidity / airdrop) | No "other" or unlabeled buckets |
| `alloc-supply-cap` | warning | Total supply has a hard cap, halving schedule, or terminal emission date | Reject "uncapped", "unlimited", "infinite" with no decay |
| `alloc-cap-disclosed` | error | If a cap exists, it is stated in absolute tokens, not just percentages | E.g. "1,000,000,000 TOKEN" must appear in spec |

## Vesting and unlocks

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `vest-insider-cliff-min` | error | Team and investor allocations have cliff >= 12 months; advisors >= 6 months | `cliff_months >= 12` for team / investor; `>= 6` for advisor |
| `vest-insider-duration-min` | error | Team vest duration (cliff + linear) is >= 36 months; investor >= 24 months | `duration_months >= 36` (team), `>= 24` (investor) |
| `vest-tge-insider-zero` | error | TGE unlock for insiders is 0% (or documented exception with justification) | `tge_pct[insider_buckets] == 0` |
| `vest-tge-community-cap` | warning | TGE unlock for community airdrop <= 50% unless allocation is a tiny share of supply (< 1%) | `tge_pct[airdrop] <= 50 OR alloc_pct[airdrop] < 1` |
| `vest-cliff-stagger` | warning | Distinct insider cohorts (seed / Series A / team / advisors) have staggered cliff dates | No two cohorts share the exact same cliff release date |
| `vest-post-cliff-cadence` | warning | Post-cliff unlock cadence is monthly or finer (not quarterly) | `unlock_cadence_days <= 31` |
| `vest-schedule-published` | error | Full unlock waterfall is published with monthly resolution before TGE | Spec contains a per-month, per-cohort table |
| `vest-no-monthly-cliff` | warning | No single calendar month unlocks > 10% of then-circulating supply | For all months, `unlock_amount / circulating_at_month <= 0.10` |

## Float and FDV

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `float-tge-band` | warning | Initial circulating supply at TGE is between 5% and 25% of total | `0.05 <= float_tge / total_supply <= 0.25` |
| `fdv-mcap-ratio` | warning | FDV / market cap at launch < 4x | `total_supply / float_tge < 4` |
| `fdv-disclosed` | error | FDV is calculated and disclosed in the public spec | Spec contains `FDV = total_supply * launch_price` |

## Emissions and value accrual

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `emit-schedule-defined` | error | Emission schedule is specified with rate, curve, and end condition | Spec describes `emissions_per_period`, `decay_rule`, `end_condition` |
| `emit-bounded` | warning | Emissions are bounded by cap, halving, or terminal date | Reject perpetual constant emission unless tail rate < 2% / yr and justified |
| `emit-sustainability-modeled` | error | Sustainability ratio is computed for year 1 and year 2: `buy_pressure / emission_value` | Both years modeled; assumptions cited |
| `emit-sustainability-floor` | warning | Modeled sustainability ratio >= 1.0 in steady state | If < 1.0, dynamic-emission throttle must be specified |
| `value-accrual-defined` | warning | At least one value-accrual mechanism is specified: real yield, treasury growth, lockup demand, conditional buyback | Spec names mechanism, not "future TBD" |
| `value-accrual-not-only-buyback` | info | Buyback-and-burn is not the *only* value-accrual mechanism | If only buyback, raise to warning |

## Utility

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `util-defined` | error | Token has at least one functional utility in the running protocol | Spec names utility (gas / weight / access / governance / fee payment) |
| `util-survives-removal` | warning | Design survives "remove the token" thought experiment: would the protocol still work? If yes, utility is too thin | Written justification required |
| `util-not-forced` | warning | Token is not required for basic protocol use; holding gets benefits, not access | No "must hold X to use Y" patterns |

## Governance

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `gov-snapshot-or-ve` | error | Voting power is either snapshot-based (past block) or ve-locked; not current-balance | Reject Governor that reads current balance |
| `gov-timelock-min` | error | Timelock between proposal pass and execution is >= 48h | `timelock_hours >= 48` |
| `gov-timelock-treasury` | error | Treasury moves require timelock >= 7 days | `timelock_hours >= 168` for treasury actions |
| `gov-quorum-defined` | error | Quorum is defined as % of circulating (not total) supply | Spec states quorum % and basis |
| `gov-quorum-band` | warning | Quorum is between 4% and 15% of circulating supply | `0.04 <= quorum_pct <= 0.15` |
| `gov-emergency-multisig` | error | Emergency multisig exists with documented composition, threshold, and powers | Multisig N-of-M, geographic / key separation noted |
| `gov-emergency-bounded` | error | Emergency multisig cannot mint, transfer treasury, or upgrade contracts unilaterally | Powers list reviewed |
| `gov-proposal-threshold` | warning | Non-zero proposal threshold to prevent spam | `proposal_threshold_pct > 0` |

## Distribution health

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `dist-top10-target` | warning | Top-10 holder share (excluding contracts) targeted < 40% post-vest | Spec states the target |
| `dist-top100-target` | warning | Top-100 holder share targeted < 70% post-vest | Spec states the target |
| `dist-monitoring` | info | Distribution metrics are tracked publicly post-launch | Spec names the dashboard / source |
| `dist-airdrop-per-wallet-cap` | warning | Airdrop has per-wallet cap and Sybil filtering | Cap value and filter rules stated |

## Liquidity

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `liq-strategy-defined` | warning | Liquidity provision strategy is documented | Spec names approach (POL, LM, hybrid) |
| `liq-pol-target` | info | If POL is used, target POL share of total liquidity is stated | Target % named |
| `liq-no-cliff` | error | Liquidity-mining program cannot drop to zero in a single step | Schedule shows phased reduction |

## Compliance and disclosure

| ID | Severity | Rule | Check |
|----|----------|------|-------|
| `comp-legalizer-passed` | error | All public-facing prose has passed the `legalizer` skill or external counsel | Sign-off recorded |
| `comp-no-roi-language` | error | No "earn / yield / ROI / passive income / appreciation / value accrual" in any public document | Grep against legalizer hard-block list |
| `comp-no-price-projection` | error | No price targets, ROI estimates, or revenue forecasts in any public document | Reject any forward-looking financial claim |
| `comp-disclosure-vesting` | error | Vesting schedule is published before TGE and updates are version-stamped | Public link present |
| `comp-disclosure-cap-table` | error | Allocation table is published before TGE | Public link present |
| `comp-audit-vesting-contract` | warning | Vesting and governance contracts are audited or use audited references (e.g. OpenZeppelin v5) | Audit firm and date or library version cited |

## How to use these checks

When reviewing a spec, run every applicable check and produce output of the form:

```text
[ERROR]   vest-insider-cliff-min
  Team allocation shows 6-month cliff; rule requires >= 12 months.
  Quoted: "Team: 6 month cliff, 24 month linear vest"
  Fix: extend cliff to >= 12 months; consider 36-month total duration.

[WARNING] fdv-mcap-ratio
  Computed FDV / MCap = 8.3x; target < 4x.
  Inputs: total_supply = 1B, float_tge = 120M, launch_price = $1.
  Fix: increase TGE float OR document unlock-extension incentives.

[INFO]    value-accrual-not-only-buyback
  Only "buyback and burn" is named. Consider real-yield distribution.
```

Group findings by severity. Reference the failure IDs from `sharp_edges.md` where they apply.
