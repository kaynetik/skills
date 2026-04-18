# Stateful invariants

Read when: the protocol has accumulating state (vaults, lending, AMMs, staking, governance) and parameterized fuzz tests are not finding accounting bugs.

## What an invariant is

A property that must hold after any sequence of externally-triggerable state transitions, for any actor, in any order. Unit tests check outcomes of specific sequences; invariants check the absence of bad states across all sequences.

Every protocol has a small set of critical invariants. Find them first; the test harness is secondary.

## Canonical invariants by protocol type

| Protocol | Invariant |
| :--- | :--- |
| Vault (ERC-4626) | `sum(previewRedeem(balanceOf(user)) for all users) <= totalAssets()` |
| Lending | `sum(collateralValue) >= sum(debtValue)` for every user (or the protocol is insolvent) |
| AMM | `reserve0 * reserve1 >= k_before_swap` (monotonically non-decreasing invariant) |
| ERC-20 | `sum(balanceOf(all holders)) == totalSupply` |
| Staking | `rewardsAccrued(user) <= rewardsEarned(user) + precision_dust` |
| Governance | Every executed proposal passed its quorum and timelock |

Write these down first. Then build the harness.

## `StdInvariant` harness

```solidity
// test/invariant/VaultInvariants.t.sol
import {Test, StdInvariant} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {VaultHandler} from "./handlers/VaultHandler.sol";

contract VaultInvariants is StdInvariant, Test {
    Vault internal vault;
    MockERC20 internal token;
    VaultHandler internal handler;

    function setUp() public {
        token = new MockERC20("Tok", "TOK", 18);
        vault = new Vault(address(token));
        handler = new VaultHandler(vault, token);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.withdraw.selector;
        selectors[2] = handler.transfer.selector;
        selectors[3] = handler.warp.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_TotalSharesMatchesSumOfHolders() public view {
        uint256 sum;
        address[] memory actors = handler.actors();
        for (uint256 i; i < actors.length; ++i) {
            sum += vault.balanceOf(actors[i]);
        }
        assertEq(sum, vault.totalSupply(), "share supply drift");
    }

    function invariant_RedeemableLECash() public view {
        uint256 totalRedeemable;
        address[] memory actors = handler.actors();
        for (uint256 i; i < actors.length; ++i) {
            totalRedeemable += vault.previewRedeem(vault.balanceOf(actors[i]));
        }
        assertLe(totalRedeemable, vault.totalAssets(), "insolvency");
    }
}
```

Key decisions:

| Decision | Why |
| :--- | :--- |
| `targetContract(handler)`, not the vault directly | Raw vault calls with random args revert 99% of the time; handlers ensure meaningful calls |
| `targetSelector(...)` explicit allowlist | Prevents fuzzer from calling view functions or malformed entry points |
| Actor tracking lives in the handler | Lets invariants iterate over real users, not arbitrary addresses |

## The handler

A handler is a contract that mediates between the fuzzer and the protocol, keeping calls well-bounded and tracking actor identity.

```solidity
// test/invariant/handlers/VaultHandler.sol
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract VaultHandler is CommonBase, StdCheats, StdUtils {
    Vault internal vault;
    MockERC20 internal token;

    address[] public actors;
    mapping(address actor => bool) internal _known;

    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;

    modifier useActor(uint256 seed) {
        address actor = _pickOrCreateActor(seed);
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    constructor(Vault v, MockERC20 t) {
        vault = v;
        token = t;
    }

    function deposit(uint256 seed, uint256 amount) public useActor(seed) {
        amount = bound(amount, 1, 1_000_000e18);
        deal(address(token), msg.sender, amount);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        ghostDeposited += amount;
    }

    function withdraw(uint256 seed, uint256 amount) public useActor(seed) {
        uint256 balance = vault.balanceOf(msg.sender);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);
        vault.withdraw(amount);
        ghostWithdrawn += amount;
    }

    function warp(uint256 seconds_) public {
        seconds_ = bound(seconds_, 1, 30 days);
        vm.warp(block.timestamp + seconds_);
    }

    function _pickOrCreateActor(uint256 seed) internal returns (address actor) {
        if (actors.length > 0 && seed % 2 == 0) {
            actor = actors[seed % actors.length];
        } else {
            actor = address(uint160(uint256(keccak256(abi.encode(seed)))));
            if (!_known[actor]) {
                actors.push(actor);
                _known[actor] = true;
            }
        }
    }
}
```

### Handler rules

| Rule | Reason |
| :--- | :--- |
| Every action wraps `bound(...)` on inputs | Reverts waste fuzz runs; `fail_on_revert = true` catches unbounded handlers |
| Handlers never revert intentionally | If a transition is not possible, return early; reverts are for real bugs only |
| Ghost variables track expected totals | Used by invariants as reference values independent of contract state |
| Actor set grows over the run | Real protocols have many users; single-actor runs hide bugs |
| Time-advancing function included (`warp`) | Time-dependent state (accrual, vesting) otherwise never gets tested |

## Ghost variables

Ghost variables are aggregate counters maintained by the handler, used as a second source of truth for invariant assertions:

```solidity
function invariant_AllDepositsAccountedFor() public view {
    assertEq(
        vault.totalAssets(),
        handler.ghostDeposited() - handler.ghostWithdrawn() + /* yield */ 0,
        "deposit accounting drift"
    );
}
```

When contract state and ghost state drift, you have an accounting bug.

## `fail_on_revert` discipline

```toml
[profile.ci.invariant]
fail_on_revert = true
```

With this on, every handler revert is a test failure. You are forced to design handlers that always succeed when the transition is possible and return early when it is not. This exposes the true state space the fuzzer is exploring.

Turn it off only during handler development; turn it back on before merging.

## Multi-contract / cross-protocol invariants

When testing against forked mainnet (e.g., your protocol integrating with Uniswap), register multiple target contracts:

```solidity
targetContract(address(vaultHandler));
targetContract(address(uniswapHandler));
```

Each handler independently advances its protocol; invariants assert cross-protocol properties (e.g., "positions on vault plus positions on Uniswap LP == total user equity").

## Invariant depth vs runs

| Setting | Meaning |
| :--- | :--- |
| `invariant.runs` | How many fresh random sequences to try |
| `invariant.depth` | How many handler calls per sequence |
| `depth * runs` | Effective call budget |

Increasing `depth` finds deeper state bugs (accrual drift over long time). Increasing `runs` finds bugs reachable from distinct initial sequences. In CI, lean toward `depth`; for nightly, scale both.

## When invariants fail

Foundry prints the call sequence that reached the failing state. Reproduce:

```bash
forge test --match-test invariant_TotalSharesMatchesSumOfHolders -vvv
```

Commit failing sequences to `cache/invariant/failures` (Foundry writes them) so the exact sequence regresses on every run.

## Invariants + property testing (Echidna / Medusa)

Once Foundry invariants are stable, add Echidna or Medusa for deeper fuzzing of the same handler. They share the same harness contract. See `static-and-property.md`.

## Verification checklist

- [ ] Critical invariants written down in English before any Solidity
- [ ] `StdInvariant` harness with explicit `targetContract` and `targetSelector`
- [ ] Handler `bound`s every input and never reverts intentionally
- [ ] Actor set grows over the run (not fixed to one address)
- [ ] Time-advancing handler function included
- [ ] Ghost variables track expected totals
- [ ] `fail_on_revert = true` in CI
- [ ] Failing sequences regress via committed failure files
