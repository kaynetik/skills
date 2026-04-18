# Deployment and Operations

Production deployment, multi-chain rollout, post-deploy monitoring, and incident response. Test setup belongs in `web3-testing/reference/setup-foundry.md`. Custody and key isolation for the deploy key belong in `reference/custody-and-keys.md`.

## Pre-deployment checklist

Do not begin a mainnet deploy until every box is checked.

- [ ] All tests pass (unit, fuzz, invariant, fork) -- see `web3-testing`
- [ ] Static analysis clean (Slither, Aderyn) -- see `web3-testing/reference/static-and-property.md`
- [ ] External audit completed; all critical / high findings remediated and re-reviewed
- [ ] Storage layout pinned and diff-checked against the last audited version
- [ ] Bytecode reproducible from a tagged commit on a clean machine
- [ ] Deployment script reviewed by at least one other engineer
- [ ] Deploy key generated on hardware wallet, never reused
- [ ] Multisig (Safe) deployed and its address known
- [ ] Timelock deployed and configured
- [ ] Emergency pause guardian configured and tested on testnet
- [ ] Etherscan / Sourcify / Blockscout API keys ready for verification
- [ ] Monitoring (Tenderly Web3 Actions, Defender Sentinels, Forta bots) configured for testnet, ready to swap to mainnet
- [ ] Post-deploy runbook reviewed and approved
- [ ] Incident response on-call rotation defined
- [ ] Frontend pinned to the deployed addresses, ready to ship
- [ ] Docs updated with new addresses
- [ ] Bug bounty program announced (Immunefi, hats.finance, or self-hosted)

## Deterministic deployment (CREATE2)

For multi-chain protocols, identical addresses across chains are a UX and integration win. Use CREATE2 via Foundry's deterministic deployer or a custom factory.

```solidity
// foundry script
import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";

contract Deploy is Script {
    bytes32 constant SALT = bytes32(uint256(0x1));

    function run() external {
        vm.startBroadcast();
        Vault vault = new Vault{salt: SALT}();
        vm.stopBroadcast();
        require(address(vault) != address(0));
    }
}
```

Properties:

- Same bytecode + same salt + same deployer = same address on every chain
- Deploy via Foundry (`forge script`) with `--broadcast --verify`
- Use the canonical CREATE2 factory at `0x4e59b44847b379578588920cA78FbF26c0B4956C` for cross-deployer consistency
- Document salt and deployer per chain; store in a versioned `deployments/` directory

## Multi-chain rollout

```text
Phase 1: Testnet deploy (one chain)
  -> Hold for at least 1 week
  -> Run integration tests against deployed addresses
  -> Bug bounty active

Phase 2: Mainnet deploy (one chain, capped TVL)
  -> Pause on at least one rate-limit module
  -> Run for 2-4 weeks
  -> Monitor: TVL, error rates, gas usage, user feedback

Phase 3: Multi-chain rollout
  -> Same bytecode, deterministic CREATE2
  -> Stagger by 1-2 weeks per chain
  -> Repeat monitoring per chain
```

Avoid simultaneous launch on multiple chains. If something is wrong, you want one chain to fix at a time.

## Verification

Source verification is a non-negotiable. Without it, users cannot inspect the bytecode, and integrators cannot generate ABIs.

- **Etherscan / equivalents** (Basescan, Arbiscan, Polygonscan): use `forge verify-contract` or `forge script --verify`
- **Sourcify** (decentralized verification): submit alongside Etherscan; verifies via the metadata hash
- **Blockscout** (used on many L2s and OP Stack chains): submit per chain
- For private chains: deploy a Blockscout instance and verify there

Verify on **every** chain, immediately after each deploy.

## Monitoring

| Tool | What it does | Default for |
|------|--------------|-------------|
| **Tenderly** | Tx simulation, alerts, Web3 Actions (custom logic), debugger | Default for any production protocol |
| **OpenZeppelin Defender** | Sentinels (event/condition triggers), Autotasks, multi-sig admin actions | Default for ops automation and admin workflows |
| **Forta** | Decentralized detection bots; library of common-attack detectors | High-value protocols, layered defense |
| **Hypernative, Hexagate** | Real-time threat detection (commercial) | Institutional protocols |
| **Custom (web3.js / viem subscriptions)** | Bespoke alerts | Last resort; ops cost is high |

