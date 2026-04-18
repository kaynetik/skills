# Fork testing

Read when: testing against real mainnet contracts, impersonating accounts, or validating integrations (Uniswap, Aave, Curve, oracles).

## When to fork

| Scenario | Fork? |
| :--- | :--- |
| Integration with external protocol (Uniswap, Curve, etc.) | Yes |
| Depends on a specific token's on-chain behavior (USDT, WETH9) | Yes |
| Oracle integration (Chainlink, Pyth) | Yes |
| Reproducing a production incident at a specific block | Yes |
| Testing your own code in isolation | No -- use unit tests; forks are slow |

Fork tests are 10-100x slower than local. Use sparingly and in their own test directory.

## Pin the block. Always.

```solidity
import {Test} from "forge-std/Test.sol";

contract UniswapForkTest is Test {
    uint256 internal mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("mainnet"), 19_000_000);
    }

    // tests...
}
```

Or via CLI:

```bash
forge test --fork-url $MAINNET_RPC_URL --fork-block-number 19000000 --match-path test/fork/*
```

Unpinned forks are flaky by construction. Block 20_000_000 today != block 20_000_000 tomorrow in terms of sequential test runs (reorgs, RPC differences). More importantly, state at block N includes prices, balances, and protocol upgrades that must be reproducible across CI runs and team members.

Pin every fork to an explicit block number. Write the reason next to it:

```solidity
// Pinned to block at which MakerDAO emergency shutdown was triggered
uint256 constant PIN_BLOCK = 16_024_823;
```

## Fork management

| Method | Use |
| :--- | :--- |
| `vm.createSelectFork(url, block)` | Default -- fork and activate |
| `vm.createFork(url, block)` | Create without activating (for multi-fork tests) |
| `vm.selectFork(forkId)` | Switch between previously-created forks |
| `vm.rollFork(block)` | Advance active fork to a newer block |
| `vm.activeFork()` | Get current fork id |

Multi-chain test:

```solidity
uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), 19_000_000);
uint256 baseFork = vm.createFork(vm.rpcUrl("base"), 12_000_000);

vm.selectFork(mainnetFork);
// ... do mainnet-side setup
vm.selectFork(baseFork);
// ... do base-side assertions
```

## Impersonation

Take control of any mainnet address:

```solidity
address constant WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;  // USDT binance hot

function test_SwapWithWhaleLiquidity() public {
    vm.selectFork(mainnetFork);
    vm.prank(WHALE);
    IERC20(USDT).transfer(alice, 10_000_000e6);

    // now alice has USDT she got from the whale
}
```

| Cheatcode | Use |
| :--- | :--- |
| `vm.prank(addr)` | One-shot call as addr (works on forks the same as local) |
| `vm.startPrank(addr)` / `stopPrank()` | Multi-call context |
| `deal(token, to, amount)` (StdCheats) | Skip impersonation; write balance directly via storage |

`deal` is usually simpler than finding a whale, but breaks for tokens that use non-standard storage layouts (e.g., tokens with yield-bearing balances). For those, impersonate.

## Overriding storage

For tokens with non-standard balances or where `deal` fails:

```solidity
bytes32 slot = keccak256(abi.encode(alice, uint256(0)));  // check the layout
vm.store(USDT, slot, bytes32(uint256(1_000_000e6)));
```

Use `forge inspect <Contract> storageLayout` to find slots when working with verified contracts.

## RPC configuration

In `foundry.toml`:

```toml
[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
base = "${BASE_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
```

Then in tests:

```solidity
vm.createSelectFork(vm.rpcUrl("mainnet"), 19_000_000);
```

The `rpc_endpoints` alias is portable across contributors -- no one has to hardcode a URL.

## Rate limiting and caching

Foundry caches RPC responses under `~/.foundry/cache/rpc/`. A block-pinned test that has been run once loads instantly thereafter.

| Practice | Benefit |
| :--- | :--- |
| Pin blocks (see above) | Enables caching |
| Share the RPC cache across CI runs via `actions/cache` | Eliminates per-run cold starts |
| Use a private RPC with high rate limits (Alchemy / Infura / QuickNode) | Public endpoints throttle fast |

CI cache key template:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.foundry/cache/rpc
    key: foundry-rpc-${{ hashFiles('**/*.sol') }}
```

Hash files into the key so cache invalidates when tests change; otherwise stale RPC responses can mask real issues.

## Reproducing production incidents

Exact incident replay:

1. Get the block number from the offending transaction.
2. Fork at `block - 1`.
3. Impersonate the attacker; replay the exact calldata.
4. Assert the loss amount or state change.

```solidity
function test_Incident_Replay() public {
    uint256 forkAtIncident = vm.createSelectFork(vm.rpcUrl("mainnet"), 17_900_000);

    vm.prank(ATTACKER);
    (bool ok,) = EXPLOIT_TARGET.call(EXPLOIT_CALLDATA);
    assertTrue(ok);

    // assert the drain amount
    assertEq(IERC20(STOLEN_TOKEN).balanceOf(ATTACKER), EXPECTED_LOSS);
}
```

This pattern lets you write a regression test for a fix: the same replay on your patched contract must fail.

## Hardhat fork equivalents (quick reference)

| Foundry | Hardhat 3 |
| :--- | :--- |
| `vm.createSelectFork(url, block)` | `network.connect({ override: { forking: { url, blockNumber }}})` |
| `vm.prank(addr)` | `viem.getWalletClient({ account: addr })` after impersonation via `hardhat_impersonateAccount` |
| `deal(token, to, amount)` | `network.provider.send('hardhat_setStorageAt', ...)` with helper |
| `vm.rollFork(block)` | `network.provider.send('hardhat_reset', [{ forking: { blockNumber }}])` |

## Verification checklist

- [ ] Every fork test has an explicit `--fork-block-number`
- [ ] Fork tests live in `test/fork/` and are excluded from the default `forge test` path for speed
- [ ] RPC URLs come from `rpc_endpoints` in `foundry.toml`, not hardcoded
- [ ] CI caches `~/.foundry/cache/rpc`
- [ ] Impersonation used only when `deal` is insufficient
- [ ] Incident replays archived with block + calldata so they regress forever
