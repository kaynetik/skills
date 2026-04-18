# Writing on-chain transactions

Read when: implementing mint, swap, approve, deposit, withdraw, governance vote, or any state-changing call.

## The four states (always surface all of them)

| State | Source | UI |
| :--- | :--- | :--- |
| Idle | nothing dispatched | enabled action button |
| Pending signature | `useWriteContract().isPending` | "Confirm in wallet..." + disable button |
| Mining | `useWaitForTransactionReceipt().isLoading` | "Submitted, waiting for confirmation" + tx hash link |
| Confirmed / Reverted | `useWaitForTransactionReceipt().isSuccess` / `error` | success state with explorer link OR error toast with `shortMessage` |

Skipping any state produces the "did anything happen?" UX bug that defines bad dApps.

## Canonical write flow

```tsx
'use client'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'
import { NFT_ABI, NFT_ADDRESS } from '@/lib/contracts'
import { useChainId } from 'wagmi'
import { explorerTxUrl } from '@/lib/explorers'

export function MintButton({ tokenId }: { tokenId: bigint }) {
  const chainId = useChainId()
  const { writeContract, data: hash, isPending, error: writeError, reset } = useWriteContract()
  const { isLoading: isMining, isSuccess, error: receiptError } = useWaitForTransactionReceipt({ hash })

  const error = writeError ?? receiptError

  const onClick = () =>
    writeContract({
      address: NFT_ADDRESS[chainId],
      abi: NFT_ABI,
      functionName: 'mint',
      args: [tokenId],
      value: parseEther('0.01'),
    })

  if (isSuccess) {
    return (
      <div>
        <p>Minted.</p>
        <a href={explorerTxUrl(chainId, hash!)} target="_blank" rel="noreferrer">View tx</a>
        <button onClick={reset}>Mint another</button>
      </div>
    )
  }

  return (
    <>
      <button onClick={onClick} disabled={isPending || isMining}>
        {isPending ? 'Confirm in wallet...' : isMining ? 'Minting...' : 'Mint'}
      </button>
      {error && <p role="alert">{error.shortMessage}</p>}
    </>
  )
}
```

Notes:

- `chainId`-aware address lookup via the per-chain table (see `abi.md`).
- `reset()` from `useWriteContract` clears stale state when the user wants to send another.
- One `error` variable -- merge write-time and receipt-time errors so the UI handles both identically.

## Simulate before sending (recommended for non-trivial calls)

`useSimulateContract` runs `eth_call` with the user's account, returning the request ready to feed into `writeContract`. This catches reverts before asking the wallet to sign.

```tsx
'use client'
import { useSimulateContract, useWriteContract } from 'wagmi'

const { data: simulation, error: simError } = useSimulateContract({
  address: VAULT,
  abi: VAULT_ABI,
  functionName: 'deposit',
  args: [amount],
})

const { writeContract, isPending } = useWriteContract()

return (
  <button
    disabled={!simulation || isPending}
    onClick={() => writeContract(simulation!.request)}
  >
    Deposit
  </button>
)
```

Use simulation for: unbounded user input, slippage-sensitive ops, anything where revert is likely. Skip it for trivial calls (a fixed-cost mint, a known-good approval).

## Error parsing

wagmi/viem throw typed errors. Always show `shortMessage`. For granular handling, switch on the error class.

```ts
import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
} from 'viem'

function parseTxError(e: unknown): string {
  if (!(e instanceof BaseError)) return 'Unknown error'
  if (e.walk((x) => x instanceof UserRejectedRequestError)) return 'Cancelled in wallet'
  const reverted = e.walk((x) => x instanceof ContractFunctionRevertedError) as ContractFunctionRevertedError | undefined
  if (reverted) return reverted.data?.errorName ?? reverted.shortMessage
  return e.shortMessage
}
```

| Error type | UX |
| :--- | :--- |
| `UserRejectedRequestError` | Toast "Cancelled" -- not an error state |
| `ContractFunctionRevertedError` with named error | Show the custom error name; map known names to friendly messages |
| `InsufficientFundsError` | "Not enough ETH for gas + value" |
| `ChainMismatchError` | Trigger network switch (see `wallet-ux.md`) |
| Generic `BaseError` | Show `shortMessage`; offer "copy details" |

