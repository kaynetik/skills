---
name: frontend-design
description: >-
  Creates distinctive, production-grade frontend interfaces with exceptional
  aesthetic intentionality. Covers design tokens, typography systems, color
  palettes, component design, motion, accessibility, and design system
  architecture. Use when building UI components, pages, or applications;
  auditing existing designs; generating design tokens; choosing fonts, colors,
  or layout strategies; or when the user asks for help with frontend design,
  CSS, UI, UX, design system, visual design, component styling, or making
  something look good.
---

# Frontend Design

Create distinctive, production-grade interfaces with a clear aesthetic point-of-view. **Choose a direction and execute it with precision.** Bold maximalism and refined minimalism both work -- intentionality beats intensity.

## Design Thinking (Before Coding)

Commit to an aesthetic direction by answering:

1. **Purpose**: What problem does this solve? Who uses it?
2. **Tone**: Pick an extreme -- brutally minimal, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial, brutalist/raw, art deco/geometric, industrial/utilitarian, etc.
3. **Differentiator**: What makes this unforgettable?

## Anti-Defaults

**NEVER use:**
- Overused fonts as display fonts: Inter, Roboto, Arial, Space Grotesk (these are acceptable as body text when deliberately paired)
- `system-ui` as the sole font stack without an intentional pairing
- Purple gradients on white backgrounds
- Predictable card-grid Bootstrap-style layouts
- Generic blue CTA buttons with rounded corners on white
- Timid, evenly-distributed color palettes

**ALWAYS:**
- Choose a display font that is unexpected and characterful; pair with a refined body font
- Dominant colors with sharp accents over safe palettes
- Asymmetry, overlap, grid-breaking, or generous negative space
- Atmosphere and depth via gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows

## Design System Architecture

### Token Naming Convention

Tokens use a flat `--{category}-{name}` CSS custom property scheme:

| Category | Pattern | Examples |
|----------|---------|----------|
| Color | `--color-{role}` | `--color-primary`, `--color-accent`, `--color-surface`, `--color-surface-elevated`, `--color-text`, `--color-text-secondary`, `--color-border` |
| Semantic | `--color-{semantic}` | `--color-success`, `--color-warning`, `--color-error` |
| Font | `--font-{role}` | `--font-display`, `--font-body`, `--font-mono` |
| Type scale | `--text-{size}` | `--text-xs`, `--text-sm`, `--text-base`, `--text-lg`, `--text-xl` |
| Spacing | `--space-{n}` | `--space-1` (0.25rem), `--space-2` (0.5rem), `--space-4` (1rem) |
| Radius | `--radius-{size}` | `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-full` |
| Shadow | `--shadow-{level}` | `--shadow-sm`, `--shadow-md`, `--shadow-lg`, `--shadow-dramatic` |
| Motion | `--ease-{name}` | `--ease-out`, `--ease-in-out`, `--ease-spring` |

### Token Reference (8px spacing base)

```css
:root {
  /* Colors -- replace with project palette */
  --color-primary: ;
  --color-primary-fg: ;
  --color-accent: ;
  --color-surface: ;
  --color-surface-elevated: ;
  --color-surface-subtle: ;
  --color-text: ;
  --color-text-secondary: ;
  --color-text-inverse: ;
  --color-border: ;
  --color-success: ;
  --color-warning: ;
  --color-error: ;

  /* Fonts -- set via next/font CSS variables */
  --font-display: var(--font-display-var, Georgia, serif);
  --font-body: var(--font-body-var, system-ui, sans-serif);
  --font-mono: 'JetBrains Mono', 'Cascadia Code', monospace;

  /* Spacing (8px base) */
  --space-1: 0.25rem;  --space-2: 0.5rem;   --space-3: 0.75rem;
  --space-4: 1rem;     --space-6: 1.5rem;    --space-8: 2rem;
  --space-12: 3rem;    --space-16: 4rem;     --space-24: 6rem;

  /* Radius */
  --radius-sm: 0.25rem;  --radius-md: 0.5rem;
  --radius-lg: 1rem;     --radius-xl: 1.5rem;  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 20px 25px -5px rgb(0 0 0 / 0.15);
  --shadow-dramatic: 0 40px 80px -20px rgb(0 0 0 / 0.3);

  /* Motion */
  --duration-fast: 150ms;  --duration-normal: 300ms;  --duration-slow: 500ms;
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}
```

