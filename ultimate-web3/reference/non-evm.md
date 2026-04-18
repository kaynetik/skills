# Non-EVM Chains

Architectural notes for Solana, Cosmos, and TON. EVM is covered separately.

## Solana

### Programming model

- Stateless programs (smart contracts) operate on accounts passed in by the caller
- All accounts a transaction touches must be declared up front (parallel execution model, Sealevel)
- Programs are deployed once; per-user state lives in **PDAs** (Program Derived Addresses), deterministically derived
- Cross-program calls use **CPI** (Cross-Program Invocation), with explicit account list propagation

### Default stack

| Layer | Choice |
|-------|--------|
| Language | Rust |
| Framework | Anchor (`anchor-lang`) |
| Tests | `anchor test` (uses local validator); `solana-program-test` for unit tests; LiteSVM for fast tests |
| Client SDK | `@solana/web3.js` v2 (modern, modular) or `@coral-xyz/anchor` for Anchor IDL |
| Wallet adapter | `@solana/wallet-adapter` |
| Indexer | Helius, Triton, or Yellowstone gRPC (Geyser plugin); Solana RPC alone is insufficient for production |
| NFT / token metadata | Metaplex Token Metadata, Metaplex Core for compressed/modern NFTs |

### Account model essentials

```rust
#[derive(Accounts)]
#[instruction(amount: u64)]
pub struct Deposit<'info> {
    #[account(mut, has_one = owner)]
    pub vault: Account<'info, Vault>,

    #[account(
        mut,
        seeds = [b"position", owner.key().as_ref()],
        bump,
    )]
    pub position: Account<'info, Position>,

    #[account(mut)]
    pub owner: Signer<'info>,

    pub system_program: Program<'info, System>,
}
```

Required Anchor constraints to use:

- `has_one` for relational integrity
- `seeds` + `bump` for PDA derivation, never trust client-supplied PDAs
- `mut` only when the account will be written
- `Signer<'info>` for any account that must authorize the action

### Compute budget

Solana transactions are bounded by compute units (CU). Default is 200,000 CU; max is 1.4M. Heavy operations (cryptography, big loops) require explicit CU budget request via `ComputeBudgetProgram.setComputeUnitLimit`. Optimize hot paths and benchmark with `anchor test --skip-lint` instrumentation.

### Address Lookup Tables (ALTs)

For transactions touching many accounts (DEX aggregators, multi-hop swaps), use ALTs to compress the account list. Required for any transaction approaching the 1232-byte tx size limit.

### Security essentials

