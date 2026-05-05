# Direction A — Luxury / Premium (ARCHIVED)

> **Status**: ARCHIVED on 2026-05-02. Not the chosen direction.
> **Live decision**: see [`../decision.md`](../decision.md). The team picked Direction B (Modern Marketplace).
> **Why kept**: this file preserves the Luxury direction's full token set as decision history, in case the brand pivots later. Do **not** import any token from this file into production code — `lib/core/theme/` reads only from the live `decision.md`.

---

> Dark elegant base, warm metallic accent, generous whitespace, soft shadows, large photography. Targets buyers shopping for high-value listings; conveys curation and trust through restraint.

## When this would have been picked

- Most listings are mid-to-high-end residential or commercial.
- Hero photography is professional / agent-supplied (not user phone shots).
- The brand wants to feel curated, like a gallery or a boutique broker — not a classifieds site.

## Why it was rejected

- AlNujom's listing volume mix is broad — owner-posted phone photos are common, not just agent-supplied hero shots.
- The marketplace pattern (وسيطك, OLX, Dubizzle) is what Syrian users recognize; Luxury reads as foreign and slow.
- Migration cost was higher: required new Playfair Display + Reem Kufi font assets and re-coloring every existing stub token. Direction B reused the existing stub primary and surface.

## Color tokens — Light theme

| Token | Hex | Notes |
|---|---|---|
| `primary` | `#1A2332` | Deep ink navy — buttons, headings, brand |
| `onPrimary` | `#F5EFE0` | Warm cream on primary |
| `primaryContainer` | `#E8E2D0` | Warm parchment for tonal surfaces |
| `onPrimaryContainer` | `#1A2332` |  |
| `secondary` | `#B8924A` | Warm gold — accents, badges, "featured" tags |
| `onSecondary` | `#FFFFFF` |  |
| `secondaryContainer` | `#F5EBD3` |  |
| `onSecondaryContainer` | `#4A3A1C` |  |
| `tertiary` | `#7A6E55` | Muted bronze — supporting metadata |
| `surface` | `#FAF7F2` | Warm off-white (NOT pure white — luxury feel) |
| `onSurface` | `#1A2332` | Body text |
| `surfaceVariant` | `#EFEAE0` | Card backgrounds |
| `onSurfaceVariant` | `#4A4538` | Secondary text |
| `outline` | `#8C8475` | Hairline dividers |
| `error` | `#B23A2C` | Muted brick red (not glaring) |
| `success` | `#2E6D43` | Forest green |
| `warning` | `#B8860B` | Antique gold |

## Color tokens — Dark theme

| Token | Hex | Notes |
|---|---|---|
| `primary` | `#C9B084` | Warm gold (was secondary in light) |
| `onPrimary` | `#1A1614` |  |
| `primaryContainer` | `#4A3F2A` |  |
| `onPrimaryContainer` | `#F5EBD3` |  |
| `secondary` | `#D4AF6E` |  |
| `onSecondary` | `#2A2014` |  |
| `surface` | `#14110D` | Rich near-black (NOT pure black — warm undertone) |
| `onSurface` | `#F5EFE0` |  |
| `surfaceVariant` | `#2A2520` |  |
| `onSurfaceVariant` | `#D4CDB8` |  |
| `outline` | `#7A7060` |  |
| `error` | `#E8907F` |  |
| `success` | `#7BC096` |  |

## Typography

| Role | Latin | Arabic |
|---|---|---|
| Display | **Playfair Display** (serif, weight 600) | **Reem Kufi** (Kufic, weight 600) |
| Headline | Playfair Display 500 | Reem Kufi 500 |
| Title | **Inter** 600 | **IBM Plex Sans Arabic** 600 |
| Body | Inter 400 | IBM Plex Sans Arabic 400 |
| Label | Inter 500 | IBM Plex Sans Arabic 500 |

Type scale (logical pixels):

| Style | Size / line-height | Tracking |
|---|---|---|
| displayLarge | 57 / 64 | -0.25 |
| displayMedium | 45 / 52 | 0 |
| headlineLarge | 32 / 40 | 0 |
| headlineMedium | 28 / 36 | 0 |
| titleLarge | 22 / 28 | 0 |
| titleMedium | 16 / 24 | 0.15 |
| bodyLarge | 16 / 24 | 0.5 |
| bodyMedium | 14 / 20 | 0.25 |
| labelLarge | 14 / 20 | 0.1 |

## Spacing — 4dp grid, generous defaults

`xs 4`, `sm 8`, `md 16`, `lg 24`, `xl 32`, `xxl 48`, `xxxl 64`. Cards default to `lg` padding; screen gutters `lg` (24).

## Radii

`sm 8`, `md 12`, `lg 16`, `xl 24`, `pill 999`. Cards default `lg`; buttons `md`; dialogs `xl`.

## Elevation

Soft and low — luxury reads as restraint, not drop-shadow.

| Level | Shadow |
|---|---|
| 0 | none |
| 1 | `0 1 2 rgba(0,0,0,0.04)` |
| 2 | `0 2 4 rgba(0,0,0,0.06)` |
| 3 | `0 4 8 rgba(0,0,0,0.08)` |

## Photography & component cues

- Listing photos: 16:9 hero on detail screen; 4:3 on cards. No filters/CSS effects.
- Cards: full-bleed photo top, generous body padding, gold "featured" badge top-right.
- Buttons: filled (primary) and outlined; both `md` radius. Avoid pill buttons except for filter chips.
