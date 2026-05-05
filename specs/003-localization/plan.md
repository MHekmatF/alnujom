# Implementation Plan: Localization

**Branch**: `003-localization` | **Date**: 2026-05-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-localization/spec.md`

## Summary

Wire ARB-driven localization end-to-end on top of the Phase 1 / Phase 2 foundation: expand the existing `lib/l10n/app_ar.arb` (default) and `lib/l10n/app_en.arb` corpus from the 6 scaffolding keys to the full Phase 3 floor (app shell + Theme Gallery chrome + standard error messages); regenerate `AppLocalizations` via `flutter gen-l10n`; preserve and tighten the existing `MaterialApp.locale` / `localizationsDelegates` wiring; extend `LocaleCubit` so the missing-translation runtime warning + debug-only visible marker (FR-008) sits behind a thin `AppStrings` wrapper; ship two build-blocking static-analysis scripts (`tool/lint_l10n_literals.dart` and `tool/lint_l10n_parity.dart`) that together enforce FR-004, FR-005, and FR-006 over **all of `lib/`** minus the explicit exemption list (Q1 clarification); add Phase 3 to the existing CI workflow as static-analysis steps only.

**Technical approach**: Phase 1 already wires the Arabic-default bootstrap path — `main.dart` reads `PreferencesStore.readLocale()` (bound to `SecurePreferencesStore`, FR-007) and passes the resolved locale into `App`, which fans `Locale` through `BlocBuilder<LocaleCubit, Locale>` into `MaterialApp.locale`. Phase 2 already vendors Cairo + IBM Plex Sans Arabic + Inter and resolves them via the active `Locale` inside `buildAppTheme`. Phase 3's job is therefore narrow: (a) **content** — expand the ARB corpus; (b) **runtime safety net** — a `AppStrings.of(context)` thin wrapper that, in debug builds only, detects template-fallback (the gen-l10n behavior where a key missing in `app_ar.arb` silently falls back to the `app_en.arb` template) and emits the FR-008 warning + visible `⟦missing:keyname⟧` marker; (c) **static-analysis guard** — two Dart scripts under `tool/` that scan and validate the ARB and `lib/` trees and exit non-zero on any violation, wired into `.github/workflows/ci.yml` as analysis-only steps; (d) **Theme Gallery chrome** — replace the page title, palette/theme/locale toggle labels, and section headers in `lib/debug/theme_gallery_page.dart` with `AppLocalizations` lookups (per Q3 clarification, per-component and per-state internals stay English). Per the durable session feedback, **no new automated tests are added in this phase**; verification is manual UI walkthrough on the Infinix Note 8 reference device per the recipe in `quickstart.md`. The Phase 2 `PropertyCard` golden suite already in the repo is preserved unchanged but is not required to run as a Phase 3 acceptance gate.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) — same as Phase 1 / Phase 2.
**Primary Dependencies**: `flutter_localizations` (built-in), `intl` (already in pubspec via Phase 1 scaffolding), `flutter_bloc` (existing), `flutter_secure_storage` (existing — already backs `SecurePreferencesStore.readLocale/writeLocale`), `injectable` / `get_it` (existing). No new runtime packages. Tooling: `analyzer` package (already a transitive dev dep) — used by `tool/lint_l10n_literals.dart` to walk Dart AST for literal-string detection.
**Storage**: Locale persisted via `flutter_secure_storage` through the existing `SecurePreferencesStore.writeLocale` / `readLocale` path. No DB tables. (Phase 4 introduces the `user_preferences.locale` column; the Phase-5 migration of the local choice into the user-scoped row is owned by the Phase 5 spec, NOT this phase.)
**Testing**: **Manual UI verification on the Infinix Note 8 reference device only.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, this phase introduces NO new automated tests of any kind — no unit, widget, integration, golden, or runtime smoke tests, and no new `flutter test` step in CI. Build-time **static analysis** is in scope and is preserved: `tool/lint_l10n_literals.dart` (FR-006) and `tool/lint_l10n_parity.dart` (FR-005) both fail the build on violations and are wired into CI as analysis-only steps. The existing Phase 2 `PropertyCard` golden suite under `test/widgets/property_card_golden_test.dart` is preserved in source but is NOT required to run as part of Phase 3 acceptance.
**Target Platform**: Android 7.0+ (API 24+); same as Phase 1 / Phase 2. iOS, Web, desktop NOT a target (Constitution XI).
**Project Type**: Mobile app (Flutter) — localization layer (`lib/l10n/`, small additions to `lib/core/localization/`, two scripts under `tool/`, edits to `lib/debug/theme_gallery_page.dart`, one CI workflow update).
**Performance Goals**:
- Fresh install reaches first usable Arabic screen within ≤ 3 s on the Infinix Note 8 (SC-010, constitution baseline).
- Locale toggle propagates across the entire visible UI within one frame (≤ 16 ms after the toggle action) — SC-002. The existing `BlocBuilder<LocaleCubit, Locale>` wrapping `MaterialApp.router` already produces this single-frame rebuild; no new performance work is needed beyond verifying it.

**Constraints**:
- Default locale = Arabic regardless of OS locale (FR-001, Constitution V).
- All user-visible strings sourced from the ARB corpus (FR-004); zero literal strings in any file under `lib/` outside the explicit exemption list (FR-006, Q1 clarification).
- Translation-key parity between `app_ar.arb` and `app_en.arb` enforced by build-blocking script (FR-005).
- `LocaleCubit.toggle()` rebuilds the entire UI live, no app restart, with no transient flash of the previous language (FR-003).
- Mid-flow form input preserved across locale switch (FR-015) — automatic via `TextEditingController` lifecycle, but explicitly verified during manual walkthrough.
- No new font assets in this phase (FR-014); Phase 2's vendored Cairo / IBM Plex Sans Arabic / Inter stack is reused.
- No new top-level locale-management UI (FR-012); only the existing app-shell `LocaleCubit.toggle()` control is touched.
- Numeric, date, and currency formatting NOT introduced (FR-013); strict scope boundary.

**Scale/Scope**:
- 2 ARB files (`app_ar.arb`, `app_en.arb`); each grows from 6 scaffolding keys to the Phase 3 floor of ~20–30 keys (app shell ≈ 6–8 + Theme Gallery chrome ≈ 5–8 + standard error messages ≈ 4–6 + a few extras for the missing-key debug marker copy itself).
- 3 generated localization files under `lib/l10n/` (master + ar + en) — regenerated by `flutter gen-l10n` from the ARB sources.
- 1 new file under `lib/core/localization/`: `app_strings.dart` (the FR-008 thin wrapper with debug-only template-fallback detection + visible marker).
- 2 new scripts under `tool/`: `lint_l10n_literals.dart`, `lint_l10n_parity.dart`.
- 1 update to `lib/debug/theme_gallery_page.dart` (chrome strings → ARB lookups).
- 1 update to `.github/workflows/ci.yml` (add two `dart run tool/...` steps as analysis-only; do NOT add `flutter test` step).
- No new Supabase tables, no new RLS, no new Edge Functions, no new migrations, no new font files, no new packages.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-clarify` Session 2026-05-05 closed three high-impact ambiguities (lint scope, terms list, Theme Gallery scope); no implementation has begun. |
| II. Source-Controlled Backend | **Pass (N/A)** | Phase 3 introduces no Supabase artifacts. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass (N/A)** | No tables, no RLS, no service-role surface in Phase 3. |
| IV. Clean Architecture Flutter | **Pass** | Localization is shared infrastructure under `lib/l10n/` and `lib/core/localization/`. Exposes no domain entities and no Supabase types. Future feature `presentation/` layers consume the kit; `domain/` and `data/` layers are unaffected. |
| V. Arabic-First Localization | **Pass — this is the principle this phase realizes.** | Default locale `ar`, RTL out of the box (FR-001), every user-visible string ARB-sourced (FR-004), `EdgeInsetsDirectional` enforced via Phase 2 components (FR-009), Cairo + IBM Plex Sans Arabic stack honored when locale is `ar` (FR-014), Syrian-friendly seeded terms recorded inline in FR-011. |
| VI. Theme System & Design Tokens | **Pass (N/A)** | No token changes; the bilingual font stack from Phase 2 is reused without modification. |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | Phase 3 has no roles, no permissions, no admin actions. Triggers from Phase 6. |
| VIII. Approval Workflow & Publisher Identity | **Pass (N/A)** | Phase 3 has no publishers, no listings. Triggers from Phase 5 / Phase 12. |
| IX. Future Backend Portability | **Pass** | The localization layer imports nothing from `package:supabase_flutter`. The `user_preferences.locale` column referenced in FR-007 / Assumptions is a Phase 4 concern, not consumed by this phase. |
| X. Testable AI Workflow | **Pass — Justified.** | Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's `## Assumptions` ("Verification posture is manual until the MVP is feature-complete"), this phase verifies every FR through manual UI walkthroughs on the reference device + two build-blocking static-analysis scripts (literal guard + parity check) — both of which satisfy Principle X's "command an agent can run" letter. The constitution explicitly permits "a UI action with expected screen state" as an acceptance step. `quickstart.md` lists the per-FR manual verifications. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All work targets the Android Flutter build only; no platform-conditional code, no iOS / Web variants. |
| XII. No Hidden Product Decisions | **Pass** | Three clarifications captured in `spec.md` `## Clarifications` (lint scope, terms list, Theme Gallery scope); rejected alternatives for missing-translation policy and OS-locale-following recorded in `## Assumptions`; remaining defaults (locale-write-failure UX, screen-reader announcement) explicitly listed as Outstanding low-impact items in the clarification report and deferred to Phase 23. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/003-localization/
├── plan.md                # This file
├── research.md            # Phase 0 — locked tech decisions (gen-l10n config, lint impl, missing-key strategy, exemption-list shape)
├── data-model.md          # Phase 1 — Locale Preference, Translation File, Translation Key, Lint Exemption List (no DB)
├── quickstart.md          # Phase 1 — reviewer/AI agent end-to-end manual verification recipe on the Infinix Note 8
├── contracts/             # Phase 1 — internal interface contracts feature phases consume
│   ├── locale-cubit.md
│   ├── app-strings.md
│   ├── lint-guard-literals.md
│   └── lint-guard-parity.md
├── checklists/
│   └── requirements.md    # From /speckit-specify (validated)
├── spec.md                # From /speckit-specify (clarified Session 2026-05-05)
└── tasks.md               # Created by /speckit-tasks (NOT by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── main.dart                                       # (existing) Bootstraps DI; reads PreferencesStore.readLocale() and passes initialLocale to App. NO CHANGE — already wired.
├── app.dart                                        # (existing) MaterialApp.router host; BlocBuilder<LocaleCubit, Locale> already drives MaterialApp.locale. NO CHANGE.
├── l10n/
│   ├── app_ar.arb                                  # EXPAND — from 6 scaffolding keys to ~20–30 covering app shell + Theme Gallery chrome + standard error messages + missing-key marker copy
│   ├── app_en.arb                                  # EXPAND — parallel English entries
│   ├── app_localizations.dart                      # GENERATED + GITIGNORED — auto-regenerated by `flutter pub get` (pubspec sets `flutter.generate: true`); ARB files are the source of truth
│   ├── app_localizations_ar.dart                   # GENERATED + GITIGNORED
│   └── app_localizations_en.dart                   # GENERATED + GITIGNORED
├── core/
│   └── localization/
│       ├── locale_cubit.dart                       # (existing) NO CHANGE to behavior — already toggles + persists via PreferencesStore (bound to SecurePreferencesStore). May add a docstring referencing FR-007 / FR-003.
│       └── app_strings.dart                        # NEW — `AppStrings.of(context)` thin wrapper around AppLocalizations; debug-only detects template-fallback (key missing in active locale → falls back to en template) and emits FR-008 warning + renders visible `⟦missing:keyname⟧` marker. Release build delegates straight to AppLocalizations.
└── debug/
    └── theme_gallery_page.dart                     # UPDATE — replace hardcoded chrome strings (page title, palette/theme/locale toggle labels, section headers) with AppLocalizations lookups. Per-component and per-state internals stay English (Q3 clarification, debug-only surface, tree-shaken).

