# Solidity Architecture

Architectural patterns for production EVM contracts. Vulnerability classes and per-function patterns belong in `solidity-security`. Test patterns belong in `web3-testing`.

## Upgradeability strategy

Pick one strategy per protocol and document why. Mixing strategies inside one system is an anti-pattern.

| Strategy | When to use | Cost |
|----------|-------------|------|
| **Immutable** (no proxy) | Audited, finalized logic; trustless guarantees primary | Cannot patch bugs; requires migrate-by-deploy |
| **UUPS proxy** (EIP-1822) | Logic may evolve; gas-conscious; no need for plugin extensibility | Storage layout discipline, admin compromise risk |
| **Transparent proxy** (TransparentUpgradeableProxy) | Legacy / OZ default before UUPS | Higher per-call gas; same admin risks |
| **Beacon proxy** | Many instances of the same upgradeable contract (factories) | Single beacon update affects all instances |
| **Diamond** (ERC-2535) | Genuine plugin extensibility, contract size > 24KB limit | High complexity, selector clash risk, harder audits |
| **Migrate-by-deploy** | Versioned contracts; users opt in to migrate | Liquidity / state migration is non-trivial |

> Use the OpenZeppelin Upgrades plugin (`openzeppelin-foundry-upgrades` or hardhat plugin) for UUPS / Transparent / Beacon. It enforces storage layout safety. Manual proxies are a footgun.

## UUPS canonical layout

```solidity
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Vault is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
```

Required discipline:

- Every implementation contract calls `_disableInitializers()` in the constructor (prevents direct-init exploit on the implementation).
- New storage variables go at the **end**, never inserted in the middle.
- Reserve storage gaps in inherited contracts (`uint256[50] private __gap;`) when the contract is meant to be inherited.
- Run storage-layout diff in CI on every PR. See `web3-testing/reference/advanced.md` for the workflow.

## Diamond (ERC-2535) considerations

Choose diamond only when:

- Contract logic exceeds the 24,576-byte EIP-170 limit and cannot be split into separate contracts cleanly
- True plugin model is a product requirement (third-party facets)
- You have an auditor familiar with diamond storage and selector collision risks

Required tooling:

- `diamond-3-hardhat` or `solidstate-diamond` for facet management
- Selector collision detection in CI (`forge inspect <Facet> methodIdentifiers`)
- DiamondCut access control with timelock

Avoid diamond if a UUPS upgrade and contract splitting (factory + module) achieve the same goal.

## Factory patterns

```solidity
contract VaultFactory {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address) public vaultOf;

    event VaultCreated(address indexed owner, address vault);

    constructor(address impl_) {
        implementation = impl_;
    }

    function createVault(bytes32 salt) external returns (address vault) {
        vault = implementation.cloneDeterministic(salt);
        Vault(vault).initialize(msg.sender);
        vaultOf[msg.sender] = vault;
        emit VaultCreated(msg.sender, vault);
    }
}
```

Patterns:

- **Minimal proxy (EIP-1167)**: cheapest deploy (~45 bytes), shared logic, per-instance state. Use OpenZeppelin `Clones`.
- **Beacon proxy**: many instances share an upgradeable implementation via a beacon.
- **Full proxy per instance**: only when each instance needs independent upgrade authority (rare).

## Modular contracts

When a single contract grows past ~500 lines, split by responsibility before splitting by storage. Common cuts:

| Module | Responsibility |
|--------|---------------|
| Core | State machine, invariants |
| Accounting | Balances, accrual, fees |
| Auth | Roles, governance hooks |
| Hooks | External integrations (Uniswap v4 hooks, ERC-4626 strategies) |
| Periphery | User-facing convenience functions, batch helpers |

Periphery contracts can be redeployed independently without touching core. Auth contracts can be replaced via timelock without affecting accounting.

## Hook architecture (Uniswap v4 style)

Uniswap v4 popularized the "hook" pattern: an immutable core protocol calls a user-supplied hook contract at well-defined points. If you build a hook:

- Hook code runs in the protocol's transaction; treat it as untrusted from the protocol side
- Hook permissions are encoded in the hook address itself (high bits) -- mining for valid addresses is required
- Test hooks against `PoolManager` directly using forge with the official hook test harness
- Be aware: a misconfigured hook can be drained, frontrun, or used to manipulate the pool

## ERC-7575 / ERC-4626 vault standards

For yield-bearing vaults:

- Use ERC-4626 for single-asset vaults; mature ecosystem (Yearn, Morpho, Aave)
- Use ERC-7575 for multi-asset vaults
- Be aware of the **inflation attack** (donate to vault, manipulate share price); standard fix is virtual shares + initial deposit lock. OpenZeppelin's `ERC4626` includes mitigation.

## Storage layout principles

1. Group hot fields into the same slot via packing (uint128 + uint128, or address + uint96).
2. Use `transient storage` (EIP-1153, Cancun+) for reentrancy locks and ephemeral state instead of SSTORE/SLOAD pairs.
3. Avoid dynamic arrays in storage when a mapping suffices; iteration over storage arrays is unbounded gas.
4. Never use `delete` on a struct containing nested mappings (incomplete cleanup).

## Access control

| Need | Use |
|------|-----|
| Single owner, no granularity | `Ownable2Step` (OZ) |
| Multiple roles | `AccessControl` (OZ) |
| Role with timelock | `AccessControlDefaultAdminRules` + `TimelockController` |
| Multisig owner | Safe multisig as `owner`, never an EOA |
| DAO governance | `Governor` + `TimelockController` (see `reference/governance.md`) |

Anti-pattern: a single EOA owner on a production protocol with TVL. Always wrap with multisig + timelock. See `reference/custody-and-keys.md`.

## EVM version pinning

Pin `evm_version` in `foundry.toml` / Hardhat config to the lowest version supported across all target chains. As of Pectra (May 2025), most Ethereum L1 and major L2s support `cancun` (transient storage, blobs). Check each target chain before enabling `prague` features.

## Anti-patterns

| Symptom | Fix |
|---------|-----|
| Implementation contract initialized by attacker | `_disableInitializers()` in constructor |
| Storage layout broken on upgrade | OZ Upgrades plugin storage-layout diff in CI |
| `delegatecall` to user-supplied address | Forbid; if required, restrict to allowlist of audited targets |
| Single EOA as `owner` of production protocol | Move to Safe multisig with timelock |
| Diamond used for "future flexibility" with no plugin requirement | Use UUPS instead |
| Custom ERC-4626 without inflation-attack mitigation | Use OZ `ERC4626` base or apply virtual-shares pattern |
| Selector collision in diamond | CI check on every PR |
| Storage gap forgotten in inheritable upgradeable contract | Add `uint256[50] private __gap;` at the end |
