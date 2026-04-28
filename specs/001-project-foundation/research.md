# Phase 0 Research: Project Foundation

**Branch**: `001-project-foundation` | **Date**: 2026-04-28
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

## Purpose

Document the locked technical decisions that flow into Phase 1 implementation, the rationale for each, and the alternatives that were considered and rejected. The `/speckit-clarify` Session 2026-04-28 already resolved the 5 highest-impact ambiguities; this file captures the remaining smaller decisions and the inherited-from-constitution decisions in one place so reviewers and the Phase 2 task generator have a single reference.

There are **no remaining `NEEDS CLARIFICATION` items**. Every decision below is either ratified by clarify, fixed by the AlNujom Constitution v1.0.0, or is a Phase-1-scoped default whose alternative is recorded.

---

## Decision 1 — Flutter version channel

**Decision**: Latest stable Flutter (3.x line, Dart 3.x) at branch-creation time. Pin via `pubspec.yaml` `environment.flutter` field plus an `.fvmrc`/`fvm` config so all contributors and CI use the same version.

**Rationale**: Constitution Principle XI fixes Flutter as the platform; "latest stable" is the constitutional default ("Flutter (latest stable)"). Pinning prevents drift between local and CI.

**Alternatives considered**:
- *Beta channel* — rejected; unstable, defeats the foundation goal.
- *Older LTS pin* — rejected; no LTS exists for Flutter, and we'd carry forward known plugin bugs.

---

## Decision 2 — State management library

**Decision**: `flutter_bloc` for both BLoCs (event-driven) and Cubits (method-driven); use Cubits as the default and BLoCs only when a feature genuinely benefits from explicit event modelling.

**Rationale**: Constitution Principle IV explicitly fixes BLoC/Cubit. `flutter_bloc` is the canonical implementation. Cubits are lighter and a strict subset of BLoCs, so starting with Cubit and graduating to BLoC where warranted minimizes boilerplate.

**Alternatives considered**:
- *`provider` only* — rejected; Constitution IV mandates BLoC/Cubit.
- *`riverpod`* — rejected; not the constitutional choice; switching would require an amendment.

---

## Decision 3 — Navigation library (locked here per constitution)

**Decision**: `go_router`. Locked for all phases.

**Rationale**: Constitution `Additional Constraints` §Mobile client says "go_router or equivalent for navigation (decided in the first feature plan, then locked)". This is that plan. `go_router` ships from the Flutter team, supports declarative routing, deep links, redirect guards (useful for Phase 5 auth gating), and nested navigators. Mature, well-documented, and the largest community.

**Alternatives considered**:
- *`auto_route`* — rejected; codegen-heavy, slower iteration, less Flutter-team alignment.
- *Plain `Navigator 2.0`* — rejected; high boilerplate cost, every later phase would re-pay it.

---

## Decision 4 — Dependency injection

**Decision**: `get_it` as the service locator, `injectable` for code-generated registration. Generated `injection.config.dart` is committed.

**Rationale**: Aligned with the IMPLEMENTATION_PLAN.md Phase 1 deps list. `get_it` is widely used with BLoC; `injectable` removes manual registration boilerplate while keeping the runtime locator transparent. Committing the generated config lets reviewers diff the DI graph in PRs.

**Alternatives considered**:
- *Hand-rolled service locator* — rejected; reinvents `get_it`.
- *`riverpod` for DI + state* — rejected; conflicts with Decision 2 (BLoC/Cubit).

---

## Decision 5 — Backend SDK isolation pattern

**Decision**: A `SupabaseClientWrapper` interface in `lib/core/network/supabase_client_wrapper.dart` exposes only the surface area later phases need (auth state stream, table query helpers, storage upload, RPC call, realtime channel factory). The single concrete implementation in `supabase_client_wrapper_impl.dart` is the only file in the entire `lib/` tree that imports `package:supabase_flutter`. A CI grep guard fails the pipeline if any other file imports it.

**Rationale**: Constitution Principle IX (Future Backend Portability) and FR-009. Confining the SDK to one file means a v2 backend swap edits one file's body, not 24 phases of features.

