# Implementation Plan: Project Foundation

**Branch**: `001-project-foundation` | **Date**: 2026-04-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-project-foundation/spec.md`

## Summary

Stand up the runnable AlNujom Android app shell that every later phase will build on: a single branded landing surface with theme and locale toggles, a `lib/core/` scaffolding (DI, routing, error model, logging, storage, network wrapper, theme stub, widget kit stubs), a source-controlled local Supabase project with only `pgcrypto`/`uuid-ossp` enabled, and a hosted GitHub Actions CI pipeline that runs analysis, tests, and a debug-APK build on every push and PR. No product features ship.

**Technical approach**: Flutter (latest stable, Dart 3) targeting Android API 24+. State via BLoC/Cubit (Constitution IV); navigation via `go_router` (locked here per the Constitution's "decided in the first feature plan, then locked"); DI via `get_it` + `injectable`; backend access via a project-defined `SupabaseClientWrapper` so domain code in later phases never imports `package:supabase_flutter` (Constitution IX, FR-009). Theme follows the device system theme until the user makes an explicit selection (FR-016); locale defaults to Arabic with RTL on first launch regardless of device locale (FR-005). Persistence for theme/locale via `flutter_secure_storage`. CI runs on Linux + Android SDK image; the smoke test exercises shell launch + theme toggle + locale toggle. Phase 1 ships placeholder visuals only; final design tokens land in Phase 2 and final ARB content in Phase 3.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel)
**Primary Dependencies**: `flutter_bloc`, `go_router`, `get_it`, `injectable`, `supabase_flutter`, `flutter_localizations`, `intl`, `flutter_secure_storage`, `equatable`, `cached_network_image`. Dev: `injectable_generator`, `build_runner`, `bloc_test`, `mockito`, `flutter_test`, `integration_test`.
**Storage**: Device-local secure storage (Android Keystore via `flutter_secure_storage`) for theme + locale preferences. Supabase Postgres backend exists locally via Supabase CLI but ships only the `init_extensions` migration (`pgcrypto`, `uuid-ossp`); no application tables until Phase 4.
**Testing**: `flutter_test` for unit, widget, and smoke-widget tests; `bloc_test` for Cubit/BLoC tests; `mockito` for fakes. The smoke test is a widget test under `test/` (NOT under `integration_test/`) so it runs as part of plain `flutter test` in CI without requiring a hosted Android emulator. Target: ≥1 Cubit test per locale/theme cubit, plus ≥1 widget smoke test that boots `App()` and exercises both toggles. Hosted-emulator / on-device integration tests are deferred to a future spec.
**Target Platform**: Android 7.0+ (API 24+); 64-bit ARM primary, 32-bit ARM tolerated. iOS, Web, desktop NOT a target (Constitution XI).
**Project Type**: Mobile app (Flutter) + source-controlled Supabase backend tree.
**Performance Goals**: Cold start to interactive shell < 3s on Helio G80-class device (Infinix Note 8 reference) at p95 over 20 launches (SC-002). Theme/locale toggle reflected within one rendered frame (SC-003). Shell debug APK ≤ 25 MB.
**Constraints**: No product features (FR-014). All Supabase SDK access goes through `SupabaseClientWrapper` (Constitution IX, FR-009). No hardcoded hex / `TextStyle(...)` literals in feature code (Constitution VI; full grep enforcement starts in Phase 2, but the rule applies now). Arabic-first; logical RTL/LTR via `EdgeInsetsDirectional` (Constitution V). WCAG 2.1 AA floor (FR-017). Backend connection details env-injected, never committed (spec Assumptions).
**Scale/Scope**: 1 user-facing screen (shell home); 2 visible toggles; ~10 `core/` modules; 1 init-extensions migration; 1 CI workflow; foundation for the remaining 23 phases.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists, `/speckit-clarify` Session 2026-04-28 closed all 5 questions; this plan derives from the spec; no implementation has begun. |
| II. Source-Controlled Backend | **Pass** | All Phase 1 backend artifacts (`supabase/config.toml`, `supabase/migrations/00000000000000_init_extensions.sql`, `supabase/seed.sql`) ship as files in this branch. No live changes via Studio. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | Phase 1 introduces no application tables, so per-table RLS is N/A here. The init migration only enables extensions. The Supabase anon key is env-injected and gated by RLS by design; service-role keys never ship to the client. ADR-0001 (Supabase Vault for secrets/PII) is referenced for future phases but does not require Vault enablement until Phase 4. |
| IV. Clean Architecture Flutter | **Pass** | No feature directories yet; the `lib/core/` scaffolding (DI, errors, routing, network wrapper, logging, storage, theme stubs) is the substrate later features' `presentation/`/`domain/`/`data/` will sit on. The `Result<T>`/`Failure` types ship now so domain layers never throw across boundaries. |
| V. Arabic-First Localization | **Pass** | Locale toggle ships with Arabic as the first-launch default (FR-005). RTL/LTR mirroring proven on Phase 1's two toggles using logical insets. ARB scaffolding lands now (`lib/l10n/`); final translated copy arrives in Phase 3. |
| VI. Theme System & Design Tokens | **Pass** | Theme toggle, light+dark `ThemeData` stubs, and a centralized `lib/core/theme/` token module ship in Phase 1 with placeholder values; final tokens swap in at Phase 2 without changing infrastructure. No hex literals in shell code. |
| VII. Dynamic Roles & Permissions | **Pass (N/A)** | Phase 1 has no roles, no permissions, no admin actions. Constitutional requirement triggers from Phase 6. |
| VIII. Approval Workflow & Publisher Identity | **Pass (N/A)** | Phase 1 has no publishers, no listings, no identity fields. Triggers from Phase 5. |
| IX. Future Backend Portability | **Pass** | `lib/core/network/supabase_client_wrapper.dart` exposes a project-defined interface. `package:supabase_flutter` import is confined to `supabase_client_wrapper_impl.dart`. A grep guard in CI confirms no other file imports the SDK. (FR-009) |
| X. Testable AI Workflow | **Pass** | Every FR maps to spec acceptance scenarios. The smoke test (`test/widgets/shell_smoke_test.dart`) exercises FR-002, FR-003, FR-004 directly; CI runs it via `flutter test` on every push and PR (FR-015). `tasks.md` (the next workflow step) will carry per-task acceptance criteria. |
| XI. Android-First MVP | **Pass** | `pubspec.yaml` declares no iOS, Web, or desktop platforms. `flutter create`-generated `ios/`, `web/`, `windows/`, `macOS/`, `linux/` directories are removed. Plugin compatibility verified for Android only. |
| XII. No Hidden Product Decisions | **Pass** | The 5 deferred decisions surfaced by `/speckit-clarify` are captured in `spec.md` `## Clarifications`; remaining defaults (toggle placement, ARB key naming, log sink) are documented in `spec.md` `## Assumptions` and in `research.md`. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-project-foundation/
├── plan.md              # This file
├── research.md          # Phase 0 output — locked tech decisions + remaining defaults
├── data-model.md        # Phase 1 output — User Preferences (local), no DB tables yet
├── quickstart.md        # Phase 1 output — reviewer/agent end-to-end validation recipe
├── contracts/           # Phase 1 output — internal interface contracts later phases depend on
│   ├── supabase-client-wrapper.md
│   ├── di-container.md
│   ├── app-router.md
│   ├── result-failure.md
│   ├── logger.md
│   └── preferences-store.md
├── checklists/
│   └── requirements.md  # From /speckit-specify (already validated)
├── spec.md              # From /speckit-specify (clarified)
└── tasks.md             # Created by /speckit-tasks (NOT by /speckit-plan)
```

### Source Code (repository root)

```text
# Flutter Android app — single Flutter project + source-controlled Supabase tree

