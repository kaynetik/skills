# Anti-patterns

Read when: reviewing a test suite, debugging flaky CI, or auditing coverage.

Format: symptom -> cause -> fix. Every entry is a real failure mode.

## `testFail_*` masking unrelated reverts

**Symptom**: A test passes but the contract has a bug along an entirely different code path.

**Cause**: Foundry's `testFail_*` prefix passes when any revert occurs, including from unrelated preconditions (address zero, insufficient balance) you forgot to set up.

**Fix**: Never use `testFail_*`. Use `vm.expectRevert(<selector>)` with an explicit expected error.

## `vm.expectRevert()` with no argument

**Symptom**: Refactor changes the revert path but tests still pass.

**Cause**: Bare `vm.expectRevert()` matches any revert; you lose the ability to regression-test the specific reason.

**Fix**: Always supply a selector or bytes: `vm.expectRevert(MyErr.selector)`.

## `revertedWith("string")` on custom errors

**Symptom**: Upgrading Solidity or optimizer settings changes internal revert reasons, tests fail with no real bug.

**Cause**: Matching revert strings is brittle; compiler and libraries change them across versions.

**Fix**: Migrate contracts to custom errors. Match by selector in tests.

## Unpinned fork

**Symptom**: Tests pass for weeks then start failing; only reproducible today.

**Cause**: Fork uses latest block; state changed under you (protocol upgrade, oracle drift, liquidity shift).

**Fix**: Always pass `--fork-block-number` or call `vm.createSelectFork(url, blockNumber)`.

## `vm.assume` instead of `bound`

**Symptom**: Fuzz tests slow to a crawl; `max_test_rejects` warning in output.

**Cause**: `vm.assume` rejects inputs instead of remapping; the fuzzer burns runs on rejected cases.

**Fix**: `amount = bound(amount, lo, hi)` for range constraints. Reserve `vm.assume` for conditions that cannot be expressed as a range.

## Handler silently reverts

**Symptom**: Invariants pass on every run, yet the protocol has a bug.

**Cause**: `fail_on_revert = false` (the default). The handler's action reverted for a boring reason (insufficient balance, unknown target), and the fuzzer moved on without exploring the intended state transition.

**Fix**: `fail_on_revert = true` in CI; bound all handler inputs so transitions are actually reachable.

## Invariants that re-implement the contract

**Symptom**: Invariant passes because it and the contract both share the same bug.

**Cause**: The invariant is a paraphrase of the contract's logic rather than a property the contract must satisfy.

**Fix**: Invariants should assert properties (conservation, monotonicity, solvency) independent of the contract's implementation. Ghost variables help because they are maintained by the handler, not the contract.

## Hardcoded block numbers, addresses, or magic constants in tests

**Symptom**: Incident-replay test rots; passes on old fork, meaningless on new one.

**Cause**: `uint256 exploit = 12345;` with no comment on why.

**Fix**: Name every magic constant: `uint256 constant INCIDENT_BLOCK = 17_900_000; // MakerDAO incident block`.

## Timestamp coupling

**Symptom**: `assertEq(stake.unlockTime(), block.timestamp + 7 days)` passes in isolation but fails when other tests modify time.

**Cause**: Test relies on implicit `block.timestamp` without capturing a baseline.

**Fix**: Capture the timestamp at the start of the test: `uint256 start = block.timestamp; ...; assertEq(stake.unlockTime(), start + 7 days);`.

## Tests that do not assert anything

**Symptom**: "Coverage high, still bugs slip through."

**Cause**: Tests call functions without assertions (`contract.doThing();` followed by nothing), gaining coverage without validating behavior.

**Fix**: Every test ends in one or more `assert*` calls. If not, the test is not exercising behavior; delete it or add assertions.

## Single-actor invariant runs

**Symptom**: Protocol ships; first multi-user transaction exposes an account-segmentation bug.

**Cause**: Invariant handler had one or two fixed addresses; never tested N-actor interactions.

**Fix**: Handler maintains a growing actor array; every action picks an actor pseudo-randomly. See `invariants.md`.

