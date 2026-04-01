---
name: legalizer
description: Audits and rewrites public-facing content (website copy, docs, announcements, social posts, whitepapers) for Web3/crypto protocol projects to eliminate securities-risk language and enforce utility-token framing. Applies guardrails derived from the SEC/CFTC joint interpretive rule, Howey test analysis, and FinCEN non-custodial guidance. Use when reviewing or writing any externally published content about a token, staking, governance, fees, or protocol participation -- or when the user mentions legalizer, compliance review, token language, Howey, securities risk, public copy, or utility framing.
---

# Legalizer

Enforces legal guardrails on public-facing content for Web3 protocol projects. Goal: keep every published statement in the "utility" lane -- functional, operational, descriptive -- and scrub anything that could trigger a Howey analysis or SEC/CFTC securities classification.

## Core Rule

**Describe what the token does. Never describe what the token earns.**

All copy must reflect the SEC/CFTC digital commodity test: value derives from the programmatic operation of a functional system, not from the managerial efforts of others or expectation of profit.

## Audit Checklist

When reviewing any content, flag every instance of:

### Hard Blocks (must rewrite, no exceptions)

| Pattern | Why |
|:---|:---|
| "earn," "yield," "return," "ROI," "APY," "APR," "passive income" | Implies profit expectation (Howey prong 4) |
| "revenue," "profit," "earnings," "income" describing token holder outcomes | Securities language |
| "investment," "investor," "invest in" | Direct investment framing |
| "fee capture," "value accrual," "revenue share," "fee revenue flows to" | Implies economic benefit from others' efforts |
| "appreciation," "upside," "price target," "token value will" | Forward-looking financial promise |
| "stake to earn," "staking rewards" (when framed as income) | Passive income framing |
| Any specific price, price projection, or revenue estimate | Prohibited in all contexts |
| "get a share of," "profit from the protocol" | Revenue distribution framing |

### Soft Flags (review context, often rewrite)

- "rewards" -- acceptable only when clearly tied to computational work, not financial return
- "incentives" -- acceptable for participation incentives, not financial incentives
- "benefits" -- acceptable for governance/utility benefits, not financial benefits
- "grow," "growth" -- acceptable for network growth, not token value growth

## Approved Substitutions

| Flagged phrase | Approved replacement |
|:---|:---|
| "earn staking rewards" | "receive validator compensation for computational work" |
| "passive income from staking" | "validators are compensated for operating network infrastructure" |
| "revenue flows to token holders" | "fee parameters are set by governance" |
| "invest in the protocol" | "participate in network operations" |
| "token value appreciation" | "network participation and governance rights" |
| "profit from fees" | "service fees sustain network operations" |
| "stakers earn a share" | "validators receive token distributions for computational work" |
| "ROI on staking" | (remove -- no acceptable substitute) |
| "get returns" | "participate in governance" |
| "fee capture mechanism" | "operational cost coverage model" |

## Tone Standard

Write with the confidence of an engineering team, not a financial product:

- Describe mechanics, not outcomes
- Use active protocol language: "the contract verifies," "validators sign," "governance votes"
- Avoid superlatives and marketing inflation ("revolutionary," "game-changing")
- Third-person factual preferred for docs; second-person action-oriented for UX copy ("you submit a proof," not "you'll earn")

## Approved Vocabulary

Use these terms freely:

- Network participation, computational work, validator operations
- Governance rights, protocol parameter voting, on-chain governance
- Service fee, operational cost, network sustainability
- Token distribution, validator compensation, contributor allocation
- Shielded transfer, privacy-preserving, ZK proof, non-custodial
- Open-source protocol, permissionless, trustless

## Rewrite Workflow

1. Scan the full document for every Hard Block term (grep/search for the word list above)
2. Flag each instance with the category: `[HARD BLOCK]` or `[SOFT FLAG]`
3. Apply the approved substitution or rewrite the sentence to remove the concept entirely
4. Re-read the rewritten passage -- if a reasonable reader could interpret it as a financial promise, rewrite again
5. Confirm: no price projections, no yield figures, no income claims remain anywhere in the document

## What to Preserve

Do not sanitize accurate technical descriptions:

- ZK proof mechanics, circuit parameters, bridge architecture
- Governance process descriptions (voting, quorum, timelock)
- Token supply, distribution schedule, vesting (factual, not as investment pitch)
- Validator requirements (stake size, hardware, uptime) -- these are operational facts
- Fee amounts or rates expressed as operational parameters, not investor returns

## Quick Reference: The Howey Test

A token is a security if it is: (1) an investment of money, (2) in a common enterprise, (3) with expectation of profits, (4) from the efforts of others.

Your copy must neutralize prongs 3 and 4 in every sentence. Describe utility, mechanics, and governance. Never describe profit expectation or reliance on the team's efforts to generate returns.
