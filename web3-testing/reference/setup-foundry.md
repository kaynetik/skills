# Foundry setup

Read when: initializing a test suite, tuning profiles, fixing `forge` config issues, or standardizing a repo.

## Install and init

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

forge init my-protocol
cd my-protocol
forge install foundry-rs/forge-std
```

Pin `foundry-rs/forge-std` to a tag in production, not `master`, to avoid silent cheatcode behavior changes.

## `foundry.toml`

Split profiles so local dev is fast, CI is thorough, and pre-release is paranoid.

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
test = "test"
script = "script"
solc_version = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 10_000
via_ir = false
bytecode_hash = "none"
cbor_metadata = false
fs_permissions = [{ access = "read", path = "./" }]

[profile.default.fuzz]
runs = 256
max_test_rejects = 131_072
seed = "0x1"

[profile.default.invariant]
runs = 64
depth = 64
fail_on_revert = false
call_override = false

[profile.ci]
fuzz = { runs = 10_000 }
invariant = { runs = 256, depth = 256, fail_on_revert = true }
verbosity = 3

[profile.intense]
fuzz = { runs = 100_000 }
invariant = { runs = 1024, depth = 1024, fail_on_revert = true }

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
base = "${BASE_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
optimism = "${OPTIMISM_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
```

Run a specific profile:

```bash
FOUNDRY_PROFILE=ci forge test
FOUNDRY_PROFILE=intense forge test --match-contract Invariant
```

## Profile rationale

| Profile | Fuzz runs | Invariant runs | fail_on_revert | Use |
| :--- | :--- | :--- | :--- | :--- |
| `default` | 256 | 64 | false | Local dev, fast feedback |
| `ci` | 10k | 256 | true | Every PR. `fail_on_revert: true` forces handlers to be well-bounded |
| `intense` | 100k | 1024 | true | Pre-release, weekly scheduled CI |

`fail_on_revert = true` is critical in CI. It forces your handler contracts to return cleanly instead of silently reverting, which would otherwise hide entire branches of the state space.

## Solc + EVM versions

| Setting | Guidance |
| :--- | :--- |
| `solc_version` | Pin to the version you deploy with. Do not use `^` wildcards in production projects |
| `evm_version` | Match the deployment target chain's supported version. L2s often lag mainnet |
| `via_ir` | Enable only if you deploy with it. Gas values and coverage behavior differ |
| `optimizer_runs` | Match deployment. Test suite uses the same code path your users will |
| `bytecode_hash = "none"` | Omit IPFS metadata from bytecode for reproducible builds |

## Remappings

```
# remappings.txt
@openzeppelin/=lib/openzeppelin-contracts/
@openzeppelin-upgradeable/=lib/openzeppelin-contracts-upgradeable/
solmate/=lib/solmate/src/
forge-std/=lib/forge-std/src/
```

Generate automatically after each install:

```bash
forge remappings > remappings.txt
```

Commit `remappings.txt`. VSCode's Solidity extension reads it; IDE go-to-def breaks without it.

## `.gitignore`

```
cache/
out/
broadcast/*/*/dry-run/
.env
```

Commit `broadcast/` subdirectories (except dry runs) -- they are the audit trail of deployments.

## `.env` discipline

```bash
# .env
MAINNET_RPC_URL=
BASE_RPC_URL=
ETHERSCAN_API_KEY=
DEPLOYER_PRIVATE_KEY=     # Never commit. Prefer --account / --interactive / HW wallets for real deploys.
```

For production deploys, use Foundry's keystore:

```bash
cast wallet import deployer --interactive
forge script ... --account deployer --sender 0x...
```

Never use `--private-key $DEPLOYER_PRIVATE_KEY` in CI. Use OIDC + KMS, or a separate signer service.

## Dependency discipline

| Source | Command |
| :--- | :--- |
| Add a library (tagged release) | `forge install OpenZeppelin/openzeppelin-contracts@v5.1.0` |
| Add a library from a specific commit | `forge install org/repo@<sha>` |
| Remove | `forge remove <alias>` |
| Update all (careful -- breaks pins) | `forge update` |

Commit `lib/` as git submodules. CI should `forge install` from the committed manifest, not arbitrary HEAD.

## Project layout

```
my-protocol/
  src/                   # contracts
  test/
    unit/                # unit tests (Test base)
    fuzz/                # parameterized fuzz tests
    invariant/           # StdInvariant harnesses + handlers
    fork/                # block-pinned fork tests
    integration/         # multi-contract flows
    utils/
      MockERC20.sol
      Fixtures.sol       # shared setUp helpers
  script/                # forge script deployments
  lib/                   # submodules
  foundry.toml
  remappings.txt
```

This separation lets CI run tiers in parallel: unit+fuzz on every PR, invariants on merge to main, fork tests on scheduled runs.

## Useful `forge` invocations

```bash
forge test                                    # all tests
forge test --match-contract Vault             # by contract name
forge test --match-test testDeposit           # by test name
forge test -vvv                               # show reverts, logs
forge test -vvvv                              # show stack traces too
forge test --gas-report                       # per-function gas
forge test --fork-url $MAINNET_RPC_URL --fork-block-number 19000000
forge test --match-path "test/invariant/*"
forge snapshot --diff .gas-snapshot           # check for regression
forge coverage --report lcov --report-file lcov.info
forge inspect src/Vault.sol:Vault storageLayout
```

Bind the common invocations to a `Makefile` or `justfile` so contributors do not have to memorize them.

## Verification checklist

- [ ] `foundry.toml` has distinct `default`, `ci`, and `intense` profiles
- [ ] `fail_on_revert = true` in CI invariant config
- [ ] `solc_version` and `evm_version` pinned, match deployment
- [ ] `forge-std` pinned to a tag
- [ ] `remappings.txt` committed
- [ ] No private keys in env files or CI
- [ ] Test tree split by type (unit / fuzz / invariant / fork / integration)
