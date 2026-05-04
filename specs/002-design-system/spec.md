# Feature Specification: Design System & Theme Tokens

**Feature Branch**: `002-design-system`
**Created**: 2026-05-02
**Status**: Draft
**Input**: User description: "Phase 2 — Design system & theme tokens. A complete themed token module and a kit of reusable widgets used by every later phase, derived from the locked Modern Marketplace direction (`docs/design/decision.md`) and the screens & components catalog (`docs/design/screens-and-components.md`)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build any feature screen using only design-system tokens and components (Priority: P1)

A developer composing a new feature screen (Home, Listing Details, Settings, etc.) opens the design system, picks the components they need (AppBar, SearchField, PropertyCard, Buttons, FormFields, EmptyState, etc.), and assembles the screen entirely from those building blocks — without ever writing a raw color value, typography style, spacing measurement, radius, or elevation. Every visual decision they need is already named, documented, and rendered identically across light/dark themes and Arabic/English locales.

**Why this priority**: This is the foundation every subsequent phase depends on. If feature screens can't reliably reach for tokenized components, drift starts on day one — colors creep, typography scatters, spacing becomes a guessing game, and accessibility regressions ship unnoticed. Without P1, Phases 4–24 each pay an interest tax.

**Independent Test**: A developer (or AI agent) can build a brand-new screen — say, a stub "About" page with title, description, and a primary action button — using only imports from `lib/core/theme/` and `lib/core/widgets/`, and the resulting screen renders correctly in light/dark × ar/en with zero raw color, typography, or spacing literals. An automated check confirms no offending literals exist in the new file.

**Acceptance Scenarios**:

1. **Given** the design system is published, **When** a developer composes a new screen using only theme tokens and component imports, **Then** every color, font, spacing, radius, and shadow on the screen resolves through a named token (no inline hex values, no inline `TextStyle` constructors, no raw pixel padding numbers).
2. **Given** a feature screen has been written using the kit, **When** the project's lint/grep guard runs, **Then** the build fails if any non-design-system file contains a raw hex literal, raw `TextStyle(...)` constructor, or raw pixel spacing number.
3. **Given** a component (e.g., `AppButton`) is requested in `loading` state, **When** the component renders, **Then** it shows the documented loading affordance (inline spinner replacing label) and remains 48 × 48 dp tappable, in both palettes and both themes.

---

### User Story 2 - End user sees a consistent, accessible UI across themes and locales (Priority: P1)

A user opens the AlNujom app on their Android phone. They tap through screens, switch the system theme from light to dark, and switch the language from Arabic to English. Every screen they see — built from the design-system kit — looks coherent: the same blue is the same blue everywhere, headlines align consistently, prices stand out the same way, touch targets are reachable, contrast is readable, and RTL layouts mirror cleanly. Nothing clips, nothing breaks, nothing falls back to a system default.

**Why this priority**: AlNujom's core users (Syrian buyers, sellers, agents) skim listings on cheap mid-range Android devices in mixed lighting. Inconsistent surfaces erode trust faster than any single bug. The app is Arabic-first; if RTL or dark mode are afterthoughts, the product fails for its primary audience.

**Independent Test**: Open the Theme Gallery surface, walk through each component, toggle every combination of light/dark × ar/en × Modern/Trust palette, and confirm every component renders with consistent contrast, alignment, and typography in all 4 (or 8 with palettes) combinations. Run the contrast checker against rendered text/icon pairs.

**Acceptance Scenarios**:

1. **Given** any component from the kit is rendered in any of the 4 environment combinations (light × ar, light × en, dark × ar, dark × en), **When** measured for text and icon contrast against its background, **Then** the ratio meets WCAG 2.1 AA (≥ 4.5:1 for body text, ≥ 3:1 for large text and UI elements) — verified for both Modern and Trust palettes.
2. **Given** a screen is rendered in Arabic, **When** padding, alignment, and back-arrow direction are inspected, **Then** all directional values resolve to RTL-correct positions (leading = right, trailing = left), with no left/right hardcoded values anywhere.
3. **Given** the system text size is set to 200%, **When** any component is rendered, **Then** text scales proportionally and no element clips, overflows, or introduces horizontal scrolling.
4. **Given** a state must be communicated (e.g., "approved", "pending", "error"), **When** the state appears, **Then** it pairs color with at least one of: an icon, a text label, or a shape — never color alone.

