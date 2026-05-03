---
description: "Tasks list for Phase 2 — Design System & Theme Tokens (specs/002-design-system)"
---

# Tasks: Design System & Theme Tokens

**Input**: Design documents from `/specs/002-design-system/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: Included — FR-002 (contrast), FR-005 (state coverage), FR-007 (lint), FR-009/FR-015 (release pin), FR-011/SC-006 (golden), FR-016 (auto theme) all explicitly require automated verification.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently.

## Format: `[ID] [P?] [Story?] Description`

- **[P]** = different files, no dependency on incomplete tasks → can run in parallel
- **[USx]** = task belongs to user story x (only on Phase 3+ tasks)
- Each task carries a `**Verify**:` line with the concrete acceptance check (Constitution Principle X)

## Path Conventions

This is a Flutter Android app. Paths below are relative to the repo root `H:\alnujom-project\`.

- Flutter source: `lib/`
- Phase 2 widget kit: `lib/core/widgets/`
- Phase 2 token modules: `lib/core/theme/`
- Debug-only surfaces: `lib/debug/`
- Feature-shared shims: `lib/shared/presentation/widgets/`
- Tests: `test/`
- Fonts: `assets/fonts/`
- Lint tool: `tool/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Vendor the locked font families, register them in `pubspec.yaml`, declare the build-time gating constants the design tools depend on, lock the icon library dependency, and remove the Phase 1 token stub now that the real tokens are about to land.

- [X] T001 Add `flutter_lucide` to `pubspec.yaml` `dependencies` per research R-02 (locked icon library)
  - **Verify**: `flutter pub get` resolves without conflict; `import 'package:flutter_lucide/flutter_lucide.dart';` compiles in a scratch Dart file

- [X] T002 [P] Vendor the canonical Cairo variable font (`Cairo[slnt,wght].ttf` from the `google/fonts` mirror, renamed to `Cairo-VariableFont_slnt_wght.ttf`) under `assets/fonts/`. **Cairo is shipped as a single variable font, not four static weights** — the canonical Cairo distribution at both upstream `Gue3bara/Cairo` and `google/fonts` no longer ships static weight TTFs; weight selection happens via the `wght` axis at runtime. See R-05 amendment.
  - **Verify**: `ls assets/fonts/Cairo-VariableFont_slnt_wght.ttf` finds the file (~600 KB); the SIL Open Font License file is present at `assets/fonts/LICENSE-Cairo.txt`; `TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w400)` and the `w500/w600/w700` siblings render visually distinct weights at runtime (verified during T013).

- [X] T003 [P] Vendor four IBM Plex Sans Arabic TTF weights (Regular / Medium / SemiBold / Bold) under `assets/fonts/`
  - **Verify**: `ls assets/fonts/IBMPlexSansArabic-*.ttf` lists 4 files; license file present at `assets/fonts/LICENSE-IBMPlexSansArabic.txt`

- [X] T004 [P] Vendor four Inter TTF weights (Regular / Medium / SemiBold / Bold) under `assets/fonts/`
  - **Verify**: `ls assets/fonts/Inter-*.ttf` lists 4 files; license file present at `assets/fonts/LICENSE-Inter.txt`

- [X] T005 Declare the three families in `pubspec.yaml` under `flutter.fonts` — `Cairo` as a single variable-font asset (no `weight:` keys; axis selection at consumption time per T002 / R-05); `IBMPlexSansArabic` and `Inter` each with the four static weight assets and matching `weight: 400/500/600/700` entries (depends on T002–T004)
  - **Verify**: `flutter pub get` succeeds; `flutter run` shows no "font not found" warnings on first launch

- [X] T006 [P] Create `lib/core/flags/app_flags.dart` declaring a single `const bool kDesignToolsEnabled = bool.fromEnvironment('DESIGN_TOOLS', defaultValue: false);` per research R-07. This single flag gates BOTH the Palette Tester chip and the Theme Gallery surface — they ship together
  - **Verify**: `flutter analyze` clean; the constant is reachable from any `lib/` import path; `flutter run` (no `--dart-define`) treats it as `false`; `flutter run --dart-define=DESIGN_TOOLS=true` flips it to `true`

- [X] T007 [P] Add the two new preference key constants to `lib/core/storage/preferences_keys.dart` (or create the file if Phase 1 used inline strings): `kPrefThemeMode = 'app.theme_mode'`, `kPrefPalette = 'app.palette'`
  - **Verify**: `grep -rE "'app\\.(theme_mode|palette)'" lib --include='*.dart'` only matches `preferences_keys.dart`; no other call site uses raw key strings

- [X] T008 Delete `lib/core/theme/tokens_stub.dart` and remove its export from any barrel file (depends on Phase 2 tokens existing — this task is recorded here for visibility but executed at the end of Phase 2 after T012 lands)
  - **Verify**: `git ls-files lib/core/theme/tokens_stub.dart` returns nothing; `grep -rE "tokens_stub" lib --include='*.dart'` returns nothing; `flutter analyze` clean

**Checkpoint**: dependency + asset infrastructure ready; the build-time flags are wired; no user-visible change yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Replace the Phase 1 token stub with the real, complete token system: five token files (`colors`, `typography`, `spacing`, `radii`, `elevation`), a `ColorPalette` sealed class producing four `ColorScheme`s (Modern light + dark + Trust light + dark), and an `app_theme.dart` builder that turns a (palette, brightness, locale) tuple into a `ThemeData`. **No user story can begin until this phase is complete.**

