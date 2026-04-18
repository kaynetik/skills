# Unit testing

Read when: writing plain `test_*` functions, learning cheatcodes, handling reverts/events, or structuring a Foundry test file.

## Test file anatomy (Foundry)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {MockERC20} from "test/utils/MockERC20.sol";

contract VaultTest is Test {
    Vault internal vault;
    MockERC20 internal token;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        token = new MockERC20("Tok", "TOK", 18);
        vault = new Vault(address(token), owner);

        token.mint(alice, 1_000e18);
        token.mint(bob, 1_000e18);
    }

    function test_Deposit_UpdatesShares() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100e18);
        uint256 shares = vault.deposit(100e18);
        vm.stopPrank();

        assertEq(shares, 100e18);
        assertEq(vault.balanceOf(alice), 100e18);
    }
}
```

Conventions:

| Convention | Why |
| :--- | :--- |
| `test_<Subject>_<Behavior>` naming | Filter by `--match-test test_Deposit_*`; grepable test intent |
| `makeAddr("alice")` | Deterministic labeled addresses in traces; never use `address(1)` / `address(2)` |
| `internal` state | Lets derived test contracts (inheritance-based fixtures) reuse it |
| One `setUp` per contract | Foundry snapshots state; each test gets a fresh copy for free |

## Cheatcode reference (most-used)

| Cheatcode | Use |
| :--- | :--- |
| `vm.prank(addr)` | Next call is `msg.sender == addr` |
| `vm.startPrank(addr)` / `vm.stopPrank()` | Multi-call prank context |
| `vm.deal(addr, amount)` | Set ETH balance |
| `deal(token, to, amount)` (StdCheats) | Set ERC-20 balance via storage write |
| `vm.warp(timestamp)` | Set `block.timestamp` |
| `vm.roll(blockNumber)` | Set `block.number` |
| `vm.expectRevert(selector)` | Expect next call to revert with custom error selector |
| `vm.expectRevert(bytes)` | Expect exact revert bytes (rare, needed for complex returns) |
| `vm.expectEmit(bool, bool, bool, bool, address)` | Match emitted event by indexed topics and data |
| `vm.recordLogs()` / `vm.getRecordedLogs()` | Capture all logs for assertion |
| `vm.mockCall(addr, data, returnData)` | Mock a call without deploying the target |
| `vm.store(addr, slot, value)` | Direct storage write (for state-only test setups) |
| `vm.load(addr, slot)` | Read storage directly |
| `vm.skip(condition)` (avoid) | Skip test -- prefer fixing the condition |

## Expecting custom errors (the right way)

```solidity
function test_Deposit_RevertWhen_AmountZero() public {
    vm.expectRevert(Vault.ZeroAmount.selector);
    vault.deposit(0);
}

