# Phase 0 Research — Release Polish, Distribution & QA Pass (Phase 24)

Locked decisions continue the project series (Phase 23 ended at R-205). Each decision records what was chosen, why, and the rejected alternatives (Principle XII).

---

## R-206 — Crash reporting tool & hosting: Sentry (self-hosted or EU instance)

**Decision**: Crash/error reporting uses **Sentry** via the `sentry_flutter` pub package, pointed at a **self-hosted or EU-region** Sentry instance (the DSN is environment-specific). This resolves the plan's §16 open question and the spec's 2026-06-02 clarification.

**Rationale**: §2 + §14 flag Firebase Crashlytics as sanctions-risky for a Syria-based project; Sentry self-hosted/EU is sanctions-safe and reachable from Syrian IPs. `sentry_flutter` is the maintained Flutter SDK, supports Android, and captures Dart + native errors.

**Alternatives rejected**:
- **Firebase Crashlytics** — sanctions risk (§2, §14); explicitly "do not adopt without legal review."
- **In-house error sink (Supabase table)** — considered (the spec's option B) but rejected by the user in favour of a real crash dashboard with grouping/stack symbolication.
- **No remote reporting** — rejected; launch is exactly when crash signal matters most (the §16 mandate to decide here).

The concrete instance (self-hosted box vs Sentry EU SaaS) is an **ops/infra detail deferred to deployment**, not a code-shape decision — the only code-visible artifact is the DSN, supplied at build time (R-217).

---

## R-207 — Crash capture is automatic; no consent UI (clarify Q1)

**Decision**: Crash reporting is **always on** (no consent prompt, no crash-consent screen). A user-facing opt-out toggle is **forward-stated** future work.

**Rationale**: Reports are PII-scrubbed (R-208), no stated regulatory mandate requires consent, and launch-time signal is most valuable. Removing the consent surface also removes a screen from this phase's localization/theming scope.

**Alternatives rejected**: one-time opt-in prompt (delays signal exactly when needed); opt-out toggle shipped in v1 (adds a settings surface + persistence for marginal v1 value).

---

## R-208 — PII/secret scrubbing + non-blocking behaviour

**Decision**: A Sentry `beforeSend` hook **scrubs** every outgoing event of: the synthetic email and any phone number (the synthetic-email→phone mapping), Vault secret material, decrypted PII, and auth tokens. The reporter is **non-blocking**: an unreachable Sentry endpoint never blocks `runApp` and never crashes the app (init is guarded exactly like the Phase 22 Firebase init pattern in `main.dart`).

**Rationale**: Principle III (no PII/secret leakage) + FR-006/FR-007. The Phase 22 `try/catch` guard around `Firebase.initializeApp()` is the established degraded-mode pattern; crash init mirrors it.

**Alternatives rejected**: shipping raw events (PII leak); blocking on init (bricks launch when the dashboard is down).

---

## R-209 — Update-version source: Supabase Storage JSON manifest (clarify Q2)

**Decision**: The latest-version source of truth is a **JSON manifest hosted on Supabase Storage** (a public bucket), downloaded on cold start via the **existing** `SupabaseClientWrapper` / Supabase client. **No** Cloudflare/Google CDN dependency.

**Rationale**: Supabase is already a dependency and already reachable from Syrian IPs (§2); a public Storage object needs no new infra and no new origin host (the project website may not exist yet). Telegram is the APK **download** channel (R-211, R-216).

**Alternatives rejected**:
- **Phase 23 `app_settings` latest-version key** — viable (spec option B) but mixes release metadata into the product-settings store; the manifest is cleaner and decoupled.
- **Project website / directly-reachable origin** — assumes an origin that may not exist for v1 and risks CDN unreachability.

---

## R-210 — Installed version via `package_info_plus`; semver-first comparison (clarify Q4)

**Decision**: The app reads its **installed** version at runtime via **`package_info_plus`** (new runtime dep). "Newer" is decided by **semantic-version comparison** (`major.minor.patch`, matching the plan's `1.<phase>.<patch>` scheme and `pubspec` `1.0.0+1`), with the **build number `+N` as a tiebreaker** only when the semantic versions are equal.

**Rationale**: `package_info_plus` is the standard, Android-supported way to read `versionName`/`versionCode` at runtime; baking a constant via dart-define is more fragile and drifts from `pubspec`. Semver-first matches the project's version scheme and is human-readable in the manifest.

**Alternatives rejected**: a generated/dart-defined version constant (drifts from the real installed version, doesn't reflect a sideloaded older APK); Android `versionCode`-only comparison (opaque, not human-readable in the manifest); build-number-only (loses the `1.<phase>.<patch>` semantics).

---

## R-211 — Update prompt: dismissible, once per cold start (clarify Q3-prompt)

**Decision**: When the manifest advertises a newer version, the app shows a **localized, dismissible dialog once per cold start** with **"Update"** (opens the Telegram/website download via the existing `url_launcher`) and **"Later"** (dismiss for the session). It **re-shows on the next cold start** until the user updates; **no persisted "dismissed version" state** in v1. A missing/unreachable/malformed manifest, or a same/older advertised version, is a **silent no-op**. A force/minimum-supported-version gate is **forward-stated**.

**Rationale**: Keeps the direct-APK audience moving to the latest build without nagging mid-session; needs no persistence; trivially testable (FR-009/FR-010).

**Alternatives rejected**: persist-dismissed-version (extra state for marginal benefit); blocking/forced update (out of v1 scope — forward-stated); a passive badge with no dialog (too easy to miss for a sideloaded audience).

---

## R-212 — App icon + splash via `flutter_launcher_icons` + `flutter_native_splash`

**Decision**: The final **app icon** (incl. Android adaptive icon) and **splash** (light + dark) are generated from source art via the **`flutter_launcher_icons`** and **`flutter_native_splash`** dev-dependencies (build-time codegen into `android/app/src/main/res/**`). Source art lives under `assets/branding/`.

**Rationale**: These are the de-facto Flutter tools for Android launcher/adaptive icons + themed splash, generate native resources deterministically (incl. `values-night` for dark), and are dev-only (no runtime weight). The current launcher icon is still the default Flutter icon.

**Alternatives rejected**: hand-authoring every `mipmap-*`/`drawable-*` density by hand (error-prone, no dark variant tooling); a runtime splash widget (flashes the OS default first).

---

## R-213 — Release signing: real config, fail-closed

**Decision**: `android/app/build.gradle.kts` gets a real **`release` `signingConfig`** sourced from a gitignored **`android/key.properties`** (keystore path + passwords) with the **keystore file kept outside the repo** (ADR-0001 secrets posture). The release build **fails closed** when `key.properties`/keystore is absent — it MUST NOT silently fall back to the debug keys (today's `signingConfig = signingConfigs.getByName("debug")` + TODO is replaced).

**Rationale**: FR-003 + Principle III. A debug-signed "release" is a real footgun; failing closed prevents shipping one by accident. The Phase 22 conditional-Gradle pattern (`if (file(...).exists())`) shows the established "guard on a gitignored file" approach.

**Alternatives rejected**: committing the keystore/passwords (secret leak — forbidden); keeping the debug-signing fallback (ships an unshippable artifact); CI-injected env-only signing with no local path (blocks local release builds for the solo maintainer).

---

## R-214 — QA evidence: hybrid (clarify Q3-QA)

**Decision**: The six golden paths are evidenced **hybrid**: **manual** on-device (Infinix Note 8) + emulator (Pixel 8 Pro AVD) walks for **all six**, **plus one automated `integration_test`** for the **primary publish path** (register → admin-approve → publish → admin-approve → public view → inquiry). The **maintenance-mode (two-device)** and **push-delivery** legs stay **manual** (neither is observable in a single in-process test). `integration_test` is already a dev dependency — **no new test dep**.

**Rationale**: Honors the standing "no new automated tests until MVP feature-complete" convention with exactly one sanctioned release-hardening exception; the AVD-walk-acceptable rule covers the manual five.

**Alternatives rejected**: automate all 6 (2 are not in-process observable; largest work item + ongoing flakiness); manual-only (no regression net on the highest-value flow).

---

## R-215 — Carried-over deferral scope reconciliation (clarify Q5)

**Decision**: Per the user's "fix all" choice, Phase 24 fixes the named carried-over items in-PR. The **ground-truth scope is smaller than the spec's headline** and is reconciled here (Principle X — drift recorded):

- **Phase 19 agency follow-ups (D-1, D-2, D-3)**: **already DONE (2026-06-01)** — search-results badge, verification-document upload, rejection-reason surfacing all landed. The remaining Phase 19 residual is **(a) the agency-logo double-prefix bug** (`lib/features/agency/data/datasources/supabase_agency_datasource.dart` stores a full public URL in `logo_path`/`cover_path`; `agency_badge.dart` re-prefixes → HTTP 400 broken-logo placeholder) — fixed **read-time** (detect an already-absolute URL and skip re-prefixing; no migration/backfill needed), and **(b)** on-device re-verification (folds into the golden-path walk, T074). **FE-1** (suspend/remove cascade choice) stays a **future spec** — explicitly OUT of Phase 24.
- **Phase 22 T044–T046**: largely **on-device verification** (T044 admin-counter two-device pass + live role grant/revoke — the live-permission half is already VERIFIED PASS; T045 six-event in-app delivery with push blocked; T046 cross-user RLS-denial from a real user-X JWT + non-admin Realtime delivers no admin rows) **plus a genuine new release task: a binary secret-scan of the built APK** (T046). The `dispatch_push` redeploy + push-tray IMPORTANCE_HIGH channel are **push-enablement** items gated on operator Vault/Firebase setup and only matter in push-enabled mode — re-stated as push-enablement prerequisites, not blocking the v1.0.0 in-app/default build.
- **`isClosed`-guard sweep**: add `if (isClosed) return;` before `emit` in the known async cubit loads — `AdSlotCubit.load` (`lib/features/ads/presentation/bloc/ad_slot_cubit.dart:41`), `AgencyVerificationCubit.load` (`lib/features/agency/presentation/bloc/agency_verification_cubit.dart:101`), `ProfileCubit.load` (`lib/features/profile/presentation/cubit/profile_cubit.dart:37`) — and **sweep the codebase** for the same pattern in other async cubit/bloc loads.

**Rationale**: FR-013 + the 2026-06-02 clarification mandate fixing the named items; recording the true (reduced) scope prevents over-sizing and double-work. A *new* out-of-scope issue surfaced during the walk is recorded in `DEFERRED.md` with a rationale rather than silently dropped.

**Alternatives rejected**: treating the headline list literally and re-doing the already-merged D-1/2/3 (waste); pulling FE-1 into v1 (it's an approved-future-spec product change, not a release-polish fix).

---

## R-216 — Distribution: Supabase Storage + Telegram + Play Store internal track (ops, not code)

**Decision**: The signed APK and the version manifest are uploaded to **Supabase Storage**; the **Telegram channel** is the user-facing download link (referenced by the update prompt and the release notes). A **Play Store internal testing track** is configured for QA/stakeholders only. These are **manual operator steps**, recorded as a checklist in the release notes and `quickstart.md` — **not** application code.

**Rationale**: §14 Channel A (direct APK + Telegram, primary for Syria) + Channel B (Play Store internal, QA-only). Hosting on Supabase Storage avoids the unreachable-CDN risk and reuses existing infra.

**Alternatives rejected**: an in-app auto-downloader/installer (silent APK install is out of v1 scope — forward-stated); advertising the Play Store track publicly (unreliable for Syrian users).

---

## R-217 — Crash reporting enablement: release/profile builds, DSN via dart-define

**Decision**: Sentry is **active in release/profile** builds; **debug** stays console-only (`ConsoleLogger` already no-ops outside `kDebugMode`). The DSN is supplied as a **dart-define** (read alongside the existing `.env.json` per the project's `--dart-define-from-file=.env.json` convention); when the DSN is empty, the reporter is inert (no init, no crash). The **forced-exception acceptance test** (SC-002) runs a **profile (or release-with-DSN)** build so the event reaches the dashboard.

**Rationale**: Avoids noisy debug-run events, keeps the DSN out of source (memory `project_dart_defines`, ADR-0001), and makes "captures a forced exception in a dev build" testable by running profile/release with the DSN set. Empty-DSN inertness keeps CI and degraded environments green (mirrors the Phase 22 push-disabled posture).

**Alternatives rejected**: hardcoding the DSN (secret in repo); enabling in debug (noise + double-reporting with the console); requiring the DSN always-present (breaks CI/degraded builds).

---

### New dependencies introduced by Phase 24 (Android-supported; Principle XI)

| Package | Kind | Purpose | Android support |
|---|---|---|---|
| `sentry_flutter` | runtime | crash/error capture → Sentry self/EU dashboard (R-206) | ✅ (also supports iOS, which we don't build — not an iOS-only plugin) |
| `package_info_plus` | runtime | read installed version for the update check (R-210) | ✅ |
| `flutter_launcher_icons` | dev (codegen) | generate launcher + adaptive icon (R-212) | ✅ (build-time) |
| `flutter_native_splash` | dev (codegen) | generate light/dark splash (R-212) | ✅ (build-time) |

`url_launcher` (download link) and `integration_test` (the one test) are **already present** — no new dep for either. This is a deliberate departure from Phase 23's zero-new-deps posture, justified per-package in `plan.md` § Complexity Tracking (the Phase 22 precedent for justified new deps).
