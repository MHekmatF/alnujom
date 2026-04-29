---
description: "Tasks list for Phase 1 — Project Foundation (specs/001-project-foundation)"
---

# Tasks: Project Foundation

**Input**: Design documents from `/specs/001-project-foundation/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: Included — FR-012 and SC-004 explicitly require a smoke test that runs on every CI build.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently.

## Format: `[ID] [P?] [Story?] Description`

- **[P]** = different files, no dependency on incomplete tasks → can run in parallel
- **[USx]** = task belongs to user story x (only on Phase 3+ tasks)
- Each task carries an indented `**Verify**:` line with the concrete acceptance check (Constitution Principle X — tasks without verifiable outcomes are rejected at task review)

## Path Conventions

This is a Flutter Android app + a source-controlled `supabase/` backend tree (see plan.md "Project Structure"). Paths below are relative to the repo root `H:\alnujom-project\`.

- Flutter source: `lib/`
- Phase-1-only landing surface: `lib/shell/` (under `lib/` so Flutter compiles it; replaced in Phase 13)
- Unit + widget + smoke-widget tests: `test/` (the FR-012 smoke test lives at `test/widgets/shell_smoke_test.dart`)
- Backend: `supabase/`
- CI: `.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project bootstrap — generate the Flutter scaffold, lock dependency versions, configure Android Gradle for the constitutional minSdk floor, set up the Supabase tree, and ship the GitHub Actions CI workflow so every later task lands with a green/red signal.

- [X] T001 Bootstrap a Flutter project at the repo root via `flutter create --platforms=android --org com.alnujom --project-name alnujom .`, then delete the generated `ios/`, `web/`, `windows/`, `macos/`, `linux/` directories per Constitution Principle XI
  - **Verify**: `git status` shows no `ios/`, `web/`, `windows/`, `macos/`, or `linux/` directories at the repo root; only `android/`, `lib/`, `test/`, `pubspec.yaml`, etc. exist after this task

- [X] T002 [P] Configure `pubspec.yaml`: set `name: alnujom`, pin `environment.flutter` to the latest stable Flutter version, add the locked Phase 1 dependencies (`flutter_bloc`, `go_router`, `get_it`, `injectable`, `supabase_flutter`, `flutter_localizations`, `intl`, `flutter_secure_storage`, `equatable`, `cached_network_image`) and dev_dependencies (`injectable_generator`, `build_runner`, `bloc_test`, `mockito`, `integration_test`); set `flutter.generate: true` for ARB codegen
  - **Verify**: `flutter pub get` resolves cleanly with no warnings about unsupported plugins; `pubspec.lock` records the locked versions

- [X] T003 [P] Configure `android/app/build.gradle.kts`: set `minSdk = 24`, `targetSdk` to the current Flutter-recommended target, JavaVersion `VERSION_17`, applicationId `com.alnujom.app`
  - **Verify**: `flutter build apk --debug` succeeds; the resulting APK's `aapt dump badging` reports `sdkVersion:'24'`

- [X] T004 [P] Author `analysis_options.yaml` at the repo root: extend `package:flutter_lints/flutter.yaml`, set `avoid_print` and `prefer_const_constructors` to error severity, enable `unawaited_futures`
  - **Verify**: `flutter analyze --fatal-infos` runs without errors against the freshly generated project

- [X] T005 [P] Add `.gitignore` entries (or extend the existing `.gitignore`): `.env.json`, `build/`, `.dart_tool/`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `*.iml`, `.idea/`, `android/.gradle/`, `android/local.properties`, `coverage/`, `*.lock` is NOT ignored (commit `pubspec.lock`)
  - **Verify**: `git check-ignore -v .env.json build/ .dart_tool/` returns each path's matched rule from `.gitignore`

- [X] T006 Run `supabase init` in the repo root to generate `supabase/config.toml`, then commit only `supabase/config.toml` (not the Docker volumes / runtime artifacts)
  - **Verify**: `supabase/config.toml` exists, references the project name, and `supabase start && supabase status` succeeds locally

