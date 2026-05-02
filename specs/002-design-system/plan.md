# Implementation Plan: Design System & Theme Tokens

**Branch**: `002-design-system` | **Date**: 2026-05-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-design-system/spec.md`

## Summary

Replace the Phase 1 token stubs with the locked Modern Marketplace design system: a typed token API for colors / typography / spacing / radii / elevation; light + dark `ThemeData` for both the Modern (default, primary `#1D4ED8`) and Trust (alternate, primary `#2457A6`) palettes; a 21-component reusable widget kit under `lib/core/widgets/`; bilingual font assets (Cairo, IBM Plex Sans Arabic, Inter) vendored under `assets/fonts/`; a debug-only Theme Gallery surface and Palette Tester chip; an automated lint guard that fails the build on any raw hex / `TextStyle(...)` / raw pixel spacing in feature code; and golden tests for `PropertyCard` across light/dark × ar/en.

**Technical approach**: All token sources live under `lib/core/theme/` and are exposed via typed wrappers (`AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadii`, `AppElevation`) sourced from `Theme.of(context)` extensions so feature code never touches a hex literal. Two `ColorPalette` instances (Modern, Trust) each produce a `light` and `dark` `ColorScheme`; a `PaletteCubit` provides the active `ColorPalette` (defaulted to Modern, persisted under `app.palette` in `PreferencesStore` only when `kDesignToolsEnabled` is true). The existing `ThemeCubit` from Phase 1 is extended to honor the OS theme on first launch (FR-016) and update live when the OS theme changes while in `auto` mode. The 21 components in `screens-and-components.md` §5 each ship as one file under `lib/core/widgets/` with the documented states; three feature-shared widgets (`ListingCard` as a thin alias of `PropertyCard`, `PriceDisplay` as an alias of `PriceTag`, plus `AdminListItem`) sit under `lib/shared/presentation/widgets/` per `IMPLEMENTATION_PLAN.md` §Phase 2. The Theme Gallery page lives under `lib/debug/` and registers its route conditionally on `kDesignToolsEnabled`, so it tree-shakes out of release builds. The Palette Tester chip is the same — its `kPaletteTesterEnabled` resolves to a `const false` in release. A standalone Dart script (`tool/lint_design_tokens.dart`) wired into CI provides the FR-007 grep guard. Golden tests for `PropertyCard` use `flutter_test`'s `matchesGoldenFile` running on the host (no emulator), matching Phase 1's "no hosted-emulator" stance.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) — same as Phase 1.
**Primary Dependencies**: `flutter_bloc`, `equatable`, `flutter_lucide` (icon library, locked here per `screens-and-components.md` §3.1), `cached_network_image` (already in Phase 1, used by image placeholders in `PropertyCard`/`OfficeCard`/`ImageGallery`). Dev: `flutter_test` (built-in, used for both widget and golden tests), `bloc_test` (existing), `mockito` (existing). No new state-management or routing dependency — both `flutter_bloc` and `go_router` carry over from Phase 1 unchanged.
**Storage**: `PreferencesStore` from Phase 1 holds `app.theme_mode` (`auto`/`light`/`dark`, FR-016) and — only in debug/QA builds — `app.palette` (`Modern`/`Trust`, FR-009). No DB tables (Phase 2 is frontend-only).
**Testing**: `flutter_test` host-runner widget tests for each component covering its applicable states (default, pressed/focused, disabled, loading, error, empty); `bloc_test` for `PaletteCubit` and the extended `ThemeCubit`; `matchesGoldenFile` golden tests for `PropertyCard` in 4 environment combinations (light × ar, light × en, dark × ar, dark × en) under the Modern palette only (per Q1 clarification: PropertyCard is the Phase 2 floor); a contrast-floor test that walks every WCAG-relevant token pair across both palettes × both themes and asserts the 4.5:1 / 3:1 ratios (FR-002). All tests run via `flutter test` in CI (no emulator), consistent with Phase 1.
**Target Platform**: Android 7.0+ (API 24+); same as Phase 1. iOS, Web, desktop NOT a target (Constitution XI).
**Project Type**: Mobile app (Flutter) — design-system layer of `lib/core/`. No backend changes.
**Performance Goals**: First-frame render of any kit-composed screen < 1s on the Infinix Note 8 reference device (Helio G80, 6 GB RAM); 60 fps scroll on a 50-item `PropertyCard` list (SC-007); palette cross-fade complete within 240 ms when the Palette Tester chip is tapped (US3 acceptance).
**Constraints**: No raw hex literals, no inline `TextStyle(...)`, no raw pixel spacing/radius in feature code (FR-007 — enforced by `tool/lint_design_tokens.dart` from this phase forward). All components use `EdgeInsetsDirectional` and logical alignment (FR-006, Constitution V). All touch targets ≥ 48 × 48 dp (FR-012). No state communicated by color alone (FR-012). Production build MUST omit Theme Gallery and Palette Tester (FR-009, FR-015 — verified by tree-shake assertion in the quickstart). On `auto` theme mode the rendered theme MUST update live without restart when the OS theme flips (FR-016).
**Scale/Scope**: 5 token files; 1 `app_theme.dart`; 2 palettes × 2 themes = 4 `ColorScheme` builds; 21 reusable components in `lib/core/widgets/`; 3 feature-shared widgets in `lib/shared/presentation/widgets/`; 1 Theme Gallery page; 1 Palette Tester chip; 1 lint-guard script; 4 golden images for `PropertyCard`; 3 font families × 4 weights (regular/medium/semibold/bold) = 12 vendored font files. No new Supabase tables, no new Edge Functions, no new migrations.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-clarify` Session 2026-05-02 closed three high-impact ambiguities; no implementation has begun. |
| II. Source-Controlled Backend | **Pass (N/A)** | Phase 2 introduces no Supabase artifacts. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass (N/A)** | No tables, no RLS, no service-role surface in Phase 2. |
| IV. Clean Architecture Flutter | **Pass** | The design system is shared infrastructure under `lib/core/`. It exposes no domain entities and no Supabase types. Future feature `presentation/` layers consume this kit; `domain/` and `data/` layers are unaffected. |
| V. Arabic-First Localization | **Pass** | Every component uses `EdgeInsetsDirectional`, logical alignment, and `Directionality`-aware mirroring (FR-006). Components accept any string via parameter — they own no translatable copy themselves; ARB content remains a Phase 3 concern. The Cairo + IBM Plex Sans Arabic + Inter typography stack is locked here per `decision.md`. |
| VI. Theme System & Design Tokens | **Pass — this is the principle this phase realizes.** | Phase 1's `tokens_stub.dart` is replaced by `colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, `elevation.dart`. `tool/lint_design_tokens.dart` enforces FR-007 in CI. Every kit component reads from `Theme.of(context)` or the typed token API; no hex literals, no inline `TextStyle`. |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | Phase 2 has no roles, no permissions, no admin actions. Triggers from Phase 6. |
| VIII. Approval Workflow & Publisher Identity | **Pass (N/A)** | Phase 2 has no publishers, no listings. Triggers from Phase 5. |
| IX. Future Backend Portability | **Pass** | The design system imports nothing from `package:supabase_flutter`. The Phase 1 grep guard that confirms only `supabase_client_wrapper_impl.dart` imports the SDK continues to apply unchanged. |
| X. Testable AI Workflow | **Pass** | Every FR maps to a verifiable acceptance criterion: contrast-floor test (FR-002, SC-002), golden suite (FR-011, SC-006), lint guard (FR-007, SC-001), tree-shake assertion (FR-009, FR-014, FR-015, SC-003), live OS-theme test (FR-016). `tasks.md` (next workflow step) will carry per-task acceptance criteria. |
| XI. Android-First MVP | **Pass** | Component widgets target the Android Material 3 surface only. No platform-conditional code, no iOS/Web variants. |
| XII. No Hidden Product Decisions | **Pass** | Three clarifications captured in `spec.md` `## Clarifications` (visual-regression scope, production palette control, theme-mode default); two cross-document conflicts (radius scale, `ListingCard`/`PropertyCard` naming) recorded in `## Assumptions`; remaining defaults (font subsetting, lint-guard implementation choice) documented in `research.md`. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-design-system/
├── plan.md                # This file
├── research.md            # Phase 0 — locked tech decisions + remaining defaults
├── data-model.md          # Phase 1 — token entities, palette/theme/state enums (no DB)
├── quickstart.md          # Phase 1 — reviewer/agent end-to-end validation recipe
├── contracts/             # Phase 1 — internal interface contracts feature phases consume
│   ├── design-tokens.md
│   ├── component-library.md
│   ├── theme-cubit.md
│   ├── palette-cubit.md
│   ├── theme-gallery.md
│   └── lint-guard.md
├── checklists/
│   └── requirements.md    # From /speckit-specify (validated)
├── spec.md                # From /speckit-specify (clarified)
└── tasks.md               # Created by /speckit-tasks (NOT by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── main.dart                                     # (existing) Entry; initializes DI, runs App
├── app.dart                                      # (existing) MaterialApp.router host; updated to read both ThemeCubit and PaletteCubit
├── core/
│   ├── flags/
│   │   └── app_flags.dart                        # NEW — kDesignToolsEnabled, kPaletteTesterEnabled (const, false in release)
│   ├── theme/
│   │   ├── app_theme.dart                        # REWRITE — ThemeData.light/dark builders parameterised by ColorPalette
│   │   ├── color_palette.dart                    # NEW — sealed ColorPalette (Modern, Trust); each emits a light + dark ColorScheme
│   │   ├── colors.dart                           # NEW — AppColors typed token API (sourced from Theme.of(context))
│   │   ├── typography.dart                       # NEW — AppTextStyles (Cairo / IBM Plex Sans Arabic / Inter)
│   │   ├── spacing.dart                          # NEW — AppSpacing (xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48)
│   │   ├── radii.dart                            # NEW — AppRadii (sm 8 / md 12 / lg 16 / xl 20 / pill 999)
│   │   ├── elevation.dart                        # NEW — AppElevation (level 0–3 shadows + dark-mode hairline border helper)
│   │   ├── theme_cubit.dart                      # UPDATE — extend to honor OS theme on first launch (FR-016) + live OS-theme listener
│   │   ├── palette_cubit.dart                    # NEW — Modern/Trust selection; persists only when kDesignToolsEnabled
│   │   └── tokens_stub.dart                      # DELETE — superseded by the five token files above
│   └── widgets/                                  # FILL — 21 components (one per file)
│       ├── app_app_bar.dart                      # AppBar with default/withBack/withSearch/transparentOnImage variants
│       ├── search_field.dart
│       ├── location_selector.dart
│       ├── category_chip.dart
│       ├── property_card.dart                    # Vertical + horizontal layouts
│       ├── office_card.dart
│       ├── app_button.dart                       # filled-primary / filled-success / outlined / tonal / text / destructive / icon-button / FAB; regular + dense
│       ├── app_text_field.dart                   # text input — base case
│       ├── app_phone_field.dart                  # +963 prefix variant
│       ├── app_password_field.dart               # eye toggle variant
│       ├── app_multi_line_field.dart
│       ├── app_number_field.dart                 # with leading/trailing unit suffix
│       ├── app_currency_field.dart               # USD/SYP toggle
│       ├── app_dropdown.dart
│       ├── app_stepper_input.dart                # − value +
│       ├── app_date_picker.dart
│       ├── app_toggle.dart
│       ├── app_checkbox.dart
│       ├── app_radio_group.dart                  # also covers segmented control
│       ├── app_tabs.dart
│       ├── app_badge.dart                        # featured / new / status pending|approved|rejected / verified office
│       ├── app_bottom_sheet.dart
│       ├── app_dialog.dart
│       ├── empty_state.dart
│       ├── loading_state.dart                    # skeleton helpers
│       ├── error_state.dart
│       ├── stepper_indicator.dart                # multi-step form progress
│       ├── image_gallery.dart                    # carousel + fullscreen
│       ├── map_preview.dart                      # static map placeholder (real map is Phase 15)
│       ├── chat_bubble.dart
│       ├── price_tag.dart                        # bold primary number + currency suffix
│       ├── app_bottom_nav.dart                   # 5-tab spine
│       └── palette_tester.dart                   # debug-only floating chip (gated by kPaletteTesterEnabled)
├── shared/
│   └── presentation/
│       └── widgets/                              # NEW — feature-shared shims per IMPLEMENTATION_PLAN §Phase 2
│           ├── listing_card.dart                 # thin alias / re-export of PropertyCard (per Assumption: same visual treatment)
│           ├── price_display.dart                # thin alias of PriceTag
│           └── admin_list_item.dart              # admin-list row primitive (used by Phase 7+ admin screens)
└── debug/                                        # NEW — design-tools-only code; tree-shaken in release
    └── theme_gallery_page.dart                   # exercises every component × every state; locale/theme/palette switchers; route registered only when kDesignToolsEnabled

