# SVG Logo Reference

Use this file when building or refining **vector logos** and brand marks. It complements [SKILL.md](SKILL.md). The workflow below matches the structure of [SVG Logo Designer](https://skills.sh/rknall/claude-skills/svg-logo-designer) on skills.sh ([rknall/claude-skills](https://github.com/rknall/claude-skills)).

## What "clean" means for a logo

- **Simple**: Few shapes; one clear silhouette. Extra detail rarely helps at 16px.
- **Memorable**: One idea, not five metaphors stacked together.
- **Scalable**: Built on a `viewBox`, not a fixed pixel composition that breaks when resized.
- **Consistent**: Stroke weights, corner radii, and optical alignment match across symbol and wordmark.
- **Honest**: Legible contrast on light and dark; monochrome versions still read.

## Phase 1: Requirements

Capture anything the user has not already stated:

**Brand**

- Company or product name
- Industry and who buys it
- Audience and personality (e.g. serious, playful, premium)
- Values and how they differ from competitors

**Logo type** (pick what fits the brief)

- Wordmark, lettermark, pictorial mark, abstract mark, mascot, combination mark, emblem

**Style**

- Palette (fixed hex list vs open), typography hints for wordmarks, overall look (minimal, geometric, organic, bold, elegant, tech, retro)

**Technical**

- Smallest size (favicon, app chrome, print)
- Contexts: web, print, merchandise, motion (if any)
- Need for monochrome and reversed treatments
- How many concepts (often **3 to 5**) and which layouts per concept

## Phase 2: Concept development

For each concept:

- Tie the shape to **one** primary metaphor or formal idea.
- Exploit **negative space** only when it stays obvious at small sizes.
- Check **uniqueness** against obvious category clichés without copying existing trademarks.
- Prefer paths that **merge** cleanly; fewer nodes usually means cleaner SVG.

**Grouped SVG structure** (adapt `viewBox` per layout):

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img" aria-labelledby="logo-title logo-desc">
  <title id="logo-title">Brand</title>
  <desc id="logo-desc">Short description</desc>
  <defs>
    <linearGradient id="brand-grad-1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4F46E5;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#7C3AED;stop-opacity:1" />
    </linearGradient>
  </defs>
  <g id="logo-symbol"><!-- mark --></g>
  <g id="logo-text"><!-- text if any --></g>
</svg>
```

## Phase 3: Layouts

| Layout | Composition | Typical use |
|--------|-------------|-------------|
| Horizontal lockup | Icon left, text right | Site header, decks |
| Vertical lockup | Icon above text | Avatars, mobile |
| Square / centered | Balanced block | App icon crops |
| Icon only | Symbol alone | Favicon, toolbar |
| Text only | Wordmark | Headers, legal lines |

Rebalance spacing and optical center per layout; do not scale one lockup SVG with CSS alone when proportions need to change.

## Phase 4: Clean SVG for logos

**Structure**

- Separate symbol, text, and accents into `<g>` groups with stable `id` values for discussion and CSS hooks.
- Put reusable paints in `<defs>`: gradients, patterns, shared `<style>` blocks.

**Color**

- Define classes once, reuse:

```xml
<defs>
  <style>
    .primary { fill: #4F46E5; }
    .secondary { fill: #10B981; }
    .text { fill: #1F2937; }
  </style>
</defs>
```

**Scale**

- Author in `viewBox` space. Avoid baking pixel dimensions into every coordinate unless required for export specs.

**Optimization**

- Remove invisible layers, merge paths when semantics stay clear, round coordinates sensibly, dedupe gradients.

**Accessibility**

```xml
<svg role="img" aria-labelledby="logo-title logo-desc">
  <title id="logo-title">Company Name Logo</title>
  <desc id="logo-desc">Short visual description</desc>
</svg>
```

## Phase 5: How to present concepts

Use a repeating block per concept:

```markdown
## Concept [n]: [Name]

### Rationale
[Metaphor, audience fit, differentiation]

### Horizontal
[usage note]
```xml
<svg>...</svg>
```

### Vertical
...

### Icon only
...

### Palette
- Primary: #...
- Secondary: #...
- Monochrome dark / light / reversed: ...
```

## Phase 6: Files and naming

Examples:

- `company-concept-1-horizontal.svg`
- `company-concept-1-vertical.svg`
- `company-concept-1-icon.svg`

Organize by concept and layout when delivering many files:

```
logos/
  concept-1/
    horizontal/
      full-color.svg
      monochrome-dark.svg
      monochrome-light.svg
    vertical/
      ...
    icon/
      ...
```

## Phase 7: Usage guidelines (handoff)

**Formats**

- SVG for web and most print prep; raster (PNG) when a locked pixel grid is required.

**Clear space**

- Often one clear unit based on mark height; no competing elements inside that margin.

**Minimum sizes** (tune to brand)

- Digital: commonly on the order of **100px** width for full lockups where readability matters.
- Print: often **1 in** width minimum for wordmarks unless a separate simplified mark exists.

**Color contexts**

- Full color on light backgrounds; monochrome dark on light; light or reversed fills on dark.
- When the mark sits next to text, aim for **roughly 4.5:1** contrast with the background for the dominant glyph fills (WCAG-style thinking for UI usage).

**Incorrect usage**

Do not: non-uniform stretch, off-palette colors, unapproved effects, arbitrary skew, busy backgrounds without breathing room, or redrawing the mark incorrectly.

**Web embedding**

```html
<img src="logo.svg" alt="Company logo" />
```

```css
.logo {
  width: 100%;
  max-width: 200px;
  height: auto;
}
```

Inline SVG is appropriate when CSS must target parts of the mark.

## PNG export

```bash
inkscape logo.svg --export-filename=logo.png --export-width=1000
convert -background none logo.svg logo.png
```

## Pattern snippets

**Wordmark** (text outlines or webfonts as appropriate for the stack):

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 80">
  <defs>
    <style>
      .wordmark { font-family: system-ui, sans-serif; font-size: 48px; font-weight: 700; fill: #1F2937; }
    </style>
  </defs>
  <text x="10" y="60" class="wordmark">COMPANY</text>
</svg>
```

**Combination mark** (icon + text):

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 80">
  <g id="icon">
    <circle cx="40" cy="40" r="30" fill="#4F46E5" />
    <path d="M30,35 L35,45 L50,25" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round" />
  </g>
  <g id="text">
    <text x="85" y="48" font-family="system-ui, sans-serif" font-size="28" font-weight="700" fill="#1F2937">COMPANY</text>
  </g>
</svg>
```

## Color associations (optional guide)

| Hue | Common associations | Example hex (illustrative) |
|-----|----------------------|------------------------------|
| Blue | Trust, tech, care | #0066CC, #4F46E5 |
| Green | Growth, health, outdoors | #10B981, #059669 |
| Red | Energy, appetite, urgency | #DC2626, #EF4444 |
| Purple | Creative, premium | #7C3AED, #8B5CF6 |
| Orange | Friendly, approachable | #F97316, #FB923C |
| Yellow | Warmth, optimism | #FBBF24, #FCD34D |
| Neutral | Luxury, clarity | #1F2937, #6B7280 |

## Iteration

1. Collect which concept to pursue and what to change.
2. Refine geometry and palette on that direction; test small sizes again.
3. Produce final layouts and color modes.
4. Ship SVGs, short usage notes, and export commands if raster is required.

## Deliverables (typical)

- SVGs per approved concept and layout
- Documented palette (hex) and when to use each mode
- Optional PNG exports at agreed pixel widths
