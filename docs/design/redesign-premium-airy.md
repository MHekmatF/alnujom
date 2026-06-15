# Phase 32 — Premium-airy redesign (DESIGN.md)

The visual language for the Al Nujom restyle, ported from **"Al Nujom Design System"**
(Claude-design export, mirrored under `docs/design/` references). A **purely visual**
restyle through the token system — no behaviour/logic/routing/data change. Arabic-first
RTL, light + dark.

## Direction
- **Light = "Premium-airy"** — warm cream surfaces + crisp white cards, an airy 4px
  rhythm, soft tinted shadows, and a confident, trustworthy feel.
- **Dark = DS "Dark" direction** — midnight-navy surfaces, electric-blue primary that
  glows on key CTAs / the active nav.

## Accent discipline (the one rule that keeps it coherent + accessible)
The DS uses a different accent per art-directed screen (gold/teal/blue). In the **app**
we run ONE light theme, so:
- **Primary BLUE (`primary`, light `#13507D`)** is the single UI accent — links
  ("عرض الكل"), active nav, filter buttons, the price, fact icons, counts, selected
  chips, primary buttons. It is the only colour ever used for **accent text** (gold and
  coral fail contrast as text).
- **Gold (`tertiary`, `#C2A14D`)** is reserved for the **"مميّز / Featured"** signal only
  — a small fill behind **dark ink** (`onTertiary #1A1714`), never as text on a light bg.
- **Coral (`accent`)** = the **favourite heart** only.
- **Verified green / WhatsApp green** = trust signals only (verified badge, contact CTA).
- Never put two of {gold, coral, blue} as competing accents in one region.

## Tokens (source of truth: `lib/core/theme/`)
- **Colour** → `color_palette.dart` `ModernPalette` (light + dark). `AppColors.of(context)`
  / `Theme.of(context).colorScheme` everywhere — **no hardcoded `Color(0x…)`/`Colors.*`**
  in feature code (the token linter enforces this).
- **Type** → `typography.dart` (`AppTextStyles.of`). Scale unchanged (display 34 → label
  12; price 22/16). Fonts kept: Cairo (display) + IBM Plex Sans Arabic (body) + Inter (en).
- **Spacing / radii / motion** → `spacing.dart`, `radii.dart`, `motion.dart` (4px grid;
  gutter 16; card radius 16, sheets/hero 24, dialogs 16, chips pill; motion 150/200/250 on
  `AppMotion.curve`).
- **Shadows** → soft, tinted (navy/warm in light, deep in dark). Cards rest at `sm`,
  floating bars at `md`, sheets at `lg`. Dark adds a blue glow ring on the active nav +
  primary FAB.

## Component cheatsheet (DS specs → Flutter widgets)
- **PropertyCard** (`property_card.dart`) — 4:3 photo (vertical) / 132² (horizontal),
  scrim gradient, **gold "مميّز" badge** top-start, glass للبيع/للإيجار badge, **coral
  heart** in a white circle top-end; body: title (w700, clamp 2), **price in primary**
  + smaller currency suffix, location (map-pin + muted), specs (bed/bath/ruler).
- **Hero card (home)** — radius-xl, 16:9-ish, scrim, featured badge, heart, over-photo
  title/price/location + frosted glass spec chips.
- **Listing detail** — 16:9 hero rounded bottom 24-28, glass back/heart, dots; sale tag
  (primary-soft fill), big price (ink), title, location (primary map-pin), 4-up **facts
  grid** (soft icon tile + value + label), agent card (verified green), **sticky WhatsApp
  CTA** (green) + side icon button.
- **Search results** — count in primary, search field + filter button, scrollable filter
  chips (selected = primary fill), **horizontal result cards** (photo + tag + heart, price
  in primary, specs).
- **BottomNav** (`main_bottom_nav.dart`) — flat, card bg + top hairline; active = primary
  + bold label + 3px top bar; center **add FAB** raised, primary fill, card border, soft
  shadow (glow in dark).
- **Buttons** — primary (filled blue), WhatsApp (green), outline, text; radius 12/“md”,
  pressed scale 0.98.
- **Chips/badges** — pill; featured = gold+dark-ink; verified = green; status = semantic.
- **Inputs** — filled (`surfaceVariant`), 12 radius, focus = 1.5 primary border.
- **States** — empty/loading/error use the icon + muted copy patterns already present.

## Verify
Pixel 8 Pro AVD, **(light/dark) × (ar/en)** on home + property card + listing detail +
search + add-listing + a settings/list screen. `tool/lint_design_tokens.dart` green;
l10n parity; `analyze --fatal-infos` green; `property_card` golden + `color_scheme_contrast`
baselines re-generated intentionally (review the diff).