---

### User Story 3 - QA reviewer compares Modern vs Trust palettes on real screens with one tap (Priority: P2)

A designer or QA reviewer is testing a feature on a development build. They want to see how the screen feels with the alternate Trust palette (`#2457A6`, calmer financial-services blue) versus the default Modern palette (`#1D4ED8`, punchier marketplace blue). They tap a small floating chip in the top-leading corner; the entire app re-tints to the alternate palette without rebuilding or losing navigation state. They walk through 5 screens, decide they prefer Modern, tap the chip again to switch back, and the choice persists across an app restart for further review the next day. The chip is invisible to end users in production.

**Why this priority**: The team has explicitly locked two palettes as swappable rather than commit blind. Without a one-tap runtime comparison, every palette decision becomes a code-change-rebuild-redeploy cycle. The chip is cheap to ship and saves dozens of design-cycle iterations.

**Independent Test**: In a development build, the Palette Tester chip appears on every screen. Tap it once → app re-tints to the alternate palette within ~200 ms. Tap it again → it tints back. Kill the app and relaunch → the last-selected palette is restored. Build with the production flag → the chip is entirely absent (no widget tree branch, no asset).

**Acceptance Scenarios**:

1. **Given** a development build is running and any screen is visible, **When** the user taps the Palette Tester chip, **Then** every screen-wide color derived from the primary token cross-fades to the alternate palette within 240 ms, and a confirmation snackbar names the now-active palette ("Modern" / "Trust").
2. **Given** the user has switched to Trust and closed the app, **When** the app is relaunched, **Then** the Trust palette remains active until explicitly switched back.
3. **Given** the production build is compiled, **When** the running app is inspected, **Then** the Palette Tester chip is not rendered on any screen and its widget code is excluded from the binary.
4. **Given** the Palette Tester chip is visible on a screen, **When** its hit area would overlap an interactive primary touch target, **Then** the chip yields hit-testing so the underlying control remains tappable.

---

### User Story 4 - Visual regressions in shared components are caught before they reach features (Priority: P2)

A developer modifies a shared component (e.g., changes the padding inside `PropertyCard` or shifts the button radius). Before the change can land, an automated visual-regression check renders the modified component in all 4 environment combinations (light/dark × ar/en) and compares the output to a baseline. If the rendering differs by more than the configured threshold, the check fails and the developer must explicitly approve the new baseline. This catches accidental drift on the most-rendered widgets before it cascades into every feature screen.

**Why this priority**: Once 20+ screens consume `PropertyCard`, a one-pixel shift becomes a thousand-pixel cumulative drift. The cost of catching it at the component layer is one test; the cost of catching it after release is rebuilding goldens for every screen.

**Independent Test**: Modify the `PropertyCard` padding by 4 dp on a development branch, run the visual-regression suite, and observe a failing test in all 4 combinations. Revert; tests pass again.

**Acceptance Scenarios**:

1. **Given** the highest-traffic shared component (`PropertyCard`) is part of the design system, **When** the visual-regression suite runs, **Then** it produces deterministic baseline images for all 4 combinations of light/dark × ar/en in the Modern palette.
2. **Given** an unintended visual change is introduced to that component, **When** the suite runs, **Then** it fails with a diff highlighting the regression and prevents the change from merging until explicitly accepted.

---

### Edge Cases

- **Missing translation string**: If a string key resolves only in Arabic but the app is rendered in English (or vice versa), the component falls back to the available locale and logs a missing-translation warning — no broken layout, no untranslated `key.like.this` displayed verbatim.
- **Network image fails in `PropertyCard`**: The placeholder strategy renders a soft `primaryContainer` block with the property-type icon centered. The broken-image system glyph is never shown.
- **Empty data set on a list-driven screen**: The screen routes through the design system's `EmptyState` component (illustration + headline + body + CTA) — never a blank screen, never a system-default "no data" string.
- **Dark mode shadow invisibility**: Cards substitute a 1 px hairline `border`/`outline` for the elevation shadow in dark theme, preserving card delineation.
- **System text scale ≥ 200%**: All typography styles scale proportionally; no layout clips or introduces horizontal scroll.
- **One-off component variant requested by a feature**: Escalates to a new entry in the component library — never inlined as a feature-local style. The kit is the only place where new visual primitives are defined.
- **Palette Tester touched in production build**: Impossible — the chip is tree-shaken behind a build-time flag and is absent from the release widget tree.
- **Conflicting radius scale between source documents**: The screens-and-components catalog scale (`sm 8 / md 12 / lg 16 / xl 20 / pill 999`) is authoritative; the legacy scale in `decision.md` is superseded (see Assumptions).