function test_Deposit_RevertWhen_CapExceeded() public {
    uint256 deposit = vault.CAP() + 1;
    vm.expectRevert(abi.encodeWithSelector(Vault.CapExceeded.selector, deposit, vault.CAP()));
    vault.deposit(deposit);
}
```

| Revert shape | Assertion |
| :--- | :--- |
| `error MyErr()` | `vm.expectRevert(MyErr.selector)` |
| `error MyErr(uint256 a, address b)` | `vm.expectRevert(abi.encodeWithSelector(MyErr.selector, a, b))` |
| `require(cond, "reason")` (legacy) | `vm.expectRevert(bytes("reason"))` -- but push the team to migrate to custom errors |
| Panic (arithmetic overflow, div by zero) | `vm.expectRevert(stdError.arithmeticError)` from forge-std |

Avoid `vm.expectRevert()` with no argument in production suites -- it matches any revert and masks refactoring regressions.

## Expecting events

```solidity
function test_Deposit_EmitsDeposit() public {
    vm.expectEmit(true, true, false, true, address(vault));
    emit Vault.Deposit(alice, 100e18, 100e18);

    vm.prank(alice);
    vault.deposit(100e18);
}
```

The four booleans control which topics to check: `(topic1, topic2, topic3, data)`. For events with indexed addresses or ids, match them exactly; unindexed fields match via the `data` bool.

## Negative test pattern

Every access-controlled function needs a negative test:

```solidity
function test_SetFee_RevertWhen_NotOwner() public {
    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vault.setFee(100);
}
```

For role-based access:

```solidity
function test_Pause_RevertWhen_MissingRole() public {
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            alice,
            vault.PAUSER_ROLE()
        )
    );
    vault.pause();
}
```

Build an access-control matrix once (role x function) and generate negative tests for every cell.

## Arrange / act / assert

Keep each test focused on one assertion set:

```solidity
function test_Withdraw_TransfersTokensAndBurnsShares() public {
    // arrange
    _depositAs(alice, 100e18);
    uint256 balanceBefore = token.balanceOf(alice);

    // act
    vm.prank(alice);
    vault.withdraw(50e18);

    // assert
    assertEq(token.balanceOf(alice), balanceBefore + 50e18, "token balance");
    assertEq(vault.balanceOf(alice), 50e18, "shares remaining");
}
```

The third `assertEq` argument is a failure message. Always include it -- CI output becomes debuggable.

## Shared fixtures via inheritance

When the same deployment pattern is used across many test contracts:

```solidity
// test/utils/BaseVaultTest.sol
abstract contract BaseVaultTest is Test {
    Vault internal vault;
    MockERC20 internal token;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");

    function setUp() public virtual {
        token = new MockERC20("Tok", "TOK", 18);
        vault = new Vault(address(token), owner);
        token.mint(alice, 1_000e18);
    }

    function _depositAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
    }
}

// test/unit/VaultDeposit.t.sol
contract VaultDepositTest is BaseVaultTest { ... }
```

Inheritance-based fixtures are the idiomatic Foundry alternative to Hardhat's `loadFixture`.

## Assertions worth knowing

| Assertion | Use |
| :--- | :--- |
| `assertEq`, `assertEq(a, b, "msg")` | Equality with optional message |
| `assertEqDecimal(a, b, decimals)` | Print mismatch in decimal form |
| `assertApproxEqAbs(a, b, delta)` | Within absolute delta |
| `assertApproxEqRel(a, b, percentDelta)` | Within relative delta (1e18 = 100%) |
| `assertLt`, `assertGt`, `assertLe`, `assertGe` | Ordering |
| `assertTrue`, `assertFalse` | Boolean |
| `vm.assertEq` | Same as top-level, scoped through vm |

Use `assertApproxEqRel` for anything involving share math, oracle prices, or time-based accrual. Strict equality on compounded values is fragile.

## Logs in tests

```solidity
emit log_named_uint("alice shares", vault.balanceOf(alice));
emit log_named_decimal_uint("TVL", vault.totalAssets(), 18);
```

Shown only with `-vv` or higher. Use sparingly -- over-logged suites slow CI output.

## Hardhat equivalents (quick reference)

| Foundry | Hardhat 3 (viem) |
| :--- | :--- |
| `vm.prank(alice)` | `await vault.write.deposit([amount], { account: alice })` |
| `vm.expectRevert(Sel.selector)` | `await assert.rejects(promise, /ZeroAmount/)` with `hardhat-chai-matchers` style |
| `vm.warp(t)` | `await network.provider.send('evm_setNextBlockTimestamp', [t])` or EDR equivalent |
| `vm.roll(n)` | `await network.provider.send('evm_mine')` loop / `hardhat_mine` |
| `deal(token, to, amount)` | `setStorageAt` via EDR with a helper |
| `vm.expectEmit(...)` | `expect(tx).to.emit(contract, 'Deposit').withArgs(...)` (chai-matchers) |

## Verification checklist

- [ ] Custom error selectors used in `vm.expectRevert`, not strings
- [ ] Every access-controlled function has a negative test
- [ ] `makeAddr("label")` for test addresses
- [ ] Assertions include failure messages
- [ ] Shared fixtures via inherited abstract test contracts
- [ ] `vm.expectEmit` matches topics + data precisely
- [ ] No bare `vm.expectRevert()` with no argument
