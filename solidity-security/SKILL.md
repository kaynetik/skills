---
name: solidity-security
description: >-
  Solidity smart contract security: vulnerability prevention, secure coding
  patterns, gas-safe optimizations, and audit preparation. Use when writing
  or reviewing Solidity code for security, auditing contracts, preventing
  reentrancy/overflow/access-control issues, optimizing gas safely, or
  preparing contracts for professional audits. Keywords: solidity security,
  smart contract audit, reentrancy, access control, CEI pattern, front-running,
  slither, invariant, vulnerability, exploit, secure solidity.
---

# Solidity Security

Vulnerability prevention, secure patterns, gas-safe optimizations, audit preparation.

---

## Code Style Rules

### No Unicode Separator Comments

Never use Unicode box-drawing characters (`─`, `━`, `═`, etc.) as comment decorators or section separators in generated code. This includes patterns like:

```
// ── State ─────────────────────────────────────────
// ══ Errors ═════════════════════════════════════════
```

These are AI slop. They carry no semantic value, are invisible noise in diffs, and mark generated code as low-quality. Use plain labels or nothing at all:

```solidity
// State
mapping(address => uint256) public balances;

// Errors
error InsufficientBalance();
```

---

## Vulnerabilities & Secure Patterns

### 1. Reentrancy

External call before state update lets an attacker re-enter mid-execution.

**Vulnerable:**

```solidity
function withdraw() public {
    uint256 amount = balances[msg.sender];
    (bool ok, ) = msg.sender.call{value: amount}("");
    require(ok);
    balances[msg.sender] = 0; // state update after call
}
```

**Secure - CEI + ReentrancyGuard:**

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    // Errors
    error InsufficientBalance();
    error TransferFailed();

    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
```

Cross-function reentrancy: attacker re-enters a *different* function that reads stale state. Apply `nonReentrant` to all functions sharing mutable state, not just the one with the external call.

### 2. Access Control

**Vulnerable:**

```solidity
function withdraw(uint256 amount) public {
    payable(msg.sender).transfer(amount);
}
```

**Secure:**

```solidity
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// Two-step transfer prevents accidental ownership loss
contract SimpleAccess is Ownable2Step {
    function emergencyWithdraw() external onlyOwner { /* ... */ }
}

// Role-based for multi-actor systems
contract RoleAccess is AccessControl {
    bytes32 public constant OPERATOR = keccak256("OPERATOR");
    function sensitiveOp() external onlyRole(OPERATOR) { /* ... */ }
}
```

- Never `tx.origin` for auth - only `msg.sender`
- `Ownable2Step` over `Ownable`
- Validate `address(0)` on all address parameters

### 3. Integer Overflow / Underflow

Solidity >= 0.8.0 has checked arithmetic by default. For `unchecked` blocks, the surrounding logic must prove bounds:

```solidity
uint256 len = arr.length;
for (uint256 i; i < len; ) {
    // i < len < type(uint256).max, so ++i cannot overflow
    unchecked { ++i; }
}
```

**Pre-0.8.0:** Use `SafeMath`. There is no reason to target < 0.8.0 for new contracts.

### 4. Front-Running / MEV

**Vulnerable:**

```solidity
function swap(uint256 amount, uint256 minOutput) public {
    uint256 output = calculateOutput(amount);
    require(output >= minOutput, "Slippage");
}
```

**Secure - Commit-Reveal:**

```solidity
// State
mapping(bytes32 => uint256) public commitBlock;
uint256 public constant REVEAL_DELAY = 1;

// Errors
error NoCommitment();
error RevealTooEarly();

function commit(bytes32 hash) external {
    commitBlock[hash] = block.number;
}

function reveal(uint256 amount, uint256 minOutput, bytes32 secret) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, amount, minOutput, secret));
    if (commitBlock[hash] == 0) revert NoCommitment();
    if (block.number <= commitBlock[hash] + REVEAL_DELAY) revert RevealTooEarly();
    delete commitBlock[hash];
}
```

Other mitigations: Flashbots Protect / MEV Blocker, slippage + deadline params, batch auctions (CoW Protocol).

### 5. Unchecked External Calls

Some tokens (USDT) don't return `bool` - raw `.transfer()` silently fails.

```solidity
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVault {
    using SafeERC20 for IERC20;

    function send(IERC20 token, address to, uint256 amount) internal {
        token.safeTransfer(to, amount);
    }
}
```

Always `SafeERC20` for token operations.

### 6. Oracle Manipulation

| Risk | Mitigation |
|------|-----------|
| Spot price manipulation | TWAP over multiple blocks |
| Single oracle failure | Multiple independent oracles, median |
| Stale data | Freshness check on `updatedAt` |
| Flash loan attack | Chainlink `latestRoundData` + sanity bounds |

```solidity
error InvalidPrice();
error StaleOracle();

