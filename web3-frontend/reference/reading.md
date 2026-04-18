# Reading on-chain data

Read when: implementing balance displays, token info panels, contract dashboards, or any view that materializes blockchain state into UI.

## Decision tree

| Need | Use | Why |
| :--- | :--- | :--- |
| Single value tied to the connected wallet | `useReadContract` (client) | Reactive to chain/account changes |
| Multiple reads from one or many contracts | `useReadContracts` (client) | Multicall3-batched, single round trip |
| Public data, no wallet, cacheable across users | viem `publicClient.readContract` in RSC | SSR-friendly, can be wrapped in `'use cache'` |
| Live event stream | `useWatchContractEvent` (client) | Subscribes via the active transport |
| Historical events / cross-block queries | The Graph / Ponder / Envio | Do not scan logs from the browser |

## Single read (client)

```tsx
'use client'
import { useReadContract } from 'wagmi'
import { erc20Abi, formatUnits } from 'viem'
import { useAccount } from 'wagmi'

export function TokenBalance({ token }: { token: `0x${string}` }) {
  const { address } = useAccount()

  const { data, isPending, error } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  if (!address) return <span>--</span>
  if (isPending) return <span>...</span>
  if (error) return <span title={error.shortMessage}>err</span>
  return <span>{formatUnits(data ?? 0n, 18)}</span>
}
```

Critical bits:

- `query.enabled` gate stops wagmi from firing the read with `undefined` args.
- Use `isPending` not `isLoading`. `isPending` covers the no-data state correctly across refetches.
- `formatUnits` from viem; never hand-roll decimal math.

## Batched reads (multicall)

`useReadContracts` aggregates multiple calls into a single Multicall3 transaction when supported. Always prefer it over multiple `useReadContract` hooks.

```tsx
'use client'
import { useAccount, useReadContracts } from 'wagmi'
import { erc20Abi, formatUnits } from 'viem'

const TOKEN = '0x...' as const

export function TokenInfo() {
  const { address } = useAccount()

  const { data } = useReadContracts({
    allowFailure: true,
    contracts: [
      { address: TOKEN, abi: erc20Abi, functionName: 'name' },
      { address: TOKEN, abi: erc20Abi, functionName: 'symbol' },
      { address: TOKEN, abi: erc20Abi, functionName: 'decimals' },
      {
        address: TOKEN,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
      },
    ],
    query: { enabled: !!address },
  })

  const [name, symbol, decimals, balance] = data ?? []

  return (
    <div>
      <p>{name?.result} ({symbol?.result})</p>
      <p>{formatUnits(balance?.result ?? 0n, Number(decimals?.result ?? 18))}</p>
    </div>
  )
}
```

`allowFailure: true` keeps the rest of the batch alive when one call reverts. Each entry's `result` is undefined and `error` is populated for the failing call.

## Server-side reads (RSC, no wallet)

Use this for public, address-agnostic data: protocol TVL, total supply, oracle price, vault parameters.

```tsx
// app/pool/[id]/page.tsx
import { publicClients } from '@/lib/viem'
import { mainnet } from 'viem/chains'
import { POOL_ABI } from '@/lib/contracts/abis'
import { PoolDashboard } from './pool-dashboard'

export default async function PoolPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const client = publicClients[mainnet.id]

  const [reserves, fee] = await client.multicall({
    contracts: [
      { address: id as `0x${string}`, abi: POOL_ABI, functionName: 'getReserves' },
      { address: id as `0x${string}`, abi: POOL_ABI, functionName: 'fee' },
    ],
  })

  return <PoolDashboard initialReserves={reserves.result} initialFee={fee.result} />
}
```

The result is serialized JSON between server and client. `bigint` does not survive `JSON.stringify` -- convert to string at the boundary, then back to `bigint` in the Client Component, or use `superjson`.

```ts
const safe = (b: bigint | undefined) => (b == null ? null : b.toString())
```

## Cacheable server reads (Next.js 16)

Wrap RSC fetches in `'use cache'` for cross-request reuse. See `ssr-caching.md` for the full pattern.

```ts
// lib/queries/pool.ts
'use cache'
import { cacheLife, cacheTag } from 'next/cache'
import { publicClients } from '@/lib/viem'

export async function getPoolReserves(pool: `0x${string}`) {
  cacheLife({ revalidate: 30, expire: 300 })
  cacheTag(`pool:${pool}`)
  return publicClients[1].readContract({
    address: pool,
    abi: POOL_ABI,
    functionName: 'getReserves',
  })
}
```

## Event watching (live updates)

```tsx
'use client'
import { useWatchContractEvent } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'

useWatchContractEvent({
  address: VAULT,
  abi: VAULT_ABI,
  eventName: 'Deposit',
  onLogs: (logs) => {
    queryClient.invalidateQueries({ queryKey: ['readContract', { address: VAULT }] })
  },
  poll: false,
})
```

Default polls every 4s on HTTP transports. Set `poll: false` only when using a `webSocket()` transport, otherwise events are silently missed.

## Historical reads (do not scan from the browser)

Browsers should not scan blockchain logs. Reasons:

| Problem | Consequence |
| :--- | :--- |
| RPC providers cap `eth_getLogs` block ranges | Random failures past the cap |
| Long ranges = many round trips | Wallet UX freezes |
| Public RPC keys leak through bundles | Rate-limit abuse, costs |

Use The Graph subgraphs, Ponder, Envio, or your own indexer. Query them via TanStack Query as you would any REST endpoint.

## Caching guidance (TanStack Query + wagmi)

| Scenario | `staleTime` | `gcTime` | Notes |
| :--- | :--- | :--- | :--- |
| Token metadata (name/symbol/decimals) | `Infinity` | 30 min | Immutable per address |
| Wallet balance | 10-30s | 5 min | Refresh on relevant tx confirmation |
| Pool reserves / oracle price | 5-15s | 2 min | Or stream via event watcher |
| User position (debt, collateral) | 15-60s | 5 min | Refresh after own tx |

Override per-hook through `query.staleTime` etc. Do not set them globally when you have heterogeneous read shapes.

## Performance checklist

- [ ] Token metadata cached with `staleTime: Infinity`
- [ ] Multiple reads collapsed into `useReadContracts`
- [ ] `query.enabled` guards prevent calls with undefined args
- [ ] `batch: true` enabled on the wagmi/viem `http` transport (see `setup.md`)
- [ ] No `eth_getLogs` from the browser
- [ ] After a tx confirms, related queries are invalidated by `queryKey`, not refetched globally
