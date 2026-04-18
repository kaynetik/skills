# Hardhat setup

Read when: the user has a Hardhat project, needs TypeScript-heavy tests, or wants ethers/viem-backed integration tests alongside contracts.

> [!IMPORTANT]
> Hardhat 3 (late 2025) is a major rewrite: ESM-first, Node.js built-in test runner, Viem-native, EDR (Rust-based EVM) replacing the legacy `@nomicfoundation/hardhat-network-helpers` in places. Verify the current API with Context7 before copying syntax. Patterns below reflect Hardhat 3 defaults.

## When to choose Hardhat over Foundry

| Scenario | Use Hardhat |
| :--- | :--- |
| TypeScript-heavy off-chain integration alongside contracts | Yes |
| Deploy pipeline already built on `hardhat-deploy` / Ignition | Yes |
| Need to run TS scripts that share types with contracts | Yes |
| Pure on-chain testing, fuzz/invariants, speed | Prefer Foundry |
| Symbolic execution, property testing | Prefer Foundry (Halmos, Echidna integrate there) |

Many teams use both: Foundry for unit/fuzz/invariants, Hardhat for deployment orchestration.

## Install (Hardhat 3)

```bash
npm init -y
npm i -D hardhat @nomicfoundation/hardhat-toolbox-viem viem
npx hardhat --init
```

Pick the `TypeScript (Viem + Node test runner)` preset.

## `hardhat.config.ts` (Hardhat 3)

```ts
import type { HardhatUserConfig } from 'hardhat/config'
import HardhatToolboxViem from '@nomicfoundation/hardhat-toolbox-viem'

const config: HardhatUserConfig = {
  plugins: [HardhatToolboxViem],
  solidity: {
    version: '0.8.30',
    settings: {
      optimizer: { enabled: true, runs: 10_000 },
      evmVersion: 'cancun',
    },
  },
  networks: {
    hardhatMainnet: {
      type: 'edr',
      chainType: 'l1',
      forking: {
        url: process.env.MAINNET_RPC_URL!,
        blockNumber: 19_000_000n,
      },
    },
    sepolia: {
      type: 'http',
      url: process.env.SEPOLIA_RPC_URL!,
      accounts: [process.env.DEPLOYER_KEY!],
    },
  },
  verify: {
    etherscan: { apiKey: process.env.ETHERSCAN_API_KEY! },
  },
  test: {
    mocha: { timeout: 60_000 },
  },
}

export default config
```

Hardhat 3 is ESM. Use `.ts` or `.mjs` for configs; CJS is no longer the default.

## Test anatomy (Viem + Node test runner)

```ts
// test/Token.ts
import { describe, it, before } from 'node:test'
import { strict as assert } from 'node:assert'
import { network } from 'hardhat'
import { parseEther } from 'viem'

describe('Token', () => {
  let publicClient: Awaited<ReturnType<typeof network.connect>>['viem']['getPublicClient']
  let walletClients: Awaited<ReturnType<typeof network.connect>>['viem']['getWalletClients']
  let token: any

  before(async () => {
    const { viem } = await network.connect()
    publicClient = viem.getPublicClient
    walletClients = viem.getWalletClients
    token = await viem.deployContract('Token')
  })

  it('mints to the deployer', async () => {
    const pc = await publicClient()
    const [deployer] = await walletClients()
    const balance = await pc.readContract({
      address: token.address,
      abi: token.abi,
      functionName: 'balanceOf',
      args: [deployer.account.address],
    })
    assert.equal(balance, parseEther('1000000'))
  })
})
```

Notes:

- `node:test` replaces mocha in Hardhat 3 defaults; `describe`/`it` come from the Node standard library.
- Viem returns `bigint` for all numerics. Never cast to `Number` -- precision loss and silent bugs.
- `network.connect()` returns a handle; each test file should connect once in `before`.

## Ethers vs viem

| | ethers v6 | viem |
| :--- | :--- | :--- |
| Type safety | Good | Better (ABI type inference) |
| API surface | Large, hooks-first | Small, tree-shakeable |
| Hardhat support | Via `@nomicfoundation/hardhat-toolbox` (legacy) | Native in Hardhat 3 toolbox |
| Large BigNumber migration | Use `bigint` everywhere | Use `bigint` everywhere |

Default to viem for new Hardhat 3 projects. Stay on ethers v6 only if the project already has significant ethers-based TS code.

## Fixtures (replacing `loadFixture`)

Hardhat 3 still supports fixture caching, now through the EDR:

```ts
import { network } from 'hardhat'

async function deployVaultFixture() {
  const { viem } = await network.connect()
  const token = await viem.deployContract('MockERC20', ['Tok', 'TOK'])
  const vault = await viem.deployContract('Vault', [token.address])
  return { token, vault }
}

it('deposits', async () => {
  const { token, vault } = await network.connect().then(
    (n) => n.fixtures.deploy(deployVaultFixture)
  )
  // ...
})
```

Fixtures snapshot EDR state and revert between tests, which is orders of magnitude faster than re-deploying.

## Forking

```ts
// inline fork (per test)
const { viem } = await network.connect({
  network: 'hardhatMainnet',
  override: { forking: { blockNumber: 19_100_000n } },
})
```

Always pin `blockNumber`. See `forking.md`.

## Verification plugin

```bash
npx hardhat verify --network sepolia 0xContract arg1 arg2
```

`@nomicfoundation/hardhat-verify` is included in the toolbox. The old `@nomiclabs/hardhat-etherscan` is deprecated -- do not use it.

## Legacy Hardhat 2 (collapsed)

<details>
<summary>If the project is still on Hardhat 2</summary>

Hardhat 2 remains maintained but new projects should start on 3. Key differences from Hardhat 3 when you must work in 2:

- CJS config (`hardhat.config.js`) and `require('@nomicfoundation/hardhat-toolbox')` still work.
- `loadFixture` from `@nomicfoundation/hardhat-network-helpers` is the canonical fixture runner.
- Mocha is the default test runner, not `node:test`.
- ethers v6 via `hre.ethers`; viem support is via a separate plugin.
- `@nomiclabs/hardhat-etherscan` is replaced by `@nomicfoundation/hardhat-verify`. Migrate before upgrading anything else.

Migrate to Hardhat 3 when the project can tolerate ESM and a test-runner switch.

</details>

## Verification checklist

- [ ] Hardhat 3 + toolbox-viem for new projects
- [ ] Solidity version and EVM pinned to deployment target
- [ ] Forking config has `blockNumber` set
- [ ] No `@nomiclabs/hardhat-etherscan` (migrate to `hardhat-verify`)
- [ ] `bigint` everywhere; no numeric casts
- [ ] Fixtures used for shared setup (EDR snapshot speed)
- [ ] Private keys via env only; never committed
