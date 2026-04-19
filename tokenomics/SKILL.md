---
name: tokenomics-design
description: Designs and audits token economics for Web3 protocols -- distribution, vesting, emission curves, value accrual, governance design, anti-dump and anti-sybil mechanics, and sustainability modeling. Use when designing or reviewing tokenomics, allocation tables, vesting schedules, emission schedules, staking or veToken systems, liquidity-mining programs, airdrops, points programs, governance parameters, or when the user mentions tokenomics, token distribution, vesting, cliff, TGE, FDV, emissions, inflation, real yield, ve-token, POL, bonding curves, airdrop design, or token launch.
---

# Tokenomics Design

Architect-level skill for token economic design and review. Focuses on **what to build, why, and how it fails** -- not on implementation code (route to `solidity-security` and `web3-testing` for that). The body is intentionally thin; depth lives in `references/`. Open only the file you need.

## Companion skills (route to these first)

This skill is the **economic-design layer**. Defer to companion skills for adjacent domains:

| Domain | Use skill |
|--------|-----------|
| Public copy about token, staking, governance, fees | `legalizer` |
| Whitepaper / litepaper authoring | `whitepapers` |
| Cross-chain, custody, governance contract architecture | `ultimate-web3` |
| Solidity vulnerability classes and secure patterns (vesting wallets, governor, timelocks) | `solidity-security` |
| Test design for vesting, emissions, governance (fuzz, invariants, fork) | `web3-testing` |

If the user asks for **how to write the contract**, route to `solidity-security`. If the user asks for **how to publish or describe** a token, route to `legalizer`. Use **this** skill for **what the mechanism should be, what numbers it should use, and how it can fail economically**.

## Token economy rules for the agent

1. Read at most **2 reference files per turn**. Choose by the routing table below.
2. Never improvise legal framing or marketing copy. Token-related public prose must pass `legalizer`.
3. Do not paste back numbers or schedules the user already provided. Critique or extend them.
4. Prefer tables, schedules, and equations over prose.
5. Use `WebSearch` for current unlock-schedule benchmarks, FDV/MCap norms by sector, and recent token launches. Norms change cycle-to-cycle.
6. When the user asks "is this tokenomics good?", run the **Audit workflow** below before commenting.

## Routing table

| User intent or keyword | Open file |
|------------------------|-----------|
| Allocation tables, vesting, cliffs, TGE, ve-token, POL, dual-token, bonding curve, halvings, real yield, points-to-token, RPGF, gauge weights | `references/patterns.md` |
| "Is this safe?", footguns, FDV-vs-float, emission death spiral, cliff dump, governance attack, airdrop dump, velocity, whale concentration, oracle manipulation, forced utility | `references/sharp_edges.md` |
| Numerical review, "does this add up?", allocation sums, cliff durations, TGE %, supply caps, governance safeguards, distribution metrics | `references/validations.md` |

## Golden rules (non-negotiable)

1. **Utility before incentive.** If the token has no functional role beyond capturing future value, it is a security narrative dressed as a token. Define what the token *does* in the running protocol before designing emissions.
2. **Allocations sum to 100% and every wallet vests.** Any insider allocation (team, investors, advisors, foundation employees) must have a cliff and a linear or stepped vesting schedule. No exceptions.
3. **Emissions are a budget, not a feature.** Every emitted token must have a buyer-of-last-resort thesis (protocol revenue, organic demand, lock-up sinks). Without it, the token is selling itself.
4. **FDV / float ratio drives launch dynamics.** A high-FDV / low-float launch concentrates dump risk at every unlock cliff. Model the unlock waterfall before announcing the cap table.
5. **Governance is an attack surface.** Snapshot voting, timelocks, quorum minima, and an emergency multisig are required from day one. Pure on-chain Governor with no timelock is a vulnerability.
6. **Distribution > narrative.** A token concentrated in <10 wallets cannot credibly market decentralization. Track Gini and top-N-holder share from launch.
7. **Securities posture is design, not disclaimer.** Profit-expectation language, dividend-like fee distributions, and "buy-and-hold to earn" framing trigger Howey analysis. See `legalizer`.
8. **Verify before recommending.** Use `WebSearch` for current FDV/MCap benchmarks, sector-specific unlock norms, and recent launch postmortems before quoting numbers.

## Default decision matrix

Defaults to use unless the user has explicit constraints. Document any deviation.

| Decision | Default | When to deviate |
|----------|---------|-----------------|
| Total supply | Capped, fixed | Dynamic only with a clear sink/source equilibrium model |
| Insider cliff | 12 months | 6 months for advisors, 24 months for team in long-horizon infra |
| Insider vesting after cliff | 36-month linear, monthly unlock | Quarterly only with disclosed schedule and small cohort |
| TGE unlock for insiders | 0% | Strict zero; never above 5% |
| TGE unlock for community airdrop | 25-50% with vested remainder | 100% only for tiny, broadly distributed allocations |
| Initial circulating float | 10-25% of total supply | Lower only with strong unlock-schedule communication |
| FDV / market-cap ratio at launch | < 4x | Above 4x is acceptable only with public unlock schedule and lock-extension incentives |
| Emission curve | Halving or smooth-decreasing | Constant only when paired with hard supply cap and short total emission window |
| Liquidity bootstrap | Phased: high emissions → POL → fee-driven | Pure perpetual liquidity mining is an anti-pattern |
| Governance | Snapshot vote + on-chain Governor + Timelock + emergency multisig | Off-chain only when no on-chain treasury or parameters exist |
| Voting power | ve-locked, time-weighted | 1-token-1-vote only for tiny treasuries with low attack value |
| Quorum | 4-10% of circulating supply | Higher for parameter changes that touch funds |
| Timelock | 48 hours minimum, 7 days for treasury moves | Shorter only for emergency-pause actions |
| Value accrual | Fee routing to staked / locked holders, denominated in non-native asset (real yield) | Token buyback acceptable only when revenue exceeds emissions |