tool/
├── lint_design_tokens.dart                         # (existing from Phase 2) NO CHANGE — separate guard for design-token literals.
├── lint_l10n_literals.dart                         # NEW — walks Dart AST under lib/ minus exemption list (FR-006, Q1). Detects raw String literals passed to user-visible widget constructors (Text, AppBar.title, ElevatedButton.child, SnackBar.content, AlertDialog.title|content, TextField labelText|hintText|helperText|errorText, etc.). Exits non-zero with file:line:literal report on violation.
└── lint_l10n_parity.dart                           # NEW — parses app_ar.arb and app_en.arb; fails with a report naming missing keys per locale (FR-005). Ignores ARB metadata keys ("@@locale", "@key" descriptors).

analysis_options.yaml                               # UPDATE — add a `# l10n_lint:exempt` comment-marker convention OR a top-level `l10n_lint_exempt:` block listing the exemption file glob list (translation source files, generated localization files, debug-only design tools, golden test fixtures). Both lint scripts read this list. The chosen format is locked in research.md.

l10n.yaml                                          # (existing from Phase 1) NO CHANGE — `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, `synthetic-package: false`. Verified compatible with the FR-008 missing-key strategy in research.md.

.github/workflows/
└── ci.yml                                          # UPDATE — add two analysis-only steps: `dart run tool/lint_l10n_literals.dart` and `dart run tool/lint_l10n_parity.dart`. Do NOT add a `flutter test` step (per durable no-new-tests rule). The Phase 2 `dart run tool/lint_design_tokens.dart` step (if present) remains unchanged.