lib/
├── main.dart                                  # Entry; initializes DI, runs App
├── app.dart                                   # MaterialApp.router host; wires theme + locale BLoCs
├── l10n/                                      # ARB scaffolding; en + ar files with placeholder strings only
│   ├── app_en.arb
│   └── app_ar.arb
├── core/
│   ├── config/
│   │   └── env_config.dart                    # Reads SUPABASE_URL, SUPABASE_ANON_KEY from --dart-define
│   ├── di/
│   │   ├── injection.dart                     # @InjectableInit-generated container entry
│   │   └── injection.config.dart              # Generated by build_runner (committed)
│   ├── errors/
│   │   ├── failure.dart                       # Sealed Failure hierarchy
│   │   └── result.dart                        # Result<T> = Success<T> | FailureResult
│   ├── logging/
│   │   ├── app_logger.dart                    # Project-defined logging interface
│   │   └── console_logger.dart                # Default impl: dart:developer.log in debug, no-op in release
│   ├── network/
│   │   ├── supabase_client_wrapper.dart       # Interface (Constitution IX, FR-009)
│   │   └── supabase_client_wrapper_impl.dart  # ONLY file in lib/ that imports package:supabase_flutter
│   ├── routing/
│   │   └── app_router.dart                    # GoRouter config; only route is the shell home
│   ├── storage/
│   │   ├── preferences_store.dart             # Interface for theme + locale persistence
│   │   └── secure_preferences_store.dart      # flutter_secure_storage-backed impl
│   ├── theme/
│   │   ├── app_theme.dart                     # ThemeData.light()/.dark() stubs (real tokens in Phase 2)
│   │   ├── theme_cubit.dart                   # ThemeMode (system/light/dark) state + persistence
│   │   └── tokens_stub.dart                   # Token placeholders consumed by widgets
│   ├── localization/
│   │   └── locale_cubit.dart                  # Locale state + persistence (FR-005)
│   ├── utils/
│   │   └── result_extensions.dart
│   └── widgets/                               # Empty in Phase 1 (.gitkeep only); design-system widgets land in Phase 2
└── shell/                                     # Phase-1-only landing surface (kept under lib/ so Flutter compiles it); replaced in Phase 13
    └── shell_home_page.dart                   # Brand mark + theme toggle + locale toggle

