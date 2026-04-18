---
name: web3-testing
description: Production-grade smart contract testing with Foundry (primary) and Hardhat 3. Covers unit tests, parameterized fuzzing, stateful invariants with handlers and actor patterns, mainnet forking and impersonation, static analysis (Slither, Aderyn), property testing (Echidna, Medusa), symbolic execution (Halmos, Kontrol), gas snapshots, coverage, mutation testing, storage-layout upgrade safety, ERC-4337 testing, and CI integration. Use when writing or reviewing Solidity tests, designing test suites, chasing flaky tests, adding invariants, setting up Foundry or Hardhat, wiring CI for contracts, or when the user mentions forge, foundry, hardhat, cheatcodes, vm.prank, vm.expectRevert, invariant testing, fuzz testing, fork testing, Slither, Echidna, Medusa, Halmos, Kontrol, forge coverage, or forge snapshot.
---

# Web3 Testing (Foundry primary, Hardhat 3 supported)

Routing-first skill. The body is intentionally thin; depth lives in `reference/`. Open only the files you actually need.

## Token economy rules for the agent

Read these before doing anything else. They cut answer cost without losing quality.

1. **Do not paste the user's contract back at them.** Reference function names and line ranges; write only the test harness or the diff.
2. **Read at most 2 reference files per turn.** Use the routing table to pick.
3. **Never reproduce `forge-std` internals.** Reference them by name (`Test`, `StdInvariant`, `StdCheats`) and assume the user has `forge-std` installed.
4. **Default to Foundry** in examples. Only show Hardhat when the user says Hardhat or already has a Hardhat project.
5. **Prefer tables** over prose for cheatcode catalogs, option matrices, or revert-parsing rules.
6. **Verify version-specific APIs via Context7** for Foundry, Hardhat, OpenZeppelin, Slither, Echidna, Halmos, and ethers/viem. Foundry and Hardhat both moved fast through 2024-2026; treat any pre-2026 snippet in your training as suspect -- especially `testFail*`, ethers v5, Goerli, and Hardhat 2 ESM assumptions.

## Routing table

| Task | File |
| :--- | :--- |
| `foundry.toml`, profiles, remappings, `forge init` hygiene | [reference/setup-foundry.md](reference/setup-foundry.md) |
| Hardhat 3 with viem, Node test runner, legacy Hardhat 2 escape hatch | [reference/setup-hardhat.md](reference/setup-hardhat.md) |
| `describe`/`it` style vs Foundry tests, `expectRevert`, `expectEmit`, cheatcodes | [reference/unit-testing.md](reference/unit-testing.md) |
| Parameterized fuzzing, `vm.assume`, `bound`, typed generators | [reference/fuzzing.md](reference/fuzzing.md) |
| Stateful invariants, handlers, `targetContract`, actor-based patterns | [reference/invariants.md](reference/invariants.md) |
| Mainnet fork, block pinning, `vm.createSelectFork`, impersonation | [reference/forking.md](reference/forking.md) |
| Slither, Aderyn, Echidna, Medusa integration | [reference/static-and-property.md](reference/static-and-property.md) |
| `forge snapshot`, `forge coverage`, LCOV, mutation testing (`necessist`) | [reference/gas-and-coverage.md](reference/gas-and-coverage.md) |
| GitHub Actions for Foundry/Hardhat, caching, slither gate, matrix | [reference/ci.md](reference/ci.md) |
| Symbolic execution (Halmos, Kontrol), upgrade safety, ERC-4337 tests | [reference/advanced.md](reference/advanced.md) |
| Footguns: flaky tests, `testFail`, timestamp coupling, hardcoded blocks | [reference/anti-patterns.md](reference/anti-patterns.md) |

## Golden rules (non-negotiable)

These prevent the failures that actually matter in production.