**Alternatives considered**:
- *Allow `supabase_flutter` in `data/` layers across features* — rejected; weakens portability and lets Supabase types leak into domain via type inference.
- *Wrap individual SDK calls per-use-case* — rejected; explodes interface surface; the wrapper-with-narrow-API approach scales better.

---

## Decision 6 — Local persistence library

**Decision**: `flutter_secure_storage` for theme + locale. A single `PreferencesStore` interface in `lib/core/storage/preferences_store.dart`; secure-storage-backed impl is the only Phase-1 implementation.

**Rationale**: Listed in the IMPLEMENTATION_PLAN Phase 1 deps. Backed by Android Keystore on Android, so we get OS-level encryption "for free" without doing any explicit crypto. The values in question (theme mode + locale code) are not sensitive, but standardizing on secure storage from Phase 1 means Phase 5 (auth) can store session tokens through the same interface without introducing a second persistence library.

**Alternatives considered**:
- *`shared_preferences`* — rejected; unencrypted, and we'd need a second persistence path for Phase 5 anyway.
- *`hive`* — rejected; overkill for two scalar values, adds a binary box on disk.

---

## Decision 7 — Logging interface

**Decision**: `lib/core/logging/app_logger.dart` defines an `AppLogger` interface with `debug/info/warning/error` methods. The default implementation `console_logger.dart` writes via `dart:developer.log` in debug builds and is a no-op in release builds. No third-party logging package in Phase 1.

**Rationale**: FR-011 only requires a severity-aware logging mechanism, not a sink. Crash reporting is explicitly out of scope (spec Assumptions). A minimal interface keeps Phase 1 dependency-light and lets a future spec (Sentry, Crashlytics) plug in by registering a different `AppLogger` impl in DI without touching call sites.

**Alternatives considered**:
- *`logger` package* — rejected; another dependency for what is essentially `print`-with-levels.
- *`firebase_crashlytics` from Phase 1* — rejected; spec excludes crash reporting; adds Firebase config at zero immediate value.

---

## Decision 8 — Result/Failure type design

**Decision**: A sealed Dart class hierarchy:

```text
sealed class Result<T> { const Result(); }
final class Success<T> extends Result<T> { final T value; }
final class FailureResult<T> extends Result<T> { final Failure failure; }

sealed class Failure { final String message; const Failure(this.message); }
final class NetworkFailure extends Failure { ... }
final class CacheFailure extends Failure { ... }
final class ConfigFailure extends Failure { ... }   // used by FR-013 backend-config-missing path
final class UnknownFailure extends Failure { ... }
```

`Failure` subtypes grow per-feature in later phases. Never use `try/catch` across architectural boundaries; data sources catch SDK exceptions and return `FailureResult`.

**Rationale**: Constitution Principle IV mandates that domain code not throw across boundaries; FR-010 codifies this. Sealed classes give exhaustive `switch` checks (Dart 3 pattern matching) in BLoCs.

**Alternatives considered**:
- *`dartz`'s `Either<L, R>`* — rejected; unfamiliar for Dart-first contributors and adds a dependency.
- *Throwing exceptions* — rejected; Constitution IV.

---

## Decision 9 — ARB scaffolding (defer real strings to Phase 3)

**Decision**: Generate `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` containing only the placeholder strings Phase 1 displays: `appTitle`, `themeToggleLabel`, `localeToggleLabel`, `currentTheme`, `currentLocale`. Phase 3 expands these. Set `pubspec.yaml`'s `flutter.generate: true` and `l10n.yaml` so the gen-l10n tool produces typed `AppLocalizations`.

**Rationale**: Constitution Principle V; the localization gate ("new strings need ar+en") starts from Phase 1. Real Syrian-Arabic phrasing for Phase 1 placeholder strings is acceptable "Modern Standard Arabic" since they are debug-facing labels, not user-flow copy.

**Alternatives considered**:
- *Inline string literals + a stub `Locale` switcher* — rejected; the constitution explicitly forbids inline literals.
- *No ARB until Phase 3* — rejected; the gen-l10n wiring itself is part of the foundation.

