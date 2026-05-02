# AlNujom — Screens & Components UI/UX Specification

> **Status**: DRAFT for visual review. Not a token source. Once a design direction is locked in [`decision.md`](decision.md), this document feeds the per-screen widget specs in `specs/00X-*` features.
> **Scope**: every screen, every state (default / empty / loading / error), every reusable widget. Arabic-first, RTL, Flutter implementation.
> **Inspiration**: Figma "Implement-Promotion-Feature" comp + the marketplace pattern used by وسيطك, Airbnb, OLX, Zillow. The visual treatment in the screenshots maps to **Direction B (Modern Tech / Marketplace)** in [`decision.md`](decision.md).

---

## 0. How this document is organized

| Section | What it covers |
|---|---|
| 1. Foundation | The "why" — product voice, audience, layout grid, RTL rules. |
| 2. Design tokens | Colors, fonts, spacing, radii, shadows. The numbers everything else cites. |
| 3. Iconography & imagery | Icon set, photo aspect ratios, placeholder strategy. |
| 4. Global patterns | RTL, navigation, empty/loading/error skeletons, sheets, dialogs. |
| 5. Component library | Every reusable widget — anatomy + states. |
| 6. Bottom navigation | The 5-tab spine of the app. |
| 7. Screens | All 22+ screens, top-to-bottom layout + interactions + states. |
| 8. Motion & micro-interactions | What animates, when, and how long. |
| 9. Accessibility & RTL checklist | The bar every screen must clear before shipping. |
| 10. Implementation notes for Flutter | Constitution-aligned guidance (no hex literals in feature code, `EdgeInsetsDirectional`, etc.). |

**Plain-language note**: this is a *design* document, not a *coding* document. It describes what the user sees and how they interact. The translation into Flutter widgets is the next step — and it's gated by the design-direction decision.

---

## 1. Foundation

### 1.1 Product voice

Confident, professional, calm. Syrian Levantine register — natural, not stiff Modern Standard Arabic. Examples:

- ✅ "ابحث عن شقة، منزل، محل…"  
- ❌ "البحث عن العقارات الموجودة في النظام"  
- ✅ "بيتك يبدأ من هنا"  
- ❌ "ابحث في قاعدة البيانات الخاصة بنا"

Trust signals matter more than novelty. Photos are the hero on listing cards; copy is the hero everywhere else.

### 1.2 Audience

| Persona | What they need most |
|---|---|
| **Buyer / renter** (anonymous → registered) | Fast search, clear price, trustworthy photos, easy contact. |
| **Owner / private seller** | Simple posting flow, clear status (pending / approved / sold). |
| **Agent / office** | Branded profile, multiple listings management, lead inbox. |
| **Moderator / admin** | Approval queue + audit (admin screens are out of scope for this doc — covered separately). |

### 1.3 Layout grid & device target

- **Primary device**: Android phone, **360 × 800 dp** logical. Designed against Infinix Note 8 form factor (~411 × 940 dp logical). Test on this device before declaring any screen done.
- **Safe areas**: top inset = status bar; bottom inset = system gesture pill. Always inset.
- **Screen gutters**: `lg` (16 dp) on either side of every screen. Cards, sections, and inputs all align to these gutters.
- **Card max-width on tablet**: 430 dp (mobile-first; tablets center the column).
- **Vertical rhythm**: every section header has `xl` (24 dp) above it and `md` (12 dp) below it.

### 1.4 RTL is the default

The app is **Arabic-first**. Every layout is described in **leading / trailing** terms — never *left / right*. Under Arabic (RTL), leading = right; under English (LTR), leading = left. Specifics:

- All padding uses **directional insets** (`EdgeInsetsDirectional.only(start: …, end: …)`).
- Back arrows mirror: in RTL the chevron points right; in LTR, left.
- Currency: Arabic numerals are fine ("85,000,000 ل.س"); the currency suffix follows the number.
- Page indicators (dots) read in the natural direction of the script (RTL = right-to-left dot order).

---

## 2. Design tokens

> **Authoritative source**: once design direction is locked, the production token values live in `lib/core/theme/`. The values below match the Figma comp the team is currently reviewing (Direction B family).

### 2.1 Palettes — two swappable schemes

The app ships with **two named palettes** that share every non-blue token (surface, card, border, text, semantic colors). Only the **primary / onPrimary / primaryContainer / accent** quartet differs. A debug-mode **Palette Tester** chip (§ 5.18) lets us flip between them at runtime so the team can compare on real screens before committing.

| Palette | Primary | Vibe | Default? |
|---|---|---|---|
| **Modern** | `#1D4ED8` | Punchy marketplace, fresh, tech-forward | ✅ default |
| **Trust** | `#2457A6` | Calm financial-services, conservative bank-blue | alternate |

**Why two**: `#1D4ED8` is the comp the team is currently reviewing (Tailwind blue-700); `#2457A6` is the original Direction B value in [`decision.md`](decision.md). Rather than pick blind, ship both and toggle live.

#### 2.1.1 Modern palette (default)

**Light theme**

| Token | Hex | Use |
|---|---|---|
| `primary` | `#1D4ED8` | Buttons, brand mark, active nav, primary links |
| `onPrimary` | `#FFFFFF` | Text/icons on primary fills |
| `primaryContainer` | `#DBEAFE` | Soft primary backgrounds (banners, "new" chips) |
| `onPrimaryContainer` | `#0B2354` |  |
| `accent` | `#06B6D4` | Gradients, highlight strokes, "promo" accents |

**Dark theme**

| Token | Hex |
|---|---|
| `primary` | `#60A5FA` |
| `onPrimary` | `#0B1220` |
| `primaryContainer` | `#1E3A8A` |
| `onPrimaryContainer` | `#DBEAFE` |
| `accent` | `#22D3EE` |

#### 2.1.2 Trust palette (alternate)

**Light theme**

