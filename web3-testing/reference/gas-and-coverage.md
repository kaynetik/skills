# Gas snapshots, coverage, mutation testing

Read when: quantifying gas regressions, measuring test coverage, or validating that your tests actually catch bugs.

## `forge snapshot`

Produce a per-test gas baseline:

```bash
forge snapshot
```

Writes `.gas-snapshot` with a line per test:

```
VaultTest:test_Deposit_UpdatesShares() (gas: 82431)
VaultTest:testFuzz_Withdraw_AnyAmount(uint256) (runs: 256, ...)
```

Commit `.gas-snapshot`. In CI, detect regressions:

```bash
forge snapshot --check
```

Exits nonzero if any test costs more than the snapshot. PRs that shift gas get an explicit review signal.

Tolerance:

```bash
forge snapshot --diff .gas-snapshot --tolerance 100
```

Allows small fluctuations (e.g., from a new optimizer run). Keep tolerance tight; easy wins in gas are often the bugs you want to notice.

## Per-function gas report

```bash
forge test --gas-report
```

Output (abbreviated):

```
| src/Vault.sol:Vault |                 |        |        |        |
| Function Name       | min             | avg    | median | max    |
| deposit             | 65_432          | 82_431 | 82_000 | 120_123 |
| withdraw            | 45_100          | 51_203 | 51_000 |  60_000 |
```

Use for:

| Goal | Action |
| :--- | :--- |
| Find hot paths | Sort by `avg * call_count` |
| Compare implementations | Fork a branch, run report, diff |
| Catch worst-case regression | `max` column -- often the interesting one |

## Coverage

```bash
forge coverage --report summary
forge coverage --report lcov --report-file lcov.info
```

Summary output by file/contract/function with line and branch percentages.

Visualize in an IDE with an LCOV-compatible viewer, or push to Codecov/Coveralls:

```yaml
- uses: codecov/codecov-action@v5
  with:
    files: lcov.info
    fail_ci_if_error: true
```

Coverage floors:

| Metric | Minimum |
| :--- | :--- |
| Line | 95% |
| Branch | 90% |
| Function | 100% (every public/external function has at least one test) |

> [!WARNING]
> High coverage is necessary but not sufficient. A suite with 100% coverage and no invariants will still miss protocol-level bugs. Do not optimize for the metric; optimize for the bugs found.

## Coverage caveats

- `forge coverage` instruments bytecode, which changes optimization behavior. Gas values under coverage are not comparable to production gas.
- Via-IR (`via_ir = true`) coverage sometimes misreports. Verify any "covered" line by stepping through it under `-vvvv`.
- Fuzz and invariant tests count the lines they hit, but do not count toward branch coverage of conditions they fail to cover.

## Mutation testing

Mutation testing answers: "If I introduce a bug into my contract, does at least one test fail?"

A mutation testing tool applies small code changes (mutants) and re-runs the test suite. Any mutant that passes all tests is a bug your suite cannot detect.

### `necessist` (Rust-based)

```bash
cargo install necessist --locked
necessist --framework foundry
```

`necessist` removes individual statements from tests to find tests that pass trivially. It is an "inverse mutation test" -- it mutates tests, not contracts.

### `slither-mutate`

Part of slither-analyzer:

```bash
slither-mutate . --test-cmd "forge test"
```

Applies classical mutations (arithmetic operator swap, boundary flip, require removal) to contracts and runs the test suite. Mutants that survive reveal weak spots.

### When to run

Mutation testing is expensive. Run on:

- A weekly cron, not every PR.
- Only on contracts you ship.
- With a budget (e.g., 100 mutants per contract, not exhaustive).

A survival rate under 10% is healthy. Over 25% means your tests assert outcomes but not mechanisms -- they pass the right inputs but do not check enough properties.

## Gas optimization workflow

1. Write the test suite first.
2. Run `forge snapshot` to establish a baseline.
3. Optimize.
4. Run tests: if any fail, the optimization broke behavior.
5. Run `forge snapshot --diff` and verify gas dropped.
6. Commit both code and snapshot in the same PR.

Never optimize in the same commit as a bug fix. The reviewer needs to see them separately.

## Tracking gas over time

Export snapshots to a dashboard:

```bash
forge snapshot --json | jq '...' > gas.json
```

Push to a time-series DB (Grafana Loki, Datadog). The chart is the conversation-starter when gas quietly climbs across releases.

## Verification checklist

- [ ] `.gas-snapshot` committed
- [ ] `forge snapshot --check` runs in CI and fails on regression
- [ ] Coverage thresholds enforced (>=95% line, >=90% branch)
- [ ] Coverage reports published to Codecov or equivalent
- [ ] Mutation testing runs on a weekly schedule
- [ ] No optimization PR without a passing test suite and snapshot diff