assets/
└── fonts/                                        # NEW — vendored families (FR-010)
    ├── Cairo-Regular.ttf, Cairo-Medium.ttf, Cairo-SemiBold.ttf, Cairo-Bold.ttf
    ├── IBMPlexSansArabic-Regular.ttf, ...-Medium.ttf, ...-SemiBold.ttf, ...-Bold.ttf
    └── Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf, Inter-Bold.ttf

test/
├── core/
│   ├── theme/
│   │   ├── theme_cubit_test.dart                 # UPDATE — covers FR-016 (auto/light/dark + live OS-theme switch)
│   │   ├── palette_cubit_test.dart               # NEW
│   │   ├── color_scheme_contrast_test.dart       # NEW — WCAG floor across both palettes × both themes (FR-002)
│   │   └── color_palette_test.dart               # NEW — Modern/Trust resolve correct token quintet
│   └── widgets/                                  # NEW — one widget test per component (state coverage per FR-005)
│       ├── app_button_test.dart
│       ├── app_text_field_test.dart
│       ├── property_card_test.dart
│       ├── ... (one per kit component)
│       └── palette_tester_test.dart              # confirms tree-shake guard: chip is absent under kPaletteTesterEnabled=false
├── widgets/
│   └── property_card_golden_test.dart            # NEW — 4-combo golden suite (FR-011, SC-006)
└── lint/
    └── design_tokens_lint_test.dart              # NEW — runs the lint script as a test; fails if grep finds any violation

