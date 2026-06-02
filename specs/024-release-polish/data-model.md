# Phase 1 Data Model — Release Polish, Distribution & QA Pass (Phase 24)

Phase 24 adds **no database schema** (FR-018 — no new table/column/RPC/migration). Its "data" is three things: the **version-manifest JSON** (hosted on Supabase Storage), the **crash-report event** shape + scrub rules, and the **Dart domain entities** for the update-check feature. All are provider-agnostic in `domain/`; the Supabase/Sentry types stay in `data/`/`core` (Principle IX).

---

## 1. Version manifest (Supabase Storage object — R-209)

A single public JSON object (e.g. bucket `app-release`, path `android/latest.json`), read on cold start. Schema:

```jsonc
{
  "latest_version": "1.0.0",        // REQUIRED — semver (major.minor.patch)
  "latest_build": 1,                 // OPTIONAL — build number; tiebreaker when semver equal
  "min_supported_version": null,     // OPTIONAL — forward-stated (force-update gate); v1 ignores it
  "download": {
    "telegram_url": "https://t.me/<channel>",   // primary user download channel
    "website_url": null                          // optional; used when present
  },
  "release_notes": { "ar": null, "en": null }    // OPTIONAL — short note shown in the prompt
}
```

**Comparison rule (R-210)**: parse `latest_version` as semver; the prompt fires when `latest_version > installedVersion`, or (`latest_version == installedVersion` AND `latest_build > installedBuild`). Any parse error / missing `latest_version` / unreachable object ⇒ **silent no-op** (FR-010). `min_supported_version` is parsed but **not enforced** in v1 (forward-stated).

**Access**: the bucket/object is **public-read**; the client never writes it (uploaded by the operator — R-216). No RLS-protected table is involved (FR-018).

---

## 2. Crash-report event + scrub rules (R-208)

Crash reporting sends a Sentry event from `recordError`/the global handlers. A **`beforeSend` scrub** runs on every event before transmission. The scrub MUST remove / redact:

| Field class | Examples in this app | Action |
|---|---|---|
| Synthetic auth identifier | `<phone>@alnujom.local` (the synthetic email) and the raw phone it encodes | strip / redact (never ship the email→phone mapping) |
| Auth tokens | Supabase access/refresh JWT, any bearer | strip from headers, breadcrumbs, extra |
| Vault material | `fcm_service_account`, `push_dispatch_token`, any `app_vault_secret()` value | never attach; strip if present |
| Decrypted PII | `legal_name`, `national_id`, `private_contact_methods`, `inquirer_phone` (ADR-0001 Vault fields) | strip / redact |
| User identity | set only a non-PII stable id (e.g. `user_id` UUID) — **never** name/phone/email | redact name/phone/email |

**Non-PII context that MAY ship**: route/screen name, app version, locale, theme, a non-PII `user_id`, and the error + stack. **Enablement (R-217)**: active in release/profile only; DSN via dart-define; empty DSN ⇒ `NoopCrashReporter` (no init, no send). Init is **guarded + non-blocking** (FR-007): a throw/timeout never blocks `runApp`.

---

## 3. Dart domain entities (`lib/features/app_update/domain/entities/`)

All Supabase-/Sentry-free (Principle IX).

- **`AppVersion`** — `{ int major, int minor, int patch, int build }` with `int compareTo(AppVersion other)` (semver-first, build tiebreaker — R-210) and `factory AppVersion.parse(String semver, {int build})`. The installed value comes from `package_info_plus` (in `data/`), wrapped into this entity.
- **`VersionManifest`** — `{ AppVersion latest, AppVersion? minSupported, String? telegramUrl, String? websiteUrl, LocalizedText? releaseNotes }`. (`LocalizedText` mirrors the Phase 23 entity shape `{ ar?, en?, forLocale(Locale) }` — re-used or re-declared locally; no cross-feature import required.)
- **`UpdateAvailability`** — a sealed result: `UpdateAvailable(VersionManifest manifest)` | `UpToDate()` | `CheckFailed()` (the last is the **silent** branch — the UI shows nothing).

Repository interface (`domain/repositories/`):

```dart
abstract interface class AppUpdateRepository {
  Future<Result<UpdateAvailability>> checkForUpdate(); // never throws; CheckFailed on any error (FR-010)
}
```

