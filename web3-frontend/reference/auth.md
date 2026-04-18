# SIWE auth and sessions

Read when: building a session-bearing dApp, gating server endpoints by wallet identity, or syncing on-chain identity with off-chain data (profile, notifications, indexer cursors).

## What SIWE solves

Sign-In with Ethereum (EIP-4361) proves the user controls a wallet address by signing a structured message. The signed message becomes the credential for an HTTP session. Without SIWE, your backend has no way to verify the address claimed by a request actually belongs to the caller.

## When you need it

| Need | SIWE? |
| :--- | :--- |
| Read-only dApp (no off-chain user data) | No |
| Personalized off-chain data (notifications, profile) | Yes |
| Webhooks back to the user's account | Yes |
| Server-side rate-limiting per address | Yes |
| Indexer queries scoped to caller | Yes |

## Stack choice

| Library | When |
| :--- | :--- |
| `siwe` (raw) + custom session cookie | Maximum control, smaller deps |
| `next-auth` + `@auth/siwe` (or community SIWE provider) | Already using NextAuth for OAuth -- add wallet as another provider |
| RainbowKit's SIWE adapter (`@rainbow-me/rainbowkit-siwe-next-auth`) | Want UI integration; auto-prompts on connect |

Pick one and stay with it. Mixing creates two sources of truth.

## SIWE message: required fields

```text
example.com wants you to sign in with your Ethereum account:
0x...

Sign in to Example.

URI: https://example.com
Version: 1
Chain ID: 1
Nonce: <server-issued, single-use>
Issued At: 2026-01-01T00:00:00Z
Expiration Time: 2026-01-01T00:10:00Z
```

| Field | Why |
| :--- | :--- |
| `Nonce` | Server-issued, single-use, stored short-term. Prevents replay attacks |
| `Domain` (first line) | Pinned to your origin; signed message is invalid on other domains |
| `Chain ID` | Address-only auth without chain ID is ambiguous on smart accounts |
| `Issued At` / `Expiration Time` | Bounded session window; reject expired signatures |
| `Statement` | Human-readable purpose; shown by wallets like MetaMask |

Never reuse a nonce. Never accept a signed message older than ~10 minutes.

## Flow

```
client                              server
  |                                    |
  | GET /api/siwe/nonce -------------->|  generate, store in cookie or KV
  |<--------------------- 200 nonce ---|
  |                                    |
  | useSignMessage(siweMsg(nonce))     |
  |                                    |
  | POST /api/siwe/verify              |
  |   { message, signature } -------->| verify with viem.verifyMessage
  |                                    | OR for smart accounts: verifyMessage with public client
  |                                    | issue signed session cookie
  |<------------------- 200 OK + cookie|
  |                                    |
  | GET /api/me  --------------------->| read cookie, return profile
```

## Verification (server side)

Use viem for both EOA and smart-account (EIP-1271) verification:

```ts
// app/api/siwe/verify/route.ts
import { SiweMessage } from 'siwe'
import { publicClients } from '@/lib/viem'
import { mainnet } from 'viem/chains'
import { sealCookie } from '@/lib/session'

export async function POST(req: Request) {
  const { message, signature } = await req.json()
  const siwe = new SiweMessage(message)

  const fields = await siwe.verify(
    { signature, nonce: getNonceFromCookie() },
    { provider: publicClients[mainnet.id] }
  )

  if (!fields.success) return new Response('Invalid signature', { status: 401 })

  const cookie = await sealCookie({
    address: siwe.address as `0x${string}`,
    chainId: siwe.chainId,
    expiresAt: Date.parse(siwe.expirationTime!),
  })

  return new Response('OK', { headers: { 'Set-Cookie': cookie } })
}
```

The `provider` argument tells siwe to fall through to EIP-1271 if the address has bytecode (smart account). Without it, smart-account signatures fail verification.

## Session cookie

Use sealed/encrypted cookies, not plain JWTs in client-readable storage.

| Property | Value |
| :--- | :--- |
| `httpOnly` | true |
| `secure` | true (production) |
| `sameSite` | `lax` (CSRF guard) |
| `maxAge` | match `Expiration Time` from SIWE message |
| Encryption | AEAD (e.g. `iron-session`, `jose` JWE, or `cookie-signature` if signing only) |

`iron-session` is the path of least resistance.

## Client side

```tsx
'use client'
import { useAccount, useSignMessage } from 'wagmi'
import { SiweMessage } from 'siwe'

export function SignInButton() {
  const { address, chainId } = useAccount()
  const { signMessageAsync } = useSignMessage()

  const onClick = async () => {
    if (!address || !chainId) return

    const nonce = await fetch('/api/siwe/nonce').then((r) => r.text())

    const message = new SiweMessage({
      domain: window.location.host,
      address,
      statement: 'Sign in to Example',
      uri: window.location.origin,
      version: '1',
      chainId,
      nonce,
      issuedAt: new Date().toISOString(),
      expirationTime: new Date(Date.now() + 10 * 60_000).toISOString(),
    }).prepareMessage()

    const signature = await signMessageAsync({ message })

    await fetch('/api/siwe/verify', {
      method: 'POST',
      body: JSON.stringify({ message, signature }),
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return <button onClick={onClick}>Sign in</button>
}
```

## Account / chain change handling

When the user switches accounts or chains, invalidate the session.

```tsx
import { useAccountEffect } from 'wagmi'

useAccountEffect({
  onConnect({ address }) {
    if (sessionAddress && sessionAddress !== address) {
      fetch('/api/siwe/logout', { method: 'POST' })
    }
  },
  onDisconnect() {
    fetch('/api/siwe/logout', { method: 'POST' })
  },
})
```

## Reading the session in RSC

```ts
// lib/session.ts
import { cookies } from 'next/headers'

export async function getSession() {
  const c = await cookies()
  const sealed = c.get('siwe-session')?.value
  if (!sealed) return null
  return await unsealCookie(sealed)
}
```

```tsx
// app/profile/page.tsx
import { getSession } from '@/lib/session'
import { redirect } from 'next/navigation'

export default async function Profile() {
  const session = await getSession()
  if (!session) redirect('/')
  return <ProfileView address={session.address} />
}
```

## Verification checklist

- [ ] Nonce is server-issued, single-use, short-lived
- [ ] Verification uses viem with `provider` to support EIP-1271 smart accounts
- [ ] Session cookie is `httpOnly`, `secure`, `sameSite=lax`, encrypted
- [ ] Session expires no later than the signed `Expiration Time`
- [ ] Account / chain change clears the session
- [ ] No address claim is trusted server-side without signature verification