> Contracts: [`contracts/design-tokens.md`](contracts/design-tokens.md), [`contracts/component-library.md`](contracts/component-library.md). Source values: [`docs/design/decision.md`](../../docs/design/decision.md), [`docs/design/screens-and-components.md`](../../docs/design/screens-and-components.md) §2.

### Token primitives (palette-agnostic)

- [X] T009 [P] Create `lib/core/theme/spacing.dart` exposing `abstract final class AppSpacing` with `static const double` members `xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=24`, `xxl=32`, `xxxl=48` per design-tokens contract
  - **Verify**: `flutter analyze` clean; `AppSpacing.lg == 16.0` evaluates true from any test

- [X] T010 [P] Create `lib/core/theme/radii.dart` exposing `abstract final class AppRadii` with `static const double` members `sm=8`, `md=12`, `lg=16`, `xl=20`, `pill=999` per research R-10 (reconciled scale)
  - **Verify**: `flutter analyze` clean; `AppRadii.md == 12.0` evaluates true from any test

### Color palette + scheme

- [X] T011 Create `lib/core/theme/color_palette.dart` declaring `sealed class ColorPalette` with `name` getter and abstract `lightScheme()` / `darkScheme()` factories returning Material 3 `ColorScheme`s; subclasses `ModernPalette` (primary `#1D4ED8` light / `#60A5FA` dark) and `TrustPalette` (primary `#2457A6` light / `#9FC5FF` dark); both share the palette-agnostic shared-token block from `decision.md` §"Shared tokens"; expose `ColorPalette.fromName(String)` and `static const ColorPalette defaultPalette = ModernPalette();`
  - **Verify**: a unit test (`test/core/theme/color_palette_test.dart`, written under T060) confirms each subclass returns the locked hex quintet in light + dark

- [X] T012 [P] Create `lib/core/theme/colors.dart` exposing `class AppColors` with field-style accessors for every token role from `contracts/design-tokens.md` and a `static AppColors of(BuildContext context)` resolving values from `Theme.of(context).colorScheme` plus `ThemeExtension`s for project-specific tokens (depends on T011 for `ColorPalette` types)
  - **Verify**: `AppColors.of(context).primary` returns the active palette's primary color; rebuilding under a different palette returns the alternate value; `flutter analyze` clean

### Typography

- [X] T013 Create `lib/core/theme/typography.dart` exposing `class AppTextStyles` with field-style accessors for all 12 type-scale roles from `contracts/design-tokens.md` and a `static AppTextStyles of(BuildContext context)` that selects Cairo / IBM Plex Sans Arabic vs Inter based on `Localizations.localeOf(context)` (depends on T005 for fonts)
  - **Verify**: under `Locale('ar')` the rendered `bodyLarge.fontFamily` resolves to `'IBMPlexSansArabic'`; under `Locale('en')` it resolves to `'Inter'`; line-height and tracking match `decision.md` §Typography

### Elevation

- [X] T014 Create `lib/core/theme/elevation.dart` exposing `class AppElevation` with `level0/1/2/3` shadow lists and `hairline` outline; `static AppElevation of(BuildContext context)` returns light-mode shadows when `Brightness.light` and dark-mode (empty shadows + 1 px outline border) when `Brightness.dark` per `decision.md` §Elevation note
  - **Verify**: under `Theme(data: ThemeData(brightness: Brightness.dark))` `AppElevation.of(context).level1` returns `<BoxShadow>[]` and `hairline` returns a `Border.all(width: 1, color: …outline)`

### Theme builder

- [X] T015 Create / rewrite `lib/core/theme/app_theme.dart` exposing `ThemeData buildAppTheme({required ColorPalette palette, required Brightness brightness, required Locale locale})` consolidating the `ColorScheme`, `TextTheme` (from `AppTextStyles`), `IconThemeData`, `AppBarTheme`, `ButtonTheme`, etc., into one Material 3 `ThemeData`; default `useMaterial3: true`; expose `ThemeData.light()` / `ThemeData.dark()` adapters that take only a `ColorPalette` and locale (depends on T011, T012, T013, T014)
  - **Verify**: a smoke widget test mounts `MaterialApp(theme: buildAppTheme(palette: ModernPalette(), brightness: light, locale: ar))` and renders without errors; `Theme.of(context).colorScheme.primary == Color(0xFF1D4ED8)`

### Wiring + cleanup

- [X] T016 Update `lib/app.dart` to read both the existing `ThemeCubit` (Phase 1) and a soon-to-exist `PaletteCubit` (added in US3, but the plumbing is wired now with a default `ModernPalette` constant) and pass `(palette, locale)` to `buildAppTheme` for both `theme:` and `darkTheme:` slots; `themeMode:` is driven by `ThemeCubit` (depends on T015)
  - **Verify**: `flutter run` boots the existing Phase 1 shell home with the locked Modern primary visible; toggling system theme between light and dark updates the rendered theme without restart

- [X] T017 Migrate `lib/shell/shell_home_page.dart` to consume the new token API — replace any `tokens_stub` references with `AppColors.of(context)` / `AppTextStyles.of(context)` / `AppSpacing.lg` / etc. Do this BEFORE T008 so the deletion is safe (depends on T009–T015)
  - **Verify**: `grep -rE "tokens_stub" lib --include='*.dart'` returns nothing in `lib/shell/`; the shell home renders identically to its Phase 1 appearance modulo the locked typography + Modern primary

**Checkpoint**: tokens land, `app_theme.dart` builds Material 3 `ThemeData` for Modern light/dark, the shell still boots, no widget kit yet.

---

