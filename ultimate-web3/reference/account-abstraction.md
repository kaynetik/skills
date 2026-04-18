# Account Abstraction

Standards landscape, when to pick which, and architectural implications. Frontend integration of smart accounts belongs in `web3-frontend/reference/wallet-ux.md`.

## Standards in production

| Standard | Type | Status | When to use |
|----------|------|--------|-------------|
| **ERC-4337** | Off-chain bundlers + on-chain EntryPoint | Live; v0.6, v0.7, v0.8 deployed | New smart-account wallets, gasless apps, session keys |
| **EIP-7702** | EOA temporarily becomes smart account via signed authorization | Live since Pectra (May 2025) | Upgrade existing EOAs, batch txns from MetaMask/Rabby/Rainbow |
| **ERC-6900** | Modular account interface (plugins) | Spec stable, adoption growing | When account needs upgradeable plugins |
| **ERC-7579** | Minimal modular accounts (alternative to 6900) | Spec stable, adoption in Safe and Rhinestone | Lighter modular standard than 6900 |

> Verify EntryPoint version (v0.6 / v0.7 / v0.8) for the chain you're targeting and pick the matching SDK. Different EntryPoint versions are not interoperable.

## ERC-4337 architecture

```text
User signs UserOperation
        |
        v
Bundler RPC (alt-mempool)
        |
        v
Bundler picks UOps -> bundle tx -> EntryPoint contract
                                          |
                                          |-- validates (Account.validateUserOp)
                                          |-- charges gas (Account or Paymaster)
                                          `-- executes (Account.execute / executeBatch)
```

Key components:

- **EntryPoint**: singleton at the same address on every chain (deterministic CREATE2). Trusted; do not deploy custom EntryPoints.
- **Account contract**: implements `validateUserOp`. OpenZeppelin and Safe both ship audited implementations.
- **Bundler**: runs an alt-mempool, simulates UserOps, builds bundles. Stackup, Pimlico, Alchemy, ZeroDev, Biconomy.
- **Paymaster**: optional contract that pays gas for the user. Sponsorship, ERC-20 gas tokens, session-based payment.

### EntryPoint version differences

| Version | Notable changes | Use for |
|---------|----------------|---------|
| v0.6 | Original spec | Maintain existing v0.6 deployments; do not start new projects on v0.6 |
| v0.7 | Packed UserOp, gas optimizations, separated validation/execution gas | Most production deployments today |
| v0.8 | EIP-7702 integration, further gas savings, simulation improvements | New projects should target v0.8 where supported |

## EIP-7702 (EOA -> smart account)

Live since Pectra. An EOA signs a `SetCode` authorization that points its code to a smart-contract delegate. From that point until revocation, the EOA executes the delegate's code.

When to use 7702 instead of 4337:

| Need | 7702 | 4337 |
|------|------|------|
| Upgrade existing EOA without migrating funds | Yes | No (requires deploy + migration) |
| Batch transactions in MetaMask/Rabby today | Yes | Wallet support uneven |
| Gas sponsorship | Yes (via 4337-compatible delegate) | Yes (paymaster) |
| Session keys / per-app permissions | Yes | Yes |
| New wallet, no existing user | Either; 4337 has more mature SDKs |

7702 + 4337 hybrid is the dominant pattern in 2025-2026: EOA delegates to a 4337-compatible smart account, gets batch + sponsorship + sessions without losing the original address.

> Security: 7702 delegation is **per-chain** (chain-specific authorization), but a single signature can authorize delegation to a malicious delegate. Wallet UX must clearly show which delegate the user is approving. See EIP-7702 for the chain-id-zero replay caveat.

## Modular accounts (ERC-6900 / ERC-7579)

When the account needs runtime-upgradeable behavior:

- Add a recovery module without redeploying the account
- Install a session key plugin per dapp
- Plug in a yield strategy module

Choose ERC-7579 unless you have a hard reason for ERC-6900. ERC-7579 is leaner and adopted by Safe (Safe{Core} accounts, Rhinestone).

## Capabilities you get with smart accounts

| Capability | Implementation |
|-----------|----------------|
| **Gasless transactions** | Paymaster sponsors (4337) or 7702 delegate routes via paymaster |
| **Batch transactions** | `executeBatch` (4337) or `BatchedCall` from 7702 delegate |
| **Session keys** | Validator module that authorizes signatures only for specific calls / time windows |
| **Social recovery** | Guardian module; quorum of guardians can rotate the owner key |
| **Multi-sig from day one** | Multi-owner validator (Safe's default) |
| **Spending limits** | Validator module with per-asset, per-time-window limits |
| **Deadline / expiry on actions** | Built into UserOp (`maxFeePerGas`, validity window) |

## Bundler choice

| Provider | Notes |
|----------|-------|
| Pimlico | Multi-chain, paymaster, popular ZeroDev / Permissionless.js stack |
| Alchemy | Embedded into Account Kit; tied to Alchemy infra |
| ZeroDev | Kernel account + bundler + paymaster as a stack |
| Biconomy | SDK, paymaster, and bundler |
| Stackup | Open-source bundler (`stackup-wallet/stackup-bundler`); self-host for control |
| Self-host (ERC-4337 reference impl) | Ops overhead; only for high-volume protocols |

## Frontend integration

Frontend code (wagmi `useCapabilities`, EIP-5792 wallet API for sponsored / batched calls) belongs in `web3-frontend/reference/writing.md`. Route there for transaction-flow code.

## Paymaster economics

A paymaster pays gas in ETH and recoups via:

- **Sponsorship**: protocol pays (acquisition cost). Budget per user, per session, per gas unit.
- **ERC-20 gas**: user pays in USDC / project token; paymaster swaps. Spread is the paymaster's fee.
- **Subscription**: user pays a monthly fee off-chain or via NFT; gets gas-included experience.

Paymaster is a contract you trust; if it's drained or paused, your users cannot transact via that path. Have a fallback (user pays gas directly) for resilience.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| Targeting EntryPoint v0.6 for a new project | Use v0.7 or v0.8 |
| Custom validator module without audit | Use Safe / ZeroDev / Rhinestone audited modules |
| Paymaster funded with $5k of ETH and no monitoring | Per-user limits + alerting + auto-refill |
| 7702 delegate hardcoded to a single contract address with no recovery path | Use a delegate that supports rotation |
| Treating bundler as trustless | Bundlers are accountable for inclusion but can censor; design for fallback |
| "We need ERC-6900" with no plugin requirement | Use ERC-7579 or a non-modular smart account |
| Smart account with single-key validation and no recovery | Add guardian module from day one |
| Mixing EntryPoint versions across chains in the same product | Pin one version per chain; document explicitly |