test/
├── core/
│   ├── errors/result_test.dart
│   ├── logging/console_logger_test.dart
│   ├── theme/theme_cubit_test.dart
│   ├── localization/locale_cubit_test.dart
│   └── storage/secure_preferences_store_test.dart
└── widgets/
    ├── shell_home_page_test.dart              # Widget test: brand renders before any toggles land
    └── shell_smoke_test.dart                  # FR-012 widget smoke test: boots App() + exercises toggles; runs in `flutter test`, no emulator

android/                                       # Standard Flutter-generated; minSdk pinned to 24
└── app/build.gradle.kts                       # minSdk 24, targetSdk current, Java 17 toolchain

supabase/
├── config.toml                                # supabase init output, scoped to this repo
├── migrations/
│   └── 00000000000000_init_extensions.sql    # CREATE EXTENSION pgcrypto, uuid-ossp
└── seed.sql                                   # Empty stub with a comment

.github/
└── workflows/
    └── ci.yml                                 # Phase 1 CI: dart format + analyze + test + build apk

docs/
├── IMPLEMENTATION_PLAN.md                     # (existing) cross-phase reference
└── decisions/
    └── 0001-secrets-and-pii-storage.md       # (existing) ADR-0001
```

**Structure Decision**: A single Flutter project under `lib/` (Constitution IV's feature-first Clean Architecture) plus a side-by-side `supabase/` backend tree (Constitution II). No `ios/`, `web/`, `windows/`, `macOS/`, or `linux/` directories — they are deleted from the `flutter create` output (Constitution XI). The Phase-1-only `lib/shell/` directory hosts the temporary landing surface (kept under `lib/` so Flutter's package system reaches it via `package:alnujom/shell/...`); it is documented as scaffolding in `spec.md` and will be replaced in Phase 13 when the real home surface lands. The `lib/core/` directory is feature-agnostic shared infrastructure; later phases create siblings under `lib/features/<feature>/{presentation,domain,data}/` per the constitution.

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