## Phase 3: User Story 1 — Build feature screens from kit only (Priority: P1) 🎯 MVP

**Goal**: Every component a feature phase will need exists under `lib/core/widgets/`, exposes its variants and states per `contracts/component-library.md`, and consumes only design-token API. The lint guard fails the build on raw color / `TextStyle` / spacing literals in non-design-system code, so feature authors cannot drift accidentally.

**Independent Test**: A developer writes a brand-new screen (e.g., `lib/features/scratch/scratch_page.dart`) using only imports from `lib/core/theme/` and `lib/core/widgets/`, and `dart run tool/lint_design_tokens.dart` exits 0. Adding a single `Color(0xFFAA0000)` to that file flips the script to exit 1.

> Note: No goldens or contrast tests in this story — those belong to US4 and US2 respectively. This story is about *availability* of the kit; *quality* across themes/locales is US2.

### Lint guard (FR-007 — gates feature code from this point forward)

- [X] T018 [P] [US1] Create `tool/lint_design_tokens.dart` per `contracts/lint-guard.md`: scans `lib/**/*.dart`, flags banned patterns L1 (raw `Color(0x…)`), L2 (inline `TextStyle(`), L3 (raw integer in `EdgeInsets(Directional)?` constructors), L4 (raw integer in `BorderRadius.circular`), L5 (raw integer in `BoxShadow(`), L6 (any reference to `archive/luxury` import paths or the archived font names `Playfair Display` / `Reem Kufi` — enforces FR-014); honors the allow-list (token files); exit 0 on clean, exit 1 on violation
  - **Verify**: `dart run tool/lint_design_tokens.dart` exits 0 against the current tree; piping a file with `Color(0xFFAA0000)` through the script flags it with `path:line:column: forbidden raw color literal …`; piping a file with `import 'package:alnujom/archive/luxury/foo.dart';` flags it with the L6 message

- [X] T019 [P] [US1] Create `test/lint/fixtures/clean.dart` containing only design-token-API uses, and `test/lint/fixtures/violations.dart` containing one of each banned pattern (L1–L6 — including a synthetic `import 'package:alnujom/archive/luxury/foo.dart';` for L6) with comments naming the rule
  - **Verify**: `clean.dart` compiles; `violations.dart` is excluded from the analyzer via `// ignore_for_file:` directives so the project's `flutter analyze` stays green

- [X] T020 [US1] Create `test/lint/design_tokens_lint_test.dart` calling the reusable scanning library (extracted from `tool/lint_design_tokens.dart` into `tool/src/lint_design_tokens_lib.dart` per `contracts/lint-guard.md`) against the two fixtures (depends on T018, T019)
  - **Verify**: `flutter test test/lint/` reports 6 violations on `violations.dart` (one per L1–L6) and 0 on `clean.dart`

- [X] T021 [US1] Update `.github/workflows/ci.yml` adding a `Lint design tokens` step that runs `dart run tool/lint_design_tokens.dart` after `flutter analyze` (depends on T018)
  - **Verify**: a deliberate `Color(0xFFAA0000)` PR fails the workflow at the lint step; the same PR with that line removed passes

### Buttons + chrome (highest reuse first)

- [X] T022 [P] [US1] Create `lib/core/widgets/app_button.dart` per component-library #7: variants `filledPrimary / filledSuccess / outlined / tonal / text / destructive / iconButton / fab`; sizes `regular` (48 dp) / `dense` (36 dp); states `default / pressed / focused / loading / disabled`; loading replaces label with an inline 16 dp `CircularProgressIndicator`; `EdgeInsetsDirectional` only
  - **Verify**: a widget test (T057 batch) mounts each variant × each state and asserts color comes from `AppColors.of(context)`, hit-target ≥ 48 × 48 dp on `regular`, label hidden when `loading`

- [X] T023 [P] [US1] Create `lib/core/widgets/app_app_bar.dart` per component-library #1: variants `default / withBack / withSearch / transparentOnImage`; back-arrow mirrors under `Directionality.of(context)`; elevation flips from 0 → 1 on scroll
  - **Verify**: a widget test mounts each variant under both `Directionality.rtl` and `Directionality.ltr`; back-arrow icon resolves to the correct chevron direction in each

- [X] T024 [P] [US1] Create `lib/core/widgets/app_bottom_nav.dart` per component-library #32: 5-tab spine (RTL-ordered: الرئيسية / البحث / إضافة / المفضلة / حسابي); active tab shows `primary` label and 2 dp top accent bar; "إضافة" tab has filled `primary` icon at 28 dp
  - **Verify**: tab labels render in correct RTL order under `Locale('ar')`; tapping the "إضافة" slot does NOT route — it triggers a callback parameter (the actual modal flow lands in Phase 12)

### Inputs (search, location, category)

- [X] T025 [P] [US1] Create `lib/core/widgets/search_field.dart` per component-library #2: `pill` radius from `AppRadii.pill`; states `default / focused / loading (debounced) / disabled`; trailing clear-X appears when text is non-empty; optional trailing filter icon prop
  - **Verify**: typing fills the field, focus shifts the border to `primary`, the loading state replaces the leading search icon with a spinner

- [X] T026 [P] [US1] Create `lib/core/widgets/location_selector.dart` per component-library #3: row showing `📍 city / area` with chevron; tap opens a placeholder callback (real cascading picker lands in Phase 8)
  - **Verify**: pressed state visible; disabled state respects 50 % opacity rule

