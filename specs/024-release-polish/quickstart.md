# Quickstart — Phase 24 Release verification recipe

A reviewer/operator validates Phase 24 end-to-end with this recipe. It assumes CR + UP + RB + CF are merged and a release build is producible. Every `flutter run`/`build` includes `--dart-define-from-file=.env.json` (memory `project_dart_defines`); for crash testing, `.env.json` carries a non-empty `SENTRY_DSN`.

## A. Build & boot (SC-001 / FR-001–003)

1. Confirm `pubspec.yaml` `version: 1.0.0+N`.
2. Place the release keystore outside the repo + `android/key.properties` (gitignored). Build the signed release:
   `flutter build apk --release --dart-define-from-file=.env.json`
3. **Fail-closed check**: temporarily remove `key.properties` → `flutter build apk --release` **must fail** (no debug-signed artifact). Restore it.
4. Install the signed APK on a **wiped** device + a **fresh** Pixel 8 Pro AVD profile (no prior app data). Confirm it boots to the first usable screen; confirm the final **launcher icon** (adaptive) and **splash** in **light and dark**; confirm **no** debug banner / palette tester.
5. `git status` / `git ls-files` → confirm **no** keystore, `key.properties`, or DSN committed.

## B. Crash reporting (SC-002 / FR-004–007)

6. Run a **profile** build with the DSN set: `flutter run --profile --dart-define-from-file=.env.json`.
7. Trigger a forced uncaught exception (a temporary debug-only trigger or a test hook). Confirm the event lands on the **Sentry** dashboard within minutes with a usable stack trace.
8. **Inspect the payload**: confirm **no** synthetic-email/phone, **no** Vault material, **no** decrypted PII, **no** tokens (data-model §2 scrub).
9. **Non-blocking check**: point the DSN at an unreachable host (or go offline) and relaunch → the app starts + runs normally (no block, no crash). Set DSN empty → confirm `NoopCrashReporter` (no init, app fine).

## C. Update prompt (SC-003 / FR-008–010)

10. Upload a manifest to Supabase Storage with `latest_version` **higher** than installed (e.g. `1.1.0`). Cold-start → confirm the **localized** update prompt with **Update** (opens Telegram) + **Later** (dismiss for session); re-cold-start → prompt re-appears.
11. Set `latest_version` **equal/older** → cold-start → **no** prompt.
12. Make the manifest **unreachable / malformed** → cold-start → **no** prompt, **no** crash (silent no-op).
13. Render the prompt in all four (light/dark)×(ar-RTL/en-LTR) combinations on the Infinix Note 8 + a 412 dp AVD (SC-007) — all strings localized, tokens only.

## D. Six golden paths (SC-004 / FR-013–014)

14. **Automated**: run the primary-publish integration test —
    `flutter test integration_test/primary_publish_path_test.dart --dart-define-from-file=.env.json` → green.
15. **Manual walks** (Infinix + AVD), record each: (1) register→approve→publish→approve→view→inquiry; (2) anonymous browse+filter+map; (3) admin reports-queue resolution; (4) super-admin role create+assign+revoke; (5) currency switch + exchange-rate update; (6) **maintenance mode + recovery (two-device)**.
16. **Push** (if push-enabled): verify delivery + deep-link manually; otherwise confirm the six in-app notifications deliver with push blocked, no crash (Phase 22 T045).

## E. Carried-over fixes (SC-009 / FR-017 + R-215)

17. Exercise the AdSlot / AgencyVerification / Profile navigations with fast back-navigation mid-load → confirm **no** "emit after close" errors in the log/crash stream.
18. Open an approved agency with a logo → confirm the **logo renders** (no broken-image placeholder — the double-prefix is fixed).

## F. Distribution & docs (SC-005 / SC-006 / FR-011–012)

19. Confirm the signed APK is **downloadable from Telegram** and installs on a fresh device; confirm the **Play Store internal track** shows `1.0.0` to an enrolled QA tester.
20. **APK secret-scan**: binary-scan the signed APK → confirm no DSN/keystore/Vault/FCM-service-account material shipped (Phase 22 T046).
21. Open `docs/release/v1.0.0.md` → confirm it covers the 6 golden-path results, install/update steps, the **no-email account-recovery** flow, the **cold-start baseline**, and the secret-scan result.

## G. Structural gate (SC-008 / FR-018)

22. Confirm: version `1.0.0`; **no** new table/RPC/permission/migration; crash + update wiring in `core/` + `lib/features/app_update/` with **no** `supabase_flutter`/`sentry_flutter`/`package_info_plus` import under any `domain/`; **no** iOS/Web code or non-Android-only plugin; the three carried-over buckets closed (D-1/2/3 verified; FE-1 left future); `flutter analyze` + the full lint suite clean.