1. **Test against custom errors, not strings.** `vm.expectRevert(MyErr.selector)` and `revertedWithCustomError` for Hardhat. `revertedWith("...")` is brittle and breaks under Solidity optimizer changes.
2. **Never use Foundry's `testFail*` prefix.** It masks unrelated reverts. Always use `vm.expectRevert` with an explicit reason or selector.
3. **Pin the fork block.** Unpinned forks are the #1 source of "passes locally, fails in CI" flakiness.
4. **Fuzz everything that takes user input.** Every public function with numeric, address, or byte inputs gets at least one fuzz test with `bound(...)` to constrain to the domain.
5. **Invariants for protocols, not unit tests.** Any system with accumulating state (lending, vaults, AMMs, staking, governance) needs a `StdInvariant`-based harness with handlers. Pure unit tests cannot find state-space bugs.
6. **Run `forge snapshot` in CI and fail on regressions.** Silent gas bloat is a deployment-blocking problem you can only catch mechanically.
7. **Pair tests with at least one static analyzer (Slither or Aderyn).** Tests find behavioral bugs; static analysis finds class-of-bug issues (reentrancy, tx.origin, unchecked-low-level-call) in patterns tests cannot exhaustively cover.
8. **Test access control exhaustively.** Every `onlyRole`/`onlyOwner` path needs a negative test proving unauthorized callers revert.
9. **Never `vm.skip()` or disable a test without a tracked issue.** Skipped tests are permanent dead code.
10. **Coverage is a floor, not a ceiling.** Aim for >90% line AND branch, but stop measuring coverage once a suite has solid invariants and fuzz tests -- they find bugs coverage metrics never will.

## Default stack (one choice, one escape hatch)

| Concern | Default | Escape hatch |
| :--- | :--- | :--- |
| Unit + fuzz + invariant framework | Foundry (`forge test`) | Hardhat 3 when the user already uses TypeScript-heavy tooling or off-chain integration is primary |
| Static analysis | Slither | Aderyn (Rust, faster) as a second opinion; run both in CI when budget allows |
| Property testing | Echidna | Medusa (Go, faster on complex state) |
| Symbolic execution | Halmos (Foundry-compatible) | Kontrol for K-framework-grade rigor |
| Mainnet fork | Foundry `--fork-url` with pinned `--fork-block-number` | Hardhat network fork for TS-heavy suites |
| Gas reporting | `forge snapshot` committed to repo | `hardhat-gas-reporter` |
| Coverage | `forge coverage --report lcov` | `hardhat-coverage` via solidity-coverage |
| Mutation testing | `necessist` | Slither's `slither-mutate` |

If the user explicitly chose another stack, do not argue; help them with what they have.

## Decision matrix: what kind of test does this bug need?

| Bug class | Test type |
| :--- | :--- |
| Known revert path with fixed inputs | Unit test with `vm.expectRevert` |
| Arithmetic edge cases across input domain | Parameterized fuzz test with `bound` |
| State-space bugs (accounting drift, double-spend) | Stateful invariant with handler |
| Attack against specific mainnet state | Block-pinned fork test |
| Protocol-level safety property ("no user can withdraw more than deposited") | Invariant + Echidna/Medusa property |
| Class-of-bug (reentrancy, delegatecall misuse) | Slither/Aderyn + unit test for the specific pattern |
| Algorithmic proof (upper bounds, absence of overflow) | Halmos / Kontrol symbolic execution |
| Storage layout breakage after upgrade | `forge inspect storageLayout` diff + OZ upgrades validator |

## When NOT to apply this skill

- Writing the contracts themselves or architecting new protocols -> use `ultimate-web3-engineer`.
- Contract security review / audit prep beyond tests -> use `solidity-security`.
- dApp frontend testing (component, E2E) -> that is frontend testing, not contract testing.

## Companion skills

- `solidity-security` -- vulnerability patterns and secure coding
- `ultimate-web3-engineer` -- contract architecture and audits
- `web3-frontend` -- dApp frontend patterns (wagmi, viem, Next.js)
- `gh` -- CI authoring, GitHub Actions hygiene