- [X] T027 [P] [US1] Create `lib/core/widgets/category_chip.dart` per component-library #4: pill with leading icon + label; states `default / pressed / focused / selected / disabled`; selected uses `primary` fill + `onPrimary` label
  - **Verify**: visual state changes are token-driven; tapping toggles `selected` via the onPressed callback

### Form fields

- [X] T028 [P] [US1] Create `lib/core/widgets/app_text_field.dart` per component-library #8: anatomy label / input / helper-or-error; states `default / focused / filled / error / disabled`; uses `EdgeInsetsDirectional` for the inner padding
  - **Verify**: error helper text renders in `AppColors.of(context).error`; the field resolves to ≥ 48 dp tall

- [X] T029 [P] [US1] Create `lib/core/widgets/app_phone_field.dart` per component-library #9: composes `AppTextField` with a leading `+963` prefix dropdown for country codes
  - **Verify**: the prefix dropdown is selectable; the value passed to onChanged includes the country code

- [X] T030 [P] [US1] Create `lib/core/widgets/app_password_field.dart` per component-library #10: composes `AppTextField` with `obscureText` and a trailing eye-toggle IconButton
  - **Verify**: tapping the eye toggle flips `obscureText`; the IconButton has its own ≥ 48 dp hit area

- [X] T031 [P] [US1] Create `lib/core/widgets/app_multi_line_field.dart` per component-library #11: composes `AppTextField` with `maxLines: null`, optional character counter (e.g., `0/1000`)
  - **Verify**: counter updates live as the user types

- [X] T032 [P] [US1] Create `lib/core/widgets/app_number_field.dart` per component-library #12: composes `AppTextField` with `TextInputType.number` and an optional leading or trailing unit suffix slot
  - **Verify**: `م²` and `ل.س` suffixes render correctly under RTL

- [X] T033 [P] [US1] Create `lib/core/widgets/app_currency_field.dart` per component-library #13: composes `AppNumberField` with a USD/SYP segmented toggle; emits `(amount, currency)` tuple
  - **Verify**: switching the toggle re-formats the displayed value (no destructive parse)

- [X] T034 [P] [US1] Create `lib/core/widgets/app_dropdown.dart` per component-library #14: standard dropdown with `default / focused / error / disabled` states
  - **Verify**: error state borders + helper text are token-driven

- [X] T035 [P] [US1] Create `lib/core/widgets/app_stepper_input.dart` per component-library #15: `−` / value / `+` row; min/max props; `default / disabled`
  - **Verify**: tapping `+` past `max` is no-op; tapping `−` past `min` is no-op

- [X] T036 [P] [US1] Create `lib/core/widgets/app_date_picker.dart` per component-library #16: trigger field that opens Material `showDatePicker` themed by the active `AppTheme`
  - **Verify**: the opened picker visually matches the active palette; selected date is formatted via `intl` (Arabic locale → Arabic numerals or Latin per `intl` defaults)

- [X] T037 [P] [US1] Create `lib/core/widgets/app_toggle.dart` per component-library #17: themed `Switch` wrapper; `default / disabled`
  - **Verify**: track and thumb colors come from `AppColors.of(context)`

- [X] T038 [P] [US1] Create `lib/core/widgets/app_checkbox.dart` per component-library #18: themed `Checkbox` wrapper; `default / pressed / disabled`
  - **Verify**: ≥ 48 dp hit area extends beyond the visual 24 dp box

- [X] T039 [P] [US1] Create `lib/core/widgets/app_radio_group.dart` per component-library #19 + #20-radio-side: composable radio group + segmented-control variant; `default / pressed / disabled`
  - **Verify**: tapping a non-selected radio emits its value via onChanged; segmented variant supports 2 / 3 / 4 segments

- [X] T040 [P] [US1] Create `lib/core/widgets/app_tabs.dart` per component-library #20-tabs-side: `segmented` (2 / 3 segments) + `underline` (4 + items) variants; `default / selected / disabled`
  - **Verify**: selected segment background = `primary`; underline-tab indicator height = 2 dp

### Badges + dialogs + sheets

- [X] T041 [P] [US1] Create `lib/core/widgets/app_badge.dart` per component-library #21: variants `featured / new / statusPending / statusApproved / statusRejected / verifiedOffice`; non-interactive
  - **Verify**: every variant pairs color with an icon or label (FR-012 — never color alone); status colors come from `AppColors.of(context).success/warning/error`

- [X] T042 [P] [US1] Create `lib/core/widgets/app_bottom_sheet.dart` per component-library #22: drag handle 4 × 32 dp; `xl` top radius; max ~85 % screen height; sticky footer slot
  - **Verify**: opening a sheet with content > screen height exposes a scrollable content slot while keeping the footer pinned

- [X] T043 [P] [US1] Create `lib/core/widgets/app_dialog.dart` per component-library #23: variants `confirm / destructive`; trailing-aligned cancel + leading-aligned action under RTL
  - **Verify**: `destructive` variant uses `AppColors.of(context).error` for the action button

### Feedback states

- [X] T044 [P] [US1] Create `lib/core/widgets/empty_state.dart` per component-library #24: illustration → headline → body → CTA composition; takes string parameters (no internalised copy — Phase 3 owns translations)
  - **Verify**: rendering with each parameter null collapses correctly (only headline → headline + body → headline + body + CTA)

- [X] T045 [P] [US1] Create `lib/core/widgets/loading_state.dart` per component-library #25: skeleton helpers — `LoadingState.card()`, `LoadingState.row()`, `LoadingState.avatar()`; uses `surfaceVariant` background and a 1200 ms shimmer animation
  - **Verify**: skeleton dimensions match the rendered content they substitute for; no layout shift when real content arrives

