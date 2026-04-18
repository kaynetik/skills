# Privacy L1 Design

Architectural notes for designing or evaluating privacy-preserving blockchains. This is a research-adjacent area; the design space is wider than EVM/Solana production work, and the failure modes are subtle.

## Threat model first

Before discussing primitives, define explicitly:

| Question | Why it matters |
|----------|----------------|
| Who is the adversary? | Chain analyst, validator, RPC provider, network observer, regulator |
| What must remain private? | Sender, receiver, amount, asset type, contract logic, timing |
| What can leak? | Transaction graph, IP address, timing correlations, view-key disclosures |
| Under what assumptions? | Honest majority, threshold honesty, trusted setup, hardware enclave |
| Who needs view-key access? | User only, regulator on demand, designated auditor |
| What is the regulatory posture? | Default-private with view keys (Aleo) vs default-transparent with optional shielding (Zcash) |

Without an explicit threat model, every primitive choice is arbitrary.

## Privacy primitives

| Technique | Hides | Trusted setup | Production examples |
|-----------|-------|---------------|---------------------|
| **Ring signatures** | Sender (within a ring) | None | Monero (CryptoNote, RingCT) |
| **zk-SNARKs (Groth16)** | Sender, receiver, amount | Per-circuit (toxic if mishandled) | Zcash Sapling |
| **zk-SNARKs (PLONK / Halo 2)** | Sender, receiver, amount | Universal (Halo 2: none) | Aztec, Aleo, Mina |
| **zk-STARKs** | Sender, receiver, amount | None; post-quantum candidate | StarkNet (programmability, not privacy by default) |
| **Bulletproofs** | Amount (range proofs) | None | Monero RingCT, Mimblewimble |
| **Stealth addresses** | Receiver (one-time addresses) | None | Monero, Umbra (Ethereum), ERC-5564 |
| **Confidential transactions** | Amount (Pedersen commitments + range proof) | None | Mimblewimble (Grin, Beam), Liquid |
| **MimbleWimble** | Sender, receiver, amount; aggregates txns | None | Grin, Beam |
| **Encrypted state (TEE)** | Contract state and execution | Hardware enclave | Secret Network (SGX), Oasis (Sapphire) |
| **Fully homomorphic encryption (FHE)** | Computation on encrypted data | None | Zama fhEVM (early production), Inco |
| **MPC** | Distributed computation | None (assumes threshold honesty) | Many emerging chains |

## Design considerations

### Transaction model

| Model | Privacy implications | Examples |
|-------|---------------------|----------|
| **UTXO** | Each output is a one-time atom; natural fit for shielded transactions and parallel validation | Bitcoin, Zcash, Monero, Mimblewimble |
| **Account** | Persistent state; harder to hide; better for general computation | Ethereum, Solana, Aleo (with zk-SNARK shield) |
| **Hybrid (eUTXO)** | UTXO with smart-contract validity scripts | Cardano |
| **Records / commitments** | UTXO-style commitments + nullifiers, with smart-contract programmability | Aztec, Aleo |

For private smart contracts, UTXO-with-commitments (Aztec, Aleo) is the dominant pattern.

### Network-layer privacy

Transaction-level privacy is undone by IP-level analysis. Mitigations:

- **Dandelion / Dandelion++** stem-and-fluff propagation
- **Tor / I2P integration** for RPC submission
- **Mix networks** (Nym, Loopix-style) for stronger latency-resistant anonymity
- **Private RPC infrastructure**: users do not query a public RPC that logs requests

### Auditability and compliance

Default-private chains face regulatory pressure. Designs include:

- **View keys** (Zcash, Aleo): user can grant a third party read access without giving spend authority
- **Optional shielding** (Zcash z2t / t2z, Penumbra): users can move between transparent and shielded pools
- **Selective disclosure**: ZK proof that a transaction satisfies a property without revealing the transaction
- **Compliance pools** (Privacy Pools, Tornado Nova ASP): users prove they are not in a sanctioned set

