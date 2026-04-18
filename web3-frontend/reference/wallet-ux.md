# Wallet UX patterns

Read when: building the connect button, identity displays, network switching, or any flow gated by wallet state.

## Identity display (ENS + fallback)

```tsx
'use client'
import { useEnsAvatar, useEnsName } from 'wagmi'
import { normalize } from 'viem/ens'

export function WalletIdentity({ address }: { address: `0x${string}` }) {
  const { data: name } = useEnsName({ address, chainId: 1 })
  const { data: avatar } = useEnsAvatar({
    name: name ? normalize(name) : undefined,
    chainId: 1,
  })

  const display = name ?? `${address.slice(0, 6)}...${address.slice(-4)}`

  return (
    <span className="inline-flex items-center gap-2">
      {avatar
        ? <img src={avatar} alt="" width={24} height={24} className="rounded-full" />
        : <Blockie address={address} />}
      <span className="font-mono text-sm">{display}</span>
    </span>
  )
}
```

| Rule | Reason |
| :--- | :--- |
| Always resolve ENS on `chainId: 1` | ENS lives on mainnet; resolving on the active chain returns nothing on L2s |
| Always fall back to truncated address | ENS resolution can fail or be slow; never block render |
| Always `normalize()` before passing a name to viem | Avoids ENSIP-15 normalization mismatches |

## Network guard

```tsx
'use client'
import { useChainId, useSwitchChain } from 'wagmi'

export function NetworkGuard({
  required,
  children,
}: {
  required: number
  children: React.ReactNode
}) {
  const chainId = useChainId()
  const { switchChain, isPending } = useSwitchChain()

  if (chainId === required) return <>{children}</>

  return (
    <div role="alert" className="rounded-md border border-amber-500/30 bg-amber-500/10 p-4">
      <p className="text-sm">Please switch to the correct network to continue.</p>
      <button
        onClick={() => switchChain({ chainId: required })}
        disabled={isPending}
        className="mt-2 text-xs underline"
      >
        {isPending ? 'Switching...' : 'Switch network'}
      </button>
    </div>
  )
}
```

Check `chainId` early -- before rendering action buttons -- so the UI never offers an action that would fail at sign time.

## Connect gate

```tsx
'use client'
import { useAccount } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'

export function ConnectGate({ children }: { children: React.ReactNode }) {
  const { isConnected, isConnecting, isReconnecting } = useAccount()

  if (isConnecting || isReconnecting) return <ConnectingSkeleton />

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center gap-4 py-16">
        <p className="text-sm text-neutral-400">Connect your wallet to continue</p>
        <ConnectButton />
      </div>
    )
  }

  return <>{children}</>
}
```

`isReconnecting` is true when wagmi is restoring a previous session from cookies. Treating this as "not connected" creates a flash of disconnected UI on every page load.

## Account-change handling

When the user switches accounts in their wallet, all per-address queries become stale. Wagmi handles refetch automatically when read hooks include the address in `args`. Manual cleanup:

```tsx
'use client'
import { useEffect } from 'react'
import { useAccount, useAccountEffect } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'

const qc = useQueryClient()

useAccountEffect({
  onConnect({ address }) {
    qc.invalidateQueries({ queryKey: ['userPosition'] })
  },
  onDisconnect() {
    qc.removeQueries({ queryKey: ['userPosition'] })
  },
})
```

`useAccountEffect` fires only on actual transitions, not on every render. Use it for any cache invalidation tied to identity.

## Disconnected-state design

The page must look intentional, not broken, when no wallet is connected:

| Bad | Good |
| :--- | :--- |
| Empty data tables with skeleton placeholders | Empty state with a CTA: "Connect your wallet to view your positions" |
| Disabled buttons with no explanation | Replace action area with a Connect button |
| Showing `0.00` everywhere | Show `--` or hide value rows entirely |

## Wallet capability detection

Use `useCapabilities` (wagmi v2) to learn what the connected wallet supports before offering a feature:

```ts
const { data: caps } = useCapabilities()
const canBatch = caps?.[chainId]?.atomicBatch?.supported
const canSponsor = caps?.[chainId]?.paymasterService?.supported
```

Capability gating is critical for ERC-4337 / EIP-5792 flows. Never assume.

## RainbowKit theme + chain config

```tsx
import { lightTheme, darkTheme, RainbowKitProvider } from '@rainbow-me/rainbowkit'

<RainbowKitProvider
  theme={{
    lightMode: lightTheme({ accentColor: 'var(--accent)' }),
    darkMode: darkTheme({ accentColor: 'var(--accent)' }),
  }}
  modalSize="compact"
  initialChain={base}
>
  {children}
</RainbowKitProvider>
```

| Setting | Why |
| :--- | :--- |
| `modalSize="compact"` | Better mobile UX; full size only useful on desktop landing pages |
| `initialChain` | Forces a default chain on first connect; otherwise users land on whatever chain MetaMask was last on |
| Theme via CSS vars | Lets your design tokens drive RainbowKit colors -- see `frontend-design` skill |

## Verification checklist

- [ ] Identity always shows ENS or truncated address; never raw `0x...` long form
- [ ] ENS resolved on `chainId: 1`
- [ ] Network guard renders before action buttons
- [ ] `isReconnecting` treated as connected (no flash)
- [ ] Disconnected state has intentional empty UI
- [ ] Capability detection before offering AA / batch features