- [X] T046 [P] [US1] Create `lib/core/widgets/error_state.dart` per component-library #26: variants `default / network`; both expose a Retry CTA via callback
  - **Verify**: tapping Retry invokes the callback exactly once per tap

### Composite + media

- [X] T047 [P] [US1] Create `lib/core/widgets/property_card.dart` per component-library #5: layouts `vertical` (full-bleed image top, photo:card 4:3) and `horizontal` (16:10 image, 280 dp wide); states `default / pressed / loading (skeleton) / empty (placeholder image)`; favorite / featured / "للبيع" overlays via slotted props
  - **Verify**: long-press surfaces a context menu (Save / Share / Report) via callback; missing image renders the `primaryContainer` placeholder block, never a broken-image glyph

- [X] T048 [P] [US1] Create `lib/core/widgets/office_card.dart` per component-library #6: logo + name + verified badge + listings count + visit-link CTA
  - **Verify**: visited state visually distinct (only via icon swap, never color alone)

- [X] T049 [P] [US1] Create `lib/core/widgets/stepper_indicator.dart` per component-library #27: N segments; completed / current / future use `success / primary / outline` fills; trailing label "(1/N)"
  - **Verify**: width adjusts to N; label updates as `currentIndex` changes

- [X] T050 [P] [US1] Create `lib/core/widgets/image_gallery.dart` per component-library #28: pageable carousel; bottom-overlaid `3/12` page indicator; tap → fullscreen with pinch-zoom; `loading (skeleton) / empty (placeholder)` states
  - **Verify**: page indicator reads RTL under `Directionality.rtl`

- [X] T051 [P] [US1] Create `lib/core/widgets/map_preview.dart` per component-library #29: 16:9 static placeholder block with a centered marker icon; tap → navigates via callback (real `flutter_map` integration is Phase 15)
  - **Verify**: placeholder uses `primaryContainer` background, not a third-party tile; tap callback fires exactly once

- [X] T052 [P] [US1] Create `lib/core/widgets/chat_bubble.dart` per component-library #30: variants `mine` (`primary` fill, trailing-aligned) and `theirs` (`card` fill, leading-aligned with 1 px border)
  - **Verify**: under RTL, `mine` aligns to the leading visual edge (left side under ar) — confirmed via golden-style snapshot, not just measurement

- [X] T053 [P] [US1] Create `lib/core/widgets/price_tag.dart` per component-library #31: bold primary number + currency suffix on one line; optional secondary alt-currency line in `textSecondary`
  - **Verify**: under `Locale('ar')`, the currency suffix follows the number (RTL); under `Locale('en')`, the suffix follows but reads LTR

### Feature-shared shims

- [X] T054 [P] [US1] Create `lib/shared/presentation/widgets/listing_card.dart` per research R-09: one-line `export 'package:alnujom/core/widgets/property_card.dart';` plus `typedef ListingCard = PropertyCard;`
  - **Verify**: importing `ListingCard` from `package:alnujom/shared/presentation/widgets/listing_card.dart` resolves to the same class as importing `PropertyCard` from `package:alnujom/core/widgets/property_card.dart`

- [X] T055 [P] [US1] Create `lib/shared/presentation/widgets/price_display.dart`: similar shim re-exporting `PriceTag` under the `IMPLEMENTATION_PLAN.md` Phase 2 name
  - **Verify**: `PriceDisplay` and `PriceTag` are the same type

- [X] T056 [P] [US1] Create `lib/shared/presentation/widgets/admin_list_item.dart`: admin-row primitive composed of `AppListTile`-style internals built on `AppColors`/`AppTextStyles`/`AppSpacing` (no inline styles); leading icon + title + subtitle + trailing action slot
  - **Verify**: no hex literal, no inline `TextStyle`, no raw spacing — passes the lint guard

### Per-component widget tests (FR-005 state coverage — these are not goldens; goldens are US4)

- [X] T057 [US1] Create one widget test per kit component under `test/core/widgets/<component>_test.dart` (28 files: T022–T053 minus the per-shim T054–T056). Each test mounts every applicable state and asserts (a) rendered colors come from `AppColors.of(context)`, (b) rendered styles come from `AppTextStyles.of(context)`, (c) hit targets ≥ 48 × 48 dp, (d) RTL layout under `Directionality.rtl` is correct (e.g., back arrow swaps direction), (e) FR-012 second clause: for every state that visually communicates information via color (badges, status outlines, error text, focus borders, success/danger affordances), the rendered subtree contains at least one of an icon, a text label, or a shape change — color is never the sole signal
  - **Verify**: `flutter test test/core/widgets/` runs, all tests pass, `flutter test --coverage` reports each component file ≥ 70 % line coverage; deliberately removing the icon from `AppBadge.statusApproved` (leaving only the green color) flips its widget test red on the new color-paired-with-icon-or-label assertion

**Checkpoint**: User Story 1 is complete — every feature phase from Phase 4 onwards can compose screens from `lib/core/widgets/` and consume only design tokens. The lint guard makes drift impossible.

---

## Phase 4: User Story 2 — Consistent, accessible UI across themes and locales (Priority: P1)

**Goal**: The kit's quality bar is observably met. Light + dark themes both pass WCAG AA in both Modern and Trust palettes. Auto theme mode honors the OS preference and live-updates when the OS flips. Every component renders cleanly in all 4 base environment combinations (light/dark × ar/en).

**Independent Test**: Run `flutter test test/core/theme/color_scheme_contrast_test.dart` — every (palette × theme) combination passes the 4.5:1 / 3:1 ratios. Toggle the device system theme while the app is running with `ThemeMode.auto` — the rendered theme flips without restart.