- Validate signer authority (`Signer<'info>`) explicitly; never derive auth from account ownership alone
- Validate account owner program: Anchor does this automatically with typed `Account<'info, T>`, but raw `AccountInfo` skips it
- Prevent reinitialization: Anchor's `init` constraint enforces it; if using `init_if_needed`, audit carefully
- Use `checked_*` arithmetic in Rust; default `+` panics in debug but wraps in release without `overflow-checks = true`. Set `overflow-checks = true` in `Cargo.toml`.
- Beware of arbitrary CPI: any program you `invoke` can re-enter your program. Use Anchor's `Program<'info, T>` to type-check the target.
- Rent exemption: every account must hold enough lamports for rent exemption or it gets purged. Anchor handles this on `init`.

### Token standards

- **SPL Token** (legacy): standard fungible tokens
- **Token-2022** (modern): native extensions (transfer fees, confidential transfers, metadata, hooks). Use for new tokens unless integrating with infrastructure that does not support Token-2022 yet.
- **Compressed NFTs** (Metaplex Bubblegum): off-chain Merkle tree state, on-chain root. Required for collections > ~10k items at reasonable cost.

## Cosmos

### Programming model

- Each Cosmos chain is a sovereign chain with its own validator set, gas token, and governance
- App logic lives in either Go modules (Cosmos SDK native) or CosmWasm contracts (Rust, sandboxed)
- Cross-chain via **IBC** (Inter-Blockchain Communication): permissionless, light-client-based, channels and packets

### Default stack

| Layer | Choice |
|-------|--------|
| Chain framework | Cosmos SDK (Go) |
| Smart contracts | CosmWasm (Rust) |
| Tests | `cw-multi-test` for CosmWasm, Go test for SDK modules |
| Client SDK | `@cosmjs/stargate` + `@cosmjs/cosmwasm-stargate` |
| Wallet | Keplr (de facto standard), Leap |
| Cross-chain | IBC for native; Axelar / Wormhole for non-Cosmos chains |

### When to use a Cosmos app-chain

- Sovereign control of validator set, gas token, governance
- Cross-chain token movement to other Cosmos chains via IBC (permissionless)
- Custom modules at the consensus layer (e.g. orderbook engines like Sei v1, Injective)
- Low per-tx cost without subsidizing your users on a shared chain

### When CosmWasm beats native Go modules

- Logic changes need to be governance-upgradable without chain restart
- Multiple independent dapps will deploy on the chain
- Team is more productive in Rust than Go

### IBC essentials

- IBC is **packet-based** and **async**: cross-chain calls are not atomic
- Light clients on each side verify the other chain's consensus
- Channels can be reset by governance if a client expires
- Packet timeouts must be set; without them, stuck packets are unrecoverable
- Use **ICA** (Interchain Accounts) for cross-chain account control; ICS-721 for NFT transfers

### Security essentials

- CosmWasm contract migration is permissioned by the contract admin; either set a multisig admin or set admin to none for immutable contracts
- Replay protection across chains: include `chain_id` in any signed message
- Reentrancy in CosmWasm is impossible by default (sub-messages execute after current message returns)
- Validate `info.sender` for every authorization decision; never trust message fields

## TON

### Programming model

- Asynchronous, message-passing actor model (each contract has its own state, communicates via messages)
- Extreme parallelism: contracts run independently, no global lock
- Sharding native at the protocol level (workchains, shardchains)
- Wallets are smart contracts (TON has no plain EOA concept)

### Default stack

| Layer | Choice |
|-------|--------|
| Smart contract language | **Tact** (preferred for new projects) or **FunC** (lower-level) |
| Build / test framework | Blueprint (`@ton/blueprint`) |
| Tests | Sandbox (`@ton/sandbox`) for in-process simulation |
| Client SDK | `@ton/ton`, `@ton/core` |
| Wallet | TON Wallet, Tonkeeper, MyTonWallet; deeplinks via TonConnect |

### Architectural mindset

- Every action is a message; replies are also messages
- Storage rent: contracts pay rent per byte per second; small unused contracts get frozen and eventually deleted
- Gas (compute fees) and storage rent are separate accounting
- Multi-contract interactions are async by design; do not assume atomic state across contracts

### When TON makes sense

- Telegram-native distribution (Mini Apps, in-chat payments)
- High-throughput consumer apps where async UX is acceptable
- Markets where Telegram is the dominant social/payment app

### Security essentials

- Validate sender address on every message handler
- Plan for partial failure: a sub-message can fail and your contract may still have updated its state
- Use bounce messages to revert state on sub-message failure
- Replay protection: standard wallets handle it via seqno; custom contracts must implement nonces

## Comparison table

| Property | Solana | Cosmos | TON |
|----------|--------|--------|-----|
| Throughput | ~50k TPS theoretical, ~3k sustained | ~5k TPS per chain | Sharded, scales horizontally |
| Finality | ~12s economic | 5-7s instant (BFT) | ~5s |
| Composability | Atomic same-chain | None across chains (IBC is async) | None across contracts (async) |
| Ecosystem (DeFi TVL) | Largest non-EVM | Mid (Osmosis, Injective) | Growing |
| Language | Rust (Anchor) | Rust (CosmWasm) or Go (SDK) | Tact / FunC |
| Wallet UX | Phantom, Backpack, Solflare | Keplr | Tonkeeper, TON Wallet |
| Distribution edge | Phantom + memecoin culture | IBC interop | Telegram |

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| Picking Solana / Cosmos / TON because the EVM team "wants something new" | Demand a user or technical justification |
| Solana program with raw `AccountInfo` everywhere | Use Anchor typed accounts with constraints |
| Cosmos chain without governance plan | Define gov from day one; sovereign chains have no escape hatch |
| TON contract treating message handlers as synchronous | Design for async and partial failure |
| Solana token without Token-2022 evaluation | At least consider it for new mints |
| CosmWasm contract with permanent admin EOA | Multisig admin or remove admin entirely |