### Type Scale Ratios

| Scale | Ratio | Character |
|-------|-------|-----------|
| major-second | 1.125 | Professional, balanced |
| minor-third | 1.200 | Clear hierarchy |
| perfect-fourth | 1.333 | Bold, impactful |
| golden-ratio | 1.618 | Dramatic, artistic |

## Motion Guidelines

One well-orchestrated page-load with staggered reveals creates more delight than scattered micro-interactions:

```css
/* Staggered reveal pattern */
.reveal { opacity: 0; transform: translateY(16px); }
.reveal:nth-child(1) { animation: fade-up 400ms var(--ease-out) 0ms forwards; }
.reveal:nth-child(2) { animation: fade-up 400ms var(--ease-out) 80ms forwards; }
.reveal:nth-child(3) { animation: fade-up 400ms var(--ease-out) 160ms forwards; }

@keyframes fade-up {
  to { opacity: 1; transform: none; }
}

/* Hover with spring */
.card {
  transition: transform var(--duration-normal) var(--ease-spring),
              box-shadow var(--duration-normal) var(--ease-out);
}
.card:hover { transform: translateY(-4px); }
```

## Accessibility Checklist

- [ ] Text contrast >= 4.5:1 (normal), >= 3:1 (large/UI)
- [ ] All interactive elements keyboard-focusable with visible indicator
- [ ] Semantic HTML (`<nav>`, `<main>`, `<button>`, not `<div>` everywhere)
- [ ] `alt` text on images; `aria-label` where context is visual-only
- [ ] Body text >= 16px, line-height >= 1.5, paragraph width < 80ch
- [ ] `prefers-reduced-motion` respected for all animations
- [ ] Touch targets >= 44x44px

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Layout Strategies

- **Grid-breaking**: position elements intentionally outside the 12-col grid
- **Negative space**: `min-height: 70vh` heroes, `padding-block: 8rem` sections
- **Asymmetry**: offset text/image pairs, diagonal dividers, rotated accents
- **Layering**: `z-index` stacking, overlapping sections, sticky sidebars

```css
/* Diagonal section break */
.section-break {
  clip-path: polygon(0 0, 100% 0, 100% 90%, 0 100%);
  padding-bottom: 8rem;
}
```

## Background and Texture Effects

```css
/* Gradient mesh */
.bg-mesh {
  background:
    radial-gradient(ellipse 80% 80% at 20% -20%, hsl(var(--color-primary) / 0.3), transparent),
    radial-gradient(ellipse 60% 60% at 80% 120%, hsl(var(--color-accent) / 0.2), transparent),
    var(--color-surface);
}

/* Noise grain overlay */
.grain::after {
  content: '';
  position: fixed; inset: 0;
  background-image: url("data:image/svg+xml,..."); /* SVG noise filter */
  opacity: 0.04;
  pointer-events: none;
}

/* Dot grid pattern */
.dot-grid {
  background-image: radial-gradient(circle, currentColor 1px, transparent 1px);
  background-size: 24px 24px;
  opacity: 0.06;
}
```

## Workflow

1. **Define aesthetic direction** -- commit to a specific tone before writing code
2. **Set tokens** -- colors, type, spacing, motion as CSS custom properties
3. **Build layout skeleton** -- sections, grid, negative space strategy
4. **Apply typography** -- display font for headings, body font for prose
5. **Layer depth** -- shadows, borders, backgrounds, textures
6. **Add motion** -- page-load stagger + key hover/focus transitions
7. **Accessibility pass** -- contrast, keyboard, semantics, reduced-motion

## Additional Resources

- For component examples in Next.js v16 App Router, see [components.md](components.md)
- For font pairing recommendations and `next/font` usage, see [typography.md](typography.md)