### Theme cubit extension (FR-016)

- [X] T058 [US2] Update `lib/core/theme/theme_cubit.dart` per [`contracts/theme-cubit.md`](contracts/theme-cubit.md): add `AppThemeMode { auto, light, dark }`; `initialize()` reads `kPrefThemeMode` (defaults to `auto`); `setMode(m)` persists then emits; corrupt-value → `auto` + warning log; the cubit emits `auto/light/dark` only — `MaterialApp.themeMode` mapping happens at the consumer (T016)
  - **Verify**: a Cubit test asserts the four state-transition cases listed in `contracts/theme-cubit.md`; the corrupt-value case logs via the injected `AppLogger`

- [X] T059 [US2] Create `test/core/theme/theme_cubit_test.dart` covering all transitions from `contracts/theme-cubit.md` plus a widget test that mounts `MaterialApp(themeMode: ThemeMode.system)`, simulates an `MediaQueryData.copyWith(platformBrightness: …)` flip, and asserts the rendered theme switches without rebuilding the cubit
  - **Verify**: `flutter test test/core/theme/theme_cubit_test.dart` passes; the live-OS-theme-flip test does NOT call `cubit.emit` — it confirms the framework path works

### Color palette + contrast verification

- [X] T060 [P] [US2] Create `test/core/theme/color_palette_test.dart` asserting `ModernPalette().lightScheme().primary == Color(0xFF1D4ED8)` and the locked hex values for the entire shared-token block in both palettes × both brightnesses (depends on T011)
  - **Verify**: the test passes; if a hex value drifts in `color_palette.dart`, the test fails with the offending token name

- [X] T061 [P] [US2] Create `test/core/theme/color_scheme_contrast_test.dart` walking every "text" / "background" token pair across (Modern × light, Modern × dark, Trust × light, Trust × dark) and asserting WCAG AA (4.5:1 for body, 3:1 for large text and UI) using a `contrastRatio(Color, Color)` helper in the test file
  - **Verify**: all 4 combinations × every relevant token pair pass; if the test fails, the output names exactly which (palette, theme, foreground, background) violates the floor and by what ratio

### Locale-aware components — RTL/LTR sweep

- [X] T062 [US2] Add an RTL/LTR matrix dimension to the per-component widget tests in T057 — for the components whose layout is direction-sensitive (`AppAppBar`, `PropertyCard`, `ChatBubble`, `AppBottomNav`, `PriceTag`, `LocationSelector`, `EmptyState`), each test mounts the component twice (under `Directionality.rtl` and `Directionality.ltr`) and asserts directional padding/alignment correctness
  - **Verify**: `flutter test test/core/widgets/` includes the new RTL/LTR cases; a deliberate `EdgeInsets.only(left: 8)` introduced into a tested component flips the rtl test red

**Checkpoint**: User Story 2 is complete — the design system meets the WCAG / RTL / live-theme bar; the kit is now demonstrably correct across all 4 base environment combinations in both palettes.

---

## Phase 5: User Story 3 — One-tap palette comparison in QA builds (Priority: P2)

**Goal**: Designers and QA can compare Modern vs Trust palettes on real screens with a single tap on a floating chip. Choice persists across reload in QA builds; the chip is entirely absent (tree-shaken) in release.

**Independent Test**: Run `flutter run --debug --dart-define=DESIGN_TOOLS=true`. Tap the chip on the Phase 1 shell home — palette cross-fades within 240 ms, snackbar names the now-active palette. Kill app, relaunch with the same flag — last selection persists. Build `flutter build apk --release` (no flag) — chip is absent.

### Palette cubit + persistence

- [X] T063 [US3] Create `lib/core/theme/palette_cubit.dart` per [`contracts/palette-cubit.md`](contracts/palette-cubit.md): `Cubit<ColorPalette>`; `initialize()` reads `kPrefPalette` only when `kDesignToolsEnabled`, defaults to `ModernPalette`; `cycle()` toggles Modern↔Trust and persists ONLY when `kDesignToolsEnabled`; release pin (`kDesignToolsEnabled = false`) makes `cycle()` a no-op
  - **Verify**: a unit test under `kDesignToolsEnabled = true` confirms `cycle()` flips the state and persists; a separate test path simulates `kDesignToolsEnabled = false` (via a runtime shim that mirrors the compile-time const) and confirms `cycle()` is a no-op

- [X] T064 [US3] Create `test/core/theme/palette_cubit_test.dart` covering all transitions from `contracts/palette-cubit.md` (fresh / persisted / corrupt / cycle / cycle×2 / release-pin)
  - **Verify**: `flutter test test/core/theme/palette_cubit_test.dart` passes all six cases

### PaletteTester chip widget

- [X] T065 [US3] Create `lib/core/widgets/palette_tester.dart` per component-library #33 + screens-and-components §5.18: 32 dp pill; swatch dot (active primary) + name label + cycle icon; absolute floating position top-leading with `lg` (16) inset; `kDesignToolsEnabled` gate at the top of `build()` returning `SizedBox.shrink()` when `false`; tap triggers `PaletteCubit.cycle()` then a snackbar; long-press opens a fullscreen palette explorer modal showing every token side-by-side
  - **Verify**: a widget test with `kDesignToolsEnabled` simulated as `true` mounts the chip, taps it, asserts a `Cubit` `cycle()` call and a snackbar appearance; with `kDesignToolsEnabled` simulated as `false`, the widget is `SizedBox.shrink()`

