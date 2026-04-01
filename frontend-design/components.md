# Component Examples -- Next.js v16 App Router

Server Components are the default. Add `'use client'` only when the component uses state, effects, event handlers, or browser APIs. A Server Component can import and render a Client Component.

## Project Structure

```
app/
  layout.tsx          # Root layout (Server Component)
  page.tsx            # Home page (Server Component)
  globals.css
  actions/            # Server Actions
    posts.ts
  (routes)/
    dashboard/
      layout.tsx      # Nested layout
      page.tsx
components/
  ui/                 # Presentational (Server Components by default)
    button.tsx
    card.tsx
  features/           # Feature-scoped
    hero.tsx
```

## Root Layout

```tsx
// app/layout.tsx -- Server Component
import type { Metadata } from 'next'
import { Instrument_Serif, DM_Sans } from 'next/font/google'
import './globals.css'

const displayFont = Instrument_Serif({
  subsets: ['latin'],
  weight: ['400'],
  style: ['normal', 'italic'],
  display: 'swap',
  variable: '--font-display-var',
})

const bodyFont = DM_Sans({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-body-var',
})

export const metadata: Metadata = {
  title: { template: '%s | App Name', default: 'App Name' },
  description: 'App description',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${displayFont.variable} ${bodyFont.variable}`}>
      <body className="antialiased font-body bg-[var(--color-surface)] text-[var(--color-text)]">
        {children}
      </body>
    </html>
  )
}
```

The `variable` prop generates a CSS custom property (e.g. `--font-display-var`) injected via the class on `<html>`. In `globals.css`, alias these to your design tokens:

```css
:root {
  --font-display: var(--font-display-var, Georgia, serif);
  --font-body: var(--font-body-var, system-ui, sans-serif);
}
```

## Server Component Page with Data Fetching

```tsx
// app/dashboard/page.tsx -- Server Component
import { cache } from 'react'
import { StatCard } from '@/components/ui/stat-card'

const getStats = cache(async () => {
  const res = await fetch('https://api.example.com/stats', {
    next: { tags: ['stats'] },
  })
  return res.json()
})

export default async function DashboardPage() {
  const stats = await getStats()
  return (
    <main className="container py-16">
      <h1 className="font-display text-4xl mb-8">Dashboard</h1>
      <div className="grid grid-cols-3 gap-6">
        {stats.map((item: { id: string }) => (
          <StatCard key={item.id} {...item} />
        ))}
      </div>
    </main>
  )
}
```

## Button -- Server Component (default)

Buttons are presentational by default. The consuming component adds `onClick` or wraps in a form with a Server Action. Only add `'use client'` if the button itself manages state (toggles, loading spinners, etc.).

```tsx
// components/ui/button.tsx -- Server Component
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
  size?: 'sm' | 'md' | 'lg'
}

const variants: Record<string, string> = {
  primary: 'bg-[var(--color-primary)] text-[var(--color-primary-fg)] hover:brightness-110',
  secondary: 'bg-[var(--color-surface-elevated)] text-[var(--color-text)] border border-[var(--color-border)]',
  ghost: 'bg-transparent text-[var(--color-text-secondary)] hover:text-[var(--color-text)] hover:bg-[var(--color-surface-elevated)]',
  danger: 'bg-[var(--color-error)] text-white hover:brightness-110',
}

const sizes: Record<string, string> = {
  sm: 'px-3 py-1.5 text-xs gap-1.5',
  md: 'px-5 py-2.5 text-sm gap-2',
  lg: 'px-7 py-3.5 text-base gap-2.5',
}

