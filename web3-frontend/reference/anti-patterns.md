# Anti-patterns

Read when: reviewing dApp code, debugging hydration errors, chasing infinite RPC requests, or auditing UX flows.

Each entry is a real failure mode seen in production. Format: symptom -> cause -> fix.

## Hydration mismatch on wallet state

**Symptom**: React warns about hydration mismatch; wallet appears disconnected for ~200ms then snaps to connected; reads fire twice on every page load.

**Cause**: wagmi config uses `localStorage` (default) which the server cannot read. Server renders disconnected; client hydrates from `localStorage` with a different state.

**Fix**: `cookieStorage` + `cookieToInitialState` round-trip. See `setup.md` and `ssr-caching.md`.

## Reading `useAccount` in a Server Component

**Symptom**: Build fails or runtime error about wagmi not being available; or it silently always returns disconnected.

**Cause**: wagmi hooks are React hooks -- they require a client runtime and the wagmi context.

**Fix**: Add `'use client'` to the file, or move the wallet-aware logic into a child Client Component and have the RSC pass it props.

## Importing a wallet connector at module scope in shared code

**Symptom**: Server build pulls browser-only globals (`window`, `localStorage`); fails on `next build`.

**Cause**: A connector or wagmi hook imported at the top of a file used by both RSC and CC.

**Fix**: Wallet primitives only inside files marked `'use client'`. Use viem's `createPublicClient` (no wallet) for server-side reads.

## Using `etherscan.io` URLs on multi-chain apps

**Symptom**: Confirmed transactions on Base or Arbitrum link to a 404 or the wrong network.

**Cause**: Hardcoded explorer URL.

**Fix**: `chainId`-keyed explorer table. See `writing.md#explorer-url-helper`.

## Resolving ENS on the active chain

**Symptom**: `useEnsName` returns `null` for users on Base/Arbitrum/etc.

**Cause**: ENS lives on Ethereum mainnet. Resolving on L2 chains returns nothing.

**Fix**: Pass `chainId: 1` to `useEnsName` and `useEnsAvatar`. Always.

## Displaying raw revert messages

**Symptom**: User sees `execution reverted: 0x4e487b71...` or `Error: rejected by user`.

**Cause**: Raw error from `error.message` or RPC string surfaced to UI.

**Fix**: Use `error.shortMessage` (wagmi/viem typed errors). For better UX, walk the error chain with viem's `BaseError.walk()` to identify `UserRejectedRequestError`, `ContractFunctionRevertedError`, etc. See `writing.md#error-parsing`.

## `eth_getLogs` from the browser

**Symptom**: Random failures past N blocks; rate-limit errors; UI freezes during history load.

**Cause**: Trying to scan event history with the wallet's provider or a public RPC.

**Fix**: Use a subgraph (The Graph), Ponder, or Envio. Query via TanStack Query. Never scan from the browser.

## Multiple `useReadContract` hooks instead of `useReadContracts`

**Symptom**: 5+ `eth_call` requests on every render of one component.

**Cause**: Each hook is a separate query. Multicall not used.

**Fix**: Combine into one `useReadContracts` call with `allowFailure: true`. Single Multicall3 round trip.

## Unbounded React effects firing reads

**Symptom**: RPC quota exhausted; thousands of identical `eth_call` requests in DevTools.

**Cause**: A `useEffect` that calls a viem function or invalidates queries on every render, often missing a dependency or depending on a non-stable reference.

**Fix**:

- Use wagmi hooks (which are deduped via TanStack Query) instead of raw viem in effects.
- For watchers, prefer `useWatchContractEvent` which manages subscription lifecycle.
- If you must use an effect, audit the dependency array; wrap callbacks in `useCallback` and reference values via refs.

## Hardcoding `gas` argument

**Symptom**: Transactions silently revert after a contract upgrade.

**Cause**: A static `gas: 100_000n` worked at deploy but no longer covers the new logic.

**Fix**: Let wagmi auto-estimate. Override only with a measured ceiling, and add a CI check that re-estimates on contract changes.