# Out of scope — explicitly NOT created in this phase:
# - test/core/localization/*  — no new tests (durable no-new-tests rule)
# - test/widgets/locale_*     — no new tests
# - lib/features/**           — feature screens are owned by their respective phases
# - assets/fonts/**           — fonts vendored in Phase 2; not touched here
# - supabase/migrations/**    — no DB changes; user_preferences.locale lands in Phase 4
```

**Structure Decision**: The Phase 3 footprint is intentionally tiny because Phase 1 already wired the bootstrap path (`main.dart` → `PreferencesStore.readLocale()` → `App(initialLocale)` → `BlocBuilder<LocaleCubit, Locale>` → `MaterialApp.locale`) and Phase 2 already vendored the bilingual font stack and resolved it through `buildAppTheme(palette:, brightness:, locale:)`. The only new runtime code is `lib/core/localization/app_strings.dart` (the FR-008 wrapper). The bulk of the work is **content** (ARB corpus expansion + Theme Gallery chrome translation) and **static analysis** (the two `tool/` scripts wired into CI). Aligning with Constitution IV, the new code is shared infrastructure under `lib/core/localization/` — no feature folders are touched in this phase. The two lint scripts live under `tool/` alongside the existing Phase 2 `lint_design_tokens.dart` so they are discoverable as a coherent guard suite. CI is extended with **analysis-only** steps; no `flutter test` invocation is introduced (durable no-new-tests rule).

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
