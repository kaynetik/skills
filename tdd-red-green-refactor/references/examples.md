# TDD Red-Green-Refactor Examples

Concrete examples of the bug-fix TDD workflow in each supported language.

---

## Rust Example

**Bug:** `withdraw` allows negative balances.

### RED -- Failing Test

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bug_42_withdraw_rejects_overdraft() {
        let account = Account::new(100);
        let result = account.withdraw(150);
        assert!(result.is_err(), "withdrawing more than balance should fail");
    }
}
```

Run `cargo test` -- test fails because `withdraw` currently allows overdrafts.

### GREEN -- Minimal Fix

```rust
impl Account {
    pub fn withdraw(&mut self, amount: u64) -> Result<(), AccountError> {
        if amount > self.balance {
            return Err(AccountError::InsufficientFunds);
        }
        self.balance -= amount;
        Ok(())
    }
}
```

Run `cargo test` -- test passes.

### REFACTOR

Extract the balance check into a reusable method if other operations need it:

```rust
impl Account {
    fn has_sufficient_funds(&self, amount: u64) -> bool {
        self.balance >= amount
    }

    pub fn withdraw(&mut self, amount: u64) -> Result<(), AccountError> {
        if !self.has_sufficient_funds(amount) {
            return Err(AccountError::InsufficientFunds);
        }
        self.balance -= amount;
        Ok(())
    }
}
```

Run `cargo test` -- still green.

---

## Go Example

**Bug:** `ParseConfig` silently ignores invalid port values.

### RED -- Failing Test

```go
func TestBug87_ParseConfig_RejectsInvalidPort(t *testing.T) {
    input := `{"host": "localhost", "port": -1}`
    _, err := ParseConfig([]byte(input))
    if err == nil {
        t.Fatal("expected error for negative port, got nil")
    }
}
```

Run `go test ./...` -- test fails because `ParseConfig` accepts port -1.

### GREEN -- Minimal Fix

```go
func ParseConfig(data []byte) (*Config, error) {
    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }
    if cfg.Port < 0 || cfg.Port > 65535 {
        return nil, fmt.Errorf("invalid port: %d", cfg.Port)
    }
    return &cfg, nil
}
```

Run `go test ./...` -- test passes.

### REFACTOR

Use a validation method on Config:

```go
func (c *Config) validate() error {
    if c.Port < 0 || c.Port > 65535 {
        return fmt.Errorf("invalid port: %d", c.Port)
    }
    return nil
}

func ParseConfig(data []byte) (*Config, error) {
    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }
    if err := cfg.validate(); err != nil {
        return nil, err
    }
    return &cfg, nil
}
```

Run `go test ./...` -- still green.

---

## TypeScript Example

**Bug:** `calculateDiscount` returns NaN for zero-quantity orders.

### RED -- Failing Test

```typescript
import { describe, it, expect } from "vitest";
import { calculateDiscount } from "./pricing";

describe("calculateDiscount", () => {
  it("bug-203: returns 0 discount for zero-quantity order", () => {
    const result = calculateDiscount({ quantity: 0, unitPrice: 50 });
    expect(result).toBe(0);
    expect(Number.isNaN(result)).toBe(false);
  });
});
```

Run the test -- fails because `calculateDiscount` divides by quantity, producing NaN.

### GREEN -- Minimal Fix

```typescript
export function calculateDiscount(order: Order): number {
  if (order.quantity === 0) {
    return 0;
  }
  const total = order.quantity * order.unitPrice;
  return total > 100 ? total * 0.1 : 0;
}
```

Run the test -- passes.

### REFACTOR

Extract threshold logic:

```typescript
const DISCOUNT_THRESHOLD = 100;
const DISCOUNT_RATE = 0.1;

export function calculateDiscount(order: Order): number {
  const total = order.quantity * order.unitPrice;
  if (total <= DISCOUNT_THRESHOLD) {
    return 0;
  }
  return total * DISCOUNT_RATE;
}
```

Run the test -- still green. The zero-quantity case is now handled by the
threshold check naturally (0 * price = 0, which is <= 100).

---

## Solidity Example (Foundry)

**Bug:** `withdraw` in a vault contract does not check if the caller has
sufficient deposited balance, allowing anyone to drain funds.

### RED -- Failing Test

```solidity
// test/Vault.t.sol
import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    Vault vault;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vault = new Vault();
        deal(alice, 10 ether);
        vm.prank(alice);
        vault.deposit{value: 5 ether}();
    }

    function test_bug_55_withdraw_rejects_overdraft() public {
        vm.prank(bob);
        vm.expectRevert("insufficient balance");
        vault.withdraw(1 ether);
    }
}
```

Run `forge test` -- test fails because bob can withdraw despite having no
deposits.

### GREEN -- Minimal Fix

```solidity
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount, "insufficient balance");
    balances[msg.sender] -= amount;
    (bool ok,) = msg.sender.call{value: amount}("");
    require(ok, "transfer failed");
}
```

Run `forge test` -- test passes.

### REFACTOR

Apply Checks-Effects-Interactions and use a custom error:

```solidity
error InsufficientBalance(uint256 requested, uint256 available);

function withdraw(uint256 amount) external {
    uint256 bal = balances[msg.sender];
    if (amount > bal) revert InsufficientBalance(amount, bal);

    balances[msg.sender] = bal - amount;

    (bool ok,) = msg.sender.call{value: amount}("");
    require(ok, "transfer failed");
}
```

Run `forge test` -- still green. Update the test to use `vm.expectRevert` with
the custom error selector.

---

## Pattern: Hypothesis-Driven Bug Investigation

When the root cause is unknown, use tests to systematically eliminate hypotheses:

```
Hypotheses for bug #312 (intermittent API timeout):
  H1: Connection pool exhaustion          -> 5 min to falsify
  H2: DNS resolution delay                -> 2 min to falsify
  H3: Retry loop with exponential backoff -> 3 min to falsify
  H4: Upstream rate limiting               -> 2 min to falsify

Prioritized order: H2, H4, H1, H3
```

Write a targeted test for each hypothesis. A test that passes (when you expected
it to fail) eliminates that hypothesis. A test that fails confirms you found the
cause -- proceed to GREEN.