---

## Decision 10 — Toggle placement on the shell home (Phase-1-only UX)

**Decision**: Two `OutlinedButton`s (or `SwitchListTile`s) directly on the shell home `Scaffold` body, vertically stacked, beneath the brand mark. Both labelled with localized strings; both sized at 48dp+ for FR-017.

**Rationale**: Spec Assumptions: "The theme and locale toggles in Phase 1 are placed on the shell screen itself for ease of testing; a real Settings screen lands in Phase 23 and will replace these placeholders." Buttons are the simplest control that satisfies FR-003/FR-004 and is trivially testable in `integration_test`.

**Alternatives considered**:
- *Drawer / bottom sheet* — rejected; more UX scaffolding than Phase 1 needs; Phase 23 will introduce real settings.
- *Debug-only menu hidden behind a long-press* — rejected; the smoke test would be harder to write and the toggles must be visible per FR-003/FR-004.

---

## Decision 11 — `theme_cubit` state model

**Decision**: `ThemeCubit` emits `ThemeMode` (`system | light | dark`). Initial state is `system`. The first explicit toggle (light↔dark) sets state to `light` or `dark` and writes through `PreferencesStore.setThemeMode(...)`. On launch, if a persisted explicit mode exists, the cubit emits it; otherwise it emits `system`. Subsequent OS theme changes are listened to but ignored once a non-`system` mode is persisted.

**Rationale**: FR-016. `ThemeMode.system` is Flutter's native "follow OS" mode, so this maps cleanly to Material's machinery without a custom listener.

**Alternatives considered**:
- *Boolean `isDarkMode`* — rejected; loses the distinction between "user picked light" and "user is letting the OS decide".
- *Always follow system, treat toggle as a one-shot override* — rejected during clarify (Q3 option D).

---

## Decision 12 — `locale_cubit` state model