Minimum monitoring for any production protocol:

- **Total Value Locked** drift alert (rapid drop)
- **Admin function calls** alert (every call to `onlyOwner` / `onlyRole`)
- **Pause / unpause** alert
- **Guardian multisig activity** alert
- **Ownership transfer** alert
- **Proxy upgrade** alert (if upgradeable)
- **Hot wallet balance** alert (depletion before threshold)
- **Oracle price deviation** alert (vs reference)
- **Failed transaction rate** alert

## Incident response

When something goes wrong, you need pre-built playbooks. Do not improvise during an incident.

### Incident classes

| Class | Examples | Authority | Latency |
|-------|----------|-----------|---------|
| **Operational** | Hot wallet drained, paymaster out of funds | Ops on-call | Minutes |
| **Configuration** | Bad oracle config, wrong parameter | Multisig | Hours |
| **Security (active)** | Active exploit in progress | Guardian (pause) | Immediate |
| **Security (postmortem)** | Vulnerability disclosed but not exploited | Multisig + audit | Days |
| **Cross-chain** | Bridge compromised | Pause home + dest, coordinate with bridge team | Immediate |

### Active-exploit runbook (sketch)

1. **Pause** via guardian multisig (3 of 5 sign immediately; pre-circulated tx).
2. **Isolate** affected contracts: revoke roles, freeze admin functions.
3. **Communicate**: status page update, Twitter / Discord / Telegram, Etherscan contract page comment.
4. **Forensics**: snapshot blockchain state, identify exploit tx, compute loss.
5. **Mitigate**: deploy patch via timelock if possible; otherwise migrate-by-deploy.
6. **Recover**: white-hat the remaining funds if attacker is unidentified; coordinate with chain team / law enforcement if value is high.
7. **Postmortem**: publish within 1-2 weeks; update tests to cover the regression; adjust monitoring.

Pre-circulate the pause tx as a Safe transaction draft. Practice it on testnet quarterly.

## Upgrade ops

For upgradeable protocols:

- Always perform an **upgrade simulation** on a fork against current mainnet state (Foundry `--fork-url` + `vm.store` + admin impersonation)
- Diff the **storage layout** (`forge inspect <Contract> storageLayout` before and after)
- Diff the **ABI** to detect breaking changes for integrators
- Publish the upgrade proposal at least 7 days before timelock execution
- Provide a **rollback path** (keep previous implementation deployed and addressable)

## Multi-chain consistency

| Risk | Mitigation |
|------|-----------|
| Different parameters on different chains | Maintain a parameter registry; reconcile in CI |
| Stuck cross-chain message after upgrade | Document upgrade sequence; pause cross-chain ops during the upgrade window |
| Different oracle configs per chain | Document explicitly; never assume parity |
| Address drift (CREATE2 salt mismatch) | Enforce salt registry in deploy script; CI check |

## Post-mortem template

```markdown
# Incident YYYY-MM-DD: <title>

## Summary
<one paragraph: what happened, when, impact>

## Timeline (UTC)
- HH:MM Detection
- HH:MM First responder paged
- HH:MM Pause executed
- HH:MM Containment confirmed
- HH:MM Resolution

## Impact
- Users affected: N
- Funds lost: $X
- Recovery: $Y

## Root cause
<technical explanation>

## What worked
- ...

## What did not
- ...

## Action items
- [ ] Owner: action, deadline
- [ ] Owner: action, deadline
```

Publish post-mortems even when the incident is operational and minor. It builds trust and forces real analysis.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| Deploy via private key in `.env` checked into git | Hardware-wallet deploy; rotate keys after; CI secrets scan |
| Source not verified on all chains | Verify on every chain immediately after deploy |
| No monitoring on admin function calls | Add Defender Sentinel for every `onlyOwner` / `onlyRole` |
| Pause not pre-circulated as a Safe draft | Create the draft now; rehearse signing |
| Upgrade pushed without storage diff | Run `forge inspect storageLayout` and diff in CI |
| Multi-chain launch all on the same day | Stagger by at least a week per chain |
| Incident postmortem skipped because "it was minor" | Publish anyway; the discipline is the point |
| Hot wallet drains discovered by user, not monitoring | Add balance threshold alerts |
| No bug bounty live | Launch on Immunefi or hats.finance before mainnet |
| Custodial service without insurance | Get coverage; document gap if not |