uint256 public constant MAX_STALENESS = 1 hours;

function getPrice(AggregatorV3Interface feed) internal view returns (uint256) {
    (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();
    if (price <= 0) revert InvalidPrice();
    if (block.timestamp - updatedAt > MAX_STALENESS) revert StaleOracle();
    return uint256(price);
}
```

### 7. Proxy / Upgrade Pitfalls

| Risk | Prevention |
|------|-----------|
| Storage collision | EIP-1967 slots, OZ upgrades plugin |
| Uninitialized proxy | `initialize()` in same tx as deploy |
| Selector clash | `TransparentUpgradeableProxy` or UUPS |
| Re-initialization | `_disableInitializers()` in constructor |

```solidity
/// @custom:oz-upgrades-unsafe-allow constructor
constructor() {
    _disableInitializers();
}
```

### 8. Signature Replay

```solidity
error InvalidSignature();
error NonceAlreadyUsed();

mapping(bytes32 => bool) public usedNonces;

function executeWithSig(
    address signer, uint256 amount, bytes32 nonce, bytes calldata sig
) external {
    if (usedNonces[nonce]) revert NonceAlreadyUsed();

    bytes32 digest = keccak256(abi.encodePacked(
        "\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(signer, amount, nonce))
    ));

    if (ECDSA.recover(digest, sig) != signer) revert InvalidSignature();

    usedNonces[nonce] = true;
}
```

Use EIP-712 typed data + nonce + `block.chainid` in the domain separator.

---

## Design Patterns

### Pull Over Push

```solidity
// State
mapping(address => uint256) public pending;

// Errors
error NothingToWithdraw();
error TransferFailed();

function recordPayment(address recipient, uint256 amount) internal {
    pending[recipient] += amount;
}

function withdraw() external {
    uint256 amount = pending[msg.sender];
    if (amount == 0) revert NothingToWithdraw();
    pending[msg.sender] = 0;
    (bool ok, ) = msg.sender.call{value: amount}("");
    if (!ok) revert TransferFailed();
}
```

### Emergency Stop

```solidity
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Protocol is PausableUpgradeable, OwnableUpgradeable {
    function deposit() external payable whenNotPaused { /* ... */ }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
```

### Input Validation

```solidity
error ZeroAddress();
error ZeroAmount();
error InsufficientBalance(uint256 available, uint256 requested);

function transfer(address to, uint256 amount) external {
    if (to == address(0)) revert ZeroAddress();
    if (amount == 0) revert ZeroAmount();
    if (balances[msg.sender] < amount) {
        revert InsufficientBalance(balances[msg.sender], amount);
    }
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

---

## Gas Optimization

Never sacrifice correctness for gas. Every `unchecked` block must have a provable safety invariant.

### Storage Packing

```solidity
// 1 slot (32 bytes)
struct Packed {
    uint128 balance;
    uint64  lastUpdate;
    uint64  nonce;
}
```

### Calldata Over Memory

```solidity
function process(uint256[] calldata data) external pure returns (uint256) {
    return data[0];
}
```

### Custom Errors Over Revert Strings

Custom errors (Solidity >= 0.8.4) are cheaper than string reverts and encode structured data.

```solidity
error WithdrawalExceedsBalance(uint256 requested, uint256 available);

function withdraw(uint256 amount) external {
    if (amount > address(this).balance) {
        revert WithdrawalExceedsBalance(amount, address(this).balance);
    }
}
```

### Events for Off-Chain Data

```solidity
event DataStored(address indexed user, uint256 indexed id, bytes data);

function storeData(uint256 id, bytes calldata data) external {
    emit DataStored(msg.sender, id, data);
}
```

Only persist to storage what on-chain logic actually reads.

---

## Security Tooling

| Category | Tool | Purpose |
|----------|------|---------|
| Static analysis | Slither | Detector suite for common vulns |
| Static analysis | Aderyn | Rust-based, Foundry-native |
| Fuzzing | Echidna | Property-based Solidity fuzzer |
| Fuzzing | Medusa | Go-based alternative to Echidna |
| Formal verification | Certora | Prover for critical invariants |
| Formal verification | Halmos | Symbolic execution for Foundry |
| SMT | SMTChecker | Built-in bounded model checker |

### Minimum CI Pipeline

```bash
slither . --filter-paths "node_modules|lib"
forge test --fuzz-runs 10000
forge snapshot --check
```

---

## Testing for Security (Foundry)

```solidity
import "forge-std/Test.sol";

contract SecurityTest is Test {
    Vault vault;
    address attacker = makeAddr("attacker");

    function setUp() public {
        vault = new Vault();
        vm.deal(address(vault), 10 ether);
    }

    function test_RevertWhen_ReentrancyAttempted() public {
        ReentrancyAttacker exploit = new ReentrancyAttacker(address(vault));
        vm.deal(address(exploit), 1 ether);
        vm.expectRevert();
        exploit.attack();
    }

    function test_RevertWhen_UnauthorizedWithdraw() public {
        vm.prank(attacker);
        vm.expectRevert(Vault.Unauthorized.selector);
        vault.emergencyWithdraw();
    }

    function testFuzz_TransferNeverExceedsBalance(uint256 amount) public {
        vm.assume(amount > 0 && amount <= vault.balanceOf(address(this)));
        vault.transfer(attacker, amount);
        assertEq(vault.balanceOf(attacker), amount);
    }
}
```

---

## Audit Preparation

### Code Quality

- [ ] NatSpec on all public/external functions (`@notice`, `@dev`, `@param`, `@return`)
- [ ] CEI on every state-changing function with external calls
- [ ] `nonReentrant` on functions sharing mutable state
- [ ] `SafeERC20` for all token operations
- [ ] Custom errors - no revert strings
- [ ] No `tx.origin`, no `block.timestamp` randomness, no on-chain secrets

### Testing

- [ ] Unit tests: every function, every revert path
- [ ] Fuzz tests: property-based for numeric/state edges
- [ ] Invariant tests: global properties that must always hold
- [ ] Fork tests: integration against mainnet state
- [ ] Static analysis clean (Slither + Aderyn, zero high/medium)

### Documentation

- [ ] Architecture overview with contract interaction diagram
- [ ] Threat model: what is trusted, what is adversarial
- [ ] Known limitations and design trade-offs
- [ ] Deployment and upgrade runbook
- [ ] Previous audit reports (if any)

### Deployment

- [ ] Access control verified and documented
- [ ] Upgrade path tested end-to-end (if proxy)
- [ ] Testnet deployment validated
- [ ] Emergency pause mechanism tested
- [ ] Multi-sig or timelock on admin functions

---

## NatSpec Template

```solidity
/// @title  Vault - Collateralized lending vault
/// @notice Accepts collateral deposits and issues vault shares.
/// @dev    UUPS-upgradeable. Tiered fee schedule per ADR-018.
contract Vault {
    /// @notice Deposit collateral into the vault.
    /// @param  token   Collateral token address.
    /// @param  amount  Deposit amount (must be > 0).
    /// @return shares  Vault shares minted.
    function deposit(address token, uint256 amount) external returns (uint256 shares) {
        // ...
    }
}
```

---

## Quick Reference

| Vulnerability | Fix |
|---------------|-----|
| Reentrancy | CEI + `ReentrancyGuard` |
| Missing access control | `Ownable2Step` / `AccessControl` |
| Unchecked ERC20 return | `SafeERC20` |
| Oracle manipulation | TWAP + freshness check + sanity bounds |
| Frontrunning | Commit-reveal, slippage + deadline params |
| Proxy storage collision | EIP-1967, OZ upgrades plugin |
| `tx.origin` auth | `msg.sender` |
| On-chain randomness | Chainlink VRF |
| Unbounded loop DoS | Pagination or pull pattern |
| Signature replay | EIP-712 + nonce + `block.chainid` |
| Flash loan price manipulation | TWAP, multiple oracles |
| Push-payment DoS | Pull-over-push |
| Delegatecall to untrusted | Never; or restrict target via allowlist |