## Gas estimation

Wagmi auto-estimates gas. You only need to override when:

- The contract self-destructs / forwards calls and estimation undershoots.
- You want to warn users when gas is unusually high.

```tsx
import { useEstimateGas } from 'wagmi'

const { data: gas } = useEstimateGas({
  to: VAULT,
  data: encodedCall,
  value: 0n,
})

const showWarning = gas && gas > 500_000n
```

Never hardcode a `gas` argument unless you have a measured ceiling. Hard limits cause silent reverts on contract upgrades.

## Sending native value

```ts
writeContract({
  address: CONTRACT,
  abi: ABI,
  functionName: 'deposit',
  args: [],
  value: parseEther('0.5'),
})
```

For approval-then-action flows (ERC-20 deposit), gate the action button on the allowance read. Show a two-step UI: "Approve" -> "Deposit".

## Permit2 / EIP-2612 (skip the approval round-trip)

If the token supports EIP-2612, sign a permit and submit a single tx. If your protocol supports Uniswap's Permit2, prefer that for a unified UX across tokens. Pattern:

1. Read `nonces(account)` and `DOMAIN_SEPARATOR` (or use `viem`'s `signTypedData`).
2. `useSignTypedData` to produce `v, r, s`.
3. Pass the permit signature into the same tx that consumes the allowance.

This eliminates the worst Web3 UX failure: "approve, wait, then sign again."

## Account Abstraction (ERC-4337)

If the user's wallet is a smart account (e.g. Safe, Coinbase Smart Wallet), batch operations into a single UserOperation:

| Need | Tool |
| :--- | :--- |
| Detect smart account | `useAccount().connector` capability flags; or check `bytecode` at the address |
| Submit batched calls | Use the wallet's `wallet_sendCalls` (EIP-5792) when supported |
| Sponsored gas | Wallet handles paymaster; you submit the calls and the wallet decides |

`viem` ships an `experimental_sendCalls` helper for EIP-5792. wagmi has `useSendCalls`. Detect support with `useCapabilities`.

```tsx
import { useCapabilities, useSendCalls } from 'wagmi'

const { data: caps } = useCapabilities()
const supports = caps?.[chainId]?.atomicBatch?.supported

const { sendCalls } = useSendCalls()
sendCalls({
  calls: [
    { to: TOKEN, data: encodeApprove(...) },
    { to: VAULT, data: encodeDeposit(...) },
  ],
})
```

Fall back to two sequential `writeContract` calls when not supported.

## Post-confirmation: invalidate, do not refetch globally

```ts
import { useQueryClient } from '@tanstack/react-query'

const qc = useQueryClient()

useEffect(() => {
  if (isSuccess) {
    qc.invalidateQueries({ queryKey: ['readContract', { address: VAULT }] })
    qc.invalidateQueries({ queryKey: ['readContract', { functionName: 'balanceOf' }] })
  }
}, [isSuccess, qc])
```

Wagmi's read query keys follow a predictable structure -- target the affected reads, not everything.

## Explorer URL helper

```ts
// lib/explorers.ts
const EXPLORERS: Record<number, string> = {
  1: 'https://etherscan.io',
  8453: 'https://basescan.org',
  42161: 'https://arbiscan.io',
  10: 'https://optimistic.etherscan.io',
}

export const explorerTxUrl = (chainId: number, hash: `0x${string}`) =>
  `${EXPLORERS[chainId] ?? EXPLORERS[1]}/tx/${hash}`
```

Hardcoding `etherscan.io/tx/${hash}` is the most common multi-chain bug.

## Verification checklist

- [ ] All four states (idle, pending, mining, confirmed/reverted) have distinct UI
- [ ] `error.shortMessage` shown on failure; never raw strings or revert bytes
- [ ] Explorer URL scoped to active `chainId`
- [ ] Affected read queries invalidated post-confirmation
- [ ] Address lookup is `chainId`-aware
- [ ] User rejection treated as a no-op, not an error
- [ ] Heavy operations gated behind `useSimulateContract`
