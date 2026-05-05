# Design direction — LOCKED

> **Status**: LOCKED on 2026-05-02. This document is the **single source of truth** for the AlNujom design system. The agent generates `lib/core/theme/colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, and `elevation.dart` directly from the values below. No hex literal will exist in feature code (Constitution VI).
>
> **Companion docs**:
> - [`screens-and-components.md`](screens-and-components.md) — every screen + every reusable widget + every state. Read this when building UI.
> - [`figma-prompts.md`](figma-prompts.md) — copy-paste prompts for Figma First Draft / Make / Galileo. Includes the runtime PaletteTester wiring.
> - [`../PROJECT_BLUEPRINT.md`](../PROJECT_BLUEPRINT.md) — the project navigator. Points to every other doc.
>
> **Archive**: the rejected Direction A (Luxury / Premium) is preserved at [`archive/luxury.md`](archive/luxury.md) for decision history. Do not import its tokens.

---

## Decision

**Chosen direction**: **Modern Marketplace** (formerly "Direction B"), with two swappable primary palettes:

- **Modern (default)** — primary `#1D4ED8`. Punchy, marketplace-fresh, Tailwind blue-700.
- **Trust (alternate)** — primary `#2457A6`. Calmer financial-services blue. Reachable at runtime via the PaletteTester chip ([`screens-and-components.md` §5.18](screens-and-components.md)).

**Decided by**: Hekmat (project owner)
**Date**: 2026-05-02
**Rationale**:

1. AlNujom's listing volume is high and mixed-quality; users come to **scan and compare**, not to luxuriate in hero photography. Marketplace density beats gallery whitespace for this audience.
2. The Modern palette matches the Figma comp the team is currently reviewing and reads fresher to younger Syrian buyers; Trust is preserved as a runtime alternate so we never have to commit blind on the blue shade.
3. Direction A (Luxury) required new Playfair Display + Reem Kufi font assets and a full re-color of the existing stub tokens. Direction B reuses the existing stub primary `#2457A6` and surface colors — cheaper to land in Phase 2 and lower-risk for the first design system spec.

**What this unlocks**: spec 002 (`002-design-system`) can now be written with concrete inputs — locked palette, locked typography, locked spacing/radii/elevation, locked component library (`screens-and-components.md` §5), locked screen catalog (§7).

---

## Color tokens

### Palettes — two swappable schemes

The app ships with **two named palettes** that share every non-blue token. Only the `primary / onPrimary / primaryContainer / accent` quartet differs. A debug-mode PaletteTester chip flips between them at runtime so the team can compare on real screens.

| Palette | Primary | Vibe | Default? |
|---|---|---|---|
| **Modern** | `#1D4ED8` | Punchy marketplace, fresh, tech-forward | ✅ default |
| **Trust** | `#2457A6` | Calm financial-services, conservative bank-blue | runtime alternate |

#### Modern palette — Light theme

| Token | Hex | Use |
|---|---|---|
| `primary` | `#1D4ED8` | Buttons, brand mark, active nav, primary links |
| `onPrimary` | `#FFFFFF` | Text/icons on primary fills |
| `primaryContainer` | `#DBEAFE` | Soft primary backgrounds (banners, "new" chips) |
| `onPrimaryContainer` | `#0B2354` |  |
| `accent` | `#06B6D4` | Gradients, highlight strokes, "promo" accents |

#### Modern palette — Dark theme

| Token | Hex |
|---|---|
| `primary` | `#60A5FA` |
| `onPrimary` | `#0B1220` |
| `primaryContainer` | `#1E3A8A` |
| `onPrimaryContainer` | `#DBEAFE` |
| `accent` | `#22D3EE` |

#### Trust palette — Light theme

