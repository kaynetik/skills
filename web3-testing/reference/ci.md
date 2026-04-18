# CI integration

Read when: wiring GitHub Actions for a contract repo, caching Foundry/Hardhat dependencies, or gating PRs on static analysis.

## Foundry CI (baseline)

```yaml
# .github/workflows/test.yml
name: test

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  forge-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - uses: foundry-rs/foundry-toolchain@v1
        with:
          version: stable

      - name: Cache RPC
        uses: actions/cache@v4
        with:
          path: ~/.foundry/cache/rpc
          key: foundry-rpc-${{ hashFiles('**/*.sol') }}
          restore-keys: foundry-rpc-

      - name: Build
        run: forge build --sizes
        env:
          FOUNDRY_PROFILE: ci

      - name: Unit + fuzz
        run: forge test --no-match-path "test/fork/*" -vvv
        env:
          FOUNDRY_PROFILE: ci

      - name: Fork tests
        run: forge test --match-path "test/fork/*" -vvv
        env:
          FOUNDRY_PROFILE: ci
          MAINNET_RPC_URL: ${{ secrets.MAINNET_RPC_URL }}

      - name: Gas snapshot check
        run: forge snapshot --check

      - name: Coverage
        run: forge coverage --report lcov --report-file lcov.info

      - uses: codecov/codecov-action@v5
        with:
          files: lcov.info
          fail_ci_if_error: true
```

## Job split strategy

| Stage | Triggered by | Duration target |
| :--- | :--- | :--- |
| `build` | Every PR | < 1 min |
| `unit + fuzz (ci profile)` | Every PR | < 5 min |
| `fork tests` | Every PR (parallel) | < 5 min |
| `slither` | Every PR | < 2 min |
| `coverage` | Every PR | < 5 min |
| `gas snapshot check` | Every PR | < 2 min |
| `invariant (intense)` | Merge to main + nightly cron | 15-60 min |
| `echidna / medusa` | Nightly cron | 1-4 hours |
| `mutation testing` | Weekly cron | 2-12 hours |

Split into separate jobs so failures are readable in the PR checks UI. Use `needs:` to gate only what needs ordering (e.g., coverage needs build, but fuzz does not need fork tests).

## Static analysis gate

```yaml
  slither:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: foundry-rs/foundry-toolchain@v1
      - name: Slither
        uses: crytic/slither-action@v0.4.0
        with:
          fail-on: high
          slither-args: --filter-paths "lib|test"
          sarif: results.sarif
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results.sarif
```

SARIF upload lets Code Scanning surface findings inline on the PR diff. High-signal UX, zero extra cost.

## Matrix over Solidity versions

For libraries (not applications):

```yaml
strategy:
  fail-fast: false
  matrix:
    solc: ["0.8.20", "0.8.25", "0.8.30"]
steps:
  - name: Build
    run: forge build --use solc:${{ matrix.solc }}
  - name: Test
    run: forge test --use solc:${{ matrix.solc }}
```

Applications should pin to one version. Libraries that span a range should matrix.

## Invariant run (nightly)

```yaml
# .github/workflows/invariant.yml
name: invariant

on:
  schedule:
    - cron: '0 3 * * *'
  workflow_dispatch:

jobs:
  invariant:
    runs-on: ubuntu-latest
    timeout-minutes: 120
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test --match-path "test/invariant/*" -vvv
        env:
          FOUNDRY_PROFILE: intense
```

Use `workflow_dispatch` so anyone can trigger an intense run manually before a release.

## Caching Foundry builds

```yaml
- name: Cache forge build
  uses: actions/cache@v4
  with:
    path: |
      cache/
      out/
    key: forge-${{ hashFiles('src/**/*.sol', 'lib/**/*.sol', 'foundry.toml') }}
    restore-keys: forge-
```

Hashed on source + config so the cache invalidates correctly. Expect 50-80% build-time reduction on cache hits.

## Hardhat CI (parallel snippet)

```yaml
  hardhat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      - run: npm ci
      - run: npx hardhat compile
      - run: npx hardhat test
        env:
          MAINNET_RPC_URL: ${{ secrets.MAINNET_RPC_URL }}
```

Prefer Node 22 (current LTS). Node 16 and 18 are EOL.

## Script injection hardening

Do not ever do:

```yaml
- run: forge test --name "${{ github.event.pull_request.title }}"  # BAD
```

User-controlled content (PR titles, branch names, issue bodies) flowing into `run:` is shell injection. If you must thread such values in, use env:

```yaml
- run: echo "$TITLE"
  env:
    TITLE: ${{ github.event.pull_request.title }}
```

Let the shell quote the variable. This applies to every shell step that references `github.*` contextual data.

## Secrets hygiene

| Practice | Reason |
| :--- | :--- |
| Never put `PRIVATE_KEY` in `secrets.*` for deploys | Use OIDC + cloud KMS or a signer service |
| Scope `MAINNET_RPC_URL` to required jobs only | Use `secrets.MAINNET_RPC_URL` only where needed; prefer environment-scoped secrets |
| Rotate RPC keys on a schedule | Revoke old keys when developers leave |
| Use environments for production workflows | Require approvals for deploys |

## Permissions

Set the narrowest permissions at the workflow level:

```yaml
permissions:
  contents: read
```

Elevate per-job only when needed:

```yaml
jobs:
  release:
    permissions:
      contents: write
      id-token: write  # for OIDC
```

Default tokens with write permissions on every job is a supply-chain risk.

## Verification checklist

- [ ] `foundry-rs/foundry-toolchain@v1` with pinned `stable` or a release tag
- [ ] `concurrency.cancel-in-progress` enabled
- [ ] `permissions: contents: read` at workflow level
- [ ] Unit, fork, slither, coverage split into parallel jobs
- [ ] RPC cache and build cache configured
- [ ] Invariant tests run nightly on `intense` profile
- [ ] Gas snapshot check gates PRs
- [ ] No user-controlled input flows directly into `run:` scripts