test/goldens/
└── property_card/
    ├── light_ar.png
    ├── light_en.png
    ├── dark_ar.png
    └── dark_en.png

tool/
└── lint_design_tokens.dart                       # NEW — Dart script; CI runs `dart run tool/lint_design_tokens.dart`

.github/workflows/
└── ci.yml                                        # UPDATE — add lint-guard step + golden test run
```

**Structure Decision**: The design system is layered under the existing Phase 1 `lib/core/` infrastructure (Constitution IV's "feature-agnostic shared layer"). The five token files and the `app_theme.dart` builder live in `lib/core/theme/`; the 21 components live in `lib/core/widgets/`; debug-only surfaces (Theme Gallery, Palette Tester) live in `lib/debug/` so the `lib/debug/` import boundary makes their tree-shake gating obvious to reviewers. The three feature-shared shims (`ListingCard`, `PriceDisplay`, `AdminListItem`) live under `lib/shared/presentation/widgets/` per `IMPLEMENTATION_PLAN.md` §Phase 2, even though two of the three are aliases of canonical `lib/core/widgets/` components — the alias indirection lets later feature phases import the documented name without churning. The Phase 1 `tokens_stub.dart` is deleted in this phase; its consumers (the temporary `lib/shell/`) are migrated to the real token API in the same change.

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
