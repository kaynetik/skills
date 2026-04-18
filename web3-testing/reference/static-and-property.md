# Static analysis and property testing

Read when: adding Slither / Aderyn to CI, running Echidna or Medusa, or deciding what tools complement Foundry.

## Tool matrix

| Tool | Language | Model | Use |
| :--- | :--- | :--- | :--- |
| Slither | Python | Pattern-based static analysis | CI gate for known bug classes (reentrancy, tx.origin, uninitialized storage) |
| Aderyn | Rust | AST analysis (faster, newer) | Second opinion; complements Slither |
| Echidna | Haskell | Coverage-guided property fuzzing | Deep property exploration beyond forge invariants |
| Medusa | Go | Coverage-guided property fuzzing | Echidna alternative; faster on complex state |
| Mythril | Python | Symbolic execution | Finds integer underflow, DoS; slow |
| Halmos | Python | Symbolic execution (bounded) | Proves properties over bounded input spaces |
| Kontrol | Rust + K framework | Formal verification | Stronger guarantees; higher setup cost |

A sensible production stack:

1. **Forge** (unit, fuzz, invariant) as the default test harness.
2. **Slither** on every PR as a CI gate.
3. **Echidna or Medusa** weekly on the same invariant harness.
4. **Halmos** on critical functions once the protocol stabilizes.

Add Kontrol / Certora only for systems that cannot tolerate bugs (bridges, custody, large TVL).

## Slither

Install:

```bash
pip install slither-analyzer
```

Run:

```bash
slither . --exclude-informational --exclude-low --foundry-out-directory out
```

Key flags:

| Flag | Purpose |
| :--- | :--- |
| `--exclude-informational` | Drop informational findings from CI noise |
| `--exclude-low` | Drop low-severity (still review manually) |
| `--filter-paths "lib\|test"` | Skip dependencies and test files |
| `--fail-high` | Exit nonzero on any high-severity finding |
| `--json report.json` | Machine-readable output for dashboards |

CI gate snippet:

```yaml
- name: Slither
  uses: crytic/slither-action@v0.4.0
  with:
    fail-on: high
    slither-args: --filter-paths "lib|test"
```

Triage workflow:

1. Run Slither on current HEAD; save `baseline.sarif`.
2. On every PR, run Slither again and diff against baseline.
3. Fail CI only on new findings, not existing ones, to avoid blocking on legacy issues while preventing regressions.

Slither ships with several printers worth knowing:

| Printer | Use |
| :--- | :--- |
| `slither . --print human-summary` | Top-level overview |
| `slither . --print inheritance-graph` | Diagram contract inheritance |
| `slither . --print call-graph` | Find untrusted call paths |

## Aderyn

Install:

```bash
cargo install aderyn
```

Run:

```bash
aderyn .
```

Aderyn is faster than Slither and written in Rust, with AST-driven detectors. It does not (yet) cover all Slither detectors, but finds some Slither misses. Run both; compare.

CI snippet:

```yaml
- uses: cyfrin/aderyn-action@v0
```

## Echidna

Install via Docker (simplest):

```bash
docker pull ghcr.io/crytic/echidna/echidna:latest
```

Write a property contract that reuses your Foundry handler:

```solidity
// test/echidna/VaultProperties.sol
import {VaultHandler} from "test/invariant/handlers/VaultHandler.sol";

contract VaultProperties is VaultHandler {
    constructor() VaultHandler(new Vault(...), new MockERC20(...)) {}

    function echidna_total_supply_matches_sum() public view returns (bool) {
        uint256 sum;
        address[] memory actors = this.actors();
        for (uint256 i; i < actors.length; ++i) {
            sum += vault.balanceOf(actors[i]);
        }
        return sum == vault.totalSupply();
    }
}
```

Config:

```yaml
# echidna.yaml
testMode: property
testLimit: 100000
corpusDir: ./corpus
coverage: true
balanceContract: 1000000000000000000000000
```

Run:

```bash
docker run --rm -v $PWD:/src ghcr.io/crytic/echidna/echidna:latest \
  /src --contract VaultProperties --config /src/echidna.yaml
```

Commit `corpus/` to git. Echidna replays past counterexamples, giving you coverage across runs.

## Medusa

Install:

```bash
go install github.com/crytic/medusa@latest
```

Run:

```bash
medusa fuzz --config medusa.json
```

Config (abbreviated):

```json
{
  "fuzzing": {
    "workers": 10,
    "workerResetLimit": 50,
    "timeout": 0,
    "testLimit": 1000000,
    "callSequenceLength": 100,
    "corpusDirectory": "corpus"
  },
  "compilation": {
    "platform": "crytic-compile"
  }
}
```

Medusa is Go-based, parallel by default, and often faster than Echidna on complex state. Use the same `VaultProperties` contract as with Echidna.

## Halmos (bounded symbolic execution)

```bash
pip install halmos
halmos --match-test "check_" -v
```

Write symbolic-style tests:

```solidity
function check_AddIsCommutative(uint256 a, uint256 b) public pure {
    assert(a + b == b + a);  // Halmos proves or disproves this over the entire uint256 space
}

function check_Deposit_AlwaysIncrementsShares(uint256 amount) public {
    vm.assume(amount > 0 && amount < type(uint128).max);
    uint256 before = vault.totalSupply();
    vault.deposit(amount);
    assert(vault.totalSupply() > before);
}
```

Halmos explores ALL possible values (bounded by symbolic solver limits), not a sample. When it says "pass," it is a proof for the input range explored.

Limitations:

- Functions with unbounded loops, `SELFDESTRUCT`, or dynamic calldata are hard.
- Long execution traces exhaust the solver.
- Best used on isolated, pure-ish functions after they are unit/fuzz-tested.

## Workflow: how these tools compose

```
every commit  -> forge test (unit, fuzz, invariant @ ci profile)
                 slither + aderyn gate
every PR      -> same + forge coverage threshold
nightly       -> echidna / medusa on handler harness
                 forge test with intense profile
                 halmos on critical pure functions
pre-release   -> manual review of each tool's full output
```

No one tool finds everything. Redundancy is the point.

## Verification checklist

- [ ] Slither runs in CI with `fail-on: high`
- [ ] Second static analyzer (Aderyn) runs alongside or on alternating days
- [ ] Echidna or Medusa configured; corpus committed
- [ ] Echidna/Medusa harness reuses the Foundry invariant handler
- [ ] Halmos `check_*` tests on critical pure functions
- [ ] Baseline findings documented so PRs only fail on new findings
