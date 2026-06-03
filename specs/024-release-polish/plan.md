# Implementation Plan: Release Polish, Distribution & QA Pass (Phase 24)

**Branch**: `024-release-polish` (spec tracked via `.specify/feature.json` → `specs/024-release-polish`) | **Date**: 2026-06-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/024-release-polish/spec.md`

## Summary

Phase 24 is the **release-hardening** phase — no new product feature; it makes the already-built v1 marketplace shippable, observable, and proven. It delivers five independent work units: **(CR)** crash & error reporting via **Sentry** (self-hosted/EU — resolves §16; Crashlytics rejected) wired behind the existing `AppLogger` seam in `lib/core/logging/` plus global error handlers in `main.dart`, automatic (no consent UI), PII-scrubbed, and non-blocking; **(UP)** an in-app **update prompt** that, on cold start, reads a **Supabase-Storage-hosted version manifest**, compares semantic versions (build-number tiebreaker), and shows a localized, dismissible "Update / Later" dialog (download via the existing `url_launcher` to Telegram), degrading to a silent no-op when the manifest is unreachable/malformed; **(RB)** a production **release build** — final app icon + adaptive icon + light/dark splash (generated via `flutter_launcher_icons` + `flutter_native_splash`), a real **fail-closed** release `signingConfig` (no debug-signed release), version `1.0.0`; **(CF)** the **carried-over fixes** the spec mandates — the Phase 19 agency-logo double-prefix bug (read-time fix), the recurring async-cubit `isClosed`-guard sweep, and reconciling the Phase 22 T044–T046 residue (largely on-device verification + an APK secret-scan); and **(QV)** the **golden-path QA pass** — all six paths verified (manual ×6 + **one** automated `integration_test` for the primary publish path; maintenance + push stay manual), the APK secret-scan, the distribution-channel bring-up (Supabase Storage + Telegram + Play Store internal track), and `docs/release/v1.0.0.md`.

**Backend**: **none** — no new table, no new migration, no new RPC, no new permission key (FR-018). (The Phase 22 `dispatch_push` redeploy + IMPORTANCE_HIGH push channel are **operator push-enablement** prerequisites, not Phase 24 application code, and only matter in push-enabled mode.) **Frontend / build**: new deps `sentry_flutter` + `package_info_plus` (runtime) and `flutter_launcher_icons` + `flutter_native_splash` (dev, codegen); `url_launcher` + `integration_test` are already present. CR touches `lib/core/logging/**` + `main.dart`; UP adds a small `lib/features/app_update/**` feature consumed from `app.dart`; RB touches `pubspec.yaml` + `android/**` + `assets/branding/**` (zero Dart symbols); CF edits pre-existing cubits + the agency datasource/badge; QV adds `integration_test/**` + `docs/release/**`. **Zero Dart-symbol build edges between the five units** (see § Phase Dependencies).

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); Android Gradle (Kotlin DSL, `build.gradle.kts`); minSdk 24. No Edge Function / migration this phase.
**Primary Dependencies**: existing — `supabase_flutter`, `flutter_bloc`, `get_it`+`injectable`, `go_router`, `equatable`, `intl`, `url_launcher`, `integration_test` (dev). **NEW** — `sentry_flutter` + `package_info_plus` (runtime), `flutter_launcher_icons` + `flutter_native_splash` (dev). All Android-supported (Principle XI; justified in § Complexity Tracking, per the Phase 22 new-dep precedent).
**Storage**: Supabase Storage **public object** for the version manifest JSON + the release APK (R-209/R-216) — read via the existing client; **no DB schema change** (FR-018). No new table/RPC/permission.
**Testing**: Hybrid (R-214) — **one** new `integration_test` (primary publish path; `integration_test` already a dev dep) + **manual** on-device (Infinix Note 8) + Pixel 8 Pro AVD walks for all six golden paths (maintenance two-device + push manual); a **binary secret-scan of the built APK** (Phase 22 T046); `flutter analyze` + the full CI linter suite (format / design-tokens / l10n-parity / l10n-literals / SDK-boundary — memory `project_wave_run_full_verify_suite`).
**Target Platform**: Android only (Principle XI); Arabic-first RTL + English LTR. NO iOS/Web.
**Project Type**: Mobile app (Flutter) + Supabase backend — established two-tree layout (no backend change this phase).
**Performance Goals**: cold-start version check is one bounded Storage GET on app-load (no per-frame work); Sentry init is guarded + non-blocking. The §15 **< 3 s cold-start budget is measured on the Infinix Note 8 and recorded as an advisory baseline in the release notes — NOT a release gate** (clarify Q2; §12 defers hard perf benchmarks for v1).
**Constraints**: crash payloads PII/secret-scrubbed via `beforeSend` (FR-006, Principle III); reporter non-blocking + DSN via dart-define, inert when empty (R-208/R-217); release signing **fails closed** with the keystore kept outside the repo (FR-003, ADR-0001); update check is fail-silent (FR-010); crash + update wiring stays in `core/`/a feature, **domain stays Supabase/crash-SDK-free** (Principle IX); all new UI strings localized `ar`/`en` (Principle V); new surfaces four-combination correct via Phase 2 tokens (Principle VI); **no iOS/Web** (Principle XI).
**Scale/Scope**: 0 migrations; 0 new tables/RPCs/permissions; new deps ×4; 1 small Flutter feature (`lib/features/app_update/`); ~6–10 new l10n keys (update prompt only); ~4 amended Dart files for CF (`ad_slot_cubit`, `agency_verification_cubit`, `profile_cubit`, `supabase_agency_datasource` + `agency_badge`); `main.dart` (CR) + `app.dart` (UP) amended; `android/app/build.gradle.kts` + `android/key.properties` (RB); 1 integration test; 1 release-notes doc.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | spec.md + 3 clarifications (specify) + 5 clarifications (clarify) complete before this plan; research / data-model / contracts / quickstart accompany it |
| II. Source-Controlled Backend | ✅ Pass | No DB change this phase. The version manifest content + signing-config scaffolding are checked-in (the `.example`/template files); secrets (keystore, passwords, DSN) are gitignored / supplied at build time, not committed |
| III. Security-First Supabase | ✅ Pass | Crash payloads scrubbed of synthetic-email/phone, Vault material, decrypted PII (FR-006); release keystore never committed + signing fails closed (FR-003); the **APK secret-scan** (Phase 22 T046) verifies no secret shipped; manifest bucket is public-read only (no write from client) |
| IV. Clean Architecture | ✅ Pass | `lib/features/app_update/{domain,data,presentation}` (UP); the crash reporter is a `core/` infrastructure seam; `supabase_flutter` + `sentry_flutter` confined to `data/`/`core`, not `domain/`; update-decision logic in a use case, not the widget |
| V. Arabic-First Localization | ✅ Pass | The update prompt's ~6–10 keys land in both ARBs + `_DebugAppLocalizations` (`project_l10n_debug_localizations_override`); crash reporting is automatic with **no consent UI** (R-207), so no consent surface to localize |
| VI. Theme System | ✅ Pass | The update dialog + splash use Phase 2 tokens (no inline hex/font/padding); light/dark splash generated by `flutter_native_splash`; four-combination correct (FR-016/SC-007) |
| VII. Dynamic Roles & Permissions | ✅ Pass | No permission key added/changed; no new sensitive admin action (FR-018). (Crash/update are not permission-gated.) |
| VIII. Approval Workflow & Identity | ✅ Pass | No approval/identity change. The CF agency-logo fix is a render-path bugfix; it does not alter publisher-identity visibility |
| IX. Future Backend Portability | ✅ Pass | Crash reporter behind a `core/` `CrashReporter` seam; update check behind an `AppUpdateRepository` interface in `domain/`; `supabase_flutter`/`sentry_flutter`/`package_info_plus` confined to `data/`/`core` impls — `domain/` imports none of them |
| X. Testable AI Workflow | ✅ Pass | Per-FR/per-SC verification map in data-model + quickstart; R-215 reconciles the carried-over scope (Phase 19 D-1/2/3 already done; FE-1 stays future) so specs match reality; the cold-start "budget vs §12" tension is reconciled to advisory (R-217 area) |
| XI. Android-First MVP | ✅ Pass | All four new deps are Android-supported (not iOS-only); no iOS/Web target, plugin, or build config added; the release build is Android APK only |
| XII. No Hidden Decisions | ✅ Pass | 3+5 clarifications resolved in spec; every plan-time choice recorded as a locked decision (R-206..R-217) with rejected alternatives |

**Gate result**: PASS — no violations. Phase 24 introduces **four new dependencies** (unlike Phase 23's zero-new-deps); these are not a constitution violation but are recorded with per-package justification in § Complexity Tracking (the Phase 22 precedent).

## Project Structure

### Documentation (this feature)

```text
specs/024-release-polish/
├── plan.md              # This file
├── research.md          # Phase 0 — locked decisions R-206..R-217
├── data-model.md        # Phase 1 — manifest JSON schema + crash-scrub fields + per-FR/SC map
├── quickstart.md        # Phase 1 — release verification recipe (build → crash → update → 6 paths → distribute)
├── contracts/           # Phase 1 — 4 interface contracts
│   ├── phase24-crash-reporting-and-logger-seam.md
│   ├── phase24-version-manifest-and-update-check.md
│   ├── phase24-release-build-signing-and-assets.md
│   └── phase24-golden-path-qa-and-carried-over-fixes.md
├── checklists/
│   └── requirements.md  # spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 — (/speckit-tasks)
```

### Source Code (repository root)

```text
# CR — crash & error reporting
lib/core/logging/
├── app_logger.dart                       # EXISTING (abstract AppLogger — unchanged interface)
├── console_logger.dart                   # EXISTING (debug-only sink — unchanged)
├── crash_reporter.dart                   # NEW — abstract CrashReporter seam (recordError/addBreadcrumb/init)
├── sentry_crash_reporter.dart            # NEW — @LazySingleton(as: CrashReporter); sentry_flutter; beforeSend scrub
└── noop_crash_reporter.dart              # NEW — inert reporter when DSN empty (mirrors NoopPushMessagingService)
lib/main.dart                             # AMENDED (CR) — guarded SentryFlutter.init / runZonedGuarded +
                                          #   FlutterError.onError + PlatformDispatcher.onError → CrashReporter

# UP — in-app update prompt
docs/release/version-manifest.example.json   # NEW (UP-owned) — checked-in canonical manifest schema (the .example
                                          #   template the plan's Constitution Check II references; operator uploads
                                          #   the live copy to Supabase Storage)
lib/features/app_update/
├── domain/
│   ├── entities/        # AppVersion (semver+build, compareTo), VersionManifest, UpdateAvailability
│   ├── repositories/    # AppUpdateRepository (abstract)
│   └── usecases/        # CheckForUpdate (download manifest, read installed version, compare)
├── data/
│   ├── datasources/     # SupabaseManifestDatasource (Storage GET), PackageInfoVersionSource
│   ├── dtos/            # VersionManifestDto
│   └── repositories/    # AppUpdateRepositoryImpl  (@LazySingleton(as: AppUpdateRepository))
└── presentation/
    ├── bloc/            # AppUpdateCubit (checkOnColdStart → emits UpdateAvailable/None/Error-silent)
    └── widgets/         # update_prompt_dialog.dart (localized; Update→url_launcher / Later→dismiss)
lib/app.dart                              # AMENDED (UP) — kick AppUpdateCubit.check() once on cold start;
                                          #   show update_prompt_dialog when UpdateAvailable (session-once)

# RB — release build, icons, splash, signing
pubspec.yaml                              # AMENDED (CR+UP+RB) — deps + flutter_launcher_icons/native_splash config
assets/branding/                          # NEW — source icon + splash art (light/dark)
android/app/build.gradle.kts              # AMENDED (RB) — real release signingConfig, fail-closed
android/key.properties                    # NEW (gitignored) — keystore path + passwords (NOT committed)
android/app/src/main/res/**               # GENERATED (RB) — mipmap/adaptive icon + splash drawables (+ -night)

# CF — carried-over fixes + isClosed sweep
lib/features/agency/data/datasources/supabase_agency_datasource.dart  # AMENDED — logo/cover URL no double-prefix
lib/features/agency/presentation/widgets/agency_badge.dart            # AMENDED — absolute-URL guard (read-time)
lib/features/ads/presentation/bloc/ad_slot_cubit.dart                 # AMENDED — if (isClosed) return; before emit
lib/features/agency/presentation/bloc/agency_verification_cubit.dart  # AMENDED — same guard
lib/features/profile/presentation/cubit/profile_cubit.dart            # AMENDED — same guard
#  + codebase sweep for the same async-load pattern

# QV — QA pass + automated test + release docs
integration_test/
└── primary_publish_path_test.dart        # NEW — register→approve→publish→approve→view→inquiry (the one automated test)
docs/release/
└── v1.0.0.md                             # NEW — 6 golden-path results, install/update steps, no-email recovery,
                                          #   cold-start baseline, APK secret-scan result, distribution checklist
specs/024-release-polish/DEFERRED.md      # NEW (if any new out-of-scope issue surfaces during the walk)

# Shared / generated (merge-contention — see Phase Dependencies)
lib/core/di/injection.config.dart         # REGENERATED (CR + UP) — codegen
lib/l10n/{app_ar.arb, app_en.arb}         # AMENDED (UP only) — update-prompt keys
lib/core/localization/app_strings.dart     # AMENDED (UP only) — matching _DebugAppLocalizations overrides
lib/l10n/app_localizations*.dart           # REGENERATED (UP) — gen-l10n
```

**Structure Decision**: Established two-tree layout. CR is a `core/` infrastructure seam + a `main.dart` amendment; UP is a small new Clean-Arch feature tree (`lib/features/app_update/`) consumed from `app.dart`; RB is pure config/assets (no Dart); CF amends pre-existing files; QV adds `integration_test/` + `docs/release/`. The four Wave-1 units occupy **disjoint files** except the shared `pubspec.yaml` (deps) and the generated `injection.config.dart` (CR + UP). No migration timestamps — there is no backend change this phase.

## Implementation Phases

> Phase 24 is one PR, decomposed into **five** implementation units. The decomposition is along **file-disjointness**: CR, UP, RB, CF share **no Dart symbol** and edit disjoint files (bar `pubspec.yaml` + the generated `injection.config.dart`), so they form **one wide Wave 1**. QV consumes the merged result for its evidence (verification-ordering, NOT a symbol edge), so it is Wave 2.

### CR — Crash & error reporting (Sentry, behind the `AppLogger`/`CrashReporter` seam)
Add `sentry_flutter` to `pubspec.yaml`. Add a `CrashReporter` abstract seam in `lib/core/logging/crash_reporter.dart` (`Future<void> init(...)`, `Future<void> recordError(Object, StackTrace, {Map context})`, `void addBreadcrumb(...)`). Implement `SentryCrashReporter` (`@LazySingleton(as: CrashReporter)`) configured with the DSN (dart-define, R-217) and a **`beforeSend` scrub** stripping synthetic-email/phone, Vault material, decrypted PII, and tokens (R-208); implement `NoopCrashReporter` bound when the DSN is empty (mirrors `NoopPushMessagingService`). Amend `lib/main.dart` to **guard-init** Sentry (try/catch like the Phase 22 Firebase guard), wrap the bootstrap in `runZonedGuarded`, and route `FlutterError.onError` + `PlatformDispatcher.onError` to the `CrashReporter` — non-blocking on failure (FR-007). Active in release/profile; debug stays console-only. Regenerate DI.
**Touch fan**: `lib/core/logging/{crash_reporter,sentry_crash_reporter,noop_crash_reporter}.dart` (new), `lib/main.dart`, `pubspec.yaml`, `lib/core/di/injection.config.dart` (codegen), `.env.json`/`.env.example.json` (DSN key — example committed, real value local).

### UP — In-app update prompt (cold-start version check vs Supabase manifest)
Add `package_info_plus` to `pubspec.yaml`. Build `lib/features/app_update/domain/` (entities `AppVersion` [semver + build, `compareTo` semver-first, build tiebreaker — R-210], `VersionManifest`, `UpdateAvailability`; abstract `AppUpdateRepository.checkForUpdate() → Result<UpdateAvailability>`; use case `CheckForUpdate`). Build `data/` (`SupabaseManifestDatasource` — Storage GET of the public manifest via the existing client; `PackageInfoVersionSource` — installed version; `VersionManifestDto`; `AppUpdateRepositoryImpl` `@LazySingleton(as: AppUpdateRepository)` returning `Result<T>`/`Failure`, **fail-silent** on unreachable/malformed — FR-010). Build `presentation/` (`AppUpdateCubit.check()`; `update_prompt_dialog.dart` — localized title/body + **Update** (`url_launcher` → Telegram/website) + **Later** (session dismiss), shown once per cold start — R-211). Amend `lib/app.dart` to call `AppUpdateCubit.check()` once on cold start and present the dialog on `UpdateAvailable`. Add the ~6–10 update-prompt l10n keys to both ARBs + `_DebugAppLocalizations` + run gen-l10n. Regenerate DI.
**Touch fan**: `lib/features/app_update/**` (new), `lib/app.dart`, `pubspec.yaml`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/core/localization/app_strings.dart`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).

### RB — Release build: icon, splash, signing, version
Add `flutter_launcher_icons` + `flutter_native_splash` dev deps + their config blocks in `pubspec.yaml`; place source art under `assets/branding/`; run the generators to produce launcher/adaptive icons + light/dark splash into `android/app/src/main/res/**` (incl. `-night`). Replace the `release` `signingConfig` in `android/app/build.gradle.kts` with a real config sourced from a gitignored `android/key.properties` (keystore outside the repo), **failing closed** when absent (no debug-signed fallback — R-213/FR-003). Confirm version `1.0.0` in `pubspec.yaml` (already `1.0.0+1`). Confirm `debugShowCheckedModeBanner: false` (already set in `app.dart`) and that `kDesignToolsEnabled` is off in release (FR-001 — no debug scaffolding). **No Dart symbol.**
**Touch fan**: `pubspec.yaml`, `assets/branding/**` (new), `android/app/build.gradle.kts`, `android/key.properties` (new, gitignored), `android/.gitignore`, `android/app/src/main/res/**` (generated).

### CF — Carried-over fixes + `isClosed` sweep (R-215)
Fix the **agency-logo double-prefix** bug (read-time): `supabase_agency_datasource.dart` stores only the object **path** (or `agency_badge.dart` detects an already-absolute URL and skips re-prefixing) — no migration/backfill. Add `if (isClosed) return;` before `emit` in `AdSlotCubit.load`, `AgencyVerificationCubit.load`, `ProfileCubit.load`, and **sweep** the codebase for the same async-cubit-load pattern. (Phase 22 T044–T046 are reconciled as **on-device verification** owned by QV + the APK secret-scan owned by QV; the `dispatch_push` redeploy / IMPORTANCE_HIGH channel are operator push-enablement, not CF code.)
**Touch fan**: `lib/features/agency/data/datasources/supabase_agency_datasource.dart`, `lib/features/agency/presentation/widgets/agency_badge.dart`, `lib/features/ads/presentation/bloc/ad_slot_cubit.dart`, `lib/features/agency/presentation/bloc/agency_verification_cubit.dart`, `lib/features/profile/presentation/cubit/profile_cubit.dart` (+ any sweep-discovered cubit). No shared-file contention with CR/UP/RB (cubit bodies only; no DI/ARB change).

### QV — Golden-path QA pass + 1 integration test + APK secret-scan + release docs + distribution
Write `integration_test/primary_publish_path_test.dart` (register → admin-approve → publish → admin-approve → public view → inquiry — the one automated test; `integration_test` already a dev dep). Run the **six golden-path manual walks** (Infinix Note 8 + Pixel 8 Pro AVD; maintenance two-device + push manual). Build the **signed release APK** (RB merged) and run a **binary secret-scan** of it (Phase 22 T046) — confirm no DSN/keystore/Vault/service-account material shipped. Measure + record the **cold-start baseline**. Author `docs/release/v1.0.0.md` (6-path results, install/update steps, the no-email account-recovery support flow, cold-start baseline, secret-scan result, distribution checklist). Perform the **distribution ops** (R-216): upload APK + manifest to Supabase Storage, post to the Telegram channel, configure the Play Store internal track. Record any new out-of-scope finding in `DEFERRED.md`.
**Touch fan**: `integration_test/primary_publish_path_test.dart` (new), `docs/release/v1.0.0.md` (new), `specs/024-release-polish/DEFERRED.md` (new, if needed). No `lib/` source edits, no shared-file contention.

## Phase Dependencies

> Rule honored: a declared "B depends on A" edge is listed **only** when a named Dart **file path AND exported symbol** crosses from A to B. Shared-file co-edits (`pubspec.yaml`, `injection.config.dart`, the ARBs) are **merge-contention**, not build edges. A relationship where B's *evidence/verification* needs A present at runtime — but B imports no symbol from A — is a **verification-ordering contract**, listed separately (the analogue of Phase 23's "Runtime/DB contracts"). No vague "easier in sequence" / "uses concepts from" edges appear.

**Declared code dependencies (build/merge-order edges):**

- **(none.)** CR, UP, RB, CF, and QV import **no new Dart symbol from each other**. Each consumes only **pre-existing** symbols:
  - CR consumes the pre-existing `AppLogger` (`lib/core/logging/app_logger.dart`, unchanged interface) and the pre-existing `main.dart` bootstrap; it adds the new `CrashReporter` seam — nothing imports `CrashReporter` from CR except `main.dart`, which CR itself edits. **0 outbound edges.**
  - UP consumes the pre-existing `SupabaseClientWrapper` (`lib/core/network/supabase_client_wrapper.dart`, Phase 1/4), `url_launcher`, the pre-existing `Result<T>`/`Failure` (`lib/core/errors/`), and the new external `package_info_plus` — **no CR/RB/CF symbol.** `app.dart` (edited by UP) imports UP's own `AppUpdateCubit`, not any CR symbol. **0 edges to CR/RB/CF.**
  - RB is **pure config/assets** — `pubspec.yaml`, `android/**`, `assets/branding/**`. **0 Dart symbols → 0 edges.**
  - CF edits pre-existing cubit/datasource bodies (`AdSlotCubit`, `AgencyVerificationCubit`, `ProfileCubit`, `supabase_agency_datasource`, `agency_badge`) — imports **no** CR/UP/RB-new symbol. **0 edges.**
  - QV's `integration_test/primary_publish_path_test.dart` imports the app's **pre-existing** entry (`package:alnujom/main.dart` / `app.dart`) and **pre-existing** Phase 5/10/12/13/16 page/bloc symbols — **no** CR/UP/RB/CF-new symbol. **0 build edges.**

**Verification-ordering contracts (NOT build-order edges — no Dart symbol crosses):**

- **QV's evidence depends on CR + UP + RB + CF being merged + a signed build existing** — the six-path walk + release notes record the behaviour of the crash reporter (CR), the update prompt (UP), the signed/icon/splash build (RB), and the fixed agency logo + clean log stream (CF); the **APK secret-scan** requires RB's signed artifact. This is a *recording/sign-off* ordering, **not** a symbol import: QV's test **code** compiles and the test runs against the pre-existing publish path independent of CR/UP/RB/CF. (For `/wave`, QV is therefore Wave 2; its test-authoring portion could be pulled into Wave 1 with zero rebase risk since the publish path is untouched by CR/UP/RB/CF.)
- **UP's runtime read of the Supabase-Storage manifest** is a string-keyed Storage GET (R-209), not a Dart import — UP compiles + `flutter analyze`s without the manifest object existing; end-to-end verification (quickstart) requires the manifest uploaded (a QV/ops step).
- **CR's runtime delivery to Sentry** requires the DSN dart-define + a reachable instance — a runtime/ops contract, not a build edge; CR compiles + analyzes with an empty DSN (binds `NoopCrashReporter`).
- **RB's signed APK** is produced by the build toolchain consuming the whole merged tree — a build-step ordering owned by QV's release step, not a code edge.

**Self-audit**: Declared code deps = **0**. Deps lacking a named consumer = **0** (there are no declared edges to lack one). Every cross-unit relationship is either **merge-contention** (shared file) or a **verification-ordering contract** (evidence needs runtime presence, no symbol crosses) — both listed explicitly above, neither a build edge. The graph is maximally lean: **CR ∥ UP ∥ RB ∥ CF run fully in parallel**; QV follows for evidence only. No over-conservative edges.

**Resulting execution waves:**

- **Wave 1 (parallel, 4-wide — 0 build edges):** CR, UP, RB, CF.
- **Wave 2:** QV — verification-ordering only (needs Wave 1 merged + a signed build for its walk, secret-scan, and release notes).

**Merge-order guidance for `/wave`** (from Touch-fan overlap, not code edges):

- **Shared-file contention is narrow.** `pubspec.yaml` is edited by **CR + UP + RB** (CR adds `sentry_flutter`; UP adds `package_info_plus`; RB adds the two dev deps + the icon/splash config blocks) — these are **disjoint regions** of the same file (dependencies vs dev_dependencies vs the trailing `flutter_launcher_icons:`/`flutter_native_splash:` config); whichever merges later unions the dependency blocks. `lib/core/di/injection.config.dart` is **regenerated by CR + UP** — the later merger re-runs `dart run build_runner build --delete-conflicting-outputs`. The **l10n ARBs + `app_strings.dart` are touched by UP only** (CR/RB/CF/QV add no UI string), so **no ARB contention** this phase — but the later-merging phase that touched the ARBs still re-runs the **l10n-parity + `_DebugAppLocalizations` gate** (memory `project_l10n_debug_localizations_override`).
- **Suggested merge order (least-touch-first): CF → RB → CR → UP, then QV last.** (CF and QV touch **zero** shared files; among CR/UP/RB only `pubspec.yaml` + `injection.config.dart` contend — the second of CR/UP to merge re-runs `build_runner` to regenerate `injection.config.dart`, and the later `pubspec.yaml` toucher unions the dependency blocks.) **QV merges last** and runs the full verification on the integrated, signed build. (This matches the least-touch-first order in `tasks.md` §Touch-Fan Table.)
- Per `project_wave_worktree_base` + `project_wave_merge_cascade_gotchas`: brief sub-agents to `git reset --hard origin/024-release-polish` first, verify ancestry before merge, and re-anchor the orchestrator CWD to repo root before each merge. After every merge re-run the **full verify suite** (`project_wave_run_full_verify_suite`) — `flutter analyze` + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary. RB's signing change means a **release build must be exercised** (not just `flutter analyze`) — fold into QV.

## Complexity Tracking

Phase 24 introduces **four new dependencies** — a deliberate departure from Phase 23's zero-new-deps posture (the Phase 22 precedent: new deps are allowed when justified and Android-supported). No constitution violation; recorded here per Principle XII.

| Addition | Why needed | Simpler alternative rejected because |
|----------|------------|--------------------------------------|
| `sentry_flutter` (runtime) | Capture uncaught/fatal errors to a sanctions-safe dashboard (FR-004, §16) | An in-house Supabase-table error sink (spec option B) was rejected by the user; no remote reporting leaves a launched product blind |
| `package_info_plus` (runtime) | Read the installed version at runtime for the semver update check (FR-008/R-210) | A dart-defined version constant drifts from the real installed `versionName`/`versionCode` (and from a sideloaded older APK) |
| `flutter_launcher_icons` (dev) | Generate the launcher + Android adaptive icon (FR-002/R-212) | Hand-authoring every `mipmap-*` density is error-prone and has no adaptive-icon tooling |
| `flutter_native_splash` (dev) | Generate the light/dark native splash (FR-002/R-212) | A runtime splash widget flashes the OS default first; hand-authoring `-night` drawables is error-prone |

No new Postgres extension, table, RPC, permission key, or migration (FR-018). All four packages support Android and are not iOS-only (Principle XI).

*Plan version: 1.0 | Generated by /speckit-plan | Aligned with constitution v1.0.0*
