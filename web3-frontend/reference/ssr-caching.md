# SSR + caching in Next.js 16

Read when: prefetching on-chain data on the server, eliminating hydration flicker, or wiring Next.js cache directives around viem reads.

> [!IMPORTANT]
> Verify cache directive syntax against current Next.js docs via Context7. Cache directives evolved rapidly; treat any pre-2026 example as suspect.

## Three layers of caching

| Layer | Scope | Lifetime | Use for |
| :--- | :--- | :--- | :--- |
| Wagmi SSR cookies | Per-request | Cookie lifetime | Wallet connection state surviving page navigations |
| TanStack Query | Per browser tab | `gcTime` | Read hooks; write invalidations |
| Next.js `'use cache'` | Cross-request, cross-user | `cacheLife` | Public on-chain data |

Use all three. They do not overlap.

## Wagmi SSR hydration boundary

Already covered in `setup.md`. Recap of the contract:

1. `getWagmiConfig()` returns a fresh config per request.
2. `cookieToInitialState(config, cookieHeader)` runs in the root `layout.tsx`.
3. `<Providers initialState={...}>` passes it to `<WagmiProvider>`.

If you skip step 2, the client renders briefly as "disconnected" then snaps to "connected", and any address-bound read fires twice with different inputs. This causes:

- Two API calls per balance read on every page load.
- Layout shift on connect-aware UI.
- React hydration mismatch warnings in dev.

## Next.js 16 `'use cache'` for on-chain reads

Cache directives let you reuse on-chain reads across requests and users. Public, non-personal data (oracle prices, pool reserves, governance proposal lists) is the perfect target.

```ts
// lib/queries/proposals.ts
'use cache'
import { cacheLife, cacheTag } from 'next/cache'
import { publicClients } from '@/lib/viem'
import { GOV_ABI, GOV_ADDRESS } from '@/lib/contracts'
import { mainnet } from 'viem/chains'

export async function getActiveProposals() {
  cacheLife({ revalidate: 60, expire: 600 })
  cacheTag('governance', 'proposals')

  return publicClients[mainnet.id].readContract({
    address: GOV_ADDRESS[mainnet.id],
    abi: GOV_ABI,
    functionName: 'getActiveProposals',
  })
}
```

| Directive | Semantics |
| :--- | :--- |
| `'use cache'` (file or function) | Marks output cacheable across requests |
| `cacheLife({ revalidate, expire })` | `revalidate`: SWR boundary in seconds; `expire`: hard eviction |
| `cacheTag('...')` | Targets for `revalidateTag()` calls in route handlers / Server Actions |

Trigger invalidation from a webhook (e.g. an indexer post-block hook):

```ts
// app/api/webhook/governance/route.ts
import { revalidateTag } from 'next/cache'

export async function POST() {
  revalidateTag('proposals')
  return Response.json({ ok: true })
}
```

## What NOT to cache with `'use cache'`

| Data | Why not |
| :--- | :--- |
| Anything keyed on the connected wallet | Per-user; would leak balances across sessions |
| Anything signed or session-bearing | Personal |
| Real-time prices in a trading UI | Cache lifetime would cause stale price quotes -> bad fills |
| Pre-tx simulation results | User-specific and time-sensitive |

Per-user reads belong in TanStack Query on the client, not the Next.js cache.

## Server prefetch -> client hydration

Pattern: RSC fetches initial data via viem and seeds the client TanStack Query cache so the first paint has data without a wallet round trip.

```tsx
// app/dashboard/page.tsx
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'
import { publicClients } from '@/lib/viem'
import { POOL_ABI, POOL_ADDRESS } from '@/lib/contracts'
import { Dashboard } from './dashboard'

export default async function Page() {
  const qc = new QueryClient()

  await qc.prefetchQuery({
    queryKey: ['pool', POOL_ADDRESS, 'reserves'],
    queryFn: () =>
      publicClients[1].readContract({
        address: POOL_ADDRESS,
        abi: POOL_ABI,
        functionName: 'getReserves',
      }),
  })

  return (
    <HydrationBoundary state={dehydrate(qc)}>
      <Dashboard />
    </HydrationBoundary>
  )
}
```

```tsx
// app/dashboard/dashboard.tsx
'use client'
import { useQuery } from '@tanstack/react-query'

export function Dashboard() {
  const { data } = useQuery({
    queryKey: ['pool', POOL_ADDRESS, 'reserves'],
    queryFn: () => readReservesViaWagmi(),
  })

  return <ReservesView data={data} />
}
```

Hydration boundary requirements:

- The `queryKey` must be identical on both sides; treat them as a stable contract.
- `bigint` does not serialize through the boundary by default. Either convert to string in the prefetch and parse in the client, or install `superjson` and configure the QueryClient with it.
- Use this pattern for page-load data, not for streaming live updates.

## Streaming with Suspense

For independent data slices, render incrementally:

```tsx
import { Suspense } from 'react'

export default function Page() {
  return (
    <>
      <Header />
      <Suspense fallback={<TVLSkeleton />}>
        <TVL />
      </Suspense>
      <Suspense fallback={<RecentDepositsSkeleton />}>
        <RecentDeposits />
      </Suspense>
    </>
  )
}
```

Each `<TVL />` and `<RecentDeposits />` is an async RSC reading via viem. The user sees the shell immediately and each slice fills in as its on-chain read resolves.

## bigint serialization

The single most common boundary bug. Three options:

| Strategy | When |
| :--- | :--- |
| Convert at the boundary (string in/out) | One-off, low effort |
| `superjson` in the HydrationBoundary | Multiple bigints, want transparency |
| Store as decimal string in a domain type | Best for large apps; never let raw bigints cross network boundaries |

```ts
const safeBigint = {
  serialize: (v: bigint) => v.toString(),
  parse: (s: string) => BigInt(s),
}
```

## Verification checklist

- [ ] `cookieToInitialState` is called in root layout
- [ ] No `useAccount`, `useChainId`, or wagmi reads inside RSC
- [ ] Public on-chain reads wrapped in `'use cache'` with `cacheLife` + `cacheTag`
- [ ] Per-user reads stay in TanStack Query, never in `'use cache'`
- [ ] Server prefetches use the same `queryKey` as the client `useQuery`
- [ ] `bigint` boundary handled (string conversion or `superjson`)
- [ ] `revalidateTag` triggered by indexer webhooks for cached on-chain data