| Token | Hex |
|---|---|
| `primary` | `#2457A6` |
| `onPrimary` | `#FFFFFF` |
| `primaryContainer` | `#D9E5FF` |
| `onPrimaryContainer` | `#001A41` |
| `accent` | `#00897B` (teal — quieter than Modern's cyan) |

#### Trust palette — Dark theme

| Token | Hex |
|---|---|
| `primary` | `#9FC5FF` |
| `onPrimary` | `#002C72` |
| `primaryContainer` | `#1F4488` |
| `onPrimaryContainer` | `#D9E5FF` |
| `accent` | `#4DB6AC` |

### Shared tokens (palette-agnostic)

These do not change between Modern and Trust.

#### Light theme

| Token | Hex | Use |
|---|---|---|
| `secondary` | `#0F172A` | Strong text, dark surfaces, contrast brand |
| `onSecondary` | `#FFFFFF` |  |
| `tertiary` | `#F57C00` | Orange — highlights, "new", price callouts (used sparingly) |
| `success` | `#16A34A` | Approved status, positive trends |
| `warning` | `#F59E0B` | "Featured" badge, pending status |
| `danger` / `error` | `#DC2626` | Errors, destructive actions |
| `surface` | `#F8FAFC` | Screen background |
| `surfaceVariant` | `#E1E5EE` | Tonal surfaces, skeleton placeholders |
| `card` | `#FFFFFF` | Card and sheet background |
| `border` / `outline` | `#E2E8F0` | Hairline dividers, input outlines |
| `outlineStrong` | `#74777F` | Strong outlines (focused states) |
| `textPrimary` / `onSurface` | `#111827` | Body and titles |
| `textSecondary` / `onSurfaceVariant` | `#64748B` | Metadata, captions |
| `textMuted` | `#94A3B8` | Placeholder, helper text |

#### Dark theme

| Token | Hex |
|---|---|
| `secondary` | `#E2E8F0` |
| `onSecondary` | `#0B1220` |
| `tertiary` | `#FFB74D` |
| `success` | `#22C55E` |
| `warning` | `#FBBF24` |
| `danger` / `error` | `#F87171` |
| `surface` | `#0B1220` |
| `surfaceVariant` | `#3E4856` |
| `card` | `#0F172A` |
| `border` / `outline` | `#1E293B` |
| `outlineStrong` | `#8E9099` |
| `textPrimary` / `onSurface` | `#F8FAFC` |
| `textSecondary` / `onSurfaceVariant` | `#94A3B8` |
| `textMuted` | `#64748B` |

> Both palettes' light + dark variants pass WCAG AA (4.5:1 body, 3:1 large text). Verify with the actual Cairo / IBM Plex Sans Arabic / Inter rendering before signing off in spec 002.

---

## Typography

| Role | Latin | Arabic |
|---|---|---|
| Display | **Inter** 700 | **Cairo** 700 |
| Headline | Inter 600 | Cairo 600 |
| Title | Inter 600 | Cairo 600 |
| Body | Inter 400 | **IBM Plex Sans Arabic** 400 |
| Label | Inter 500 | IBM Plex Sans Arabic 500 |

Type scale (logical pixels):

| Style | Size / line-height | Tracking |
|---|---|---|
| displayLarge | 45 / 52 | 0 |
| displayMedium | 36 / 44 | 0 |
| headlineLarge | 28 / 36 | 0 |
| headlineMedium | 24 / 32 | 0 |
| titleLarge | 20 / 28 | 0.15 |
| titleMedium | 16 / 24 | 0.15 |
| bodyLarge | 16 / 24 | 0.5 |
| bodyMedium | 14 / 20 | 0.25 |
| labelLarge | 14 / 20 | 0.1 |
| labelMedium | 12 / 16 | 0.5 |

> Tajawal was considered and rejected — too monoline at headline weights. Cairo + IBM Plex Sans Arabic is the locked Arabic pairing.

---

## Spacing — 4dp grid, marketplace density

`xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32`, `xxxl 48`. Cards default `md` (12) padding; screen gutters `lg` (16).

## Radii

**LOCKED scale (reconciled in spec 002, research R-10):** `sm 8`, `md 12`, `lg 16`, `xl 20`, `pill 999`. This matches `screens-and-components.md` §2.5 and the Figma comp. Cards: `md` (12). Buttons: `md` (12). Dialogs: `lg` (16). Bottom sheets / large surfaces: `xl` (20).

> Earlier draft of this doc carried a smaller `sm 4 / md 8 / lg 12 / xl 16` scale and flagged the conflict as unresolved. Spec 002 closed it on the screens-and-components scale; `lib/core/theme/radii.dart` is now the source of truth.

## Elevation

Defined shadows for clear card hierarchy.

| Level | Shadow |
|---|---|
| 0 | none |
| 1 | `0 1 3 rgba(0,0,0,0.10)` |
| 2 | `0 2 6 rgba(0,0,0,0.12)` |
| 3 | `0 4 12 rgba(0,0,0,0.14)` |

> Shadows in dark mode are essentially invisible — use a `1px` border of `outline` to delineate cards instead.

---

## Photography & component cues

- Listing photos: **4:3** on detail (sticky title section sits below); **16:10** on cards (denser fold).
- Cards: photo on the leading side (40% width) on tablet horizontal variants; stacked photo-on-top on phone vertical variants. See PropertyCard anatomy in [`screens-and-components.md` §5.5](screens-and-components.md).
- Price prominent in `primary` (Modern) or `primary` (Trust) — both palettes use primary for price callouts; `tertiary` orange is reserved for "new" badges only.
- Buttons: filled primary, tonal secondary (uses `primaryContainer`), outlined, text. `md` radius. Pill chips for filters only.

---

## Accessibility floor

Every screen must clear these — non-negotiable.

- All text/icon contrast ≥ **4.5:1** on its surface (WCAG 2.1 AA body); large text and UI ≥ **3:1**.
- Touch targets ≥ **48 × 48 dp**.
- No color-only state signals — every state pairs color with an icon or label (FR-017).
- All directional padding uses `EdgeInsetsDirectional` (Constitution V).
- Dark theme honestly passes the same checks — not an afterthought.

---

## Migration cost (now realized in spec 002)

Modern Marketplace was the cheaper landing because it reuses the existing Phase 1 stub primary (`#2457A6` → archived as Trust palette) and `surface` / `onSurface` tokens. Spec 002 work:

1. Expand Phase 1 stub `tokens_stub.dart` into full Material 3 `ColorScheme` for both palettes (Modern light/dark + Trust light/dark = 4 schemes).
2. Vendor font assets under `assets/fonts/`: Cairo, IBM Plex Sans Arabic, Inter (regular + medium + semibold + bold for each).
3. Build the component library defined in [`screens-and-components.md` §5](screens-and-components.md) — the canonical 33-row catalog (see `specs/002-design-system/contracts/component-library.md`), one widget per file under `lib/core/widgets/`, plus the feature-shared shims in `lib/shared/presentation/widgets/`.
4. Wire the PaletteTester chip ([`screens-and-components.md` §5.18](screens-and-components.md)) behind a single `kDesignToolsEnabled` const (the same flag that gates the Theme Gallery) that resolves to `false` in release builds — chip and gallery tree-shake together out of production.
5. Golden tests for every component under each of the 4 theme-palette combinations.

---

## What this document does NOT cover

- Per-screen layouts → see [`screens-and-components.md` §7](screens-and-components.md).
- Per-component anatomy → see [`screens-and-components.md` §5](screens-and-components.md).
- Bottom nav structure → see [`screens-and-components.md` §6](screens-and-components.md).
- Implementation order / phases → see [`../IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) and [`../PROJECT_BLUEPRINT.md`](../PROJECT_BLUEPRINT.md).
- Admin dashboard design → out of scope until Phase 22; will get its own decision doc.

---

## Next steps

1. ✅ This file is locked. Direction A archived to `archive/luxury.md`.
2. Run `/speckit-specify` for spec `002-design-system` with this file + `screens-and-components.md` + `PROJECT_BLUEPRINT.md` as input.
3. Spec 002 will produce: `specs/002-design-system/spec.md`, `plan.md`, `tasks.md`, contracts for the component library.
4. Implementation lands phase-by-phase on the `002-design-system` branch (already cut). One PR for the whole spec at end-of-spec, per [`../AI_AGENT_WORKFLOW.md`](../AI_AGENT_WORKFLOW.md).