- [X] T007 [P] Create `supabase/migrations/00000000000000_init_extensions.sql` containing `CREATE EXTENSION IF NOT EXISTS pgcrypto;` and `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
  - **Verify**: `supabase db reset` rebuilds the local database with both extensions present (`SELECT extname FROM pg_extension;` returns `pgcrypto` and `uuid-ossp`)

- [X] T008 [P] Create `supabase/seed.sql` containing only a header comment that says it's intentionally empty for Phase 1 and that real seed data lands in Phase 4+
  - **Verify**: file exists, contains the placeholder comment, and `supabase db reset` runs it without error

- [X] T009 [P] Create the empty directory structure with placeholder `.gitkeep` files: `lib/core/{config,di,errors,logging,network,routing,storage,theme,localization,utils,widgets}/`, `lib/l10n/`, `lib/shell/`, `test/core/{errors,logging,storage,theme,localization}/`, `test/widgets/`. Note: `lib/shell/` is under `lib/` so Flutter compiles it; do NOT create a top-level `shell/`. No `integration_test/` is needed in Phase 1 — the smoke test ships as a widget test under `test/widgets/`.
  - **Verify**: `git ls-files | grep -c .gitkeep` reports `19` (one `.gitkeep` per leaf directory listed above: 11 under `lib/core/`, plus `lib/l10n/`, `lib/shell/`, 5 under `test/core/`, and `test/widgets/`); `find lib/shell test/widgets -maxdepth 1` confirms both are present; no top-level `shell/` or `integration_test/` directory exists

- [X] T010 [P] Create `.github/workflows/ci.yml` per research.md Decision 14: trigger on `pull_request` (any target) and on `push` to `001-*` branches; steps in order — checkout, setup-java@v4 (Temurin 17), subosito/flutter-action@v2 (channel stable, pinned to pubspec), `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, the Constitution-IX grep guard `! grep -rE "package:supabase_flutter" lib --include='*.dart' --exclude='supabase_client_wrapper_impl.dart'`, `flutter test`, `flutter build apk --debug --dart-define=SUPABASE_URL='' --dart-define=SUPABASE_ANON_KEY=''`
  - **Verify**: pushing the branch triggers the `verify` workflow on GitHub Actions; the workflow file passes `actionlint` (or GitHub's own validator) with no syntax errors

**Checkpoint**: project compiles to a debug APK; CI workflow file is present and the workflow runs (it may currently fail at later steps because no source code is in place — that's expected and the next phases land it).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the entire `lib/core/` substrate (errors, logging, config, storage, network wrapper, theme stubs, localization scaffolding, DI, router, app skeleton) plus tests for each piece. After this phase the app boots into a blank `Scaffold` placeholder. NO user-visible feature lands here — that's what Phase 3+ stories deliver. **No user story can begin until this phase is complete.**

### Errors module (Constitution Principle IV; FR-010; contract: `contracts/result-failure.md`)

- [X] T011 [P] Implement the sealed `Failure` hierarchy in `lib/core/errors/failure.dart`: abstract sealed `Failure` with `String message`, optional `Object? cause`, `StackTrace? stackTrace`; concrete `NetworkFailure`, `CacheFailure`, `ConfigFailure`, `UnknownFailure`
  - **Verify**: `flutter analyze` is clean; a Dart 3 `switch (failure) { case NetworkFailure(...) ... }` over a `Failure` value compiles with exhaustiveness checking

- [X] T012 [P] Implement `Result<T>` sealed type in `lib/core/errors/result.dart`: `sealed class Result<T>`, `final class Success<T> extends Result<T>` carrying `T value`, `final class FailureResult<T> extends Result<T>` carrying `Failure failure` (depends on T011)
  - **Verify**: a `switch (result) { case Success(:final value): ... case FailureResult(:final failure): ... }` compiles with exhaustiveness checking; `flutter analyze` clean

- [X] T013 [P] Add `lib/core/utils/result_extensions.dart` with `Result<T>.map<U>((T) => U)` and `Result<T>.fold<U>(onSuccess, onFailure)` extensions (depends on T011, T012)
  - **Verify**: helpers preserve `Failure` identity through `.map`; covered by tests in T015

- [X] T014 [P] Write unit tests in `test/core/errors/result_test.dart`: cover `Success`/`FailureResult` round-trip, exhaustive pattern match compiles, `.map` propagates failures unchanged
  - **Verify**: `flutter test test/core/errors/result_test.dart` passes; ≥4 distinct test cases

### Logging module (FR-011; contract: `contracts/logger.md`)

- [X] T015 [P] Define the `AppLogger` interface in `lib/core/logging/app_logger.dart` with `debug/info/warning/error` methods (each takes `String message`, optional `Object? error`, `StackTrace? stackTrace`, `String? tag`)
  - **Verify**: `flutter analyze` clean; the interface has zero implementations yet

- [X] T016 Implement `ConsoleLogger` in `lib/core/logging/console_logger.dart` annotated `@LazySingleton(as: AppLogger)`: in `kDebugMode` forwards to `dart:developer.log` with severity numbers (300 debug, 800 info, 900 warning, 1000 error) and the `tag` as `name`; in release builds all methods are no-ops (depends on T015)
  - **Verify**: covered by T017

- [X] T017 [P] Write `test/core/logging/console_logger_test.dart` using `dart:developer.log` capture (or a `Zone` override) to assert that debug-build calls produce log records with the correct severity and name; release-build behavior is verified via a build-flag-conditional test
  - **Verify**: `flutter test test/core/logging/console_logger_test.dart` passes

### Config module (research.md Decision 13)

- [X] T018 [P] Implement `EnvConfig` in `lib/core/config/env_config.dart` annotated `@singleton`: reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `String.fromEnvironment(...)` at compile time; exposes `bool get isConfigured` returning true iff both values are non-empty
  - **Verify**: a `flutter test` run with `--dart-define=SUPABASE_URL=foo --dart-define=SUPABASE_ANON_KEY=bar` reports `EnvConfig.isConfigured == true`; with no defines, `isConfigured == false`

### Storage module (FR-006; FR-016; contract: `contracts/preferences-store.md`; data model: data-model.md "User Preferences (local)")

- [X] T019 [P] Define the `PreferencesStore` interface in `lib/core/storage/preferences_store.dart`: `Future<Result<ThemeMode?>> readThemeMode()`, `Future<Result<void>> writeThemeMode(ThemeMode mode)`, `Future<Result<Locale?>> readLocale()`, `Future<Result<void>> writeLocale(Locale locale)` (depends on T011, T012)
  - **Verify**: `flutter analyze` clean; types are Dart/Flutter built-ins (`ThemeMode`, `Locale`) — no Supabase types leak across this boundary

- [X] T020 Implement `SecurePreferencesStore` in `lib/core/storage/secure_preferences_store.dart` annotated `@LazySingleton(as: PreferencesStore)`: uses `FlutterSecureStorage` with default Android options; storage keys per data-model.md (`com.alnujom.preferences.theme_mode`, `com.alnujom.preferences.locale_code`); reads tolerate unrecognized values by returning `Success(null)` and logging a warning via injected `AppLogger`; writes that throw return `FailureResult(CacheFailure(...))` (depends on T011, T012, T015, T019)
  - **Verify**: covered by T021

- [X] T021 [P] Write `test/core/storage/secure_preferences_store_test.dart` using a Mockito-generated fake `FlutterSecureStorage`: cover read-absent, read-recognized (`'dark'` → `ThemeMode.dark`), read-unrecognized (`'foo'` → `Success(null)` + warning logged), write-success, write-error → `FailureResult(CacheFailure)`
  - **Verify**: `flutter test test/core/storage/secure_preferences_store_test.dart` passes; ≥5 test cases

### Network wrapper (Constitution Principle IX; FR-009; contract: `contracts/supabase-client-wrapper.md`)

- [X] T022 [P] Define project-defined types `AuthState` and `RealtimeChannel` in `lib/core/network/types/`: enum `AuthState { signedOut, signedIn, error }` and `abstract interface class RealtimeChannel { ... }` — these are NOT re-exports of `supabase_flutter` types
  - **Verify**: `flutter analyze` clean; `grep -r "package:supabase_flutter" lib/core/network/types/` returns nothing

- [X] T023 [P] Define the `SupabaseClientWrapper` interface in `lib/core/network/supabase_client_wrapper.dart` per `contracts/supabase-client-wrapper.md`: required methods `isInitialized`, `initialize({url, anonKey})`, `dispose()`; stub methods `authStateChanges()`, `selectRows(...)`, `rpc(...)`, `uploadObject(...)`, `realtimeChannel(...)` (depends on T011, T012, T022)
  - **Verify**: `flutter analyze` clean; the interface file MUST NOT import `package:supabase_flutter`

- [X] T024 Implement `SupabaseClientWrapperImpl` in `lib/core/network/supabase_client_wrapper_impl.dart` annotated `@LazySingleton(as: SupabaseClientWrapper)`: this is the **only** file in `lib/` allowed to `import 'package:supabase_flutter/...';`. `initialize` returns `FailureResult(ConfigFailure)` if `url` or `anonKey` is empty (FR-013); otherwise calls `Supabase.initialize(url:, anonKey:)`. Stub methods throw `UnimplementedError('wired up in Phase X')` (depends on T011, T012, T015, T022, T023)
  - **Verify**: `grep -rE "package:supabase_flutter" lib --include='*.dart' --exclude='supabase_client_wrapper_impl.dart'` returns 0 matches (Constitution-IX guard); calling `initialize` with empty values returns `FailureResult(ConfigFailure)`

### Theme stubs (Constitution Principle VI)

- [X] T025 [P] Implement `lib/core/theme/tokens_stub.dart` exposing placeholder color/text token getters (e.g. `AppTokens.primary`, `AppTokens.surface`, `AppTokens.bodyTextStyle`) with values that are visibly distinct between light and dark — these are placeholders only; final tokens land in Phase 2
  - **Verify**: file exists; no hex literal lives outside this file; consumed by T026

- [X] T026 Implement `lib/core/theme/app_theme.dart` exporting `appLightTheme()` and `appDarkTheme()` returning `ThemeData` instances built from `AppTokens` only — no inline `Color(...)` or `TextStyle(...)` literals (depends on T025)
  - **Verify**: `grep -E "Color\\(0x" lib/core/theme/app_theme.dart` returns 0 matches; both functions return non-null `ThemeData` with distinct `brightness`

### Localization scaffolding (Constitution Principle V; research.md Decision 9)

- [X] T027 [P] Create `l10n.yaml` at the repo root pointing at `lib/l10n/`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, `synthetic-package: false`
  - **Verify**: file exists with the four keys above

- [X] T028 [P] Create `lib/l10n/app_en.arb` with the placeholder Phase 1 keys: `appTitle`, `themeToggleLabel`, `localeToggleLabel`, `currentTheme`, `currentLocale`, `backendConfigMissingWarning` — English values are debug-friendly placeholders
  - **Verify**: file is valid JSON-as-ARB; running `flutter gen-l10n` produces `lib/l10n/app_localizations.dart` and `app_localizations_en.dart` without errors

- [X] T029 [P] Create `lib/l10n/app_ar.arb` with the same keys as T028 in Arabic — values are professional Syrian-Arabic placeholders, not stiff Modern Standard Arabic; mirror `appTitle` exactly across both for now (the brand reads "النجوم")
  - **Verify**: file is valid JSON; gen-l10n produces `app_localizations_ar.dart`; `grep -c '"' lib/l10n/app_en.arb lib/l10n/app_ar.arb` returns equal key counts (no key drift between locales — Constitution localization gate)

### DI module (FR-008; contract: `contracts/di-container.md`)

- [X] T030 Author `lib/core/di/injection.dart`: declare `final getIt = GetIt.instance;` and a top-level `Future<void> configureDependencies() async` annotated `@InjectableInit(initializerName: r'$initGetIt', preferRelativeImports: true, asExtension: false)` that calls `await $initGetIt(getIt);` (depends on T016, T018, T020, T024 — all `@LazySingleton`-annotated impls must exist for codegen to succeed)
  - **Verify**: `flutter analyze` is clean; the file alone does not reference any concrete implementation

- [X] T031 Run `dart run build_runner build --delete-conflicting-outputs` to generate `lib/core/di/injection.config.dart` and **commit the generated file** (research.md Decision 4) (depends on T030)
  - **Verify**: `git add lib/core/di/injection.config.dart && git status` shows the file as added; the generated file references all six expected bindings (`EnvConfig`, `AppLogger`, `PreferencesStore`, `SupabaseClientWrapper`, plus a `GoRouter` provider added in T033, and the cubits added in US2/US3 — those latter bindings will require a re-run of build_runner in their respective tasks)

### Routing skeleton (FR-007; contract: `contracts/app-router.md`)

- [X] T032 [P] Define `AppRoutes` and `AppRouteNames` constants in `lib/core/routing/app_router.dart` (just the constants for now — `static const shellHome = '/';` and `static const shellHome = 'shell-home';`)
  - **Verify**: file compiles; no `GoRouter` instance constructed yet (that's T033)

- [X] T033 Add `GoRouter buildAppRouter({required AppLogger logger})` to `lib/core/routing/app_router.dart` returning a router with one `GoRoute(path: AppRoutes.shellHome, ..., builder: (c, s) => const Scaffold(body: SizedBox.shrink()))` placeholder, plus an `errorBuilder` returning a basic error view; register `GoRouter` as a singleton in DI via an `@module` provider in `lib/core/di/injection.dart` (depends on T015, T030, T032)
  - **Verify**: `getIt<GoRouter>()` returns a non-null router instance after `configureDependencies()`; `injection.config.dart` regenerated and committed

### App entry & host (FR-002, FR-013)

- [X] T034 Author `lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized()`, `await configureDependencies()`, resolve `EnvConfig` and `SupabaseClientWrapper` from DI, call `wrapper.initialize(url: env.supabaseUrl, anonKey: env.supabaseAnonKey)` and log a warning via `AppLogger` if the result is a `FailureResult` (FR-013), then `runApp(const App())` (depends on T011, T012, T015, T016, T018, T024, T030, T031)
  - **Verify**: launching with empty `--dart-define`s does NOT crash; the debug console contains a `[SupabaseClientWrapper] Backend configuration missing or invalid; continuing without backend.` warning line

- [X] T035 Author `lib/app.dart` with a `class App extends StatelessWidget` that returns `MaterialApp.router` configured with: `routerConfig: getIt<GoRouter>()`, `theme: appLightTheme()`, `darkTheme: appDarkTheme()`, `themeMode: ThemeMode.system` (placeholder until US2 wires the cubit), `locale: const Locale('ar')` (placeholder until US3 wires the cubit), `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`, `debugShowCheckedModeBanner: false` (depends on T026, T028, T029, T033)
  - **Verify**: `flutter run` launches successfully and the app reaches an interactive frame (currently a blank scaffold from T033's placeholder route)

**Checkpoint**: `lib/core/` is complete. The app boots to a blank scaffold. All later user stories build on this substrate.

---

## Phase 3: User Story 1 — Runnable AlNujom Android shell from a clean clone (Priority: P1) 🎯 MVP

**Goal**: Replace the placeholder route widget with a real `ShellHomePage` carrying the AlNujom brand mark; verify on emulator and on the Infinix Note 8 that the shell launches reliably and matches spec acceptance scenarios AS-1.1, AS-1.2, AS-1.3.

**Independent Test**: A reviewer runs `flutter run` after cloning, sees the AlNujom brand on the home screen, rotates the device, backgrounds and resumes the app, and observes no crashes — full mapping to spec.md User Story 1.

### Tests for User Story 1

- [X] T036 [P] [US1] Write `test/widgets/shell_home_page_test.dart` (widget test): pump `ShellHomePage` inside a `MaterialApp` with `AppLocalizations` delegates; assert `find.text(AppLocalizations.of(context)!.appTitle)` resolves; assert no buttons / interactive elements exist yet (US2 and US3 add them)
  - **Verify**: test FAILS before T037 (file does not exist), PASSES after

- [X] T037 [P] [US1] Write `test/widgets/shell_smoke_test.dart` v1 using `testWidgets(...)`: `await tester.pumpWidget(const App())`, `await tester.pumpAndSettle()`, assert the brand title (`AppLocalizations.of(context).appTitle`) is on screen, assert `tester.takeException() == null`. NOTE: this is a widget test under `test/` (NOT `integration_test/`) so it runs in plain `flutter test` and therefore in CI without an emulator (research.md Decision 14, Open items)
  - **Verify**: test FAILS before T038 (placeholder scaffold has no brand text), PASSES after; runs as part of `flutter test` with no `flutter test integration_test/...` invocation needed

### Implementation for User Story 1

- [X] T038 [US1] Create `lib/shell/shell_home_page.dart` — a `StatelessWidget` that returns a `Scaffold` with a centered `Text(AppLocalizations.of(context).appTitle)` styled via `Theme.of(context).textTheme.headlineMedium` (no hex literals, no `TextStyle(...)`); WCAG 2.1 AA: text contrast against scaffold background ≥ 4.5:1, semantic label inherited from the Text widget (depends on T028, T029, T035)
  - **Verify**: T036 passes; manually launching the app shows "النجوم" in Arabic on first launch (FR-002, FR-005)

- [X] T039 [US1] Update `lib/core/routing/app_router.dart`: import `package:alnujom/shell/shell_home_page.dart` and replace the placeholder `Scaffold(body: SizedBox.shrink())` with `const ShellHomePage()` in the shell-home route's `builder` (depends on T033, T038)
  - **Verify**: T037 passes; `flutter run` reaches an interactive shell within the SC-002 budget on emulator; `flutter analyze` clean (no unresolved import)

- [X] T040 [US1] Manual hardware verification on the Infinix Note 8 per quickstart.md §8: build a **profile** APK (`flutter build apk --profile --dart-define-from-file=.env.json`), cold-launch the app 20 times, capture `adb shell am start -W`'s `WaitTime` (interactive-ready, *not* `TotalTime`), verify p95 ≤ 3000 ms (SC-002); record results in the PR description
  - **Verify**: results table pasted into PR; if profile-mode p95 > 3000 ms, file a follow-up task to investigate and add a polish task before declaring Phase 1 done
  - **Phase 3 check 2026-04-29 (initial, failed)**: First run measured WaitTime p95 = 5493 ms over 20 cold starts on a **debug** APK with empty Supabase config. Debug Flutter ships JIT bytecode and assertions, so its cold-start is ~1.5–2× the user-installed app and is not a meaningful proxy for SC-002. The recipe in quickstart.md §8 was corrected to require a profile APK; T062 tracks the re-measurement.
  - **Phase 3 check 2026-04-29 (re-measurement, PASS)**: 20 cold-start `WaitTime` samples on Infinix Note 8 (X692) with the profile APK and empty Supabase config — min 2520 ms, median 2542 ms, mean 2566 ms, **p95 ≈ 2649 ms** (nearest-rank), max 2662 ms. Comfortably under the 3000 ms SC-002 budget. T062 closed.

- [X] T041 [US1] Manual edge-case verification on an Android target (emulator OR primary verification device — spec.md AS-1.2/AS-1.3 do not mandate emulator): rotate device twice (AS-1.2), background and resume (AS-1.2), launch with empty `SUPABASE_URL`/`SUPABASE_ANON_KEY` (AS-1.3) — confirm in each case the app stays interactive and the missing-config warning appears in the `flutter run` terminal
  - **Verify**: each scenario observed and a one-line note added to the PR description
  - **Phase 3 check 2026-04-29 (initial, partial fail)**: First run on physical Infinix X692. Rotation, background/resume, and missing-config launch all kept the shell interactive. The missing-config warning did not appear in `adb logcat` *or* in `flutter run`'s terminal because `ConsoleLogger` was using `dart:developer.log` alone, which only surfaces in DevTools. Root-cause fix: `ConsoleLogger._log` now mirrors each entry via `debugPrint` so the warning is visible in `flutter run`'s terminal — see `lib/core/logging/console_logger.dart`.
  - **Phase 3 check 2026-04-29 (re-run, PASS)**: With the logger fix, re-ran on Infinix X692 with empty defines. `flutter run` terminal showed `[Bootstrap] INFO: Dependency injection configured.` followed by `[SupabaseClientWrapper] WARNING: Backend configuration missing or invalid; continuing without backend.` Rotation × 2, background/resume, and missing-config launch all kept the shell interactive. AS-1.2 and AS-1.3 verified.

**Checkpoint**: User Story 1 is complete and independently testable. The shell launches, displays the brand, and survives rotation, backgrounding, and missing backend config. **This is the MVP — Phase 1 could ship here if scope is cut.**

---

## Phase 4: User Story 2 — Theme switching scaffolding (Priority: P2)

**Goal**: Add a visible theme toggle to the shell home; introduce `ThemeCubit` driving `MaterialApp`'s `themeMode`; on first-ever launch follow the device system theme (FR-016), then lock to the user's pick after the first explicit toggle; persist via `PreferencesStore` and restore on cold start.

**Independent Test**: A reviewer launches the shell, taps the theme toggle once, observes the theme flip within one frame, force-stops the app, relaunches it, and observes the previously selected theme is restored (spec User Story 2).

### Tests for User Story 2

- [ ] T042 [P] [US2] Write `test/core/theme/theme_cubit_test.dart` using `bloc_test` with a Mockito-generated fake `PreferencesStore`: cover initial state = `ThemeMode.system` when persisted is null; initial state = `ThemeMode.dark` when persisted is `dark`; `toggle()` from system → light writes through to store; `toggle()` from light → dark writes through; persistence-write-failure logs a warning but does not revert in-memory state (FR-016)
  - **Verify**: test FAILS before T043 (cubit doesn't exist), PASSES after

### Implementation for User Story 2

- [ ] T043 [US2] Implement `lib/core/theme/theme_cubit.dart` annotated `@injectable`: `class ThemeCubit extends Cubit<ThemeMode>`; constructor takes injected `PreferencesStore` and `AppLogger` plus the initial `ThemeMode` resolved from store-read in `main.dart`; method `toggle()` flips between `light` and `dark` (if current is `system`, picks the opposite of the platform brightness as the first explicit choice); writes through to store and logs warnings on failure (depends on T015, T019, FR-016)
  - **Verify**: T042 passes; `flutter analyze` clean

- [ ] T044 [US2] Update `lib/main.dart` to read persisted theme via `PreferencesStore.readThemeMode()` BEFORE `runApp`; supply the resolved initial `ThemeMode` (or `ThemeMode.system` if null) to `ThemeCubit` via an `@injectable` `factoryParam` so `getIt<ThemeCubit>(param1: initialMode)` constructs a fresh cubit seeded with the persisted state. Do NOT use `BlocProvider.value` here — `BlocProvider(create:)` in T045 owns the cubit lifecycle (depends on T020, T034, T043)
  - **Verify**: a fresh install launches with `ThemeMode.system`; on a second launch after a toggle, the stored value is restored; `injection.config.dart` regenerated and committed to reflect the new `factoryParam`

- [ ] T045 [US2] Update `lib/app.dart`: wrap `MaterialApp.router` in `BlocProvider<ThemeCubit>(create: (_) => getIt<ThemeCubit>())` and inside, a `BlocBuilder<ThemeCubit, ThemeMode>` that supplies the `themeMode:` parameter (depends on T035, T043, T044)
  - **Verify**: changing the cubit's state visibly re-themes the app within one frame (FR-003); covered by the smoke-test extension in T047

- [ ] T046 [US2] Update `lib/shell/shell_home_page.dart` to add a theme toggle control beneath the brand mark — an `OutlinedButton.icon` labelled with `AppLocalizations.of(context).themeToggleLabel`; `onPressed: () => context.read<ThemeCubit>().toggle()`; minimum touch-target 48×48 dp (FR-017); `Semantics(label: ..., value: <currentTheme>)` wrapper for TalkBack (depends on T038, T043)
  - **Verify**: launching the app and tapping the toggle once flips theme visibly (AS-2.1); contrast spot-check ≥ 3:1 on the icon against the button surface

- [ ] T047 [US2] Extend `test/widgets/shell_smoke_test.dart` v2: after the brand-visible assertion, locate the theme toggle (e.g., by `find.bySemanticsLabel(...)` or a stable widget Key), `await tester.tap(...)`, `await tester.pumpAndSettle()`, assert that `Theme.of(tester.element(...)).brightness` flipped from its initial value
  - **Verify**: `flutter test` passes (the smoke test runs as part of the default test suite); CI step "flutter test" stays green

- [ ] T048 [US2] Manual hardware verification on Infinix Note 8: tap toggle, force-stop the app via `adb shell am force-stop com.alnujom.app`, relaunch, confirm restored theme (AS-2.2); rapid-toggle 10× in 2 seconds and confirm final state is persisted exactly once (edge case "Rapid repeated toggling")
  - **Verify**: results captured in PR description

**Checkpoint**: User Stories 1 AND 2 work independently. The shell launches, displays the brand, toggles theme, and persists.

---

## Phase 5: User Story 3 — Locale switching scaffolding with RTL/LTR mirroring (Priority: P3)

**Goal**: Add a visible locale toggle to the shell home; introduce `LocaleCubit` driving `MaterialApp`'s `locale`; default to Arabic on first-ever launch (FR-005), persist via `PreferencesStore`, ensure the layout direction flips between RTL and LTR within one frame.

**Independent Test**: Fresh install launches in Arabic with RTL; toggle flips to English with LTR within one frame; cold restart preserves selection (spec User Story 3).

### Tests for User Story 3

- [ ] T049 [P] [US3] Write `test/core/localization/locale_cubit_test.dart` using `bloc_test`: cover initial state = `Locale('ar')` when persisted is null (FR-005); initial state = `Locale('en')` when persisted is `'en'`; `toggle()` from `ar` → `en` writes through; from `en` → `ar` writes through; persistence-write-failure logs a warning but does not revert in-memory state
  - **Verify**: test FAILS before T050 (cubit doesn't exist), PASSES after

### Implementation for User Story 3

- [ ] T050 [US3] Implement `lib/core/localization/locale_cubit.dart` annotated `@injectable`: `class LocaleCubit extends Cubit<Locale>`; constructor takes injected `PreferencesStore` and `AppLogger` plus the initial `Locale` (default `Locale('ar')` if persisted is null per FR-005); `toggle()` flips between `Locale('ar')` and `Locale('en')`; writes through to store and logs warnings on failure (depends on T015, T019)
  - **Verify**: T049 passes; `flutter analyze` clean

- [ ] T051 [US3] Update `lib/main.dart` to read persisted locale via `PreferencesStore.readLocale()` BEFORE `runApp`; resolve the initial `Locale` to the persisted value or `Locale('ar')` if null; supply it to `LocaleCubit` via an `@injectable` `factoryParam` so `getIt<LocaleCubit>(param1: initialLocale)` constructs a fresh cubit seeded with persisted state (mirroring T044's pattern for theme). Do NOT use `BlocProvider.value` (depends on T020, T044, T050)
  - **Verify**: a fresh install launches in Arabic regardless of device system locale (FR-005, AS-3.1); `injection.config.dart` regenerated and committed

- [ ] T052 [US3] Update `lib/app.dart`: add `BlocProvider<LocaleCubit>(create: (_) => getIt<LocaleCubit>())` and a `BlocBuilder<LocaleCubit, Locale>` that supplies the `locale:` parameter to `MaterialApp.router` (depends on T045, T050, T051)
  - **Verify**: changing the cubit's state flips both visible strings AND `Directionality.of(context)` within one frame (FR-004, AS-3.2)

- [ ] T053 [US3] Update `lib/shell/shell_home_page.dart` to add a locale toggle control adjacent to the theme toggle — an `OutlinedButton.icon` labelled with `AppLocalizations.of(context).localeToggleLabel`; uses `EdgeInsetsDirectional` and other directional primitives so the layout flips correctly under RTL (Constitution Principle V); `onPressed: () => context.read<LocaleCubit>().toggle()`; min 48dp touch target; Semantics label includes current locale (depends on T046, T050)
  - **Verify**: tapping the toggle flips the layout direction visibly; manual reviewer confirms the toggle position swaps left↔right edges of the screen as locale flips

- [ ] T054 [US3] Extend `test/widgets/shell_smoke_test.dart` v3: after the theme toggle assertion, locate and tap the locale toggle, `await tester.pumpAndSettle()`, assert `Directionality.of(tester.element(...)) == TextDirection.ltr` after toggling away from Arabic; tap again to confirm round-trip (FR-012, SC-004)
  - **Verify**: `flutter test` passes; the smoke test now exercises FR-002 + FR-003 + FR-004 (the full FR-012 surface) and runs in CI as part of the default test suite

- [ ] T055 [US3] Manual hardware verification on Infinix Note 8: fresh install launches in Arabic + RTL even with device system locale set to English (AS-3.1); toggle flips within one frame (AS-3.2); force-stop and relaunch preserves selection (AS-3.3); change device system locale at OS level — app stays on its in-app locale
  - **Verify**: results captured in PR description

**Checkpoint**: All three user stories complete and independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finish the constitutional compliance surface, fill in residual documentation, and run the full quickstart.md gate before declaring Phase 1 shippable.

- [ ] T056 [P] Run the WCAG 2.1 AA spot-check from quickstart.md §9 manually on the Infinix Note 8: enable TalkBack, navigate the shell, verify both toggles announce purpose + current state; bump system font size to 130%, verify no truncation; sample contrast on toggle text, brand, and icons against their backgrounds with a contrast meter or `Color.computeLuminance()` check (FR-017)
  - **Verify**: results captured in a short table in the PR description; any failure produces a polish task before declaring Phase 1 done

- [ ] T057 [P] Verify Constitution Principle XII grep-style guards locally and in CI: `grep -rE "package:supabase_flutter" lib --include='*.dart' --exclude='supabase_client_wrapper_impl.dart'` returns 0; `grep -rE "Color\\(0x" lib --exclude-dir=l10n` returns matches only inside `lib/core/theme/`
  - **Verify**: both checks pass locally; CI step from T010 reproduces them; if any new violation appears, fix before merging

- [ ] T058 Update root `README.md` (create if absent) with a one-paragraph project description, a link to `docs/IMPLEMENTATION_PLAN.md`, and a one-line pointer to `specs/001-project-foundation/quickstart.md` for the Phase 1 verification recipe
  - **Verify**: README renders in GitHub's preview without broken links

- [ ] T059 Run the full `specs/001-project-foundation/quickstart.md` validation start-to-finish on a fresh clone to confirm SC-001 (≤30 minutes from clone to running emulator with no undocumented manual steps); record actual time in the PR description
  - **Verify**: SC-001 met; if any documented step is wrong or missing, fix the quickstart before declaring done

- [ ] T060 Run `/speckit-analyze` on the feature folder to confirm cross-artifact consistency (spec.md ↔ plan.md ↔ data-model.md ↔ contracts/ ↔ tasks.md); resolve any finding before merge
  - **Verify**: `/speckit-analyze` reports no inconsistencies; any finding either fixed or recorded as a deferred follow-up issue

- [ ] T061 Configure GitHub branch protection on `main`: require the `verify` workflow status check to pass before any PR can merge; require linear history; disallow direct pushes (FR-015 "Pipeline failure MUST block merge"). This is a one-time admin action via the GitHub repo Settings → Branches UI (or `gh api -X PUT repos/:owner/:repo/branches/main/protection ...` for an automatable equivalent)
  - **Verify**: opening a PR against `main` shows "Required" next to the `verify` status check on the merge page; trying to merge with a failing CI run shows the merge button disabled; a screenshot or `gh api repos/:owner/:repo/branches/main/protection` JSON output is pasted into the PR description as evidence

- [X] T062 Close the Phase 3 SC-002 verification: re-run T040 on a **profile** APK per the corrected quickstart.md §8 recipe and paste the new 20-launch `WaitTime` results table into the Phase 3 PR. Pass condition: p95 ≤ 3000 ms on Infinix Note 8. If profile-mode p95 also fails, only then escalate to a startup-profiling investigation; otherwise mark T040 [X] and close T062
  - **Verify**: updated 20-launch table for the profile APK shows p95 ≤ 3000 ms on Infinix Note 8; T040 marked [X]; T062 closed before Phase 1 PR merges (per quickstart.md §9 final gate)
  - **Closed 2026-04-29**: profile-mode p95 = 2649 ms on Infinix Note 8, ~350 ms under the 3000 ms budget. T040 marked [X]. See T040's Phase 3 check note for the full 20-sample distribution.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately on the `001-project-foundation` branch.
- **Phase 2 (Foundational)**: Depends on Setup completion. **Blocks all user stories.**
- **Phase 3 (US1 — P1)**: Depends on Foundational. Independent of US2 and US3.
- **Phase 4 (US2 — P2)**: Depends on Foundational. Modifies `app.dart` and `lib/shell/shell_home_page.dart` from US1 — therefore dependent on US1 being merged or co-developed (within-file conflict).
- **Phase 5 (US3 — P3)**: Depends on Foundational. Modifies `app.dart` and `lib/shell/shell_home_page.dart` — same conflict risk with US1 and US2; sequence US1 → US2 → US3 if a single developer.
- **Phase 6 (Polish)**: Depends on whichever stories are in scope being complete.

### Critical task-level dependencies

- T011 → T012 → T013 (Failure → Result → extensions)
- T015 → T016 (logger interface → console impl)
- T011, T012, T015, T019 → T020 (errors + logger + interface → secure store impl)
- T011, T012, T015, T022, T023 → T024 (errors + logger + types + interface → wrapper impl)
- T025 → T026 (tokens → app theme)
- T028, T029 → gen-l10n (codegen needs both ARB files)
- T016, T018, T020, T024 → T030 → T031 (DI annotations → injection.dart → codegen)
- T032 → T033 (route constants → router builder)
- T030, T031, T033 → T034 (DI ready → main.dart can resolve)
- T026, T028, T029, T033 → T035 (themes + ARB + router → app.dart)
- T035 → T038, T039 (app shell ready → US1 home page)
- T043 → T044 → T045 → T046 (theme cubit → main wiring → app wiring → toggle UI)
- T050 → T051 → T052 → T053 (locale cubit chain mirrors theme)

### Parallel opportunities

**Setup phase**: T002, T003, T004, T005 are all independent file edits; T007, T008, T009, T010 are all independent — within Setup, run all eight in parallel after T001 completes.

**Foundational phase, wave 1** (interfaces + standalone files): T011, T015, T018, T019, T022, T023, T025, T027, T028, T029 are all `[P]` and independent.

**Foundational phase, wave 2** (depends on wave 1): T012, T013, T014, T016, T017, T020, T021, T024, T026 — partially parallel (e.g. T021 depends on T020 which depends on T015+T019).

**Within US1**: T036 and T037 are both `[P]` test tasks against not-yet-existing code; can be authored in parallel before T038 lands.

**Within US2**: T042 (cubit test) is `[P]`; the impl tasks T043–T046 are sequential within `app.dart`/`shell_home_page.dart` because they touch the same files.

**Within US3**: T049 is `[P]`; the impl tasks T050–T053 are sequential for the same reason.

### Single-developer recommended order

```text
T001 → (T002 ∥ T003 ∥ T004 ∥ T005) → T006 → (T007 ∥ T008 ∥ T009 ∥ T010)
     → (T011 ∥ T015 ∥ T018 ∥ T019 ∥ T022 ∥ T023 ∥ T025 ∥ T027 ∥ T028 ∥ T029)
     → (T012 ∥ T016) → (T013 ∥ T014 ∥ T017 ∥ T020 ∥ T024 ∥ T026)
     → (T021) → (T032) → (T030) → (T031) → (T033) → (T034) → (T035)
     → MVP CHECKPOINT
     → US1: (T036 ∥ T037) → T038 → T039 → T040 → T041
     → US1 SHIPPABLE — STOP HERE FOR MVP IF DESIRED
     → US2: T042 → T043 → T044 → T045 → T046 → T047 → T048
     → US3: T049 → T050 → T051 → T052 → T053 → T054 → T055
     → Polish: (T056 ∥ T057) → T058 → T059 → T060 → T061
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Setup (Phase 1) — T001 through T010.
2. Foundational (Phase 2) — T011 through T035.
3. User Story 1 (Phase 3) — T036 through T041.
4. **STOP and validate**: run quickstart.md User Story 1 acceptance scenarios on the Infinix Note 8.
5. Open a PR for the MVP slice. Theme and locale toggles do not exist yet — that's intentional.

This is a viable shippable Phase 1 if scope is cut: a runnable Android shell with no toggles. US2 and US3 are subsequent slices in the same branch (or follow-up branches if this PR is merged first).

### Incremental delivery (recommended)

1. Setup → Foundational → US1 → demo. Optionally merge.
2. Add US2 → demo (theme toggle works + persists).
3. Add US3 → demo (locale toggle works + persists, RTL/LTR flips).
4. Run Polish → quickstart full pass → merge into `main`.

Each story adds value without breaking previous stories. The smoke test grows additively across US1 → US2 → US3.

### Parallel team strategy

If multiple contributors are available:

1. Team completes Setup + Foundational together — these tasks touch many independent files; the `[P]`-marked tasks parallelize cleanly.
2. After Foundational checkpoint:
   - Developer A: US1 (T036–T041) — owns `shell/shell_home_page.dart` v1
   - Developer B: holds; US2 modifies the same file
   - Developer C: holds; US3 modifies the same file
3. Sequence US1 → US2 → US3 by file-conflict order, OR coordinate a single shared `shell_home_page.dart` editor.

In practice, Phase 1 is small enough that one developer running the full sequence is faster than the coordination overhead.

---

## Notes

- `[P]` tasks = different files, no dependency on incomplete tasks; can run in parallel without coordination.
- `[USx]` label maps a task to the user story it serves (Phase 3+ only); Setup, Foundational, and Polish tasks have no story label.
- Every task carries an indented `**Verify**:` line per Constitution Principle X (testable AI workflow).
- Commit after each task or each logical group — `/speckit-git-commit` is the recommended path.
- Stop at any **Checkpoint** to validate the work-in-progress story end-to-end.
- Avoid: introducing product features (FR-014); importing `package:supabase_flutter` outside `supabase_client_wrapper_impl.dart` (Constitution IX); inline hex literals or `TextStyle(...)` in feature code (Constitution VI); throwing exceptions across architectural boundaries (Constitution IV, FR-010).