**Decision**: `LocaleCubit` emits `Locale('ar')` or `Locale('en')`. Initial state on first-ever launch is `Locale('ar')` regardless of device locale (FR-005). Toggling persists via `PreferencesStore.setLocale(...)`. No `system` mode for locale (the Constitution V's Arabic-first principle overrides the device locale).

**Rationale**: FR-005 + Constitution V. Unlike theme, the constitution mandates Arabic as the *product* default — not "follow OS".

**Alternatives considered**:
- *Follow device locale on first launch, fall back to ar* — rejected; FR-005 explicitly forbids this.

---

## Decision 13 — Env-injected configuration

**Decision**: `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read via `String.fromEnvironment(...)` at compile time, supplied by `--dart-define` flags in local `flutter run` and CI build commands. Defaults are empty strings; if either is empty at app launch, the wrapper logs a `ConfigFailure` warning and the shell launches anyway (FR-013). A `--dart-define-from-file=.env.json` pattern is documented in `quickstart.md` for local dev convenience; `.env.json` is `.gitignore`'d.

**Rationale**: Spec Assumptions ("Backend connection details … env-injected … NOT committed"). `--dart-define` is Flutter's standard mechanism. Compile-time injection means the secret never lives in any committed file.

**Alternatives considered**:
- *`flutter_dotenv` package* — rejected; reads `.env` at runtime, which means the file ships in the APK assets bundle.
- *Hard-coded for dev, env-injected only for release* — rejected; defeats the "no committed secrets" rule even in dev.

---

## Decision 14 — CI pipeline shape

**Decision**: `.github/workflows/ci.yml` defines one job, `verify`, on `pull_request` (any target) and on `push` to `001-*` feature branches. Steps:

1. Checkout
2. Setup Java 17 (`actions/setup-java@v4`, distribution `temurin`)
3. Setup Flutter (`subosito/flutter-action@v2`, channel `stable`, version pinned to `pubspec.yaml`)
4. `flutter pub get`
5. `dart run build_runner build --delete-conflicting-outputs`
6. `dart format --output=none --set-exit-if-changed .`
7. `flutter analyze --fatal-infos`
8. Custom step: `! grep -rE "package:supabase_flutter" lib --include='*.dart' --exclude='supabase_client_wrapper_impl.dart'` → fail if any other file imports the SDK (Constitution IX guard)
9. `flutter test` — runs everything under `test/`, including the FR-012 smoke widget test (`test/widgets/shell_smoke_test.dart`). The smoke test is written with `testWidgets(...)` and pumps `App()` directly, so no Android emulator is required.
10. `flutter build apk --debug --dart-define=SUPABASE_URL='' --dart-define=SUPABASE_ANON_KEY=''` (CI uses empty placeholder values; the smoke test confirms the app boots without real backend access per FR-013)

**Rationale**: FR-015. Spec Assumptions lock GitHub Actions as the host. `subosito/flutter-action` is the de-facto community action and pins Flutter consistently across runners. Step 8 enforces FR-009 mechanically.

**Alternatives considered**:
- *Run on-device `integration_test/` in CI on a hosted Android emulator* — deferred to a future spec (Phase 24 release polish or sooner). Hosted emulators are flaky and slow; Phase 1's smoke test is a widget test under `test/` (boots `App()` via `testWidgets`), which runs in plain `flutter test` without an emulator. Real-device smoke is covered by the local Infinix Note 8 verification per SC-002.
- *Two separate workflows (lint vs. build)* — rejected; one job is simpler and the cost difference is negligible at Phase 1 size.

---

## Decision 15 — Phase-1-only `lib/shell/` directory

**Decision**: The Phase-1 landing surface lives in `lib/shell/shell_home_page.dart` (under `lib/`, NOT at the repo root, NOT under `lib/features/`). It is documented as temporary scaffolding in `spec.md` and will be removed when Phase 13 (Public home & listing details) ships the real home.

**Rationale**: A top-level `shell/` directory at the repo root would not be reachable by `package:alnujom/shell/...` imports (Flutter only compiles code under `lib/`) and would silently never run. Putting it under `lib/features/shell/` would imply feature-first Clean Architecture (presentation/domain/data) — but it has no domain or data layer; it is a purely presentational placeholder. `lib/shell/` keeps the Phase 1 story explicit ("this is scaffolding, not a feature"), is reachable by Flutter's package system, and gives Phase 13 a clean, no-rename replacement target — Phase 13 simply deletes `lib/shell/` and lands `lib/features/home/` in its place.

**Alternatives considered**:
- *Top-level `shell/` at repo root* — rejected; not reachable as a Flutter package import; would not be compiled.
- *Put it under `lib/features/shell/presentation/`* — rejected; misleading taxonomy.
- *Put `shell_home_page.dart` directly in `lib/`* — rejected; clutters the top of the source tree.

---

## Open items deferred to later phases (NOT Phase 1 concerns)

These were considered during research but explicitly deferred:

- **Crash reporting** (Sentry/Crashlytics) — out of scope (spec Assumptions). Future spec will add an `AppLogger` impl that forwards errors.
- **Analytics** — out of scope. Same plug-point pattern as crash reporting.
- **Deep linking** — out of scope. `go_router` already supports it; Phase 16 (Contact, inquiries) is the first phase that needs it.
- **Feature flags** — out of scope. Future spec.
- **Automated accessibility checks in CI** — deferred to Phase 24 release polish or earlier. Phase 1 verifies WCAG 2.1 AA manually per FR-017.
- **Real-device smoke runs in CI** — deferred. Phase 1's CI runs unit/widget/build only; the Infinix Note 8 covers real-device smoke locally per SC-002.
- **Vault enablement** — explicitly Phase 4's deliverable per ADR-0001. Phase 1 introduces no secrets to vault.

---

## Inputs used

- `specs/001-project-foundation/spec.md` (after `/speckit-clarify` Session 2026-04-28)
- `.specify/memory/constitution.md` v1.0.0
- `docs/IMPLEMENTATION_PLAN.md` Phase 1 section
- `docs/decisions/0001-secrets-and-pii-storage.md`