## `vm.store` without knowing the layout

**Symptom**: Fork test "succeeds" but the contract state is corrupted; subsequent calls behave nonsensically.

**Cause**: `vm.store(addr, slot, value)` with a hand-computed slot that does not match the actual storage layout (packed variables, upgradeable proxy offsets).

**Fix**: Use `forge inspect <Contract> storageLayout` to confirm the slot. Prefer `deal()` for tokens; reserve `vm.store` for edge cases.

## Mocking protocol code you also test

**Symptom**: Unit tests pass; integration breaks in production because the mock and the real contract diverged.

**Cause**: `MockVault` with simplified logic used for testing callers, while `Vault` evolves.

**Fix**: Either (a) run integration tests against the real contract, or (b) generate the mock from the real contract's interface and keep behavior synchronized.

## Coverage maximalism

**Symptom**: Team spends weeks chasing 100% line coverage; bugs still slip through.

**Cause**: Coverage measures lines hit, not properties checked.

**Fix**: Hit >=95% line and >=90% branch, then stop. Redirect effort to invariants, fuzz properties, and mutation testing, which find the bugs coverage never will.

## Running `forge test` without profile awareness

**Symptom**: PRs pass locally with 256 fuzz runs; CI finds a counterexample minutes later.

**Cause**: Local default profile has low run counts; CI is the first place the expensive run happens.

**Fix**: Document the `FOUNDRY_PROFILE=ci forge test` command; run it before pushing when touching anything with fuzz tests.

## Committing `.env` or private keys

**Symptom**: RPC usage spikes; wallet drained.

**Cause**: `.env` committed to git history even if deleted from HEAD; git history is forever.

**Fix**: Put `.env` in `.gitignore` from the first commit. If it was ever committed, rotate all keys immediately; history rewrite does not help downstream clones.

## Skipped tests without issue tracking

**Symptom**: Suite accumulates `vm.skip(true)` or commented-out tests.

**Cause**: A test was flaky or broken; disabling it was the path of least resistance.

**Fix**: Ban skipped tests in CI (`grep vm.skip` as a check). Every skip requires a linked issue; fix or delete.

## Running Slither / Echidna only ad-hoc

**Symptom**: New bug classes land in main between audits.

**Cause**: Tools are not in CI; they run only during manual review.

**Fix**: Slither as a CI gate on every PR. Echidna or Medusa on a nightly schedule. Tools are only effective when they run on every change.

## Fuzz tests with single-value properties

**Symptom**: Fuzz test passes; the matching unit test for `amount == 5` is where the bug sits.

**Cause**: The fuzz test's property is weaker than the unit test's.

**Fix**: Fuzz tests assert general properties. When a specific value has special behavior (overflow at max, rounding at 1), keep a dedicated unit test for it.

## Testing against a single Solidity version

**Symptom**: Downstream consumer compiles your library with solc 0.8.20 and gets different behavior than you expect.

**Cause**: Library tested only against latest solc; version-specific codegen differences not exercised.

**Fix**: Matrix build + test across supported solc range. Applications pin one version; libraries test the range they support.

## Fixtures that mutate shared state

**Symptom**: Test ordering affects outcomes; `forge test --match-test A` passes but `forge test` has A failing.

**Cause**: A fixture or `setUp` modifies a singleton or file-system state in a way the next test does not reset.

**Fix**: `setUp` must be self-contained; every test starts from a clean deployment. Foundry snapshots local state; rely on that.

## Verification checklist

- [ ] No `testFail_*` in the repo
- [ ] No `vm.expectRevert()` with empty argument
- [ ] No `revertedWith("...")` on custom errors
- [ ] Every fork test has a pinned block
- [ ] Every fuzz handler input bounded
- [ ] `fail_on_revert = true` in CI invariant profile
- [ ] Every test ends in assertions
- [ ] No skipped tests without a tracked issue
- [ ] Slither and Echidna/Medusa in CI, not ad-hoc
- [ ] `.env` in `.gitignore` and keys rotated if ever committed
