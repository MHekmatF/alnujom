# Tasks: Release Polish, Distribution & QA Pass (Phase 24)

**Input**: Design documents from `specs/024-release-polish/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Exactly **ONE** new automated test — the primary-publish `integration_test` (the sanctioned release-hardening exception to the standing `feedback_no_new_tests` convention; `integration_test` is already a dev dep). All other verification is **manual** on-device (Infinix Note 8) + Pixel 8 Pro AVD walks (maintenance two-device + push manual), plus the **APK binary secret-scan**, recorded against the Success Criteria. Acceptance tasks below are verification steps, not test code.

**Organization**: Tasks are grouped by the plan's **five implementation phases** (CR, UP, RB, CF, QV) — the units `/wave` dispatches — with `[US#]` labels mapping each task to the spec's user stories. Waves: **CR ∥ UP ∥ RB ∥ CF** (Wave 1, 4-wide, **0 build edges**) → **QV** (Wave 2, verification-ordering only).

## Format: `[ID] [P?] [US?] Description with file path`

- **[P]**: Can run in parallel (different file, no dependency on an incomplete task)
- **[US#]**: The user story this task serves (US1 signed build · US2 crash reporting · US3 golden paths · US4 update prompt · US5 distribution+docs · US6 l10n/theming/stability)
- All paths are repository-relative.

> **⚠️ Checkbox discipline (memory `feedback_strict_task_completion` + `docs/AI_AGENT_WORKFLOW.md`)**: each sub-agent MUST flip its `- [ ] T<id>` → `- [X] T<id>` **in the same commit as the implementation** — never as a later "cleanup pass." A verification/acceptance task stays `- [ ]` (or `- [ ] **⚠️ PARTIAL —**`) until the check is actually run on the target device/build and the outcome recorded; do not flip it by inference.

> **No separate Setup/Foundational phase**: the project is established (DI, theme, l10n, router, Supabase client, `AppLogger` seam all exist). The five units are independent (0 Dart-symbol build edges); CR/UP/RB/CF run as a 4-wide Wave 1. Phase 24 adds **4 new deps** (`sentry_flutter`, `package_info_plus`, `flutter_launcher_icons`, `flutter_native_splash`) — included as explicit pubspec tasks.

---

## Phase CR — Crash & error reporting (Sentry, behind the `CrashReporter` seam) (serves US2) — Wave 1

**Goal**: Uncaught/fatal errors captured to a sanctions-safe Sentry dashboard, behind a `core/` seam, PII-scrubbed, non-blocking, `domain/`-free.
**Independent Test**: profile build with a real DSN → a forced exception lands on the dashboard with a usable stack trace and **no** secrets/PII in the payload; with the dashboard unreachable the app starts + runs normally.

- [ ] T001 [P] [US2] Add `sentry_flutter` to `dependencies` in `pubspec.yaml` (Android-supported; R-206)
- [ ] T002 [P] [US2] Create the abstract `CrashReporter` seam in `lib/core/logging/crash_reporter.dart` (`init({dsn, environment})`, `recordError(error, stack, {context})`, `addBreadcrumb`, `close`) per `contracts/phase24-crash-reporting-and-logger-seam.md`
- [ ] T003 [US2] Create `SentryCrashReporter` (`@LazySingleton(as: CrashReporter)`) in `lib/core/logging/sentry_crash_reporter.dart` — wraps `sentry_flutter`; installs the **`beforeSend` scrub** stripping synthetic-email/phone, Vault material, decrypted PII, and tokens (data-model §2) (depends on T001, T002)
- [ ] T004 [P] [US2] Create `NoopCrashReporter` (`implements CrashReporter`, all no-ops) in `lib/core/logging/noop_crash_reporter.dart` — bound when the DSN is empty (mirrors `NoopPushMessagingService`) (depends on T002)
- [ ] T005 [US2] Amend `lib/main.dart` — read `SENTRY_DSN` (dart-define); **guard-init** Sentry in `try/catch` (Phase 22 Firebase-guard pattern), wrap the bootstrap in `runZonedGuarded`, route `FlutterError.onError` + `PlatformDispatcher.onError` → `CrashReporter.recordError`; bind `NoopCrashReporter` when the DSN is empty; init MUST NOT block `runApp` (FR-007); release/profile only (depends on T003, T004)
- [ ] T006 [P] [US2] Add a `SENTRY_DSN` key to `.env.example.json` (committed) + a one-line doc note; do **NOT** commit a real DSN (R-217, ADR-0001)
- [ ] T007 [US2] Run `dart run build_runner build --delete-conflicting-outputs` + `flutter analyze`; grep-confirm **no** `package:sentry_flutter` import under any `domain/` — **acceptance (record outcome)**: in a **profile build with the DSN set**, force an uncaught exception via a **`--dart-define`-gated debug-only "throw test error" affordance** (inert/removed in the shipped release) → confirm it lands on the dashboard; payload inspected (no secrets/PII); unreachable dashboard → app runs (SC-002). **⚠️ PARTIAL —** dashboard verification needs a profile build + real DSN on-device (deferred to QV).

**Checkpoint**: production crashes are captured + scrubbed; the app never blocks/crashes on reporter failure.

---

## Phase UP — In-app update prompt (cold-start version check vs Supabase manifest) (serves US4, US6) — Wave 1

**Goal**: On cold start the app compares its installed version to a Supabase-Storage manifest and prompts to update; unreachable/older ⇒ silent no-op.
**Independent Test**: higher manifest version ⇒ localized Update/Later prompt + working download; equal/older or unreachable ⇒ no prompt, no crash.

- [ ] T008 [P] [US4] Add `package_info_plus` to `dependencies` in `pubspec.yaml` (Android-supported; R-210)
- [ ] T009 [P] [US4] Create domain entities in `lib/features/app_update/domain/entities/`: `app_version.dart` (`AppVersion` {major,minor,patch,build} + `compareTo` semver-first/build-tiebreaker + `parse`), `version_manifest.dart` (`VersionManifest`), `update_availability.dart` (sealed `UpdateAvailability`: `UpdateAvailable`/`UpToDate`/`CheckFailed`) per data-model §3
- [ ] T010 [P] [US4] Create abstract `AppUpdateRepository` in `lib/features/app_update/domain/repositories/app_update_repository.dart` (`Future<Result<UpdateAvailability>> checkForUpdate()` — never throws)
- [ ] T011 [US4] Create the `CheckForUpdate` use case in `lib/features/app_update/domain/usecases/check_for_update.dart` (depends on T010)
- [ ] T012 [P] [US4] Create `VersionManifestDto` (+ tolerant JSON decode) in `lib/features/app_update/data/dtos/version_manifest_dto.dart` (data-model §1); **also commit the checked-in canonical schema template** `docs/release/version-manifest.example.json` (Principle II/XII — the operator uploads the live copy to Supabase Storage; the DTO MUST decode this example) — satisfies the plan's "manifest content checked-in" claim
- [ ] T013 [US4] Create `SupabaseManifestDatasource` (Storage GET of the public manifest via the existing `SupabaseClientWrapper`) + `PackageInfoVersionSource` (installed version via `package_info_plus`) in `lib/features/app_update/data/datasources/` (depends on T008, T012)
- [ ] T014 [US4] Create `AppUpdateRepositoryImpl` (`@LazySingleton(as: AppUpdateRepository)`) in `lib/features/app_update/data/repositories/app_update_repository_impl.dart` — **fail-silent** (`CheckFailed`) on unreachable/malformed (FR-010) (depends on T010, T013)
- [ ] T015 [US4] Create `AppUpdateCubit` in `lib/features/app_update/presentation/bloc/app_update_cubit.dart` — `check()` → emits `UpdateAvailable`/`UpToDate`/`CheckFailed` (depends on T011)
- [ ] T016 [P] [US6] Add the update-prompt l10n keys (title, body, Update, Later, optional release-note label) to `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb` + matching `_DebugAppLocalizations` overrides in `lib/core/localization/app_strings.dart`; run `flutter gen-l10n` (memory `project_l10n_debug_localizations_override`)
- [ ] T017 [US4] Create `update_prompt_dialog.dart` in `lib/features/app_update/presentation/widgets/` — localized; **Update** (`url_launcher` → `telegram_url` ?? `website_url`) + **Later** (dismiss for session); Phase 2 tokens (depends on T015, T016)
- [ ] T018 [US4] Amend `lib/app.dart` — provide `AppUpdateCubit`, call `check()` **once on cold start** (not on every resume), and show `update_prompt_dialog` on `UpdateAvailable` (session-once; R-211) (depends on T015, T017)
- [ ] T019 [US4] Run `build_runner` + `flutter analyze`; grep-confirm no `supabase_flutter`/`package_info_plus` import under `lib/features/app_update/domain/` — **acceptance (record outcome)**: higher manifest ⇒ prompt + download; equal/older/unreachable ⇒ silent no-op; four-combination render (SC-003/SC-007). **⚠️ PARTIAL —** on-device walk deferred to QV.

**Checkpoint**: the direct-APK audience is kept current; a missing manifest never disturbs the app.

---

## Phase RB — Release build: icon, splash, signing, version (serves US1, US6) — Wave 1

**Goal**: A signed `1.0.0` build with the final icon + light/dark splash that boots on a fresh device; release signing **fails closed**. **No Dart symbol.**
**Independent Test**: signed APK installs + boots on a wiped device (icon + splash correct light/dark); a release build with no keystore **fails** (no debug-signed artifact).

- [X] T020 [P] [US1] Add `flutter_launcher_icons` + `flutter_native_splash` to `dev_dependencies` + their config blocks in `pubspec.yaml`; add source art under `assets/branding/` (icon + light/dark splash) (R-212)
- [X] T021 [US1] Run `dart run flutter_launcher_icons` → generates `mipmap-*` + the Android adaptive icon into `android/app/src/main/res/**` (depends on T020)
- [X] T022 [US1] [US6] Run `dart run flutter_native_splash:create` with **light + dark** config → generates splash drawables + `values`/`values-night` (depends on T020)
- [X] T023 [P] [US1] Replace the `release` `signingConfig` in `android/app/build.gradle.kts` with a real config reading gitignored `android/key.properties` (keystore outside the repo); **fail closed** when absent (remove the `signingConfigs.getByName("debug")` fallback + TODO); add `key.properties` + `*.jks`/`*.keystore` to `android/.gitignore` (R-213, FR-003)
- [ ] T024 [US1] **⚠️ PARTIAL —** `pubspec.yaml` version confirmed `1.0.0+1`; `debugShowCheckedModeBanner: false` confirmed; `kDesignToolsEnabled` is `bool.fromEnvironment('DESIGN_TOOLS', defaultValue: false)` — OFF in release (no dart-define). Signed-build-on-fresh-device deferred to QV (needs keystore + device). (depends on T021, T022, T023)

**Checkpoint**: a shippable, properly-signed `1.0.0` artifact with final branding.

---

## Phase CF — Carried-over fixes + `isClosed` sweep (serves US3, US6) — Wave 1

**Goal**: Fix the named carried-over items so the golden paths + crash stream are clean (R-215). Phase 19 D-1/2/3 are **already done** (verify only); FE-1 stays a **future spec**.
**Independent Test**: fast back-navigation mid-load shows **no** "emit after close" errors; an approved agency's logo renders (no broken-image placeholder).

- [X] T025 [P] [US6] Fix the **agency-logo double-prefix**: amend `lib/features/agency/data/datasources/supabase_agency_datasource.dart` to store only the object **path** (not the full public URL) and/or amend `lib/features/agency/presentation/widgets/agency_badge.dart` to detect an already-absolute URL and skip re-prefixing — **read-time fix, no migration/backfill** (R-215)
- [X] T026 [P] [US6] Add `if (isClosed) return;` before `emit` in `AdSlotCubit.load` (`lib/features/ads/presentation/bloc/ad_slot_cubit.dart:41`)
- [X] T027 [P] [US6] Add the same guard in `AgencyVerificationCubit.load` (`lib/features/agency/presentation/bloc/agency_verification_cubit.dart:101`)
- [X] T028 [P] [US6] Add the same guard in `ProfileCubit.load` (`lib/features/profile/presentation/cubit/profile_cubit.dart:37`)
- [X] T029 [US6] **Sweep** the codebase for the same async-cubit-load-then-`emit` pattern (cubits/blocs that `await` then `emit` without an `isClosed` guard); add the guard where found; record the list in the commit message (depends on T026, T027, T028)
- [ ] T030 [US6] Run `flutter analyze` — **acceptance (record outcome)**: exercise the AdSlot / AgencyVerification / Profile navigations with fast back-nav → **no** "emit after close"; open an approved agency → logo renders (SC-009). **⚠️ PARTIAL —** on-device exercise deferred to QV. (depends on T025–T029)

**Checkpoint**: the recurring async-cubit noise is gone and agency logos render — the crash stream (CR) will show real problems only.

---

## Phase QV — Golden-path QA pass + 1 integration test + APK secret-scan + release docs + distribution (serves US3, US5, US6) — Wave 2

**Goal**: Prove the whole product end-to-end on the signed build, ship the artifact + docs. (Verification-ordering: needs CR+UP+RB+CF merged + a signed build.)
**Independent Test**: all six golden paths pass; the automated test is green; the APK carries no secret; `docs/release/v1.0.0.md` exists and is complete.

- [ ] T031 [US3] Write `integration_test/primary_publish_path_test.dart` — the one automated test: register → admin-approve → publish → admin-approve → public view → inquiry (drives pre-existing Phase 5/10/12/13/16 surfaces). **Include a SETUP/teardown that establishes the test fixture**: a fresh registerable phone (the synthetic-email pattern), a **pre-seeded admin** holding `users.approve` + `listings.approve` (the admin-side approvals driven via service-role/SQL between UI steps), deterministic listing data, and a reset so the test is **re-runnable** (idempotent against the live/staging backend)
- [ ] T032 [US3] Run `flutter test integration_test/primary_publish_path_test.dart --dart-define-from-file=.env.json` on the Pixel 8 Pro AVD — **acceptance (record outcome)**: green (depends on T031, Wave 1 merged). **⚠️ PARTIAL —** needs the merged build + a seeded backend.
- [ ] T033 [US3] Run the **six manual golden-path walks** (Infinix Note 8 + Pixel 8 Pro AVD): (1) primary publish; (2) anonymous browse+filter+map; (3) admin reports-queue resolution; (4) super-admin role create+assign+revoke; (5) currency switch + exchange-rate update; (6) **maintenance mode + recovery (two-device)**; record each — **acceptance (SC-004)**. **⚠️ PARTIAL —** on-device.
- [ ] T034 [US5] Build the signed release APK and run a **binary secret-scan** of it (Phase 22 T046) — confirm **no** DSN / keystore / Vault / FCM-service-account material shipped — **acceptance (record outcome)**. **⚠️ PARTIAL —** needs the signed APK (RB + keystore).
- [ ] T035 [US3] Measure + record the **cold-start baseline** on the Infinix Note 8 vs the §15 < 3 s budget — **advisory, not a gate** (clarify Q2) — **acceptance (record value)**. **⚠️ PARTIAL —** on-device.
- [ ] T036 [US5] Author `docs/release/v1.0.0.md` — the six golden-path results, install/update instructions, the **no-email account-recovery support flow** (admin issues a temp password via the super-admin UI, §15), the cold-start baseline, the APK secret-scan result, the distribution checklist, **and the operator prerequisites that gate the release** (the Sentry self/EU instance + DSN, the release keystore, the Telegram channel) (FR-012; depends on T032–T035)
- [ ] T037 [US5] **Distribution ops** (R-216): upload the signed APK + the version manifest JSON to Supabase Storage; post the APK to the Telegram channel; configure the Play Store internal testing track (QA-only) — **acceptance (SC-005)**. **⚠️ PARTIAL —** operator step.
- [ ] T038 [US3] Run the **full verify suite** (`flutter analyze` + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary — memory `project_wave_run_full_verify_suite`) + the **structural gate** (quickstart §G: version `1.0.0`; **no** new table/RPC/permission/migration; **no** `supabase_flutter`/`sentry_flutter`/`package_info_plus` import under any `domain/`; **no** iOS/Web; carried-over buckets closed, FE-1 left future); record any **new** out-of-scope finding in `specs/024-release-polish/DEFERRED.md` with a rationale (no silent drop) — **acceptance (SC-008)**
- [ ] T039 [US3] Verify the **Phase 22 carried-over QA residual** (FR-013 / R-215 — beyond the T034 APK secret-scan): **(a) T044** — admin counters move ≤5 s + reconcile after a forced network drop on a 2nd device (the live role grant/revoke half is already VERIFIED PASS — re-confirm on the release build); **(b) T045** — all six in-app notification events deliver (center + badge) with push **blocked**, no crash; **(c) T046** — cross-user RLS-denial from a **real user-X JWT session** + non-admin Realtime delivers **no** admin rows — record each — **acceptance (SC-004; closes the FR-013 "fix all" mandate)**. **⚠️ PARTIAL —** two-device / on-device + a real user-X session.

**Checkpoint**: v1.0.0 is verified, signed, distributed, and documented; the Phase 22 carried-over QA residual is closed.

---

## Dependencies & Execution Order

### Phase dependencies
- **CR, UP, RB, CF** have **no Dart-symbol dependency on each other** → **Wave 1 (4-wide parallel)**. Each consumes only pre-existing symbols (see Dependency Audit).
- **QV** depends on CR+UP+RB+CF being merged + a signed build existing — a **verification-ordering contract** (its evidence/secret-scan need the integrated artifact), **NOT** a build edge (QV's test code imports no CR/UP/RB/CF-new symbol) → **Wave 2**.

### Within-phase ordering
- CR: T001/T002/T006 [P]; T003 after T001+T002; T004 after T002; T005 after T003+T004; T007 last.
- UP: T008/T009/T010/T012 [P]; T011 after T010; T013 after T008+T012; T014 after T010+T013; T015 after T011; T016 [P]; T017 after T015+T016; T018 after T015+T017; T019 last.
- RB: T020 first; T021/T022 after T020; T023 [P] (independent of T020); T024 after T021+T022+T023.
- CF: T025/T026/T027/T028 [P]; T029 after T026+T027+T028; T030 last.
- QV: T031 first; T032 after T031; T033/T034/T035/T039 [P] after Wave 1 merged; T036 after T032–T035; T037 after T036; T038 anytime after Wave 1 merged.

### Build edges (Dart symbols — see Dependency Audit below)
- **None.** (CR/UP/RB/CF/QV: zero inter-phase Dart-symbol edges.)

---

## Parallel Example

```text
# Wave 1 — dispatch CR, UP, RB, CF together (no shared Dart symbol; only pubspec + injection.config.dart contend):
Agent A (CR): T001–T007  (Sentry seam + main.dart handlers)
Agent B (UP): T008–T019  (app_update feature + dialog + l10n)
Agent C (RB): T020–T024  (icon + splash + fail-closed signing)
Agent D (CF): T025–T030  (agency-logo fix + isClosed sweep)

# Wave 2 — after Wave 1 merges + a signed build exists, dispatch QV:
Agent E (QV): T031–T039  (integration test + 6-path walk + Phase 22 residual verify + secret-scan + release notes + distribution)

# Within UP, launch the independent creators in parallel:
T009 entities  ‖  T010 repo interface  ‖  T012 DTO  ‖  T016 l10n
```

---

## Implementation Strategy

### MVP scope
The three P1 stories are US1 (signed build boots), US2 (crash reporting), US3 (six golden paths) — the plan's three acceptance criteria. MVP = RB (US1) + CR (US2) + QV's six-path walk (US3). US4 (update prompt), US5 (distribution/docs), US6 (polish) layer on.

### Incremental delivery
1. Wave 1 (CR ‖ UP ‖ RB ‖ CF) → crash reporting, update prompt, signed build + branding, carried-over fixes — all independent.
2. Wave 2 (QV) → the six-path QA pass + the one automated test + APK secret-scan + release notes + distribution on the integrated signed build.

---

# Multi-Agent Execution Plan

## Touch-Fan Table

Shared / contention-prone files each phase modifies (the `/wave` orchestrator uses this to warn sub-agents up front and to pick merge order least-touch-first). New, phase-private files (e.g. `lib/features/app_update/**`, the new `lib/core/logging/*crash*` files) are omitted.

- **CR**: `pubspec.yaml` (adds `sentry_flutter`), `lib/main.dart`, `lib/core/di/injection.config.dart` (codegen), `.env.example.json`.
- **UP**: `pubspec.yaml` (adds `package_info_plus`), `lib/app.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen), `docs/release/version-manifest.example.json` (new, UP-owned).
- **RB**: `pubspec.yaml` (dev deps + `flutter_launcher_icons`/`flutter_native_splash` config), `android/app/build.gradle.kts`, `android/key.properties` (new, gitignored), `android/.gitignore`, `android/app/src/main/res/**` (generated), `assets/branding/**` (new).
- **CF**: `lib/features/agency/data/datasources/supabase_agency_datasource.dart`, `lib/features/agency/presentation/widgets/agency_badge.dart`, `lib/features/ads/presentation/bloc/ad_slot_cubit.dart`, `lib/features/agency/presentation/bloc/agency_verification_cubit.dart`, `lib/features/profile/presentation/cubit/profile_cubit.dart` (+ any sweep-discovered cubit). **No shared codegen/ARB/pubspec edit.**
- **QV**: `integration_test/primary_publish_path_test.dart` (new), `docs/release/v1.0.0.md` (new), `specs/024-release-polish/DEFERRED.md` (new, if needed). **No `lib/` edit.**

**Contention set**: `pubspec.yaml` is edited by **CR + UP + RB** in **disjoint regions** (CR/UP add separate lines under `dependencies`; RB adds `dev_dependencies` + the trailing `flutter_launcher_icons:`/`flutter_native_splash:` config) — the later merger unions the blocks. `lib/core/di/injection.config.dart` is **regenerated by CR + UP** — the later merger re-runs `build_runner`. The **l10n ARBs + `app_strings.dart` are touched by UP only** → **no ARB contention this phase** (CR/RB/CF/QV add no UI string). **CF and QV touch ZERO shared files.**

**Merge least-touch-first** → **CF (0 shared) → RB (pubspec + private `android/`) → CR (pubspec + injection.config + main.dart) → UP (pubspec + injection.config + ARBs + app.dart) → QV (0 shared, last for verification)**. The second of CR/UP to merge re-runs `dart run build_runner build --delete-conflicting-outputs` (regenerates `injection.config.dart`) and, because UP touched the ARBs, re-runs the **l10n-parity + `_DebugAppLocalizations` override gate**. **RB's signing change requires exercising an actual release build** (not just `flutter analyze`) — folded into QV.

## Dependency Audit

Re-read of plan.md §"Phase Dependencies". The graph has **zero declared build edges** — every cross-phase relationship is either merge-contention (above) or verification-ordering (below). Each "would-be" edge was checked and is **false** (no Dart symbol crosses):

- **CR → (none)** — `SentryCrashReporter` consumes only the pre-existing `AppLogger` interface (`lib/core/logging/app_logger.dart`, unchanged) + the `main.dart` bootstrap; the new `CrashReporter` symbol is consumed **only by `main.dart`, which CR itself edits**. No UP/RB/CF symbol.
- **UP → (none)** — `AppUpdateRepositoryImpl`/`SupabaseManifestDatasource` consume the pre-existing `SupabaseClientWrapper` (`lib/core/network/supabase_client_wrapper.dart`), `Result`/`Failure` (`lib/core/errors/`), `url_launcher`, and the new external `package_info_plus`. `app.dart` imports UP's own `AppUpdateCubit`. **No CR/RB/CF symbol.**
- **RB → (none)** — pure config/assets (`pubspec.yaml`, `android/**`, `assets/branding/**`). **0 Dart symbols.**
- **CF → (none)** — edits pre-existing cubit/datasource/widget bodies; imports no CR/UP/RB-new symbol.
- **QV → (none, build-wise)** — `integration_test/primary_publish_path_test.dart` imports the app's pre-existing entry (`package:alnujom/main.dart`/`app.dart`) + pre-existing Phase 5/10/12/13/16 page/bloc symbols. **No CR/UP/RB/CF-new symbol** → **not a build edge.**

**Verification-ordering contract (NOT a build edge)**: **QV needs CR+UP+RB+CF merged + a signed build** for its 6-path walk, APK secret-scan, and release notes — a *recording/sign-off* ordering, not a symbol import. (QV's test code could even be authored in Wave 1 with zero rebase risk, since the publish path is untouched by CR/UP/RB/CF; it is placed in Wave 2 only because its evidence requires the integrated artifact.)

**False deps removed: 0** (the plan was already minimal — 0 build edges). **Unnamed deps: 0** (there are no declared edges to lack a consumer).

## Wave Plan

Topological sort of {CR, UP, RB, CF, QV} over the audited edges (0 build edges; QV is verification-ordering after the other four):

- **Wave 1**: **CR, UP, RB, CF** — no unmet deps. (**4 phases = cap of 4 ✓**; no tests-only exception needed.)
- **Wave 2**: **QV** — all of CR/UP/RB/CF merged + a signed build available. (1 phase ≤ 4 ✓)

Run via `/wave all --auto`. Wave 1 is exactly at the 4-phase cap; QV follows as the verification/release wave.

## Model Routing per Phase

- **CR: Opus** — the crash reporter is a **security/reliability boundary**: the `beforeSend` scrub must never leak the synthetic-email→phone mapping, Vault material, or decrypted PII (Principle III), and the global `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` wiring must be **non-blocking** and not swallow/double-report — correctness-critical invariants.
- **UP: Sonnet** — feature scaffolding (entities, DAO/datasource, cubit, dialog) + semver comparison + l10n; standard Clean-Arch + UI work, no atomic/RLS invariant.
- **RB: Sonnet** — `flutter_launcher_icons`/`flutter_native_splash` config + a fail-closed Gradle `signingConfig` (a well-trodden pattern); no Dart logic. (Flag in the sub-agent brief: the fail-closed requirement is a hard invariant — no debug-signed fallback.)
- **CF: Sonnet** — mechanical bugfix (read-time URL guard) + `isClosed`-guard additions + a pattern sweep; no atomic/RLS logic.
- **QV: Sonnet** — one `integration_test` + manual verification walks + the APK secret-scan + release-notes authoring + distribution ops; no implementation invariants.

`Phase CR: Opus (crash PII-scrub + non-blocking global error handlers). Phase UP: Sonnet (update feature + l10n). Phase RB: Sonnet (icon/splash + fail-closed signing config). Phase CF: Sonnet (agency-logo fix + isClosed sweep). Phase QV: Sonnet (integration test + QA walk + release docs + distribution).`

---

## Notes

- `[P]` = different file, no dependency on an incomplete task.
- `[US#]` maps a task to its spec user story.
- **Flip checkboxes in the same commit as the code** — never defer to a cleanup pass; acceptance/verification tasks stay unchecked (or `**⚠️ PARTIAL —**`) until actually run on-device/build and recorded (memory `feedback_strict_task_completion`).
- Run every `flutter run`/`build` with `--dart-define-from-file=.env.json` (memory `project_dart_defines`); crash testing additionally needs a non-empty `SENTRY_DSN` in `.env.json`.
- `/wave` sub-agents: `git reset --hard origin/024-release-polish` first, verify ancestry before merge, re-anchor orchestrator CWD to repo root before each merge (memories `project_wave_worktree_base`, `project_wave_merge_cascade_gotchas`); run the full verify suite after each merge (`project_wave_run_full_verify_suite`).
- **New deps**: pin each to an **exact resolved version (no caret)** per the `pubspec.yaml` convention (e.g. `equatable: 2.0.8`, `go_router: 17.2.2`); after any phase that edits `pubspec.yaml` (CR/UP/RB), run `flutter pub get` before `build_runner`/`analyze`.
- **Operator prerequisites (not code — gate QV)**: a **Sentry self/EU instance + DSN** (CR/T006-T007), the **release keystore** (RB/T023), and the **Telegram channel** (QV/T037) must be provisioned by the operator before the corresponding acceptance can be recorded; document them in `docs/release/v1.0.0.md` (T036) and, if any is unavailable at QA time, record it in `specs/024-release-polish/DEFERRED.md` rather than blocking silently (the Phase 22 Vault/Firebase precedent).

**Total tasks**: 39 (CR 7, UP 12, RB 5, CF 6, QV 9). **Per story**: US1 ≈ T020–T024 (+ QV verify); US2 ≈ T001–T007; US3 ≈ T031–T033/T038/T039; US4 ≈ T008–T019; US5 ≈ T034/T036/T037; US6 ≈ T016/T022/T025–T030.
