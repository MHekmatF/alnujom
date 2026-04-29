# Quickstart: Project Foundation (Phase 1)

**Branch**: `001-project-foundation` | **Date**: 2026-04-28
**Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

This is the end-to-end recipe a reviewer (or a fresh AI agent) follows to verify Phase 1 is "done" against `spec.md`. The smoke-test steps map directly to the acceptance scenarios for User Stories 1, 2, 3 and Success Criteria SC-001 through SC-005.

> **Note**: as of this plan's date, the implementation has NOT been written. This file documents the verification path that the implementation MUST satisfy when it lands. The Phase 2 `/speckit-tasks` command and the Phase 3 `/speckit-implement` command will refer to this file.

---

## 0. Prerequisites (one-time)

Install on the workstation:

| Tool | Version | Why |
|---|---|---|
| Flutter SDK | **3.35.2** (per `pubspec.yaml`'s `environment.flutter`) | Pinned for CI / local parity; bump only via a PR that updates `pubspec.yaml` |
| Android SDK | API 24 minSdk + a current API for `targetSdk` | minSdk floor (spec Clarification Q1) |
| Java | 17 (Temurin) | Gradle toolchain |
| Supabase CLI | latest | Local backend; `supabase init`/`supabase start` |
| Docker Desktop | latest | Required by the Supabase CLI for the local Postgres (becomes mandatory at Phase 4 when application tables and RLS land; not required for Phase 1 verification) |

Confirm:

```bash
flutter --version            # 3.x stable
flutter doctor               # all checks green for Android; iOS/Web warnings are EXPECTED and acceptable
adb devices                  # at least one emulator OR connected Android device
supabase --version
docker --version
```

---

## 1. Clone and configure

```bash
git clone <repo>
cd alnujom-project
git checkout 001-project-foundation     # or wherever the branch lands
```

Create `.env.json` in the repo root (gitignored — confirm with `git check-ignore .env.json`):

```json
{
  "SUPABASE_URL":      "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "<paste-from-`supabase start`-output>"
}
```

If you want to verify the FR-013 graceful-degradation path (shell still launches when config is missing), use placeholder values like `""` and observe the launch warning.

---

## 2. Install dependencies + run codegen

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The build_runner step generates `lib/core/di/injection.config.dart`; this file is committed (research.md Decision 4) — running build_runner just keeps it in sync with annotations.

---

## 3. Start the local Supabase project (optional for Phase 1)

Phase 1's shell launches with or without backend connectivity (FR-013). If you want a "happy path" run anyway:

```bash
supabase start
```

This applies `supabase/migrations/00000000000000_init_extensions.sql` (enables `pgcrypto` + `uuid-ossp`) and prints the local API URL and anon key. Paste those into `.env.json`.

Stop later with `supabase stop`.

---

## 4. Run the app on an emulator

Start an Android emulator (any device profile sized at API 24+):

```bash
flutter emulators --launch <emulator-id>
```

Then run the app:

```bash
flutter run --dart-define-from-file=.env.json
```

Or for a strict reproduction of `flutter build apk --debug` (closer to CI):

```bash
flutter build apk --debug --dart-define-from-file=.env.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.alnujom.app/.MainActivity   # adjust package as configured in android/
```

**Expected**: the AlNujom shell renders. Brand mark is visible. Two toggle controls are visible on the screen — one for theme, one for locale. Debug-console output shows the DI configuration log line.

---

## 5. Verify acceptance scenarios

### User Story 1 — "Runnable AlNujom Android shell from a clean clone" (P1)

1. ✅ **AS-1.1** — From the steps above, the app launches without crashes. The debug console shows no errors.
2. ✅ **AS-1.2** — Rotate the emulator (`Ctrl+→` / `Ctrl+←`) twice. The shell re-renders without losing visual state. Background the app (`Home` button) and resume — same outcome.
3. ✅ **AS-1.3** — Edit `.env.json` to set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to `""`. Rebuild and run via `flutter run --dart-define-from-file=.env.json`. The shell still launches; the **`flutter run` terminal** contains a warning line tagged `SupabaseClientWrapper` saying "Backend configuration missing or invalid; continuing without backend." No crash dialog. (The warning is emitted via `dart:developer.log`, which is captured by `flutter run` and DevTools — *not* by `adb logcat`. If you launch the installed APK with `am start` and run `adb logcat` you will not see it; that is by design.)

### User Story 2 — "Theme switching scaffolding works end-to-end" (P2)

1. ✅ **AS-2.1** — Tap the theme toggle once. Within one frame, the shell flips between light and dark. All visible chrome (background, brand text color, toggle button styles) updates consistently — no half-themed elements.
2. ✅ **AS-2.2** — Force-stop the app via `adb shell am force-stop com.alnujom.app` and relaunch. The shell launches in the most recently selected theme.

### User Story 3 — "Locale switching scaffolding with RTL/LTR mirroring" (P3)

1. ✅ **AS-3.1** — On a fresh install (`adb shell pm clear com.alnujom.app && adb shell am start -n com.alnujom.app/.MainActivity`), the shell launches in Arabic with a right-to-left layout. Confirmed: brand text is rendered RTL; the theme toggle sits on the right edge of the screen, locale toggle on the left.
2. ✅ **AS-3.2** — Tap the locale toggle. Within one frame, the shell switches to English with LTR layout — toggles flip to the opposite edges; visible placeholder strings change from `الموضوع` / `اللغة` (or whatever the placeholder ARB keys hold) to `Theme` / `Locale`.
3. ✅ **AS-3.3** — Force-stop and relaunch. The app launches in the most recently selected locale and direction.

### Edge cases

- ✅ **Backend config invalid**: covered by AS-1.3.
- ✅ **Rapid toggle**: tap the theme toggle 10 times in 2 seconds. Final state matches the last tap; no visual flicker after the burst stops; secure storage contains exactly one persisted value.
- ✅ **Storage denied**: simulate by pre-empting `flutter_secure_storage` reads in a test (the secure-preferences-store unit test covers this). Manual repro on device is impractical and not required.
- ✅ **OS theme change with no in-app selection**: install fresh, change Android system theme via Quick Settings — the app reflects it (FR-016 "follow system before first toggle").
- ✅ **OS theme change with an in-app selection**: select dark in-app, then change system theme to light via Quick Settings — the app stays dark (FR-016 "lock after first toggle").
- ✅ **OS locale change**: change device system language. The app stays on its in-app locale (FR-005).

---

## 6. Run the smoke test (FR-012)

```bash
flutter test
```

**Expected**: all tests pass. The smoke test is a widget test under `test/widgets/shell_smoke_test.dart` (NOT under `integration_test/`), so it runs as part of the default `flutter test` command and therefore in CI without needing an Android emulator. Output mentions:

- `result_test.dart`
- `console_logger_test.dart`
- `theme_cubit_test.dart`
- `locale_cubit_test.dart`
- `secure_preferences_store_test.dart`
- `shell_home_page_test.dart` (brand-renders widget test)
- `shell_smoke_test.dart` (FR-012 smoke: boots `App()`, taps theme toggle, taps locale toggle, asserts `Directionality.of(context)` flipped after the locale tap)

---

## 7. CI verification (FR-015)

Push the branch (or open a PR). The GitHub Actions `verify` workflow MUST run and pass within ~10 minutes. Confirm:

- ✅ `dart format` succeeds (no diff)
- ✅ `flutter analyze --fatal-infos` passes
- ✅ Constitution-IX guard passes: no `package:supabase_flutter` imports outside `supabase_client_wrapper_impl.dart`
- ✅ `flutter test` passes (this includes the FR-012 smoke widget test)
- ✅ `flutter build apk --debug` succeeds with placeholder env values
- ✅ The PR status check shows `verify / verify (pull_request)` green

A failed CI run SHOULD block merge per FR-015. The mechanism that enforces this is GitHub branch protection — `verify` set as a required status check on `main` via GitHub Settings → Branches. That branch-protection rule lands as **task T061 in the Polish phase**, not as part of this PR's verification recipe. Until T061 lands, a maintainer technically *can* merge a red PR — the FR-015 requirement is satisfied by the workflow existing and posting status; T061 is the post-merge follow-up that closes the gate.

For this PR's verification recipe, "CI green" is enough. Branch protection is verified separately when T061 runs.

---

## 8. Hardware verification (SC-002 — primary device)

On the **Infinix Note 8** (or an equivalent Helio G80-class device with 4–6 GB RAM on API 24+):

1. Connect via USB; confirm `adb devices` shows it.
2. Build + install a **profile** APK:

   ```bash
   flutter build apk --profile --dart-define-from-file=.env.json
   adb install -r build/app/outputs/flutter-apk/app-profile.apk
   ```

   Profile mode is required (not debug). A debug APK ships JIT-compiled Dart bytecode plus assertions; its cold-start time is ~1.5–2× the user-installed app and is not a meaningful proxy for SC-002, which is about user-visible startup of the app a real user would install. Release mode is closer still but lacks the instrumentation needed for diagnostics; profile is the standard Flutter benchmark mode.
3. Cold-launch the app (force-stop, then `am start`) 20 times. Use `adb shell am start -W` to capture `WaitTime` (interactive-ready) — not `TotalTime`, which can include first-frame paint.
4. Compute the 95th percentile of `WaitTime`. Expected: ≤ 3000 ms (SC-002).
5. Toggle theme + locale 20 times each, force-stop and relaunch each time, confirm 100% restore (SC-003).

Capture results in the PR body or a `verification.md` for the reviewer's record.

---

## 9. Final gate before declaring "done"

The reviewer (human or `/review` agent) confirms:

- [ ] Spec acceptance scenarios AS-1.x, AS-2.x, AS-3.x all pass on emulator
- [ ] Smoke test green on emulator
- [ ] CI green on the PR
- [ ] Hardware run on Infinix Note 8 meets SC-002 and SC-003
- [ ] `flutter analyze` clean; no `print(...)` in `lib/`; no `package:supabase_flutter` imports outside the wrapper
- [ ] No product feature reachable from the shell (SC-005); a 5-minute manual exploration finds only the brand mark + two toggles
- [ ] WCAG 2.1 AA spot-check: enable TalkBack, navigate the shell, hear meaningful labels for both toggles; bump system font size to 130%, confirm no truncation; sample contrast on toggles ≥ 4.5:1 (FR-017)

When all boxes are checked, Phase 1 is shippable. The natural next step is `/speckit-tasks` to generate the dependency-ordered task list, then `/speckit-implement` to actually write the code.