| Token | Hex |
|---|---|
| `primary` | `#2457A6` |
| `onPrimary` | `#FFFFFF` |
| `primaryContainer` | `#D9E5FF` |
| `onPrimaryContainer` | `#001A41` |
| `accent` | `#00897B` (teal — quieter than Modern's cyan) |

**Dark theme**

| Token | Hex |
|---|---|
| `primary` | `#9FC5FF` |
| `onPrimary` | `#002C72` |
| `primaryContainer` | `#1F4488` |
| `onPrimaryContainer` | `#D9E5FF` |
| `accent` | `#4DB6AC` |

### 2.2 Shared tokens (palette-agnostic)

These do not change between Modern and Trust.

**Light theme**

| Token | Hex | Use |
|---|---|---|
| `secondary` | `#0F172A` | Strong text, dark surfaces, contrast brand |
| `onSecondary` | `#FFFFFF` |  |
| `success` | `#16A34A` | Approved status, positive trends |
| `warning` | `#F59E0B` | "Featured" badge, pending status |
| `danger` | `#DC2626` | Errors, destructive actions |
| `surface` | `#F8FAFC` | Screen background |
| `card` | `#FFFFFF` | Card and sheet background |
| `border` | `#E2E8F0` | Hairline dividers, input outlines |
| `textPrimary` | `#111827` | Body and titles |
| `textSecondary` | `#64748B` | Metadata, captions |
| `textMuted` | `#94A3B8` | Placeholder, helper text |

**Dark theme**

| Token | Hex |
|---|---|
| `secondary` | `#E2E8F0` |
| `onSecondary` | `#0B1220` |
| `success` | `#22C55E` |
| `warning` | `#FBBF24` |
| `danger` | `#F87171` |
| `surface` | `#0B1220` |
| `card` | `#0F172A` |
| `border` | `#1E293B` |
| `textPrimary` | `#F8FAFC` |
| `textSecondary` | `#94A3B8` |
| `textMuted` | `#64748B` |

> Both palettes' light + dark variants pass WCAG AA (4.5:1 body, 3:1 large text) for text/icon contrast. Verify with the actual Cairo / IBM Plex Sans Arabic / Inter rendering before signing off.

### 2.3 Typography

**Arabic**: Cairo (display + headline + title), IBM Plex Sans Arabic (body + label).  
**Latin**: Inter (all weights).

| Style | Size / line-height (dp) | Weight | When to use |
|---|---|---|---|
| `displayLarge` | 36 / 44 | 700 | Splash brand mark only |
| `displayMedium` | 28 / 36 | 700 | Empty-state hero text |
| `headlineLarge` | 24 / 32 | 700 | Page title (e.g., "إضافة إعلان") |
| `headlineMedium` | 20 / 28 | 600 | Section headers ("عقارات مميزة") |
| `titleLarge` | 18 / 26 | 600 | Card titles, list item titles |
| `titleMedium` | 16 / 24 | 600 | Form field labels in step headers |
| `bodyLarge` | 16 / 24 | 400 | Primary body copy |
| `bodyMedium` | 14 / 20 | 400 | Secondary body, metadata |
| `labelLarge` | 14 / 20 | 500 | Button text, tab labels |
| `labelMedium` | 12 / 16 | 500 | Chip labels, badges, captions |
| `priceLarge` | 22 / 28 | 700 | Listing price on details screen |
| `priceMedium` | 16 / 22 | 700 | Listing price on cards |

**Plain-language note**: "weight 700" = bold; "weight 600" = semibold; "weight 400" = regular. The numbers map to font files we'll vendor under `assets/fonts/`.

### 2.4 Spacing — 4 dp grid

`xs 4` · `sm 8` · `md 12` · `lg 16` · `xl 24` · `xxl 32` · `xxxl 48`

- Card internal padding default: `md` (12).
- Card-to-card gap in lists: `md` (12).
- Section header gap: `xl` (24) above, `md` (12) below.
- Screen gutter: `lg` (16).

### 2.5 Radii

`sm 8` · `md 12` · `lg 16` · `xl 20` · `pill 999`

- Cards: `md` (12).
- Buttons: `md` (12), or `pill` for filter chips.
- Sheets: top corners `xl` (20).
- Dialog: `lg` (16).

### 2.6 Elevation (shadows)

| Level | Shadow | Use |
|---|---|---|
| 0 | none | Flat surfaces, pressed buttons |
| 1 | `0 1 3 rgba(15,23,42,0.06)` | Cards at rest |
| 2 | `0 2 6 rgba(15,23,42,0.08)` | Floating search bar, sticky CTAs |
| 3 | `0 4 12 rgba(15,23,42,0.10)` | Bottom sheet, modal dialog, FAB |

> Shadows in dark mode are essentially invisible. Use a `border` 1px hairline of `#1E293B` to delineate cards instead.

### 2.7 Motion (durations & curves)

- Tap feedback: 80 ms `easeOut`.
- Sheet open/close: 240 ms `easeOutCubic`.
- Page transition (push): 280 ms `easeInOutCubic`, slide-from-trailing under RTL.
- Skeleton shimmer: 1200 ms loop.
- Snackbar enter: 200 ms; auto-dismiss after 4 s unless action present.

---

## 3. Iconography & imagery

### 3.1 Icons

- Library: **Lucide** (or `flutter_lucide`). Keep one library — do not mix Material + Lucide + custom.
- Stroke weight: 2 px at 24 dp.
- Default size: `24 dp`. Inline-with-text size: `16 dp`. Tab icons: `24 dp`.
- Color: `textPrimary` by default; `primary` on active state; `textSecondary` on disabled.

Common icons by use:

| Use | Icon |
|---|---|
| Search | `search` |
| Notification | `bell` |
| Favorite (filled / unfilled) | `heart` |
| Share | `share-2` |
| Phone | `phone` |
| WhatsApp | `message-circle` (or brand mark via SVG) |
| Map pin | `map-pin` |
| Home | `home` |
| Add | `plus-circle` |
| Profile | `user` |
| Filter | `sliders-horizontal` |
| Sort | `arrow-up-down` |
| Bed | `bed` |
| Bath | `bath` |
| Area (m²) | `square` |
| Verified | `badge-check` |

### 3.2 Imagery

- **Listing cards**: 4:3 image on top (full-bleed within card), or 16:10 if a horizontal-scroll variant.
- **Listing details hero**: 16:9 carousel filling top ~45% of screen.
- **Onboarding**: vector illustrations using brand colors only — no third-party stock.
- **Office profile cover**: 16:9, dark overlay 30% for legibility of name on top.
- **Placeholder when image missing**: a soft `primaryContainer` block with the property-type icon centered. Never show a broken-image glyph.

### 3.3 Skeleton placeholders

Every image, every text line on a card, every avatar has a skeleton state — a `surfaceVariant` rectangle with the shimmer animation. Skeletons match the dimensions of the real content, never resize the layout when content arrives.

---

## 4. Global patterns

### 4.1 Navigation hierarchy

```
RootShell (BottomNav, 5 tabs)
├── Home (tab 1)
│   ├── Search results
│   │   ├── Filter sheet (modal)
│   │   └── Listing details
│   │       ├── Inquiry sheet (modal)
│   │       └── Image gallery (fullscreen)
│   └── Listing details (deep link)
├── Search (tab 2)
├── Add Listing (tab 3, opens multi-step modal flow)
├── Favorites (tab 4)
└── Profile (tab 5)
    ├── My Listings
    ├── Messages
    │   └── Chat detail
    ├── Notifications
    ├── Settings
    │   ├── Language
    │   ├── Theme
    │   └── About
    └── Office Profile (if office account)

Auth flow (gated, no bottom nav):
Splash → Onboarding 1/2/3 → Login → Register → Pending Approval
```

### 4.2 Empty / loading / error pattern

Every screen that loads data has three states. Default to designing all three before declaring a screen done.

| State | Visual |
|---|---|
| **Loading** | Skeleton shapes mirroring the final layout. No spinners except inside buttons. |
| **Empty** | Centered illustration (~120 dp), `headlineMedium` Arabic line, `bodyMedium` supporting text, single primary CTA. See § 7.21. |
| **Error** | Same shape as empty state but with `danger`-tinted illustration and a "إعادة المحاولة" (Retry) CTA. Surface the friendly Arabic message; log the technical error to Sentry. |

**Plain-language note**: a "skeleton" is a grey-ish placeholder shaped like the real content, so the page doesn't look broken while data loads.

### 4.3 Sheets & dialogs

- **Bottom sheet** (modal): drag handle `4 × 32 dp` centered at top, `xl` top radius, max height ~85% of screen, content scrollable, sticky footer for primary action.
- **Confirm dialog**: title (`titleLarge`), body (`bodyMedium`), two-button footer (cancel outlined trailing, action filled-primary or destructive leading).
- **Snackbar**: bottom of screen, `card` background, leading status icon (info/success/error), trailing optional action label in `primary` color, auto-dismiss 4 s.

### 4.4 Toasts vs snackbars vs banners

- **Toast / snackbar**: ephemeral feedback after a user action ("تم الحفظ").
- **Banner**: persistent until dismissed — used for system-wide notices like "أنت في وضع التصفح كزائر".
- **Inline alert**: at the top of a form section, explaining a field-level error in context.

---

## 5. Component library

Each component below has: anatomy (parts), states (default / hover-pressed / focus / disabled / loading / error), and behavior notes. These are the widgets we will eventually build and reuse — no one-off variants per screen.

### 5.1 AppBar

**Anatomy**: leading slot · title · trailing slot(s).

**Variants**:
- `AppBar.default` — title `headlineMedium`, no leading icon (root tabs).
- `AppBar.withBack` — leading back arrow (mirrored RTL), title centered or leading-aligned.
- `AppBar.withSearch` — replaces title with a `SearchField`.
- `AppBar.transparentOnImage` — over a hero image; uses frosted glass background (60% surface + blur).

**States**: at top scroll = no elevation; once scrolled = `elevation 1`.

### 5.2 SearchField

**Anatomy**: leading search icon · input · trailing clear-X (when not empty) · trailing filter icon (optional).

**States**:
- Idle: `surfaceVariant` background, `pill` radius, `textMuted` placeholder.
- Focused: `border` shifts to `primary`, 1.5 px.
- With value: clear-X appears trailing.
- Loading: small spinner replaces leading search icon while debounced query runs.

**Behavior**: tap on the home-screen "search bar look-alike" doesn't focus an input — it pushes the dedicated Search screen. The real input lives there.

### 5.3 LocationSelector

A short row showing `📍 المدينة / المنطقة` with a chevron. Tapping opens a cascading picker (governorate → city → area). Used at the top of Home and inside the filter sheet.

### 5.4 CategoryChip

Pill with leading icon + label. Two visual states: idle (`card` bg, `border` outline, `textPrimary` label) and selected (`primary` bg, `onPrimary` label, no border).

Used in two places:
- Home: horizontal scrollable row of property types.
- Search results: a strip of removable filter chips with trailing × to clear individual filters.

### 5.5 PropertyCard

**The most-rendered widget in the app**. Two layouts; pick per context.

#### 5.5.1 PropertyCard — vertical (Home "أحدث الإعلانات", Search results, Favorites, My Listings)

```
┌─────────────────────────────────┐
│   [4:3 image, full-bleed]   [♡] │  ← image with favorite overlay top-trailing
│ [للبيع]                          │  ← purpose chip, top-leading, primary fill
│ [مميز]                           │  ← featured badge (warning fill), bottom-leading on image
├─────────────────────────────────┤
│ شقة فاخرة في المزة         titleLarge
│ 📍 دمشق - المزة              bodyMedium textSecondary
│ 85,000,000 ل.س                 priceMedium primary
│ 🛏 3   🛁 2   📐 180 م²        labelMedium textSecondary
└─────────────────────────────────┘
```

- Card: `card` bg, `md` radius, `elevation 1`, `md` (12) inner padding.
- Tappable surface = entire card. Tap → Property Details.
- Long-press: shows a context menu with Save / Share / Report.

#### 5.5.2 PropertyCard — horizontal (Home "عقارات مميزة" carousel)

Same content, but image is 16:10 and card is constrained to 280 dp wide. Used in horizontal-scroll rows.

### 5.6 OfficeCard

Used on the office directory and office profile suggestions.

```
┌───────────────────────────────────┐
│ [logo]  مكتب النخبة العقاري        │
│         📍 دمشق ✔ موثّق             │
│         12 إعلان نشط                │
│                          [زيارة →] │
└───────────────────────────────────┘
```

### 5.7 Buttons

| Variant | Use |
|---|---|
| `Filled.primary` | Primary action on a screen ("تسجيل الدخول"). |
| `Filled.success` | Positive action ("تواصل عبر واتساب"). |
| `Outlined` | Secondary action ("إنشاء حساب جديد"). |
| `Tonal` | Mid-emphasis ("تطبيق الفلتر"). Background = `primaryContainer`. |
| `Text` | Tertiary ("نسيت كلمة السر؟"). |
| `Destructive` | Delete / unpublish ("حذف الإعلان"). Filled with `danger`. |
| `IconButton` | Single-tap actions in app bars. |
| `FAB` | Map-only "تحديد موقعي". |

Sizes:
- Regular: 48 dp tall (default).
- Dense: 36 dp tall (used inside cards or in tight rows like image gallery thumbnails).

States: default · pressed · focused · loading (inline spinner replacing label) · disabled (50% opacity, no shadow).

### 5.8 Form fields

**Anatomy**: label (above field) · input · helper / error text (below field).

**Variants**:
- `Text input`
- `Phone input` (with `+963` country-code prefix dropdown)
- `Password input` (with eye toggle)
- `Multi-line input` (description fields)
- `Number input` (with leading/trailing unit suffix like `م²` or `ل.س`)
- `Currency input` (USD / SYP toggle)
- `Dropdown / select`
- `Stepper` (− value +)
- `Date picker`
- `Toggle / switch`
- `Checkbox`
- `Radio` group / segmented control

**States**: idle · focused · filled · error (border + helper text in `danger`) · disabled.

### 5.9 Tabs / segmented control

Used for "للبيع / للإيجار" toggles, currency switches, and the chat list filter.

- 2- and 3-segment variants.
- Selected segment = `primary` filled, `onPrimary` label.
- Underline-style tabs (4+ items): primary underline 2 dp, label `labelLarge`.

### 5.10 Badges

Small status markers, never tappable.

| Badge | Style | Example |
|---|---|---|
| `Featured` | `warning` fill, `card` text | "مميّز" |
| `New` | `accent` fill, `onPrimary` text | "جديد" |
| `Status: Pending` | `warning` outline, `warning` text | "قيد المراجعة" |
| `Status: Approved` | `success` outline, `success` text | "نشط" |
| `Status: Rejected` | `danger` outline, `danger` text | "مرفوض" |
| `Verified office` | `success` fill, `onPrimary` text + check icon | "موثّق" |

### 5.11 Bottom sheet (filter, sort, gallery)

See § 4.3 + § 7.9 for the filter sheet specifics.

### 5.12 EmptyState

A reusable composition: illustration → headline → body → CTA. Variants per screen are content-only — the layout is identical.

### 5.13 Stepper / progress indicator (multi-step forms)

A horizontal bar of N segments. Completed = `success` fill; current = `primary` fill; future = `border` fill. Step label "(1/7)" sits trailing.

### 5.14 Image gallery / carousel

- Pageable horizontally (RTL-aware).
- Bottom-overlaid `3 / 12` style page indicator.
- Tap-to-fullscreen with pinch-zoom.

### 5.15 Map preview

Used inside Listing Details. A static OpenStreetMap tile cropped to 16:9 with a single marker. Tap → opens dedicated Map screen with all listings in the area.

### 5.16 ChatBubble

- **Mine**: `primary` fill, `onPrimary` text, trailing-aligned (left in RTL because the message comes *from* you and reads inward).
- **Theirs**: `card` fill, `border` 1px, `textPrimary` text, leading-aligned.
- Timestamp `labelMedium textMuted` underneath, subtle.

### 5.17 PriceTag

Reusable text component for prices: bold primary number + currency suffix, with optional secondary line "≈ value in alternate currency" in `textSecondary`. Used on cards, details, and chat property previews.

### 5.18 PaletteTester (debug + design-review only)

A floating chip that **cycles the active palette** (Modern ⇄ Trust) without rebuilding the app. Exists so the team can compare both blues on real screens before committing.

**Anatomy**:

```
┌────────────────────────┐
│ ● Modern  ⇄            │   ← color swatch dot (active primary) + name + cycle icon
└────────────────────────┘
```

- Pill, 32 dp tall, `card` background, 1 px `border`, `md` (12) horizontal padding.
- Swatch: 12 dp circle filled with the active `primary`.
- Label: `labelMedium` showing palette name ("Modern" / "Trust").
- Cycle icon: `lucide:repeat-2`, 16 dp, `textSecondary`.

**Position**:

- **Top-leading** corner of the screen, inset `lg` (16) from each edge, with a top safe-area inset.
- Floats above content (elevation 2). Never blocks a primary touch target — if the chip's hit area overlaps an interactive element, the chip yields hit-testing.

**States**:

- **Idle**: as drawn above.
- **Pressed**: scale 0.95 for 80 ms, then a 200 ms color cross-fade as the new palette propagates.
- **After cycle**: snackbar — "تم تبديل الألوان: Trust" / "Modern" — auto-dismiss 2 s.
- **Long-press**: opens a fullscreen palette explorer modal showing every token side-by-side for both palettes (light + dark).

**Behavior & gating**:

- Visible **only** when `AppFlags.designToolsEnabled` is true. In production builds this flag is `false`; in debug + internal QA builds it's `true`. End users never see this chip.
- Persists the chosen palette in `SharedPreferences` under key `app.palette` so reload preserves the choice.
- Cycling order: `Modern → Trust → Modern` (extensible if we add a third palette later).
- Tapping triggers a `PaletteChanged` event on the global theme `Cubit`; every screen rebuilds via `Theme.of(context)` — no per-widget plumbing.

**Why a chip and not a settings toggle**:

- Visible on every screen at once → easy A/B comparison without leaving the surface being tested.
- Doesn't pollute the real Settings screen with dev-only options.
- Mirrors the same pattern in Figma (a button on every frame wired to a Figma Variable) — § 4.13 of [`figma-prompts.md`](figma-prompts.md).

**Removing it for prod**: tree-shaken. The widget references a const `kDesignToolsEnabled` (the single design-tools flag, shared with the Theme Gallery) that resolves to `false` in release builds, so the entire branch + its assets are stripped.

---

## 6. Bottom navigation

5 items, RTL ordering. Active item shows label in `primary` and a 2 dp top accent bar; inactive items show icon + label in `textSecondary`.

| Order (RTL leading→trailing) | Tab | Icon |
|---|---|---|
| 1 | الرئيسية | `home` |
| 2 | البحث | `search` |
| 3 | إضافة | `plus-circle` (filled, primary, slightly larger) |
| 4 | المفضلة | `heart` |
| 5 | حسابي | `user` |

Behavior:
- Tap tab → navigate to that root.
- Tap active tab → scroll to top + reset stack.
- "إضافة" tab does not navigate — it opens the Add Listing modal flow as a full-screen sheet over the current tab.

Height: 64 dp (above gesture bar). Background: `card` with `elevation 2` upward.

---

## 7. Screens

For each screen below: **Purpose · Layout (top-to-bottom) · Key interactions · States · Edge cases**.

### 7.1 Splash

- **Purpose**: brand boot screen during app init.
- **Layout**: centered logo (`displayLarge` "النجوم"), tagline `bodyLarge` ("بيتك يبدأ من هنا") on `surface` background, subtle 2 dp progress bar at bottom safe area.
- **Duration**: ≤ 1.5 s. Never trap the user here — if init fails, route to a friendly error screen with a "إعادة المحاولة" button.

### 7.2 Onboarding (3 frames)

- **Purpose**: orient first-run users to the value proposition.
- **Layout per frame**: top 60% illustration; bottom 40% headline + body + page indicator (3 dots) + footer with "تخطّي" leading and "التالي" trailing. Last frame trades "التالي" for "ابدأ".
- **Frame copy**:
  1. **ابحث عن العقار المناسب** — اعرض أفضل العقارات بسهولة وسرعة.
  2. **بيع أو أجر عقارك بسهولة** — انشر إعلانك خلال دقائق ووصلك للزبائن.
  3. **تواصل مباشر وآمن** — اتصل، راسل، احفظ ما يهمك.
- **Skip behavior**: routes straight to Login. No "remember me skipped" — show onboarding once per install only (gated by local preference flag).

### 7.3 Login

- **Purpose**: returning user authenticates by phone + password.
- **Layout**:
  1. AppBar transparent with leading back arrow (only if reachable from non-root).
  2. Brand mark "النجوم" (`headlineLarge`), tagline.
  3. Phone field (with `+963` prefix).
  4. Password field (with eye toggle).
  5. "نسيت كلمة السر؟" trailing-aligned text link.
  6. Filled-primary "تسجيل الدخول" full-width.
  7. Divider with "أو" centered.
  8. Outlined "إنشاء حساب جديد".
  9. Tertiary text "متابعة كزائر" (Continue as guest).
  10. Footer micro-links: شروط الاستخدام · سياسة الخصوصية.
- **States**:
  - Default · Loading (button spinner) · Field error (helper text in `danger`) · Auth failure (snackbar "رقم الهاتف أو كلمة السر غير صحيحة").
- **Edge cases**: "متابعة كزائر" routes to Home with limited write actions — favoriting and posting trigger a "سجّل دخولك أولاً" sheet.

### 7.4 Register

- **Purpose**: new user creates an account.
- **Layout**:
  1. AppBar with back arrow + title "إنشاء حساب".
  2. Account type segmented control: "مستخدم" / "مكتب عقاري".
  3. Full name (required).
  4. Phone (`+963` prefix).
  5. City dropdown.
  6. Password + confirm password (with strength meter).
  7. Email (optional, helper "يلزم لاستعادة كلمة السر فقط").
  8. Checkbox "أوافق على شروط الاستخدام وسياسة الخصوصية" — required.
  9. Filled-primary "إنشاء الحساب".
  10. Footer: "عندك حساب؟ سجّل الدخول".
- **Office account variant**: shows extra fields (office name, license number, logo upload) inside an expanding section after toggling.
- **Submit success**: routes to Pending Approval screen (§ 7.5).

### 7.5 Pending approval

- **Purpose**: post-registration limbo, awaiting admin approval.
- **Layout**: centered illustration (hourglass), `headlineMedium` "بانتظار الموافقة", `bodyMedium` "حسابك قيد المراجعة من قبل الإدارة. عادةً تستغرق العملية أقل من 24 ساعة.", outlined "تواصل مع الدعم" CTA, text-link "تسجيل الخروج" in `danger` at bottom.
- **No bottom nav** — this screen gates further navigation.
- **Polling**: silently refetches account status every 30 s; on approval, transitions to Home with a celebratory snackbar "تم اعتماد حسابك ✓".

### 7.6 Home

> The Figma comp matches this screen — implementation should mirror it pixel-by-spec.

- **Purpose**: discovery surface — search-first, with featured + recent listings.
- **Layout** (top to bottom, all under bottom nav):
  1. **AppBar**: leading logo + brand "النجوم للعقارات" (`headlineMedium primary`), trailing notification bell with unread dot (`danger` fill).
  2. **Search bar look-alike**: `pill`, `surfaceVariant`, leading search icon, placeholder "ابحث عن شقة، منزل، محل…". Tap → Search screen.
  3. **LocationSelector**: `📍 المدينة / المنطقة` with chevron.
  4. **Category chips row** (horizontal scroll): شقق · منازل · محلات · مكاتب · أراضي · مزارع.
  5. **Promo banner**: 4:3-ish gradient card (`primary` → `accent`), white headline "عروض مميزة اليوم", subtitle "اكتشف أفضل العقارات المختارة لك", small "تصفح الآن" pill button.
  6. **Section: "عقارات مميزة"** — section header `headlineMedium`, "عرض الكل" link trailing, horizontal-scroll PropertyCard carousel.
  7. **Section: "أحدث الإعلانات"** — section header, vertical-list PropertyCards.
  8. **Bottom navigation** (sticky).
- **Pull-to-refresh** rebuilds featured + latest sections.
- **States**: populated · loading skeleton (4 placeholder cards) · empty ("لا توجد إعلانات بعد — كن أول من يضيف عرضاً" + "أضف إعلاناً" CTA).
- **Anonymous variant**: tapping the heart icon on a card surfaces a sign-in prompt sheet.

### 7.7 Search

- **Purpose**: dedicated search input + recent searches + suggestions.
- **Layout**:
  1. AppBar with persistent SearchField (focused on entry); back arrow leading.
  2. **Recent searches**: a list of last 10 queries with leading clock icon and trailing remove-X.
  3. **Suggested cities**: chips row (دمشق · حلب · حمص · اللاذقية · طرطوس · حماة).
  4. **Trending searches**: small list — text-only items.
- **Behavior**: typing debounces 300 ms then runs query; results screen replaces this view via push.

### 7.8 Search results

- **Purpose**: paginated list of listings matching a query / filter.
- **Layout**:
  1. AppBar with persistent SearchField (showing the active query) + filter icon trailing.
  2. **Result count + sort row**: "127 عرض" leading, sort dropdown trailing ("الأحدث" / "السعر: من الأرخص" / "السعر: من الأغلى" / "الأكثر مساحة").
  3. **Active filter chips strip** (horizontal scroll): each chip shows a label + ×; tap × removes that filter and re-runs the query. Trailing "مسح الكل" link if 2+ active.
  4. **Tabs / chips for purpose**: للبيع · للإيجار · مفروش · تجاري — a quick toggle that re-applies a single filter dimension on top of the current query.
  5. **Results list**: vertical PropertyCards, paginated with infinite scroll. Skeleton on next-page load.
  6. **Sticky FAB** (optional): "عرض على الخريطة" — opens Map view scoped to the current results.
- **Empty state**: "لم نجد عقارات تطابق بحثك — جرّب تعديل الفلاتر" + outlined "إعادة الفلاتر" + filled "تعديل الفلاتر".
- **Error state**: "حدث خطأ في تحميل النتائج" + Retry.

### 7.9 Filter sheet

- **Purpose**: build a structured filter on top of the current search.
- **Layout** (modal bottom sheet, ~85% screen height):
  1. Drag handle.
  2. Header: title "تصفية النتائج" trailing-aligned, "إعادة" link in `danger` leading.
  3. **Sections** (each with `headlineMedium` header):
     - **نوع العرض** — segmented للبيع / للإيجار / مفروش / تجاري.
     - **نوع العقار** — wrap of pill chips, multi-select.
     - **الموقع** — three cascading dropdowns: محافظة, مدينة, منطقة.
     - **السعر** — currency toggle USD / SYP + dual-thumb min-max slider with side number inputs.
     - **المساحة** — dual-thumb slider (m²) + side inputs.
     - **عدد الغرف** — stepper 0–5+.
     - **عدد الحمامات** — stepper 0–3+.
     - **الطابق** — dropdown (أرضي / 1 / 2 / …).
     - **حالة العقار** — chips: مفروش / غير مفروش.
     - **عمر العقار** — dropdown (جديد / أقل من 5 سنوات / 5–10 / 10+).
     - **المميزات** — wrap of pill chips multi-select: مصعد · كراج · بلكون · مفروش · مكيف · حديقة · تدفئة.
  4. **Sticky footer**: filled-primary "تطبيق (127)" full-width — the count updates as filters change.

### 7.10 Property Details

- **Purpose**: the conversion surface — convince + contact.
- **Layout**:
  1. **Image gallery** (top ~45% of screen): horizontal pageable carousel; bottom-overlaid page indicator; expand-to-fullscreen icon top-trailing.
  2. **Floating top action bar** (overlaid frosted glass): leading back arrow; trailing favorite, share, report (kebab) icons.
  3. **Sticky title section** (under gallery): title `headlineLarge`; price `priceLarge` in `primary`; secondary price (alternate currency) `bodyMedium textSecondary`.
  4. **Status row**: featured badge if applicable, "جديد" if posted < 24h, listing date "نُشر قبل 3 أيام" `bodyMedium textSecondary`.
  5. **Quick-facts row** — 4 stat cards on a horizontal row: 🛏 الغرف · 🛁 الحمامات · 📐 المساحة · 🏢 الطابق. Each card has icon + value + label.
  6. **Property specs section**: `headlineMedium` header "التفاصيل" + key/value rows (نوع العقار, حالة العقار, العمر).
  7. **Description**: `headlineMedium` "الوصف" + `bodyLarge` text. Truncate at 4 lines with "اقرأ المزيد".
  8. **Amenities**: `headlineMedium` "المميزات" + wrap grid of icon+label items.
  9. **Map preview**: static map 16:9 with marker, address text below. Tap → Map view focused on this listing.
  10. **Advertiser card**: avatar + name + verified badge if applicable + "زيارة الصفحة" trailing link → Office Profile or User Profile.
  11. **Similar properties section**: horizontal carousel of related PropertyCards.
  12. **Sticky bottom CTA bar** (over content with safe-area inset): three buttons in a row — اتصال (filled-primary) · واتساب (filled-success) · رسالة (outlined). Heart icon and share icon as side IconButtons before the first button.
- **Inquiry sheet** (when "رسالة" tapped): modal bottom sheet with name (prefilled if logged in), phone, message textarea, "إرسال" filled-primary CTA.
- **Edge cases**:
  - Listing sold/rented: bottom CTAs replaced by a banner "هذا العرض لم يعد متاحاً" + outlined "عقارات مشابهة".
  - No images: large `primaryContainer` placeholder with property-type icon — gallery still shows but with a single placeholder slide.

### 7.11 Favorites

- **Purpose**: see saved listings.
- **Layout**:
  1. AppBar title "المفضلة" + trailing "تحديد متعدد" icon (entering a select mode for bulk-remove).
  2. Sort dropdown above list ("بحسب الإضافة" / "بحسب السعر").
  3. Vertical list of PropertyCards. Heart icon is filled `danger`; tap removes (with snackbar "تمت الإزالة" + "تراجع" action).
- **Empty state**: heart-outline-with-house illustration; headline "لا توجد مفضلات بعد"; body "اضغط على القلب في أي عرض لإضافته هنا"; "تصفّح العروض" CTA.
- **Anonymous variant**: shows the empty state with "سجّل دخولك للحفظ" CTA → Login.

### 7.12 Add Listing — multi-step (7 steps)

A full-screen modal flow opened from the bottom-nav "إضافة" tab.

**Common chrome**:
- AppBar: leading × close (with confirm-discard dialog if changes pending), title "إضافة إعلان", trailing "حفظ كمسودّة" text link.
- Stepper bar: 7 segments. Sticky footer: outlined "السابق" leading (disabled on step 1) + filled "التالي" trailing (becomes "نشر" on step 7).

**Step 1 — نوع العقار**:
- Section header + subhead "اختر نوع العقار".
- 2-column grid of 6 type cards (each card = `card` bg, `md` radius, icon + label, single-select with `primary` border + `primaryContainer` fill on selection): شقة · منزل · محل · مكتب · أرض · مزرعة.
- This matches the second Figma screenshot.

**Step 2 — نوع العملية**:
- Segmented control (full-width tonal): للبيع · للإيجار.
- Below: radio group for sub-modes ("يومي" / "شهري" / "سنوي") if "للإيجار" selected.

**Step 3 — التفاصيل الأساسية**:
- عنوان الإعلان (text).
- المدينة (dropdown).
- المنطقة (dropdown, dependent on city).
- العنوان التفصيلي (text, optional).
- السعر (currency input + USD/SYP toggle).
- المساحة (number with `م²` suffix).
- عدد الغرف (stepper).
- عدد الحمامات (stepper).
- الطابق (dropdown).
- وصف العقار (multi-line, character count `0/1000`).

**Step 4 — المميزات**:
- Wrap of pill toggle chips: مصعد · كراج · بلكون · مفروش · مكيف · حديقة · تدفئة · إنترنت · كاميرات أمنية · حارس بناء.

**Step 5 — الصور**:
- Grid of 10 image slots (3 columns).
- Empty slot = `primaryContainer` bg, dashed border, plus icon, "أضف صورة" label.
- Filled slot = thumbnail with × delete top-trailing; first slot has a "رئيسية" badge top-leading (drag-to-reorder enables changing the main).
- Below grid: "فيديو (اختياري)" with single field for a video URL or upload button (≤30 MB).
- Helper line: "أضف 3 صور على الأقل لإعلان أفضل".

**Step 6 — معلومات التواصل**:
- الاسم (prefilled).
- رقم الهاتف (prefilled, editable).
- واتساب (toggle: نفس رقم الهاتف؟ + secondary input if not).
- إظهار رقم الهاتف للزوار — toggle (default: on).

**Step 7 — مراجعة ونشر**:
- A read-only preview rendered as a real PropertyCard at the top.
- Below: collapsible sections for each step's data with edit icons (tap → returns to that step).
- Footer: outlined "حفظ كمسودّة" + filled-primary "نشر الإعلان".
- After publish: success screen "تم إرسال إعلانك للمراجعة" with illustration + "العودة للرئيسية" CTA.

### 7.13 My Listings

- **Purpose**: manage user's posted listings.
- **Layout**:
  1. AppBar title "إعلاناتي" + trailing "+" IconButton → Add Listing flow.
  2. Tabs: نشط · قيد المراجعة · مباع/مؤجّر · مرفوض · مسوّدة.
  3. Vertical list of PropertyCards with status chip overlay (top-leading) + per-card menu (kebab) with: تعديل · إيقاف مؤقت · حذف · "ترقية الإعلان" (post-v1, shown disabled with "قريباً" label).
- **Empty state per tab**: "ليس لديك إعلانات [في هذه الحالة] بعد" + "أضف إعلاناً جديداً" CTA on the active tab only.

### 7.14 Messages (conversation list)

- **Purpose**: inbox for chats around listings.
- **Layout**:
  1. AppBar title "الرسائل" + trailing search icon.
  2. Optional segmented filter: الكل · غير المقروءة · أرشيف.
  3. List items, each row 72 dp tall:
     - Leading: 48 dp circular avatar of the other party.
     - Content: name (`titleMedium`), last message preview (`bodyMedium textSecondary`, truncate 1 line).
     - Trailing: 40 × 40 thumbnail of the listing this conversation is about + timestamp `labelMedium` above + unread dot below if unread.
- **Empty state**: speech-bubble illustration; "لا توجد محادثات بعد"; "ابدأ بمراسلة صاحب أي عرض يهمك"; "تصفّح العروض" CTA.

### 7.15 Chat detail

- **Purpose**: 1:1 conversation around a specific listing.
- **Layout**:
  1. AppBar with back arrow + leading 32 dp avatar + name + "متصل الآن"/`بدأ منذ N` `labelMedium`. Trailing: phone icon and WhatsApp icon as IconButtons.
  2. **Property preview banner** (sticky under AppBar): 56 dp tall row — listing thumbnail + title + price + chevron. Tap → Property Details.
  3. Message thread (scrollable, newest at bottom): ChatBubbles with day-separator chips ("اليوم" / "أمس" / "12 أبريل").
  4. Sticky composer: text input (multi-line, 1–4 lines), trailing send button (filled-primary IconButton). Leading attachment icon (image / location). Mic icon trailing for voice notes (post-v1; show disabled).

### 7.16 Notifications

- **Purpose**: surface app-driven events.
- **Layout**: vertical list of notification rows; tappable.
  - Leading colored icon by type:
    - Listing approved → `success` check.
    - Listing rejected → `danger` cross.
    - New message → `primary` chat.
    - Price drop on favorite → `warning` price-tag.
    - Promotion alert → `accent` star.
  - Content: `titleMedium` line + `bodyMedium textSecondary` line + relative time.
  - Unread items: `primaryContainer` background tint.
- **Header action**: trailing "تحديد الكل كمقروء".
- **Empty state**: bell illustration; "لا توجد إشعارات".

### 7.17 Office Profile

- **Purpose**: branded landing page for a real-estate office.
- **Layout**:
  1. **Hero**: 16:9 cover image + 30% dark overlay; centered logo (96 dp circle); office name (`headlineLarge` on `surface`-against-overlay text); city + verified badge.
  2. AppBar: transparent over hero; back arrow + share icon + (if owner) "تعديل" trailing.
  3. **Stats row**: 3 cards — `إعلانات نشطة` · `مبيعة/مؤجرة` · `سنوات الخبرة`.
  4. **About**: `headlineMedium` "نبذة" + `bodyLarge` text.
  5. **Contact card**: phone, WhatsApp, address, hours; `Filled.primary` "تواصل" + `Filled.success` "واتساب".
  6. **Listings tabs**: نشطة · مباعة/مؤجرة · مؤرشفة. Below: vertical PropertyCards.
- **States**: own-office variant exposes "تعديل" + "إضافة إعلان" FAB.

### 7.18 User Profile

- **Purpose**: account hub for non-office users.
- **Layout**:
  1. AppBar title "حسابي".
  2. **Profile card**: 80 dp avatar + name + phone + status chip ("معتمد" / "قيد المراجعة"). Trailing "تعديل" link.
  3. **Stats row**: 3 mini-cards — إعلاناتي · المفضلة · الاستفسارات.
  4. **Section list** (rows 56 dp, leading icon + label + trailing chevron):
     - إعلاناتي
     - المفضلة
     - الاستفسارات
     - الرسائل
     - الإشعارات
     - --- divider ---
     - الإعدادات
     - الدعم
     - عن التطبيق
     - --- divider ---
     - تسجيل الخروج (in `danger`)
  5. Footer: app version `labelMedium textMuted`.

### 7.19 Settings

- **Purpose**: preferences and account control.
- **Layout** (rows like 7.18):
  - **Account**: تعديل الملف الشخصي · تغيير كلمة السر · تغيير رقم الهاتف.
  - **App**:
    - اللغة → trailing value "العربية" → opens picker (العربية / English).
    - المظهر → "تلقائي" / "فاتح" / "داكن" → opens segmented picker.
    - العملة المفضلة → "ل.س" / "$".
    - الإشعارات → opens sub-screen with category toggles.
    - الخصوصية → opens sub-screen.
  - **Help**:
    - مركز المساعدة
    - تواصل مع الدعم
    - شروط الاستخدام
    - سياسة الخصوصية
    - عن التطبيق (version, build, licenses).
  - **Danger zone**:
    - تسجيل الخروج (`danger` label).
    - حذف الحساب (`danger` label, requires re-auth confirm).

### 7.20 Map view (mentioned in plan, included for completeness)

- **Purpose**: spatial discovery.
- **Layout**:
  1. Full-bleed OpenStreetMap tile background.
  2. Floating SearchField pinned to top safe area + filter icon.
  3. Markers — `primary` rounded squares with price label "$95K"; clustered when overlapping ("+12").
  4. Bottom sheet — peek 120 dp showing the focused listing as a horizontal PropertyCard. Drag up reveals full list.
  5. FAB trailing-bottom: "تحديد موقعي".
  6. Bottom-leading attribution chip: "© OpenStreetMap" (license-required, must remain visible).

### 7.21 Empty states (catalog)

Every empty state follows the same layout (illustration → headline → body → CTA). Per-screen copy:

| Screen | Headline | Body | CTA |
|---|---|---|---|
| Home | "لا توجد إعلانات بعد" | "كن أول من يضيف عرضاً" | أضف إعلاناً |
| Search results | "لا توجد نتائج" | "جرّب تعديل الفلاتر أو وسّع نطاق البحث" | تعديل الفلاتر |
| Favorites | "لا توجد مفضلات بعد" | "اضغط على القلب في أي عرض لإضافته هنا" | تصفّح العروض |
| Messages | "لا توجد محادثات بعد" | "ابدأ بمراسلة صاحب أي عرض يهمك" | تصفّح العروض |
| My Listings | "ليس لديك إعلانات بعد" | "أضف أول إعلان لك" | أضف إعلاناً |
| Notifications | "لا توجد إشعارات" | "ستظهر إشعاراتك هنا عند وصولها" | (none — no CTA) |
| Network error | "حدث خطأ" | "تأكد من الاتصال بالإنترنت وحاول مرة أخرى" | إعادة المحاولة |

### 7.22 Error & confirmation dialogs

- **Discard listing draft**: "حذف المسوّدة؟" / "ستفقد كل التغييرات التي لم تُحفظ." / cancel + "حذف" (`danger`).
- **Delete listing**: "حذف الإعلان؟" / "لا يمكن التراجع عن هذا الإجراء." / cancel + "حذف" (`danger`).
- **Logout**: "تسجيل الخروج؟" / cancel + "خروج" (`danger`).
- **Sign-in prompt** (for guests trying to favorite/post): "سجّل دخولك للمتابعة" / "تحتاج لحساب للحفظ والإضافة." / "إنشاء حساب" + "تسجيل الدخول".

---

## 8. Motion & micro-interactions

| Element | Animation |
|---|---|
| Bottom-nav tab switch | Cross-fade label color 120 ms; icon scale 0.95→1 in 80 ms. |
| Heart toggle | Heart scales 1→1.3→1 in 240 ms with overshoot; color cross-fades. |
| Card tap | 80 ms scale-down to 0.98, release back. |
| Sheet open | 240 ms `easeOutCubic` slide-up + scrim fade-in. |
| Image carousel page change | 280 ms slide. |
| Stepper progress fill | 200 ms `easeInOutCubic` width grow. |
| Snackbar | 200 ms slide-up; 4 s linger; 200 ms slide-down. |
| Map marker selection | Marker scales 1→1.2 + bottom sheet peeks up. |

Avoid: long-form hero animations, parallax scrolling, anything > 400 ms on a routine action. The app feels fast because it doesn't waste the user's time.

---

## 9. Accessibility & RTL checklist

Every screen must clear this list before being signed off.

- [ ] All text/icon contrast ≥ **4.5:1** body, **3:1** large text & UI elements.
- [ ] All touch targets ≥ **48 × 48 dp**.
- [ ] No color-only state signals — color is always paired with an icon or text label.
- [ ] All directional padding/margins use `EdgeInsetsDirectional` (Constitution V).
- [ ] Back-arrow icons mirror under RTL (use `Icons.arrow_back_ios_new` with `Directionality.of(context)` aware mirror, or the dedicated `chevron_forward` in RTL).
- [ ] Numeric values (prices, areas, room counts) render correctly in RTL — right-to-left readers expect numbers + Arabic digits to read naturally.
- [ ] Form fields announce their label and error to screen readers (`Semantics(label: …, value: …)`).
- [ ] Image avatars and icons that carry meaning have `Semantics.label`; decorative icons use `excludeSemantics`.
- [ ] Font scales correctly under system text-size 100% / 130% / 200% — nothing clips, no horizontal scroll appears.
- [ ] Dark theme honestly passes the same checks.

---

## 10. Implementation notes for Flutter

> Constitution-aligned (see `.specify/memory/constitution.md`). Treat these as guardrails for the eventual `lib/feature/<screen>/` widgets.

### 10.1 Tokens, not hex literals

- No `Color(0xFFXXXXXX)` in feature code. Read from `Theme.of(context).colorScheme.<role>` or a typed `AppColors` wrapper that maps tokens to `colorScheme`.
- Same for spacing — use `AppSpacing.lg`, not `16`.
- Same for radii, type styles, shadows.

### 10.2 Directional everything

- `EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)`.
- `Alignment.centerStart` / `Alignment.centerEnd`.
- `PositionedDirectional` for stack overlays.
- Test under `Directionality.rtl` AND `Directionality.ltr` in widget tests.

### 10.3 Component structure (one widget = one file)

Each component in § 5 maps to a single Dart file under `lib/core/widgets/<component>.dart`. Screens compose components — they don't redefine button or card styles inline. If a screen needs a one-off variant, escalate to a new component spec; don't inline.

### 10.4 State management

- **BLoC / Cubit** per screen, per [Constitution Principle IV](`.specify/memory/constitution.md`).
- Each screen has a `<Screen>State` sealed class: `Initial`, `Loading`, `Success(data)`, `Empty`, `Failure(message)`. Map UI states 1:1 from this — no ad-hoc booleans.

### 10.5 Routing

- `go_router` declarative routes — see [Implementation Plan §2](IMPLEMENTATION_PLAN.md). Every screen has a stable path; deep links into Listing Details and Office Profile must work.

### 10.6 Localization

- `flutter_localizations` + ARB files. Every visible string lives in `app_ar.arb` first, then `app_en.arb`. No hardcoded Arabic in widget code.
- Plurals use ICU select syntax in ARB (e.g., `{count, plural, one{عرض واحد} two{عرضان} few{# عروض} many{# عرضاً} other{# عرض}}`).

### 10.7 Image loading

- `cached_network_image` with the placeholder strategy from § 3.2.
- All listing thumbnails are responsive — request a sized variant from the CDN (Phase 2 wiring), never load the full-resolution photo for a card.

### 10.8 Performance budgets

- Home first frame < 1 s on the Infinix Note 8 reference device.
- Card list scroll holds 60 fps with 50+ items.
- Image gallery swipe < 16 ms per frame.
- Run `flutter run --profile` on the reference device before declaring any feature done.

---

## 11. Locked decisions (with rationale)

The seven calls below are made and the document treats them as load-bearing. Each can still be revisited, but only by an explicit ADR — not by drift.

### 11.1 Palette: Modern (`#1D4ED8`) is default; Trust (`#2457A6`) is a runtime alternate

- **Decision**: Ship both palettes (§ 2.1) behind the runtime PaletteTester chip (§ 5.18). Default = **Modern**.
- **Why**: Modern matches the comp the team is currently reviewing, sits in the same trust-blue family as `#2457A6`, but reads fresher for a marketplace where buyers are scanning lots of listings. Carrying Trust as a swappable alternate costs ~12 hex values and one Cubit — cheap insurance against committing wrong.
- **Implication**: `decision.md` Direction B's primary should be updated to `#1D4ED8` (with `#2457A6` archived as the "Trust" alternate). One ADR, then archive.

### 11.2 Bottom navigation: 5 tabs

- **Decision**: 5 tabs in RTL order — الرئيسية · البحث · إضافة · المفضلة · حسابي.
- **Why**: this is the marketplace pattern (وسيطك, OLX, Airbnb, Dubizzle). A dedicated central "إضافة" CTA is essential for a posting-driven app — burying "Add Listing" inside the profile menu kills posting volume. The older 4-tab variant in `figma-prompts.md` is superseded.
- **"إضافة" is special**: it does not navigate; it opens the multi-step Add Listing modal flow over the current tab. Icon is filled `primary` and slightly larger (28 dp vs 24 dp) to signal its central-action role.

### 11.3 Typography: Cairo + IBM Plex Sans Arabic + Inter

- **Decision**: Cairo (display / headline / title), IBM Plex Sans Arabic (body / label), Inter (Latin, all weights). Match § 2.3.
- **Why**: Cairo has the best Arabic display rendering at marketplace headline sizes (16–28 dp); IBM Plex Sans Arabic is the recognized body champion for paragraph readability in Syrian Arabic; Inter pairs cleanly with both at numeric/weight parity. Tajawal was considered and rejected — too monoline at headline weights.
- **Vendoring**: all three fonts under `assets/fonts/` declared in `pubspec.yaml` (Phase 2 task).

### 11.4 Map markers: price-label rounded squares + clusters

- **Decision**: Markers are `primary`-filled rounded squares (`md` radius) showing the listing price as `labelLarge` `onPrimary` text (e.g., "$95K" / "85م ل.س"). Overlapping markers cluster as `primary`-filled circles with `+12` count.
- **Why**: marketplace users compare prices spatially. A price label carries more information per pixel than a colored pin and reduces tap-explore-tap-back churn. Cluster circles keep dense areas legible.
- **Provider**: locked to `flutter_map` + OpenStreetMap tiles (per IMPLEMENTATION_PLAN §2). Attribution chip is mandatory.

### 11.5 Office profile = User profile shell + Office extension

- **Decision**: shared base widget (avatar, name, contact rows, settings stub) + an Office-only extension that adds the 16:9 hero cover, 3-stat row, and listings tabs.
- **Why**: DRY — both profile types share ~70% of their structure. Office-specific affordances live in a single conditional region, gated by `account.type == office`. Easier to maintain than two parallel screens.
- **Implication**: § 7.17 and § 7.18 in this doc describe the rendered output; the implementation is one widget tree with role-conditional regions, not two screens.

### 11.6 Chat voice notes & rich attachments: post-v1

- **Decision**: text + image attachments in v1. Voice notes, location share, and document attach are post-v1.
- **Why**: voice notes need recording UX, server-side transcoding, and storage budget that's out of scope for v1. Hide nothing — show the mic icon as **disabled** with a tooltip "قريباً" so users see the roadmap.

### 11.7 Promoted-listing UI: visible but disabled

- **Decision**: in My Listings (§ 7.13), the per-card menu shows "ترقية الإعلان" disabled with "قريباً" trailing label.
- **Why**: per IMPLEMENTATION_PLAN, the schema is ready but the checkout flow is post-v1. Telegraphing the feature builds anticipation without overpromising; hiding it makes the eventual launch feel bolted-on.

---

> Once a stakeholder signs off on these seven calls, this document graduates from DRAFT to **source-of-truth** and feeds spec 002+ widget tasks directly. The PaletteTester chip stays in the codebase indefinitely — gated behind the design-tools flag — so palette comparisons remain a one-tap operation for the lifetime of the project.