## Forgetting `query.enabled`

**Symptom**: First render fires a read with `args: [undefined]` -> RPC error or wrong data cached.

**Cause**: `useReadContract({ ..., args: [address] })` runs even when `address` is undefined.

**Fix**: Add `query: { enabled: !!address }`. Wagmi treats `enabled: false` as "never fire".

## Treating `isReconnecting` as disconnected

**Symptom**: Connect button flashes on every page load for users who were already connected.

**Cause**: `if (!isConnected) return <ConnectGate />` runs while wagmi is restoring the cookie session.

**Fix**: Render a skeleton when `isConnecting || isReconnecting`. Treat both as "in progress, do not branch".

## Optimistic UI without rollback

**Symptom**: After a user-rejected tx, the UI still shows the optimistic state.

**Cause**: Optimistic updates applied immediately on `writeContract` call, never reverted on error.

**Fix**: Apply optimism only after `useWaitForTransactionReceipt().isSuccess`, OR keep the optimistic mutation pattern from TanStack Query (`useMutation` with `onError` rollback).

## Trusting the address claimed by an HTTP request

**Symptom**: Anyone can read another user's data by sending `?address=0x...`.

**Cause**: No SIWE; backend trusts whatever address the client sends.

**Fix**: SIWE login, sealed session cookie, address derived from the session. See `auth.md`.

## Leaking private RPC keys via `NEXT_PUBLIC_*`

**Symptom**: Quota burn through public usage of your paid RPC.

**Cause**: `NEXT_PUBLIC_ALCHEMY_KEY` ships in the JS bundle; anyone can extract it.

**Fix**: Private RPCs in non-prefixed envs, used only on the server. For client-side reads, either use a free public endpoint or proxy through your own server route.

## Caching personal data with `'use cache'`

**Symptom**: User A sees User B's balance; or stale balances after a transfer.

**Cause**: `'use cache'` on a function that reads per-wallet data; cache is shared across all users.

**Fix**: `'use cache'` only on address-agnostic data. Per-user data goes through TanStack Query on the client. See `ssr-caching.md`.

## Mixing two SIWE libraries

**Symptom**: Sessions intermittently invalid; two cookies named differently.

**Cause**: NextAuth SIWE provider AND a custom `siwe` integration both running.

**Fix**: Choose one. See `auth.md#stack-choice`.

## Approving with `MaxUint256` without warning

**Symptom**: Users complain about unbounded approvals; a contract bug drains balances.

**Cause**: Default approval set to `2**256 - 1` for UX reasons.

**Fix**: Default to the exact spend amount + small buffer; offer "approve max" as an explicit opt-in with a clear warning, OR use Permit2 / EIP-2612.

## Using `localhost` as `domain` in SIWE

**Symptom**: Sessions issued on `localhost` validated as `example.com` -- attack vector.

**Cause**: Hardcoded `domain: 'example.com'` instead of `window.location.host`.

**Fix**: Always derive `domain` from the current request origin. Verify it matches an expected origin server-side.

## Forgetting to invalidate after a write

**Symptom**: User mints an NFT, balance does not update; they refresh the page to see it.

**Cause**: Write succeeds but the relevant `useReadContract` keeps the old cached value.

**Fix**: After `useWaitForTransactionReceipt().isSuccess`, `queryClient.invalidateQueries({ queryKey: [...affected reads] })`. See `writing.md#post-confirmation`.

## Verification checklist

- [ ] No wagmi imports outside `'use client'` files
- [ ] All `useReadContract` calls have `query.enabled` guards
- [ ] No raw error strings shown to users
- [ ] Block explorer links scoped to `chainId`
- [ ] No `eth_getLogs` from the browser
- [ ] Cookie-based wagmi storage with SSR initial state
- [ ] No `'use cache'` on per-wallet reads
- [ ] Backend never trusts a client-claimed address without SIWE
- [ ] Approvals default to exact amount, not `MaxUint256`
- [ ] Post-write query invalidation in place
