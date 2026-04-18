# Advanced patterns

Read when: proving properties formally, validating upgrade safety, testing ERC-4337 flows, or dealing with anything where unit/fuzz/invariant tests are not sufficient.

## Symbolic execution (Halmos)

Unlike fuzzing, which samples inputs, symbolic execution explores the entire reachable state within solver bounds.

```bash
pip install halmos
halmos --match-test "check_" -vv
```

```solidity
contract SymbolicTests is Test {
    Vault vault;

    function setUp() public { vault = new Vault(...); }

    // All inputs symbolic; solver attempts to find a counterexample
    function check_Deposit_NoOverflow(uint256 amount) public {
        vm.assume(amount > 0 && amount < 2 ** 128);
        uint256 sharesBefore = vault.totalSupply();
        vault.deposit(amount);
        assert(vault.totalSupply() >= sharesBefore);
    }
}
```

Rules:

| Rule | Reason |
| :--- | :--- |
| Use `check_` prefix (or Halmos's configured prefix) | Keeps Halmos tests separate from forge fuzz tests |
| Bound inputs narrowly with `vm.assume` | Unbounded uint256 is solver-untractable in most cases |
| Avoid unbounded loops | The solver times out; refactor loops to bounded form |
| Avoid storage-heavy code paths | Slower; prioritize pure/view functions for symbolic checks |

Halmos is complementary to fuzzing, not a replacement. Use it on a shortlist of invariants where you want mathematical assurance within a bounded domain.

## Storage layout upgrade safety

For upgradeable contracts, storage layout drift is a silent catastrophe. Protect with automated diffing.

### Inspect layout

```bash
forge inspect src/Vault.sol:Vault storageLayout --pretty
```

Output shows slot numbers, offsets, and variable names. Any reorder, removal, or type change breaks upgrades.

### CI check

```yaml
- name: Storage layout check
  run: |
    forge inspect src/Vault.sol:Vault storageLayout > layout.current.json
    diff layout.baseline.json layout.current.json
```

Commit `layout.baseline.json`. Update it intentionally as part of an upgrade PR with explicit review.

### OpenZeppelin Upgrades Plugin

For Hardhat / foundry-zksync projects using OZ transparent or UUPS proxies:

```ts
import { validateUpgrade } from '@openzeppelin/upgrades-core'

await validateUpgrade('VaultV1', 'VaultV2', { kind: 'uups' })
```

This runs the same layout check the plugin uses at deploy time. Adding it to tests catches bugs before you deploy.

### Layout discipline

| Practice | Reason |
| :--- | :--- |
| Never remove storage variables; deprecate with a `__gap` | Removed slots misalign subsequent variables |
| Add new variables only at the end | Appends are always safe |
| Use `__gap` arrays in inherited contracts | Reserves slot space for future additions |
| Never change a variable's type, even same-size | Semantic drift undetectable by layout check |

## ERC-4337 / Account Abstraction testing

Smart-account tests require an EntryPoint, a UserOperation, and sometimes a paymaster. Use `account-abstraction/contracts` reference implementation or the canonical deployed addresses on the target chain.

### Minimal structure

```solidity
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

contract AATest is Test {
    EntryPoint entryPoint;
    MySmartAccount account;
    uint256 signerKey;
    address signer;

    function setUp() public {
        entryPoint = new EntryPoint();
        (signer, signerKey) = makeAddrAndKey("signer");
        account = new MySmartAccount(entryPoint, signer);
        vm.deal(address(account), 1 ether);
    }

    function _signUserOp(PackedUserOperation memory op)
        internal view returns (PackedUserOperation memory)
    {
        bytes32 hash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        op.signature = abi.encodePacked(r, s, v);
        return op;
    }

    function test_Execute_TransfersFromAccount() public {
        PackedUserOperation memory op = /* build op ... */;
        op = _signUserOp(op);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, payable(address(this)));
    }
}
```

### What to test

| Surface | Property |
| :--- | :--- |
| `validateUserOp` | Returns 0 (valid) for correctly signed ops, 1 (invalid sig) for bad ones |
| Nonce handling | Two ops with same nonce: second rejected |
| Paymaster flow | Paymaster gets charged, user account is not |
| Gas sponsorship edge cases | Paymaster deposit exhaustion triggers expected reverts |
| Batched calls (EIP-5792) | Atomic execution; partial failure reverts the batch |

ERC-4337 is large. Verify the current EntryPoint version (v0.7 vs v0.8) and PackedUserOperation layout against current docs via Context7.

## Session keys / delegated access

Smart accounts often support session keys. Property tests:

```solidity
function testFuzz_SessionKey_BoundedToScope(
    address target,
    bytes4 selector,
    uint256 value
) public {
    // Session key may only call approved (target, selector). Any other call reverts.
    vm.assume(!_isAllowedScope(target, selector));

    vm.prank(sessionKey);
    vm.expectRevert();
    account.execute(target, value, abi.encodePacked(selector));
}
```

## Formal verification (Certora, Kontrol)

Use when the stakes are high enough to justify the setup cost:

| Platform | Language | Model |
| :--- | :--- | :--- |
| Certora Prover | CVL (custom spec language) | SMT-based; proves rules over all executions |
| Kontrol | K framework | Symbolic + concolic; deeper but slower |

Both require writing specifications separate from the test suite:

```
// CVL example
rule deposit_increases_shares(uint256 amount) {
    env e;
    require amount > 0;
    uint256 before = totalSupply();
    deposit(e, amount);
    assert totalSupply() > before;
}
```

This is a full discipline, not a quick tool. Budget a week per contract for a solid spec. Use the result to catch bugs that no fuzzer or invariant harness will ever find.

## Chain re-org and block time tests

For protocols that depend on block timing (oracles, vesting, governance), test explicitly:

```solidity
function test_Oracle_HandlesMultipleBlocksInOneTx() public {
    // attacker sandwiches a price update
    vm.roll(block.number + 1);
    oracle.update(100);
    vm.roll(block.number + 1);
    oracle.update(200);
    // assert TWAP smoothing works
}
```

## Flash-loan attack patterns

For DeFi contracts, test against a flash-loan scenario:

```solidity
function test_NoFlashPriceManipulation() public {
    IFlashLoanReceiver receiver = new AttackerReceiver(vault, pool);
    uint256 balanceBefore = IERC20(asset).balanceOf(address(vault));

    pool.flashLoan(address(receiver), asset, 1_000_000e18, "");

    // assert vault did not lose value during the flash-loan-bounded call
    assertGe(IERC20(asset).balanceOf(address(vault)), balanceBefore);
}
```

## Differential testing across versions

When refactoring a contract, deploy both the old and new version in the same test and assert behavioral equivalence:

```solidity
function testFuzz_NewMatchesOld(uint256 x) public {
    x = bound(x, 0, 1e30);
    uint256 oldOut = OLD.compute(x);
    uint256 newOut = NEW.compute(x);
    assertEq(oldOut, newOut);
}
```

Use this pattern before cutting a migration. Foundry makes it cheap -- both contracts coexist in the same test process.

## Verification checklist

- [ ] Halmos `check_*` tests on critical pure/view functions
- [ ] Storage layout diffed in CI for upgradeable contracts
- [ ] ERC-4337 account has `validateUserOp` negative tests
- [ ] Session-key scope enforcement fuzzed
- [ ] Flash-loan attack scenarios tested for DeFi contracts
- [ ] Differential tests in place during refactors
- [ ] Formal verification specs for high-stakes contracts (bridges, custody)