## Workflows

### Design workflow (new token)

```
Phase 1: Function
  - Define what the token does in the protocol (gas, weight, access, governance).
  - Reject mechanisms that exist only to create demand for the token.
  - Confirm with legalizer scope: utility framing only.
  Gate: one-paragraph utility statement that survives a "remove the token" thought experiment.

Phase 2: Allocation
  - Build allocation table (community, ecosystem, treasury, team, investors, advisors).
  - Sums = 100.0% exactly. Every insider bucket has cliff + vest.
  - Open references/patterns.md for vesting and distribution patterns.
  Gate: validations.md checks 1, 2, 3 pass.

Phase 3: Emissions and sinks
  - Choose curve (halving / smooth decreasing / fixed window).
  - Identify sinks (burns, locks, fees consumed, governance lockup).
  - Model: weekly_emission_value vs expected_buy_pressure for year 1 and year 2.
  Gate: sustainable emission check (sharp_edges.md "emission-exceeds-demand").

Phase 4: Governance
  - Snapshot or on-chain Governor + Timelock + emergency multisig.
  - Set quorum, proposal threshold, voting period, timelock delays.
  - Decide ve-lock vs flat voting power.
  Gate: governance safeguard check (validations.md check 8).

Phase 5: Launch dynamics
  - Compute float, FDV, FDV/MCap ratio.
  - Build full unlock waterfall (per cohort, per month, in tokens and % of float).
  - Stress-test: assume each cohort sells 100% at unlock. Identify cliff dates.
  Gate: no single unlock event > 10% of circulating supply.

Phase 6: Compliance and disclosure
  - Run all public-facing strings through legalizer.
  - Publish vesting schedule and unlock waterfall before TGE.
  - Cross-link audit reports for vesting and governance contracts.
  Gate: zero legalizer hard-block phrases in any external document.
```

### Audit workflow (existing tokenomics)

Use this when reviewing a published or proposed token model.

```
1. Open references/validations.md and run every check against the user's spec.
   For each failed check, cite the rule and quote the offending line.

2. Open references/sharp_edges.md and match the model against each failure mode.
   For each match, name the failure ID and describe the symptom in this specific design.

3. Compute the unlock waterfall:
   - For each insider cohort: cliff date, total tokens, unlock pace.
   - For each month after TGE: tokens unlocked, % of then-circulating, % of total supply.
   - Flag any month where unlock > 10% of circulating supply.

4. Compute the emission sustainability ratio:
   weekly_emission_value = weekly_token_emissions * current_price
   weekly_buy_pressure = protocol_revenue + organic_demand_estimate + new_capital_inflow
   sustainability_ratio = weekly_buy_pressure / weekly_emission_value
   Flag if ratio < 1.0; warn if ratio < 1.5.

5. Compute distribution health:
   - Top-10 holder share (target: < 40% post-vest, excluding contracts).
   - Top-100 holder share (target: < 70% post-vest).
   - Gini coefficient if data available (target: < 0.8).

6. Review governance parameters against defaults in this file.

7. Run all quoted public-facing copy through legalizer rules.

8. Output a structured report:
   - Critical (must fix before launch)
   - High (fix before next phase)
   - Medium (address in next iteration)
   - Info (worth noting)
   Each finding cites a check ID from validations.md or a failure ID from sharp_edges.md.
```

## Self-check before sign-off

Run this list before declaring a tokenomics design done. Every item must pass or have a written justification.

- [ ] Allocation table sums to exactly 100.000%.
- [ ] Every insider bucket has a cliff (>= 6 months) and a vesting schedule.
- [ ] TGE unlock for insiders is 0% (or documented exception with justification).
- [ ] Token has at least one functional utility in the running protocol; design survives "remove the token" thought experiment.
- [ ] Emission schedule is bounded (cap, halving, or terminal date).
- [ ] Sustainability ratio modeled for year 1 and year 2; thresholds defined.
- [ ] Unlock waterfall published; no single month exceeds 10% of circulating supply.
- [ ] Governance has timelock (>= 48h), quorum, proposal threshold, emergency multisig.
- [ ] Value accrual mechanism specified (real yield, treasury growth, lockup demand) -- not "buyback hopes".
- [ ] Distribution targets named (top-10, top-100, Gini) and tracked post-launch.
- [ ] All public-facing copy passes legalizer hard-block list.
- [ ] Vesting and governance contracts referenced to audited implementations (e.g. OpenZeppelin v5 `VestingWallet`, `Governor`, `TimelockController`) or carry their own audit.
- [ ] Whitepaper / litepaper section on tokenomics matches this spec exactly.

## Do not

- Do not propose mechanisms that exist purely to create token demand (forced utility, artificial sinks).
- Do not quote APYs above ~30% as sustainable; emissions-funded yields collapse.
- Do not recommend "buyback and burn" as a primary value-accrual story; it is often a red flag for missing utility.
- Do not design 1-token-1-vote governance for any treasury > $1M.
- Do not ship without a published unlock waterfall.
- Do not write public-facing copy from inside this skill; route to `legalizer`.
- Do not invent percentages or vesting numbers when the user provided real ones; critique the user's numbers instead.