- [X] T066 [US3] Wire the chip overlay into `lib/app.dart`: stack the `PaletteTester` above the router outlet inside the `MaterialApp.builder`, surfaced on every screen; the tree-shake guard inside the chip handles release absence (depends on T065)
  - **Verify**: `flutter run --debug --dart-define=DESIGN_TOOLS=true` renders the chip on the shell home; building release `flutter build apk --release` and inspecting size with `flutter build apk --analyze-size` shows `palette_tester.dart` absent from the reachable code list

### Tree-shake assertion

- [X] T067 [US3] Add a manual verification step to `quickstart.md` step 8 (already drafted) confirming the chip is absent in release; also add a `test/widgets/palette_tester_release_pin_test.dart` widget test that asserts under a simulated release-equivalent flag the widget produces no rendered output (depends on T065)
  - **Verify**: the widget test passes; the manual quickstart step is reproducible

**Checkpoint**: User Story 3 is complete — the runtime palette comparison loop is closed for QA; production end users see only Modern (FR-015 unchanged).

---

## Phase 6: User Story 4 — Visual-regression coverage on PropertyCard (Priority: P2)

**Goal**: Pixel-level drift in `PropertyCard` is caught automatically. Phase 2 establishes the golden-suite floor at the highest-traffic component × 4 environment combinations under Modern; expansion to other components is deferred (per Q1 clarification + research).

**Independent Test**: `flutter test test/widgets/property_card_golden_test.dart` passes against the committed goldens. Modify `PropertyCard` padding by 4 dp on a development branch — the test fails in all 4 combinations with a diff image emitted. Revert — test passes again.

### Golden suite

- [X] T068 [US4] Create `test/widgets/property_card_golden_test.dart`: mounts `PropertyCard` with deterministic sample data (locked title, price, location, area, bed/bath counts, image asset), iterates the 4 combinations (light × ar, light × en, dark × ar, dark × en) under Modern, and calls `matchesGoldenFile('test/goldens/property_card/<theme>_<locale>.png')` for each
  - **Verify**: running `flutter test --update-goldens test/widgets/property_card_golden_test.dart` once on a clean tree generates 4 PNG files; subsequent `flutter test test/widgets/property_card_golden_test.dart` runs match those goldens

- [X] T069 [US4] Commit the four generated golden PNGs at `test/goldens/property_card/{light_ar,light_en,dark_ar,dark_en}.png` (depends on T068)
  - **Verify**: `git ls-files test/goldens/property_card/` lists exactly 4 PNG files; `git diff` after `flutter test test/widgets/property_card_golden_test.dart` is empty

### Theme Gallery (debug surface — supports US4 visual review + US3 palette QA)

- [X] T070 [US4] Create `lib/debug/theme_gallery_page.dart` per [`contracts/theme-gallery.md`](contracts/theme-gallery.md): switcher row at top (locale / theme / palette pill segments); component sections below grouped by category (Chrome / Inputs / Cards / Badges / Sheets / Dialogs / Feedback / Media / Chat / Price / BottomNav / PaletteTester); each section renders every variant × every applicable state with labels
  - **Verify**: opening `/_debug/theme-gallery` in a debug build renders the page without exceptions in all 8 combinations

- [X] T071 [US4] Update `lib/core/routing/app_router.dart` to register `/_debug/theme-gallery` route conditionally on `kDesignToolsEnabled`; the import of `theme_gallery_page.dart` MUST sit inside the `if (kDesignToolsEnabled)` branch so dead-code elimination drops the page from release builds (depends on T070)
  - **Verify**: `flutter run --debug --dart-define=DESIGN_TOOLS=true` reaches the gallery via `context.go('/_debug/theme-gallery')`; `flutter build apk --release` with no flags produces an APK where searching for the literal `_debug/theme-gallery` returns no hits

- [X] T072 [US4] Create `test/widgets/theme_gallery_test.dart` mounting `ThemeGalleryPage` in each of the 4 base combinations (light × ar, light × en, dark × ar, dark × en) under Modern and asserting no exceptions, every section header renders, and the three switcher pills are tappable
  - **Verify**: `flutter test test/widgets/theme_gallery_test.dart` passes

**Checkpoint**: User Story 4 is complete — `PropertyCard` regressions are blocked at PR time; the Theme Gallery exists as the design-review surface for the next 22 phases.

---

## Phase 7: Polish & Cross-Cutting

**Purpose**: Close out the spec — exercise the full quickstart on the reference device, sweep documentation, and ensure CI gates the design-system invariants for every PR going forward.

- [ ] T073 [P] Run `quickstart.md` steps 1–10 end-to-end on the Infinix Note 8 reference device (Helio G80, 6 GB RAM, Android 10/11) and record results in a short pass/fail table embedded as a comment in the eventual PR description
  - **Verify**: every step's pass signal is observed; any failures are filed as follow-ups before merge

- [ ] T074 [P] Update `.github/workflows/ci.yml` adding a golden-test step (`flutter test test/widgets/property_card_golden_test.dart`) and the contrast-floor test (`flutter test test/core/theme/color_scheme_contrast_test.dart`) — both must already be covered by the broad `flutter test` step but explicit steps make CI failure messages clearer
  - **Verify**: a deliberate hex drift in `color_palette.dart` (e.g., changing `#1D4ED8` to `#1E4ED8`) flips the contrast / palette tests red; reverting passes

- [ ] T075 Sweep `lib/` for any inline color / `TextStyle` / spacing literal that the lint guard L3–L5 rules might have missed during early Phase 2 implementation; if any are found, refactor to the token API
  - **Verify**: `dart run tool/lint_design_tokens.dart` exits 0 on the entire `lib/` tree