## Clarifications

### Session 2026-05-02

- Q: How many components must Phase 2 cover with visual-regression goldens? → A: `PropertyCard` only, and only the four `theme × locale` combinations under the **Modern** palette (matches FR-011 / SC-006 and the plan's "PropertyCard golden suite only … across 4 combinations using Modern palette" hard requirement). Palette-expanded coverage and additional-component goldens are explicitly out of scope for Phase 2 and tracked as separate follow-ups.
- Q: In production builds, can end users choose the palette? → A: No. Production renders the Modern palette only; no end-user-facing palette switch exists in Settings, no hidden gesture, no deep link. The Trust palette remains in source for internal QA comparison only.
- Q: What is the default theme mode for a fresh install? → A: Follow OS theme by default on first launch (`auto`). An explicit user choice in Settings (Light / Dark / Auto) overrides and persists across launches until the user clears it back to `auto`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST expose a single, named, programmatically reachable source for every color, typography style, spacing step, radius, and elevation level used by any screen in the application.
- **FR-002**: System MUST provide both Light and Dark themes that meet WCAG 2.1 AA contrast (≥ 4.5:1 body text, ≥ 3:1 large text and UI elements) for every text/icon pair, in both the Modern and Trust palettes.
- **FR-003**: System MUST ship two named, swappable color palettes — **Modern** (default, primary `#1D4ED8`) and **Trust** (alternate, primary `#2457A6`) — sharing every non-primary token (surface, card, border, semantic colors, text colors).
- **FR-004**: System MUST provide a reusable component library covering every entry enumerated in `contracts/component-library.md` — at minimum: AppBar (with variants), SearchField, LocationSelector, CategoryChip, PropertyCard (vertical + horizontal layouts), OfficeCard, Buttons (filled-primary, filled-success, outlined, tonal, text, destructive, icon-button, FAB; regular and dense sizes), Form fields (text, phone, password, multi-line, number, currency, dropdown, stepper, date picker, toggle, checkbox, radio/segmented), Tabs/segmented control, Badges (featured, new, status pending/approved/rejected, verified office), Bottom sheet, App dialog, EmptyState, LoadingState, ErrorState, Stepper/progress indicator, Image gallery/carousel, Map preview placeholder, ChatBubble, PriceTag, AppBottomNav, PaletteTester (debug-only). The catalog deliberately omits a generic `AppCard` primitive — typed cards (`PropertyCard`, `OfficeCard`, `AdminListItem`) are the canonical surface, each composed directly from design-token primitives.
- **FR-005**: Every component MUST visibly support each of its applicable states — at minimum: `default`, `pressed`/`focused`, `disabled`, `loading` (where applicable), `error` (where applicable), and `empty` (where applicable) — with the visual treatment specified in the screens & components catalog.
- **FR-006**: All components MUST render correctly under Arabic (RTL) and English (LTR), using directional alignment primitives only (no hardcoded left/right values), with bilingual font coverage via the locked typography stack: Cairo (display/headline/title Arabic), IBM Plex Sans Arabic (body/label Arabic), Inter (all Latin).
- **FR-007**: System MUST prevent raw visual literals from leaking into feature code — an automated, build-blocking check MUST fail if any non-design-system file contains a raw hex color, an inline `TextStyle` constructor, or a raw pixel spacing/radius number.
- **FR-008**: System MUST provide a debug-only "Theme Gallery" surface exercising every component in every applicable state, with controls to switch live across locale (ar/en), theme (light/dark), and palette (Modern/Trust) without app restart.
- **FR-009**: System MUST provide a Palette Tester chip that — in development and internal-QA builds only — floats on every screen, toggles between Modern and Trust palettes within 240 ms via cross-fade, persists the selection across app reloads, and is entirely absent (tree-shaken) from production builds.
- **FR-010**: System MUST vendor the Cairo, IBM Plex Sans Arabic, and Inter font families locally (each with at minimum regular, medium, semibold, and bold weights) so the app renders identically without network access and without operating-system font fallback.
- **FR-011**: System MUST provide visual-regression coverage (deterministic golden image comparison) for the highest-traffic shared component (`PropertyCard`) across all 4 combinations of theme × locale in the Modern palette, with the suite failing on any unapproved visual change.
- **FR-012**: All touch targets in design-system components MUST be at least 48 × 48 dp, and no state communicated by a component MUST rely on color alone — color MUST always be paired with an icon, a text label, or a shape.
- **FR-013**: System MUST expose a unified component contract: each component is one named entity with one canonical visual treatment per variant; ad-hoc per-screen restyling is forbidden, and any new variant requires extending the component library — not inlining styles.
- **FR-014**: System MUST surface the rejected design direction (Direction A — Luxury) only as an archived reference document; no Luxury tokens, fonts, or components MUST be reachable from production code paths.
- **FR-015**: In production builds, the active color palette MUST be fixed to **Modern**; no end-user-facing palette switch MUST exist anywhere in the shipped surface (no Settings row, no hidden gesture, no deep link, no remote config flip). The Trust palette MUST remain in source as a reference for internal QA only, reachable solely via the debug-build Palette Tester chip (FR-009).
- **FR-016**: On first launch, the active theme mode MUST follow the operating-system theme preference (treated as `auto`). Settings MUST expose an explicit override with three values — `auto` / `light` / `dark` — and the chosen override MUST persist across launches until the user resets it back to `auto`. While `auto` is selected, the rendered theme MUST update live when the OS theme changes without requiring an app restart.

### Key Entities

- **Design Token**: A named, immutable visual primitive (e.g., `primary`, `surface`, `bodyMedium`, `spacing.lg`, `radius.md`, `elevation.2`). Tokens are the only legitimate source of color, typography, spacing, radius, and shadow values.
- **Color Palette**: A named bundle of color tokens (`Modern`, `Trust`). Each palette has a Light and Dark variant. Palettes share all non-primary tokens; only the `primary / onPrimary / primaryContainer / onPrimaryContainer / accent` quintet differs between Modern and Trust.
- **Theme Mode**: `Light` or `Dark` — selected from system preference or explicit user override; affects every token's resolved value.
- **Locale Mode**: `Arabic (RTL)` or `English (LTR)` — affects directional alignment, font selection (Arabic vs Latin family), and back-arrow direction.
- **Component**: A named, reusable visual building block (e.g., `AppButton`, `PropertyCard`, `SearchField`). Each component has: a fixed catalog of variants, a documented set of states, and a single canonical visual treatment per (variant, state).
- **Theme Gallery**: A debug-only surface that enumerates every component in every state and supports live switching across locale, theme, and palette. Exists for design review and QA, never shipped to end users.
- **Palette Tester**: A debug-only floating chip persisting palette choice in app preferences and absent from production builds.
- **Archived Direction**: The rejected Luxury direction (Direction A), preserved as a historical reference document only — not reachable from any code path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of feature screens implemented in any subsequent phase compose their visual surface from design-system tokens and components only — verified by an automated build-blocking check that finds zero raw hex colors, zero raw `TextStyle` constructors, and zero raw pixel spacing/radius numbers in feature code.
- **SC-002**: Every text/icon pair rendered by any design-system component in any of the 8 environment combinations (Modern × Light/Dark × ar/en + Trust × Light/Dark × ar/en) measures at or above the WCAG 2.1 AA contrast floor (4.5:1 body, 3:1 large text and UI).
- **SC-003**: A team member can compare Modern vs Trust palettes on any screen of a development or internal-QA build with a single tap on the Palette Tester chip; the palette change propagates across the entire visible UI within 240 ms and persists across app restarts; the chip is absent from production builds.
- **SC-004**: A developer can author a new feature screen end-to-end without producing any new color, typography, spacing, or shadow definition — every visual choice they need is already named in the kit. (Verified by reviewing the diff of the first feature screen built after Phase 2 lands: no additions to `lib/core/theme/`, only consumption.)
- **SC-005**: The Theme Gallery surface renders cleanly — no clipped text, no broken alignment, no missing component states — in all 4 base combinations (light/dark × ar/en) and in both palettes.
- **SC-006**: Visual regressions in `PropertyCard` are detected automatically before merge: the golden suite covers all 4 environment combinations, and any pixel-level diff above the configured threshold fails the build until the new baseline is explicitly approved.
- **SC-007**: First-render performance on the reference device (Infinix Note 8, Helio G80, 6 GB RAM, Android 10/11) for a screen composed entirely of design-system components is within the standard mid-range Android budget — no perceptible jank on initial layout, smooth 60 fps scroll for a 50-item PropertyCard list.
- **SC-008**: System text scaling at 100%, 130%, and 200% renders every component without clipping, overflow, or horizontal scroll.

## Assumptions

- **Phase 1 foundation is in place**: The DI container, router, `Result`/`Failure` types, `AppLogger`, and `PreferencesStore` from `specs/001-project-foundation/` are available; the design system consumes preferences (palette choice, theme mode) through the existing `PreferencesStore` rather than introducing a new persistence layer.
- **Phase 3 (Localization) is a separate concern**: The design system does not own translated strings — it accepts any string supplied to its components. Translation lookups, locale switching plumbing, and ARB management are owned by the localization phase that follows.
- **No backend dependency**: Phase 2 is frontend-only. No Supabase tables, no RLS, no edge functions are introduced or modified.
- **Reference device for sign-off**: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) is the canonical hands-on QA device for performance and visual review (per project memory).
- **Radius scale reconciliation**: The screens-and-components catalog scale (`sm 8 / md 12 / lg 16 / xl 20 / pill 999`) is authoritative. The earlier scale in `decision.md` (`sm 4 / md 8 / lg 12 / xl 16 / pill 999`) is superseded — confirmed in `decision.md` §"Note" and the `screens-and-components.md` §11 locked decisions.
- **Component name unification**: The feature-shared `ListingCard` referenced in `IMPLEMENTATION_PLAN.md` is a thin alias for the canonical `PropertyCard` defined in the screens-and-components catalog. Both names refer to the same visual treatment; the implementation should expose one source and one re-export rather than two parallel widgets.
- **Font licensing permits redistribution**: Cairo, IBM Plex Sans Arabic, and Inter are all licensed for in-app embedding under terms compatible with the project's distribution model. (Verification of the font license files belongs to the implementation phase but the assumption is load-bearing for vendoring.)
- **No app icon, splash branding, or marketing assets**: Phase 2 covers tokens and reusable components only. Splash screen and brand-mark artwork are out of scope and will be addressed when their owning screens are built (Splash is part of `Phase 6 — Public home & listing details` chrome work or earlier auth phase, per IMPLEMENTATION_PLAN.md).
- **Modern Marketplace direction is locked**: Direction A (Luxury) is archived. No tokens, fonts, or components from Direction A are reachable; the archive at `docs/design/archive/luxury.md` exists for decision history only.
- **`kDesignToolsEnabled` flag gating**: A single build-time constant `kDesignToolsEnabled` (sourced from `--dart-define=DESIGN_TOOLS=true`) gates BOTH the Palette Tester chip AND the Theme Gallery surface — they are two parts of one design-tools surface and ship together. The constant resolves to `true` in development and internal-QA builds, `false` in production, so both widget trees and their assets are tree-shaken from release artifacts.
- **Visual-regression scope**: Golden tests cover `PropertyCard` (the highest-traffic shared component) in all 4 environment combinations as the Phase 2 floor; expanding goldens to additional components is a follow-on effort tracked separately.
- **Stakeholder sign-off on `screens-and-components.md` is the prerequisite**: Once the catalog graduates from DRAFT to source-of-truth (per its closing paragraph), Phase 2 implementation work is unblocked. If sign-off has not yet occurred, that approval gate runs in parallel with `/speckit-clarify` and `/speckit-plan`.
