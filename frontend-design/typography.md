# Typography

## Font Pairing Principles

- **Display font**: distinctive, characterful, creates personality
- **Body font**: highly legible, comfortable for long reads
- Never use Inter/Roboto/Arial as the display font -- reserve neutrals for body only when deliberately paired

## Curated Pairings (Google Fonts)

### Editorial / Literary
- Display: `Instrument Serif` -- elegant, slight italic personality
- Body: `DM Sans` -- clean, approachable

### Modern Bold
- Display: `Syne` -- geometric, strong
- Body: `Outfit` -- friendly, readable

### Luxury / Refined
- Display: `Cormorant Garamond` -- high-contrast serif, fashion-forward
- Body: `Jost` -- geometric sans, clean

### Brutalist / Raw
- Display: `Space Mono` -- monospace, industrial
- Body: `IBM Plex Sans` -- technical, honest

### Playful / Product
- Display: `Fraunces` -- optical-size quirky serif
- Body: `Plus Jakarta Sans` -- friendly, modern

### Technical / Developer
- Display: `JetBrains Mono` -- monospace, credible
- Body: `Inter` -- neutral, readable (acceptable as body when paired with a characterful display font)

## Loading Fonts (Next.js v16)

Use `next/font/google` -- it self-hosts the font at build time, eliminates layout shift, and adds zero runtime JS.

The `variable` prop generates a CSS custom property. Use a `-var` suffix for the generated variable, then alias it to your design token in `globals.css`. This provides a fallback stack when fonts fail to load.

```tsx
// app/layout.tsx
import { Instrument_Serif, DM_Sans } from 'next/font/google'

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

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${displayFont.variable} ${bodyFont.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

## CSS Setup

```css
/* globals.css */
:root {
  --font-display: var(--font-display-var, Georgia, serif);
  --font-body: var(--font-body-var, system-ui, sans-serif);
  --font-mono: 'JetBrains Mono', 'Cascadia Code', monospace;

  /* Type scale (perfect-fourth: 1.333) */
  --text-xs:   0.75rem;   /* 12px -- labels, captions only */
  --text-sm:   0.875rem;  /* 14px */
  --text-base: 1rem;      /* 16px */
  --text-lg:   1.333rem;  /* ~21px */
  --text-xl:   1.777rem;  /* ~28px */
  --text-2xl:  2.369rem;  /* ~38px */
  --text-3xl:  3.157rem;  /* ~51px */
  --text-4xl:  4.209rem;  /* ~67px */
}

body {
  font-family: var(--font-body);
  font-size: var(--text-base);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
}

h1, h2, h3, h4 {
  font-family: var(--font-display);
  line-height: 1.15;
  letter-spacing: -0.02em;
}

code, pre, kbd {
  font-family: var(--font-mono);
  font-size: 0.9em;
}
```

### Why the `-var` indirection?

`next/font` injects the generated variable (e.g. `--font-display-var`) via a class on `<html>`. In `globals.css`, we alias it to `--font-display` with a fallback. This ensures:

1. Design tokens reference a stable name (`--font-display`) throughout all CSS and components
2. A readable fallback stack (`Georgia, serif`) renders while fonts load or if they fail
3. Swapping font pairings requires changing only the layout file, not every component

## Responsive Typography

Use `clamp()` for fluid type that scales smoothly between breakpoints:

```css
h1 { font-size: clamp(2.5rem, 6vw, 4.5rem); }
h2 { font-size: clamp(1.75rem, 4vw, 3rem); }
h3 { font-size: clamp(1.25rem, 3vw, 2rem); }
p  { font-size: clamp(1rem, 1.5vw, 1.125rem); }
```

## Tailwind v4 Font Utilities

When using Tailwind CSS v4, map your font tokens in `globals.css`:

```css
@theme {
  --font-display: var(--font-display-var, Georgia, serif);
  --font-body: var(--font-body-var, system-ui, sans-serif);
  --font-mono: 'JetBrains Mono', 'Cascadia Code', monospace;
}
```

Then use `font-display`, `font-body`, `font-mono` as Tailwind utilities.