export function Button({
  variant = 'primary',
  size = 'md',
  className = '',
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={`inline-flex items-center justify-center font-semibold tracking-wide
                  rounded-[var(--radius-lg)]
                  transition-all duration-150 ease-out cursor-pointer
                  focus-visible:outline-2 focus-visible:outline-offset-2
                  disabled:opacity-50 disabled:cursor-not-allowed
                  ${variants[variant]} ${sizes[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  )
}
```

### When to add `'use client'` to Button

```tsx
// components/ui/button-loading.tsx -- Client Component (manages loading state)
'use client'

import { useFormStatus } from 'react-dom'
import { Button } from './button'

export function SubmitButton({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  const { pending } = useFormStatus()
  return (
    <Button type="submit" disabled={pending} {...props}>
      {pending ? 'Submitting...' : children}
    </Button>
  )
}
```

## Card -- Server Component

```tsx
// components/ui/card.tsx -- Server Component
interface CardProps {
  children: React.ReactNode
  elevated?: boolean
  className?: string
}

export function Card({ children, elevated = false, className = '' }: CardProps) {
  return (
    <div
      className={`rounded-[var(--radius-xl)] p-6 border
                  ${elevated
                    ? 'bg-[var(--color-surface-elevated)] shadow-lg border-white/8'
                    : 'bg-[var(--color-surface-subtle)] border-[var(--color-border)]'
                  } ${className}`}
    >
      {children}
    </div>
  )
}
```

### Card with depth (CSS)

```css
.card-depth {
  background: var(--color-surface-elevated);
  border: 1px solid rgb(255 255 255 / 0.08);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-md),
              inset 0 1px 0 rgb(255 255 255 / 0.06);
}
```

### Glassmorphism variant

```css
.glass {
  background: rgb(255 255 255 / 0.08);
  backdrop-filter: blur(16px) saturate(180%);
  border: 1px solid rgb(255 255 255 / 0.12);
}
```

## Hero Section -- Server Component

```tsx
// components/features/hero.tsx -- Server Component
import { Button } from '@/components/ui/button'

export function Hero() {
  return (
    <section className="relative min-h-[80vh] flex items-center overflow-hidden">
      <div className="absolute inset-0 bg-mesh pointer-events-none" aria-hidden="true" />
      <div className="relative container mx-auto px-6 py-24">
        <div className="max-w-3xl">
          <span className="inline-block text-xs font-bold tracking-[0.2em] uppercase
                           text-[var(--color-accent)] mb-6">
            New Release
          </span>
          <h1 className="font-display text-5xl md:text-7xl leading-tight
                         text-[var(--color-text)] mb-6">
            Main Headline <br />
            <span className="text-[var(--color-primary)]">Goes Here</span>
          </h1>
          <p className="text-lg text-[var(--color-text-secondary)] leading-relaxed max-w-xl mb-10">
            Supporting copy that explains the value proposition clearly.
          </p>
          <div className="flex flex-wrap gap-4">
            <Button size="lg">Primary CTA</Button>
            <Button variant="ghost" size="lg">Learn more</Button>
          </div>
        </div>
      </div>
    </section>
  )
}
```

## Server Action with Cache Invalidation

```tsx
// app/actions/posts.ts
'use server'

import { revalidateTag } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createPost(formData: FormData) {
  await db.post.create({
    data: {
      title: formData.get('title') as string,
      content: formData.get('content') as string,
    },
  })
  revalidateTag('posts')
  redirect('/posts')
}
```

## Form using Server Action (Server Component)

```tsx
// app/posts/new/page.tsx -- Server Component
import { createPost } from '@/app/actions/posts'
import { SubmitButton } from '@/components/ui/button-loading'

export default function NewPostPage() {
  return (
    <form action={createPost} className="space-y-6 max-w-lg mx-auto py-16">
      <div>
        <label htmlFor="title" className="block text-sm font-medium mb-2">Title</label>
        <input
          id="title"
          name="title"
          required
          className="w-full px-4 py-2.5 rounded-[var(--radius-md)]
                     bg-[var(--color-surface-elevated)] border border-[var(--color-border)]
                     focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
        />
      </div>
      <div>
        <label htmlFor="content" className="block text-sm font-medium mb-2">Content</label>
        <textarea
          id="content"
          name="content"
          rows={6}
          required
          className="w-full px-4 py-2.5 rounded-[var(--radius-md)]
                     bg-[var(--color-surface-elevated)] border border-[var(--color-border)]
                     focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)]"
        />
      </div>
      <SubmitButton>Create Post</SubmitButton>
    </form>
  )
}
```