- [ ] T076 Update `docs/PROJECT_BLUEPRINT.md` (if it exists at this point) and the per-spec navigator entries to reflect the new design-system artifacts, and re-confirm `CLAUDE.md`'s SPECKIT block is current
  - **Verify**: `grep -E "002-design-system" docs/` returns matches in the navigator; `CLAUDE.md` SPECKIT block names spec 002

- [ ] T077 Performance sanity: run `flutter run --profile` on the reference device, navigate the Theme Gallery, fling-scroll the long components list, and confirm DevTools shows no skipped frames and rasterizer time stays under 16 ms
  - **Verify**: matches `quickstart.md` step 10's pass signal; results recorded in the PR description

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories.
- **User Stories**:
  - **US1 (Phase 3)** — depends on Foundational (Phase 2). Independent of US2/US3/US4.
  - **US2 (Phase 4)** — depends on Foundational (Phase 2). Independent of US1 architecturally, but US2's per-component RTL/LTR matrix (T062) extends the widget tests US1 introduced (T057), so practically US2's T062 lands after US1's T057.
  - **US3 (Phase 5)** — depends on Foundational (Phase 2). Independent of US1/US2/US4.
  - **US4 (Phase 6)** — depends on US1's `PropertyCard` (T047) for the golden suite; otherwise independent.
- **Polish (Phase 7)**: Depends on all desired user stories.

### Within Each User Story

- US1 implementation tasks T022–T056 are mostly file-disjoint (`[P]`-marked); the per-component widget test task T057 depends on the components existing.
- US2's contrast test T061 and palette test T060 depend on Phase 2's `color_palette.dart` (T011) only.
- US3's chip wiring T066 depends on the chip widget T065 and the `PaletteCubit` T063.
- US4's golden suite T068 depends on `PropertyCard` (T047); the gallery T070 depends on every kit component existing.

### Parallel Opportunities

- All Setup `[P]` tasks (T002–T007) can run in parallel after T001.
- All Foundational `[P]` token primitives (T009, T010) can run in parallel; `colors.dart` (T012), `elevation.dart` (T014), `typography.dart` (T013) parallelize once `color_palette.dart` (T011) exists.
- Phase 3 component creation tasks (T022 through T056) are file-disjoint and can be tackled in any parallel order, modulo the `AppButton` and `EmptyState`/`LoadingState`/`ErrorState` being widely depended upon by composite components — start those first.
- US2's T060 / T061 are independent of US1 entirely once Foundational is done — a second developer (or agent) can sweep the contrast verification while US1 component work proceeds.
- US3's `PaletteCubit` (T063) and `PaletteTester` (T065) can be developed alongside late US1 component work since neither touches the kit components themselves.

### MVP scope

The MVP per the spec's priority labels is **User Story 1** alone. Completing Setup + Foundational + Phase 3 ships:

- A consumable token API + 33-file widget kit + 3 shared shims
- The lint guard preventing drift
- An Modern-light-only end-user experience (dark + Trust palette aren't quality-verified yet — that's US2 and US3)

Practically, US1 + US2 together is the smallest production-ready slice (locks light + dark + WCAG AA + RTL correctness). US3 (palette tester) and US4 (goldens) are quality-of-life gates that don't change end-user surface but de-risk all later phases.

---

## Implementation Strategy

### Suggested order (single-developer / single-agent sequential)

1. Phase 1 Setup (T001–T008) → fonts + flags + key constants land.
2. Phase 2 Foundational (T009–T017) → tokens + theme builder land; existing shell home migrates off the stub.
3. Phase 3 US1 — start with the lint guard (T018–T021) so every subsequent component lands behind the no-drift gate.
4. Phase 3 US1 — components in the order: buttons (T022) → feedback states (T044–T046) → form fields (T028–T040) → inputs (T025–T027) → chrome (T023, T024) → cards + composite (T047–T053) → shims (T054–T056) → widget tests (T057).
5. Phase 4 US2 — theme cubit extension (T058, T059) + contrast tests (T060, T061) + RTL test sweep (T062).
6. Phase 5 US3 — palette cubit (T063, T064) + chip (T065, T066, T067).
7. Phase 6 US4 — Theme Gallery (T070, T071, T072) → goldens (T068, T069).
8. Phase 7 Polish (T073–T077).

### Parallel team strategy

- Developer A: Phase 1 Setup → Phase 2 Foundational → US1 components (chrome + cards + composite).
- Developer B: in parallel after Foundational: US1 form fields + inputs + lint guard.
- Developer C: in parallel after Foundational: US2 contrast / palette tests + theme cubit; then US3 (palette cubit + chip) once US2 is complete.
- Developer A loops back for US4 Theme Gallery + goldens once US1 + US2 complete.
- Single integration cadence: per spec branch contract, one PR for the whole spec at the end (per the durable git workflow contract — `ONE PR per spec`).

---

## Notes

- `[P]` = different files, no dependency on incomplete tasks.
- `[USx]` traces a task back to its user story for review.
- Every `**Verify**:` line is a Constitution Principle X requirement — a task without a verifiable outcome is rejected at task review.
- Commit cadence: one commit per logical task group (Setup, Foundational, each user story, Polish) — matches the Phase 1 commit style. The whole spec lands as a single squash-merge PR per the durable git workflow contract.
- The `screens-and-components.md` catalog is the visual source of truth for every component task — when in doubt about anatomy or state visuals, that doc wins.