The design tension is: stronger privacy attracts more regulatory scrutiny; weaker privacy defeats the purpose. Make this tradeoff explicit.

### Consensus

Privacy chains favor consensus mechanisms with predictable finality and resistance to validator-level deanonymization:

- **Tendermint BFT** (Cosmos): instant finality; suitable
- **PoS with VRF leader selection** (Ouroboros Praos style): predictable, formally analyzed
- **Avalanche-style metastable consensus**: high throughput, weaker formal analysis
- **PoW**: still used by Monero; energy-intensive but battle-tested

Avoid consensus designs that leak which validator proposed a specific block in ways that correlate with the transaction set.

### Post-quantum considerations

Most ZK constructions today rely on cryptographic assumptions (discrete log, pairings) broken by sufficiently large quantum computers. For long-term privacy:

- **Hash-based signatures** (XMSS, SPHINCS+): post-quantum, large signatures
- **Lattice-based** (Dilithium, Falcon): post-quantum, NIST-finalized
- **STARKs**: post-quantum (hash-based)
- **Symmetric primitives** (AES with 256-bit keys): post-quantum-resistant

If your chain is meant to keep transactions private for decades, evaluate post-quantum primitives now.

### Implementation safety

- **Constant-time** implementation of all cryptographic primitives (no data-dependent branches or memory accesses)
- **Trusted setup ceremonies**: if using Groth16 or KZG, run a multi-party computation ceremony with public participation, publish all transcripts
- **Audited circuits**: ZK circuits have a long history of subtle soundness bugs; require independent review
- **Side-channel hardening**: timing, power, EM analysis matter for hardware wallets and TEE-based designs
- **Reference implementations**: prefer audited libraries (arkworks, halo2, plonky2) over hand-rolled

## Reference designs to study

| Project | Worth studying for |
|---------|-------------------|
| **Zcash** | Sapling and Orchard circuits; transparent / shielded interop |
| **Monero** | Ring signatures, RingCT, stealth addresses, network-layer (Dandelion++, Tor) |
| **Aztec** | Private smart contracts via PLONK; hybrid public/private state |
| **Aleo** | snarkVM, zkSNARK execution model, view keys |
| **Penumbra** | Cosmos-native shielded chain; flow-based privacy |
| **Mina** | Recursive ZK proofs; succinct chain state |
| **Mimblewimble** (Grin, Beam) | Cut-through; chain compression |
| **Secret Network** | TEE-based encrypted state (note: TEE has weaker guarantees than ZK) |
| **Tornado Cash / Nova / Privacy Pools** | Mixing pool designs and compliance approaches |

## Open research problems

- Trusted setup elimination at production scale (Halo 2, Plonky3, recursive proofs)
- Scalable private smart contracts (current designs sacrifice composability or throughput)
- Cross-chain private transfers (most bridges deanonymize)
- Privacy-preserving regulatory compliance (proof-of-non-membership in sanction lists)
- MEV and frontrunning resistance in privacy chains
- Timing-attack resistance on ring signature member selection
- Quantum-resistant ZK constructions efficient enough for production

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| "Privacy chain" with no formal threat model | Write the threat model before writing code |
| Custom cryptographic construction without academic review | Use audited primitives; novel cryptography requires peer review |
| Transaction-layer privacy without network-layer privacy | Integrate Dandelion, Tor, or mix network |
| ZK proofs without circuit audit | Audit independently; subtle soundness bugs are common |
| Trusted setup performed by founders only | Run a public multi-party ceremony |
| TEE-based privacy claimed as cryptographic guarantee | TEEs have side-channel and supply-chain risks; do not equate to ZK |
| No regulatory or compliance posture documented | Define it; default-private chains face inevitable scrutiny |
| Ignoring post-quantum threat for long-lived privacy | At least document the migration plan |
