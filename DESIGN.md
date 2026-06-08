# AlNujom — Design System (DESIGN.md)

Phase 25 visual identity for **AlNujom (النجوم — "the stars")**, an Arabic-first
(RTL) Syrian real-estate marketplace. The system is **token-first**: every
visual value lives in `lib/core/theme/*` and is consumed via `AppColors.of`,
`AppTextStyles.of`, `AppSpacing`, `AppRadii`, `AppElevation`, `AppMotion`. The
`tool/lint_design_tokens.dart` linter forbids raw `Color(0x…)`, inline
`TextStyle(`, and numeric `EdgeInsets`/`BorderRadius`/`BoxShadow` outside the
theme files.

**Register:** product (design serves the product). **Mood:** trustworthy, calm,
crafted, restrained — never cluttered. Photos lead, data supports. Trust and
verification are central. WCAG-AA throughout (`color_scheme_contrast_test`).

## Brand mark
The shipped identity (PRs #72/#73) is the **N-logo**: a deep-blue "N" inside a
ring of stars over a skyline arc, with the Arabic wordmark **النّجوم** and the
English line *Al Nujoom Real Estate Marketing*. Assets:
`assets/branding/icon.png` (adaptive-icon foreground) + `icon_legacy.png`;
`splash_full.png` (splash, light+dark); `logo_mark.png` (emblem only) and
`logo_full.png` (full lockup — rendered by the in-app `AppLogo` on
login/register/reset, sized by width). A logo is never mirrored for RTL.

> **Known reconciliation item:** the in-app `BrandMark` widget (the `CustomPainter`
> two-tone star used in the home app bar + onboarding) predates the N-logo
> rebrand, so the app currently carries two marks. Unifying `BrandMark` to the
> N-logo is a branding decision pending sign-off — tracked, not yet applied.

## Color tokens (`color_palette.dart` → `ModernPalette`)

| Token | Light | Dark |
|---|---|---|
| primary | `#13507D` | `#6BB0E6` |
| onPrimary | `#FFFFFF` | `#062339` |
| primaryContainer | `#D7E6F3` | `#15466B` |
| onPrimaryContainer | `#082B44` | `#CFE6F8` |
| accent (coral) | `#F4795B` | `#FF8E72` |
| onAccent | `#FFFFFF` | `#3A1207` |
| accentContainer | `#FBE2DA` | `#5A271A` |
| secondary (slate) | `#0F172A` | `#E2E8F0` |
| tertiary (amber) | `#C8842F` | `#E2A856` |
| success | `#2E9E6B` | `#4CB587` |
| warning | `#C98318` | `#E2B25A` |
| error | `#D23F3F` | `#F0706E` |
| surface | `#F6F8FB` | `#0E141A` |
| surfaceVariant | `#ECF1F6` | `#1A222B` |
| card | `#FFFFFF` | `#161E26` |
| outline | `#D8E0E8` | `#2B3640` |
| onSurface | `#14202B` | `#E9EFF4` |
| onSurfaceVariant | `#475663` | `#AAB7C2` |
| textMuted | `#5F6C78` | `#7E8C98` |
| **verified** (trust) | `#1F7A4D` | `#57C48C` |
| **verifiedContainer** | `#DCF0E5` | `#163A2A` |
| onError | `#FFFFFF` | `#420A0A` |
| onSuccess | `#FFFFFF` | `#04231A` |
| onPhoto | `#FFFFFF` | `#FFFFFF` |
| photoOverlay | `#8C0B1118` | `#8C0B1118` |
| scrim | `#66000000` | `#99000000` |

> `textMuted` light was darkened from `#74838F` (3.66:1, below AA) to `#5F6C78`
> (5.06:1) in the Phase-25 Impeccable polish — see `color_palette.dart`.
> `onError`/`onSuccess` are explicit fills' foregrounds; `onPhoto` (always
> white), `photoOverlay` (over-photo chip + scrim base) and `scrim` (modal
> backdrop) are theme-independent and replace the old hardcoded
> `Colors.white`/`Colors.black` over-photo values. The Material-3
> `surfaceContainer*` tonal ladder is provided by `ColorScheme.fromSeed`.

Semantic usage: **sale** purpose → `primary`/`primaryContainer` (blue); **rent**
→ `verified`/`verifiedContainer` (green); favorites/CTA highlight → `accent`.
`TrustPalette` is the alternate (design-tools only); both pass WCAG-AA.

## Typography (`typography.dart` → `AppTextStyles`)
Arabic: **Cairo** (display/headline/title/price) + **IBM Plex Sans Arabic**
(body/label). Latin: **Inter**. Scale: display 34 · headline 26/22 · title 19/16
· body 16/14 · label 14/12 (semibold) · price 22/16 (Cairo). The Material
"Small" slots are derived from these tokens in `app_theme.dart` so small text
keeps the Arabic font.

## Spacing · radii · elevation · motion
- **Spacing** (`AppSpacing`, 8pt): 4 · 8 · 12 · 16 · 24 · 32 · 48.
- **Radii** (`AppRadii`): sm 8 · md 12 (inputs) · lg 16 (cards/buttons) · xl 24
  (sheets) · pill 999.
- **Elevation** (`AppElevation`): soft navy-tinted light shadows (`#102A43`
  @ ~6/8/14%); real dark shadows + hairline border on dark surfaces.
- **Motion** (`AppMotion`): fast 150ms · base 200ms · slow 250ms · entrance
  400ms · stagger 55ms · shared `Cubic(.2,.7,.3,1)`, plus `emphasized`
  (entrance) and `exit` (dismiss) curves.
- **Gradients** (`AppGradients.of(context)`): `photoScrim` + `photoTopScrim`
  (over-photo legibility, derived from `photoOverlay`) and a whisper-soft
  `featuredTint` (primary wash) for premium cards. Token-derived, never raw.

## Components
- **Listing card** (`home_listing_card.dart`, `property_card.dart`): 16:10 photo,
  frosted `GlassPill` type label + semantic `StatusPill` purpose, white over-photo
  favorite chip (coral when saved), price below, location with pin, green
  verified-agency footer; soft shadow + hairline border.
- **Pills:** `GlassPill` (frosted dark, over photos), `StatusPill` (solid
  semantic), category shortcuts (filled, borderless).
- **Inputs:** filled `surfaceVariant`, 1.5px focus ring in `primary`, radius md.
- **App bar:** transparent, `BrandMark` wordmark on home.
- **Bottom sheets / dialogs:** card surface, radius xl/lg, drag handle.
- **Verified badge** (`AgencyBadge`): green container + green check.

## Anti-patterns (avoided)
Purple gradients, glassmorphism overload, generic SaaS dashboards, per-section
all-caps eyebrows, cream/beige body backgrounds, em dashes in copy, washed-out
gray body text.
