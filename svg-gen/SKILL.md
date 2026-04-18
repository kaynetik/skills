---
name: svg-gen
description: "Generates clean, accessible SVG assets: UI icons, vector logos, and simple illustrations. Covers viewBox-first layout, grouped markup, palette classes or currentColor, optimization, brand layouts, and handoff. Use when the user asks for SVG icons, logos, wordmarks, favicons, sprites, inline SVG, or guidance on clean vector marks. Keywords: SVG, vector logo, wordmark, brand mark, icon set, scalable graphics."
---

# SVG Generation

Produce production-quality SVG. Favor simple silhouettes, stable `viewBox` scaling, and readable structure over ornament.

## When to Use

- UI icons (glyphs, sets, `currentColor` theming)
- Logos and brand marks (wordmarks, lettermarks, pictorial, abstract, combination, emblem)
- Small illustrations when the deliverable is SVG

For diagram-only work (flows, sequences, ER), use the Mermaid skill. This skill is for **authored vector artwork**.

## Choose a Track

| Track | Focus | Typical output |
|-------|--------|----------------|
| **Icons** | Grid alignment, stroke rules, reuse | Files per icon or `<symbol>` sprite |
| **Logos / branding** | Concepts, lockups, variants, guidelines | Concepts plus horizontal, vertical, square, icon-only, text-only as needed |
| **Spot illustration** | One scene or hero graphic | Single SVG |

## Shared Technical Rules

1. **Root**: `xmlns="http://www.w3.org/2000/svg"` and a deliberate `viewBox`. Avoid fixed root `width`/`height` unless the user needs a default; size with CSS in apps.
2. **Layers**: Use `<g id="...">` for symbol vs text vs accents. Shared gradients, patterns, and `<style>` live in `<defs>`.
3. **Color**: App icons use `fill="currentColor"` or matching stroke. Brand marks use named classes in `<defs><style>` (or CSS variables if the stack allows) so palettes stay consistent.
4. **IDs**: Prefix file-scoped IDs (`brand-grad-1`, `brand-clip-1`) so multiple SVGs on one page do not clash.
5. **Optimization**: Drop editor noise, merge paths when it stays clear, trim decimals, remove hidden paths.
6. **Accessibility**: Decorative: `aria-hidden="true"`. Communicative: `role="img"` plus `<title>` / `<desc>` and `aria-labelledby` where appropriate.

### Icon skeleton

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
  <path fill="currentColor" d="..." />
</svg>
```

### Logo skeleton

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img" aria-labelledby="logo-title logo-desc">
  <title id="logo-title">Brand name</title>
  <desc id="logo-desc">Short description for assistive tech</desc>
  <defs>
    <style>.primary { fill: #4F46E5; }</style>
  </defs>
  <g id="logo-symbol">...</g>
  <g id="logo-text">...</g>
</svg>
```

## Icon Track

- Default grid **24x24** unless specified. For strokes, align to the grid so 1px strokes stay crisp at common scales.
- Stroke sets: shared `stroke-width`, `stroke-linecap`, `stroke-linejoin`. Reserve `vector-effect="non-scaling-stroke"` for explicit hairline requests.
- Sprites: `<symbol id="name" viewBox="...">` plus `<use href="#name" />`.

## Logo Track (summary)

Good marks read at a glance and survive favicon size. Before drawing, collect missing facts (see [reference.md](reference.md)). Then:

1. **Concepts**: Offer **3 to 5** distinct directions when the user wants exploration. Each needs a one-paragraph rationale (metaphor, differentiation, fit for audience).
2. **Design discipline**: Simple silhouette, intentional negative space, no extra nodes. Sanity-check at **16px to 24px** width for icon-style marks.
3. **Layouts**: Horizontal lockup, vertical lockup, square or centered, icon-only, text-only as the brief requires.
4. **Color modes**: Full color plus monochrome dark, monochrome light, and reversed-on-dark when relevant.
5. **Files**: Stable names (`brand-concept-2-horizontal.svg`, `brand-concept-2-icon.svg`). Persist variants the user asked for.

Authoring detail, presentation templates, usage rules for handoff, and pattern snippets are in [reference.md](reference.md).

## Presentation

- Order: rationale, then SVG in fenced `xml` blocks. List hex codes for approved fills.
- Large deliveries: short summary in chat, full set on disk.

## Quality Checklist

- [ ] Valid XML; `viewBox` drives layout
- [ ] No ID collisions across inline SVGs on the same document
- [ ] Logo marks legible at small raster sizes when used as icons
- [ ] Icons use `currentColor` where theme switching matters
- [ ] Brand SVGs use repeatable classes or tokens for color

## Additional Resources

- Clean logo criteria, phased workflow, layouts, SVG patterns, usage and export: [reference.md](reference.md)

## Sources

Logo workflow and handoff patterns align with [SVG Logo Designer](https://skills.sh/rknall/claude-skills/svg-logo-designer) ([rknall/claude-skills](https://github.com/rknall/claude-skills)). Icon-track triggers were informed by [svg-icon-generator](https://skills.sh/jeremylongshore/claude-code-plugins-plus-skills/svg-icon-generator).