Use case `CheckForUpdate` wraps the repository; `AppUpdateCubit` (presentation) calls it once on cold start and emits an `UpdateAvailable`/`UpToDate`/`CheckFailed` state; the dialog renders only on `UpdateAvailable` (R-211).

---

## 4. Per-FR → design element map

| FR | Where it lives | Verification |
|----|----------------|--------------|
| FR-001 signed 1.0.0 boots on fresh device | RB (signing) + `pubspec` version | SC-001 — install on wiped device/AVD |
| FR-002 final icon + light/dark splash | RB (`flutter_launcher_icons`/`flutter_native_splash`) | SC-001 — launcher + splash in both themes |
| FR-003 signing fails closed, key not committed | RB (`build.gradle.kts` + gitignored `key.properties`) | SC-001/SC-008 — build fails with no key; `git` shows no keystore |
| FR-004 capture errors → Sentry, behind logger seam | CR (`CrashReporter` + `main.dart` handlers) | SC-002 — forced exception on dashboard |
| FR-005 forced exception appears (dev build) | CR (profile/release-with-DSN) | SC-002 |
| FR-006 payload scrubbed of secrets/PII | CR (`beforeSend` — §2 scrub table) | SC-002 — inspect dashboard payload |
| FR-007 reporter non-blocking; domain SDK-free | CR (guarded init; seam in `core`, not `domain`) | SC-002/SC-008 — offline dashboard, app runs; grep domain |
| FR-008 cold-start check vs Supabase manifest | UP (`SupabaseManifestDatasource`) | SC-003 — manifest GET on cold start |
| FR-009 newer ⇒ localized Update/Later prompt | UP (`AppUpdateCubit` + `update_prompt_dialog`) | SC-003 — higher manifest ⇒ prompt + download |
| FR-010 unreachable/older ⇒ silent no-op | UP (`CheckFailed`/`UpToDate`) | SC-003 — offline/older ⇒ no prompt, no crash |
| FR-011 APK on Telegram + Play Store internal track | QV (distribution ops — R-216) | SC-005 |
| FR-012 release notes (+ recovery + baseline) | QV (`docs/release/v1.0.0.md`) | SC-006 |
| FR-013 six paths verified + carried-over fixed | QV (walks + test) + CF (fixes — R-215) | SC-004/SC-008 |
| FR-014 hybrid evidence (manual×6 + 1 test) | QV (`integration_test` + walks) | SC-004 |
| FR-015 new strings localized ar/en | UP (ARBs + `_DebugAppLocalizations`) | SC-007 |
| FR-016 new surfaces four-combination | UP (dialog) + RB (splash), Phase 2 tokens | SC-007 |
| FR-017 isClosed sweep | CF (3 sites + sweep) | SC-009 |
| FR-018 no new table/permission/iOS/Web; domain clean | all (no DB change; deps Android-only) | SC-008 |

## 5. Per-SC → evidence map

| SC | Evidence |
|----|----------|
| SC-001 | Install signed `1.0.0` on a wiped device + fresh AVD; boots to first screen; icon + splash correct light/dark; build fails closed without the key |
| SC-002 | Force a fatal error in a profile/release-with-DSN build; event on the Sentry dashboard within minutes; payload inspected — no secrets/PII |
| SC-003 | Manifest `latest_version` > installed ⇒ localized prompt + working download; manifest unreachable/malformed ⇒ no prompt, no crash |
| SC-004 | Six golden-path walks recorded (Infinix + AVD); the primary-publish `integration_test` green; maintenance two-device + push verified manually |
| SC-005 | APK retrievable from Telegram + installs on a fresh device; Play Store internal track shows the build to an enrolled tester |
| SC-006 | `docs/release/v1.0.0.md` covers the 6 results, install/update steps, the no-email recovery flow, the cold-start baseline, the APK secret-scan result |
| SC-007 | Update prompt renders correct in (light/dark)×(ar-RTL/en-LTR) on Infinix + a 412 dp AVD; no untranslated literal; tokens only |
| SC-008 | Structural check: version `1.0.0`; no new table/permission; crash+update wiring in `core/`+feature with no Supabase/Sentry import under any `domain/`; no iOS/Web; carried-over items closed |
| SC-009 | The previously-recurring "emit after close" errors no longer appear when the AdSlot/AgencyVerification/Profile navigations are exercised |
