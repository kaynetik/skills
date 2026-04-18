# Custody and Keys

Key management is design, not configuration. Decide custody architecture before writing the first contract.

## Custody models

| Model | Key holder | Use case |
|-------|-----------|----------|
| **Non-custodial** (user wallet) | End user | Default for consumer dApps |
| **Custodial** (service holds keys) | Operator (HSM / MPC / exchange) | Compliance-bound services, fiat onramps, simplified UX |
| **Smart account** (programmable custody) | User signer + protocol-defined rules | New default for consumer apps; see `reference/account-abstraction.md` |
| **Multisig** (Safe) | M of N owners | Treasury, protocol admin, deploy ops |
| **MPC / threshold** (Fireblocks, CCS, Coinbase Custody, Privy) | Distributed key shares | Institutional, embedded wallets |

## Key separation

Always separate keys by environment, role, and risk:

| Key | Used for | Storage |
|-----|----------|---------|
| **Deploy key** | Initial contract deployment | Hardware wallet, fresh seed, single-use; rotate after deploy |
| **Admin / upgrade key** | Proxy admin, upgrade authorization | Multisig (Safe) with timelock; never an EOA |
| **Operator key** | Routine operations (push oracle update, refill paymaster) | Hot wallet with rate limits; rotated frequently |
| **Treasury key** | Holds protocol funds | Multisig (Safe) with high quorum; geographically distributed signers |
| **Hot user wallet** (custodial service) | Daily withdrawals | HSM or MPC, with daily limits and approval workflows |
| **Cold storage** | Long-term reserves | Air-gapped, multi-sig, geographic separation |

**Never reuse keys across environments**: a testnet key compromise must not affect mainnet.

## Multisig: Safe defaults

For any production protocol, the canonical choice is **Safe** (formerly Gnosis Safe).

| Decision | Default |
|----------|---------|
| Quorum | 3 of 5 minimum for treasury; 2 of 3 acceptable for ops; 4 of 7 or higher for high-TVL |
| Timelock | 24h-72h for upgrades; instant for routine ops below a value cap |
| Owner diversity | Geographic separation; mixed device types (Ledger, Trezor, Lattice); at least one MPC owner for institutional |
| Signing ceremony | Documented; out-of-band confirmation channel (Signal, in-person); never copy-paste tx hash from email |
| Recovery plan | Documented, tested at least annually; key holder rotation playbook |
| Module usage | Spending limits module for ops budget; auto-execute disabled in production |

Use **Safe{Core} SDK** or **Safe{Wallet}** for off-chain coordination. Never wrap a Safe in custom proxy logic without an audit.

## MPC and threshold signatures

When to choose MPC over multisig:

| Property | Multisig (Safe) | MPC (Fireblocks, CCS, Privy embedded) |
|----------|-----------------|---------------------------------------|
| On-chain footprint | 1 contract per address; tx looks like multi-sig | Looks like a normal EOA; cheaper gas |
| Cross-chain consistency | Different Safe instances per chain | Same address derivation across chains |
| Compliance integration | Manual workflows | Built-in policy engine, audit logs, SOC 2 |
| Key recovery | Owner key recovery via wallet | Provider's recovery (or threshold reshare) |
| Trust assumption | Smart contract code + signers | MPC protocol + provider operational security |
| Best for | DAOs, protocol admin, dev teams | Custodians, exchanges, institutional services |

**Embedded wallets** (Privy, Dynamic, Magic, Web3Auth) use MPC under the hood to give users a custody experience that feels Web2 (email/social login) while preserving non-custodial signing. Useful for consumer apps where seed-phrase UX kills conversion.

## Deploy ceremony

For mainnet protocol deployment:

1. **Generate fresh deploy key** on hardware wallet, never reused.
2. **Pre-fund** with exactly the gas needed (no excess).
3. **Deploy via deterministic CREATE2** so addresses are predictable and verifiable.
4. **Hand off** ownership/admin to multisig **immediately** after deploy.
5. **Verify on every relevant explorer** (Etherscan, L2 explorers, Sourcify).
6. **Publish deployment artifacts**: addresses, deploy block, deploy tx, source verification status, owner addresses.
7. **Drain or burn the deploy key**: any leftover ETH back to multisig; key never used again.
8. **Document who held the key, when, and where** (compliance trail).

See `reference/deployment-ops.md` for the operational details.

## Hardware wallet hygiene

For human signers on a multisig:

- Use a **dedicated** hardware wallet for protocol operations, not personal funds
- Keep firmware updated; verify firmware signatures from the vendor
- Use a **passphrase** (BIP-39 25th word) for hidden wallet
- Backup seed: metal plates, geographically separated
- **Verify transaction details on the device screen**, never trust the host computer's display
- Never sign blind transactions; require ABI parsing on the device (Ledger Clear Signing) where possible

## Hot wallet operations

When a hot wallet is unavoidable (oracle pusher, bot operator, paymaster funder):

- **Daily / weekly limit** enforced on-chain (Safe spending limit module or custom)
- **Auto-refill** from a Safe via timelock or approved automation (OZ Defender)
- **Per-action approval** via off-chain signing for any value above a threshold
- **Monitoring + alerting** on every transaction (Tenderly Web3 Actions, Defender Sentinel)
- **Rotation schedule**: rotate hot wallet keys at least monthly; quarterly minimum
- **Burner pattern**: drain to zero between sessions when possible

## Custodial service (if you must)

If you must hold user funds (exchange, fiat onramp, regulated service):

- Use a regulated custodian (BitGo, Anchorage, Coinbase Custody, Fireblocks) -- do **not** roll your own
- Implement **withdrawal allowlists** with manual review for new addresses
- Implement **velocity limits**: max withdrawal per user per period
- Implement **dual control**: any withdrawal above $X requires two approvers
- Maintain an **immutable audit log** (append-only, signed)
- **Insurance**: get a custody insurance rider (Lloyd's, Nexus Mutual, Marsh)
- **Proof of reserves**: publish at agreed cadence, ideally with a third-party attestation

## Cross-chain custody

For multi-chain protocol admin:

- Deploy the **same Safe address on every chain** via CREATE2 (Safe supports this with `safe-deployments`)
- Document which chains the multisig is deployed on
- For Cosmos chains: use a multisig module-account or ICA (Interchain Account) controlled from the home chain
- For Solana: use Squads (multi-sig protocol for Solana)
- Never assume cross-chain admin is one address; document per-chain

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| Production protocol owned by a single EOA | Move to Safe multisig with timelock |
| Same key used for deploy and admin | Separate; rotate deploy key after deployment |
| Hot wallet with no rate limit and no monitoring | Add limit module + Defender alerts |
| Multisig with all signers on the same hardware vendor | Diversify (Ledger + Trezor + Lattice) |
| Multisig with no documented recovery plan | Write the plan; test it annually |
| Embedded wallet provider with no withdrawal export path | Choose a provider that supports key export or secure migration |
| Custodial service holding 100% of user funds in a hot wallet | Cold storage majority; hot covers daily ops only |
| Deploy ceremony documented in a Discord chat | Use a runbook; commit it to a private repo |
| Ignoring key compromise drills | Test "what if signer X is compromised today" annually |
| Cross-chain protocol with different Safe addresses per chain | Deploy via CREATE2 to keep addresses uniform |
