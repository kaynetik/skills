# Parameterized fuzzing

Read when: writing tests that take numeric, address, or bytes input, or finding edge cases in arithmetic.

## When to fuzz

Fuzz any function whose correctness depends on the input domain, not a specific value. Concrete examples:

| Input shape | Fuzz | Reason |
| :--- | :--- | :--- |
| `deposit(uint256 amount)` | Yes | Overflow, zero, max |
| `transfer(address to, uint256 amount)` | Yes | Zero address, self-transfer, max |
| `setOwner(address owner)` | No (unit test is enough) | Pure assignment, no domain logic |
| `withdraw(uint256 shares)` | Yes | Share math rounds differently at boundaries |
| `permit(..., uint8 v, bytes32 r, bytes32 s)` | Yes + dedicated signature fuzzer | Signature malleability surface |

## Foundry parameterized fuzz

```solidity
function testFuzz_Deposit_AnyAmount(uint256 amount) public {
    amount = bound(amount, 1, type(uint128).max);
    token.mint(alice, amount);

    vm.startPrank(alice);
    token.approve(address(vault), amount);
    uint256 shares = vault.deposit(amount);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), shares);
    assertGe(shares, 0);
}
```

Key parts:

| Part | Purpose |
| :--- | :--- |
| `testFuzz_` prefix | Convention; forge treats any function with parameters as a fuzz test regardless |
| `bound(x, lo, hi)` | Re-maps fuzzed value to `[lo, hi]` without rejecting it. Always prefer over `vm.assume` |
| `type(uint128).max` ceiling | Avoids overflow in unrelated arithmetic; choose based on realistic domain |

## `bound` vs `vm.assume`

```solidity
// GOOD -- bound
amount = bound(amount, 1, 1_000_000e18);

// BAD -- assume rejects; hits max_test_rejects and stalls
vm.assume(amount >= 1 && amount <= 1_000_000e18);
```

`vm.assume` rejects runs that do not match, wasting fuzz budget. `bound` deterministically maps into range, so every run is useful.

Use `vm.assume` only for conditions you cannot express as a range:

```solidity
vm.assume(to != address(0));
vm.assume(to != address(vault));
vm.assume(to.code.length == 0);  // EOA only
```

Three or fewer assumes per test is a reasonable ceiling. More than that means you should change the test design.

## Address fuzzing

```solidity
function testFuzz_Transfer_ToAnyNonZeroAddress(address to, uint256 amount) public {
    vm.assume(to != address(0));
    vm.assume(to != address(vault));

    amount = bound(amount, 1, token.balanceOf(alice));

    vm.prank(alice);
    token.transfer(to, amount);

    assertEq(token.balanceOf(to), amount);
}
```

Common address constraints:

| Constraint | When |
| :--- | :--- |
| `to != address(0)` | Almost always |
| `to != address(contract)` | Self-transfer and self-approval invariants |
| `to.code.length == 0` | EOA-only flows |
| `to.code.length > 0` | Contract-recipient flows |
| `to != precompile` | When testing transfer to address(1)..address(9) matters |

## Bytes and calldata fuzzing

```solidity
function testFuzz_Permit_RevertWhen_InvalidSignature(
    address signer,
    uint256 amount,
    uint8 v,
    bytes32 r,
    bytes32 s
) public {
    vm.assume(signer != address(0));

    // Make the signature structurally valid-looking but not a real signature for this digest
    v = uint8(bound(v, 27, 28));

    vm.expectRevert();
    token.permit(signer, address(this), amount, block.timestamp + 1, v, r, s);
}
```

For structural fuzzing of arbitrary bytes (e.g., calldata-decoding bugs):

```solidity
function testFuzz_DecodeHandlesArbitraryBytes(bytes calldata data) public {
    vm.assume(data.length <= 1024);  // keep fuzzer tractable
    try this.decode(data) returns (Decoded memory d) {
        // invariants about successfully-decoded output
    } catch {
        // decode should fail gracefully, never panic
    }
}
```

## Property-style fuzz tests

Fuzz tests express properties, not specific outcomes. Patterns:

| Property | Assertion |
| :--- | :--- |
| Round-trip | `decode(encode(x)) == x` for all `x` in domain |
| Monotonicity | Depositing more -> not fewer shares |
| Conservation | `preTotalSupply - burned == postTotalSupply` |
| Commutativity | `swapA(swapB(x)) == swapB(swapA(x))` where applicable |
| Idempotence | Calling `harvest()` twice in the same block matches calling once |

Example:

```solidity
function testFuzz_Deposit_MonotonicInAmount(uint256 a, uint256 b) public {
    a = bound(a, 1, 1e24);
    b = bound(b, a, 1e24);

    uint256 sharesA = vault.previewDeposit(a);
    uint256 sharesB = vault.previewDeposit(b);

    assertGe(sharesB, sharesA);
}
```

## Differential fuzzing

Compare the contract against a reference implementation:

```solidity
function testFuzz_ExpMatchesReference(uint256 x) public {
    x = bound(x, 0, 1e18);
    uint256 onchain = Math.exp(x);
    uint256 reference = _referenceExp(x);  // pure Solidity, minimal logic, easy to audit by eye
    assertApproxEqRel(onchain, reference, 1e14);  // 0.01%
}
```

Use this when you optimize a function (assembly, Q64.96 fixed point) and need to prove the optimization preserves behavior.

## Fuzz seed reproduction

When CI finds a counterexample, it prints a seed. Reproduce locally:

```bash
forge test --match-test testFuzz_Deposit_AnyAmount --fuzz-seed 0xabc123
```

Commit seeds that found real bugs to a regression fixture. Foundry writes found counterexamples to `cache/fuzz/failures` automatically in newer versions -- check it into git for the suite to regression-test the exact input.

## Fuzz budget tuning

| Profile | Runs | When |
| :--- | :--- | :--- |
| `default` | 256 | Local dev loop, fast feedback |
| `ci` | 10_000 | Every PR |
| `intense` / nightly | 100_000+ | Pre-release, weekly scheduled |

Runs scale linearly with fuzz time. 10k runs over a dozen fuzz tests is typically single-digit minutes.

## Verification checklist

- [ ] Every public function with numeric input has at least one fuzz test
- [ ] `bound(...)` used instead of `vm.assume` for ranges
- [ ] `vm.assume` limited to 3 or fewer constraints per test
- [ ] Properties asserted (monotonicity, conservation, round-trip) not specific outputs
- [ ] Counterexample seeds checked into the repo
- [ ] `fuzz.runs >= 10_000` in CI profile
