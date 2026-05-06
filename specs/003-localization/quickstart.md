# Phase 3 Quickstart — Localization

A reviewer (human or AI agent) verifies the Phase 3 deliverables end-to-end by running the steps below. The recipe is **manual UI verification only** on the Infinix Note 8 reference device — there are no automated tests in this phase. Each step maps to one or more functional requirements (FR) or success criteria (SC) from `spec.md`.

**Reference device**: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10 / 11) — per project memory.

**Estimated walkthrough time**: ~15 minutes for the golden path; ~25 minutes including the lint-guard sub-checks.

## Prerequisites

- The 003-localization branch is checked out.
- `flutter pub get` has succeeded.
- `flutter gen-l10n` has been run since the most recent ARB edit (regenerated files are checked in).
- The Infinix Note 8 is connected via USB with developer mode enabled and ADB authorized.
- A debug build of the app is available: `flutter run --debug -t lib/main.dart`.

---

## Step 1 — Fresh-install Arabic boot (FR-001, SC-001, SC-010)

1. On the device, open Settings → Apps → AlNujom → Storage → **Clear data**. (Or uninstall and re-install the debug APK; either fully resets the persisted locale.)
2. Launch the app from the launcher.
3. Observe the very first frame: every visible string is Arabic, the layout reads right-to-left (bottom-nav items right-to-left, back arrows pointing right, app-bar title leading-aligned to the right).
4. Confirm the app reaches the first usable screen within ~3 seconds (mid-tier device cold-start budget).

**Pass criteria**:
- ✅ No transient flash of English at first frame.
- ✅ No `key.like.this` placeholder anywhere on screen.
- ✅ App-bar title, locale toggle label, theme toggle label all read in Arabic.
- ✅ Cold-start to first usable screen ≤ 3 s.

**Fail signals**: any English string visible, any RTL chrome appearing left-aligned, any visible placeholder marker `⟦missing:...⟧` on the first screen.

---

## Step 2 — Toggle to English, walk through the UI (FR-002, FR-003, SC-002)

1. From the running Arabic app, tap the locale toggle in the app shell.
2. Observe: the entire visible screen rebuilds in English, layout flips to LTR (back arrow on the left, bottom-nav items left-to-right), within one frame — no spinner, no flicker.
3. Navigate to at least three other reachable screens (Theme Gallery if `kDesignToolsEnabled=true`, settings stub, any home stub). Confirm every label, button caption, and message on each is English.
4. Toggle back to Arabic. Confirm the reverse holds and no English string remains.

**Pass criteria**:
- ✅ Single-frame rebuild on toggle (no perceptible delay, no spinner).
- ✅ Zero pages remain in the previous language after toggling.
- ✅ Toggling back is symmetric.

---

## Step 3 — Persistence across cold restart (FR-007, SC-003, R-02)

1. With the app in English, force-stop it (Settings → Apps → AlNujom → Force stop). Or swipe-kill from the recent-apps tray.
2. Re-launch from the launcher.
3. Observe: the app boots straight into English with LTR layout — no transient Arabic flash.
4. Toggle to Arabic, force-stop again, relaunch — confirm Arabic persists.
5. Clear app data (as in Step 1), relaunch — confirm the Arabic default returns (Step 1's pass criteria apply again).

**Pass criteria**:
- ✅ English persists across a cold restart.
- ✅ Arabic persists across a cold restart.
- ✅ Wiping data resets to the Arabic default.

---

## Step 4 — Locale switch with a dialog / snackbar visible (FR-003 acceptance scenario 3)

1. Open any screen that exposes a snackbar or dialog (the Theme Gallery's debug surface is the easiest target while feature screens are sparse — surface a snackbar via the gallery's debug-controls section if available; otherwise use any error-state preview).
2. With the snackbar / dialog visible, tap the locale toggle.
3. Observe: the overlay's content rebuilds in the new language alongside the underlying screen — no overlay is left in the previous language.

**Pass criteria**:
- ✅ Overlay rebuilds in the new language on toggle.
- ✅ No "stale overlay" with old-language text remains.

If no snackbar / dialog is currently reachable in the Phase 3 surface (because feature screens land in later phases), record this step as **deferred** in the PR and re-run during the first phase that ships a dialog-bearing screen.

---

## Step 5 — Bilingual font stack honors the active locale (FR-014)

1. With the app in Arabic, open the Theme Gallery (debug build). Inspect the typography section.
2. Confirm: titles render in Cairo, body / labels render in IBM Plex Sans Arabic. Both are visibly Arabic-script families.
3. Toggle to English. Confirm: the same surfaces now render in Inter (Latin sans-serif, distinctly different glyph shapes from Cairo).
4. Toggle back to Arabic; confirm Cairo / IBM Plex Sans Arabic returns.

**Pass criteria**:
- ✅ Arabic-script families resolve when locale = `ar`.
- ✅ Inter resolves when locale = `en`.
- ✅ No system-default fallback font appears in either locale.

---

## Step 6 — Form input preservation across locale switch (FR-015, SC-009, R-08)

1. Open any form-bearing screen reachable in the Phase 3 surface. (If none ships in Phase 3, build a temporary debug form by adding a `TextField` to the Theme Gallery — record this as a temporary scaffold and remove before merge. Otherwise re-run this step in the first phase that ships a real form.)
2. Type a few characters into the field. Do NOT submit.
3. Toggle the locale.
4. Observe: the field's user input is preserved verbatim. Only the field's label, placeholder, helper text, and any visible validation message change language.

**Pass criteria**:
- ✅ Typed input is unchanged after the toggle.
- ✅ Surrounding labels / placeholders / helper text re-render in the new language.

---

## Step 7 — Missing-translation runtime marker (FR-008, SC-006, contract `app-strings.md`)

1. In `lib/l10n/app_en.arb`, add a temporary new entry (e.g., `"_temp_missing_ar_key": "TEST"`).
2. Do NOT add the matching entry to `lib/l10n/app_ar.arb`.
3. Reference the key from a temporary debug widget under `lib/debug/` (e.g., `Text(AppStrings.of(context).loc._temp_missing_ar_key)` once gen-l10n regenerates).
4. Run `flutter gen-l10n` to regenerate the typed Dart bindings.
5. Run a debug build on the device. Navigate to the Theme Gallery (or wherever the temporary widget is mounted).
6. Observe: the rendered string is wrapped in the visible marker `⟦missing:_temp_missing_ar_key⟧`, AND the device log shows a warning entry `[AppStrings] Missing ar translation for key: _temp_missing_ar_key`.
7. Run `dart run tool/lint_l10n_parity.dart`. Observe exit code 1 with `_temp_missing_ar_key` listed under "Missing in lib/l10n/app_ar.arb".
8. Restore parity by adding the Arabic entry. Re-run `flutter gen-l10n` and the parity script. Observe exit code 0 and the marker disappearing.
9. Remove the temporary entry from both ARB files and from the debug widget before merging.

**Pass criteria**:
- ✅ Visible `⟦missing:...⟧` marker on screen in debug.
- ✅ Warning log entry naming the missing key.
- ✅ Parity script exits non-zero on the gap and zero after restoration.

---

## Step 8 — Literal-string lint guard catches a regression (FR-006, SC-004, contract `lint-guard-literals.md`, Q1 clarification)

1. Add a temporary line `Text("hello world")` to any file anywhere under `lib/` that is NOT on the lint exemption list (e.g., `lib/shell/app_shell.dart` or any future feature file). Save.
2. Run `dart run tool/lint_l10n_literals.dart`. Observe exit code 1 and a report line of the form `path/to/file.dart:LINE:COL: literal "hello world" passed to Text() — replace with AppStrings.of(context).loc.<key>`.
3. Replace the literal with `AppStrings.of(context).loc.<some-existing-key>`. Re-run. Observe exit code 0.
4. Add a temporary `Text("only on the gallery")` literal inside `lib/debug/theme_gallery_page.dart` (which IS on the exemption list). Re-run. Observe exit code 0 — the exemption list correctly suppresses the literal.
5. Remove the temporary literal from the gallery file before merging.

**Pass criteria**:
- ✅ Lint guard fails on a non-exempt literal.
- ✅ Lint guard passes when the literal is replaced with an `AppStrings` lookup.
- ✅ Lint guard ignores literals in exempt files (Theme Gallery, generated localization files, ARB files, golden test fixtures).

---

## Step 9 — ARB parity check against an intentionally-broken state (FR-005, SC-005, contract `lint-guard-parity.md`)

1. Temporarily delete the `localeToggleLabel` entry from `lib/l10n/app_en.arb` (do NOT touch `app_ar.arb`).
2. Run `dart run tool/lint_l10n_parity.dart`. Observe exit code 1 and a report listing `localeToggleLabel` under "Missing in lib/l10n/app_en.arb".
3. Restore the entry. Re-run. Observe exit code 0 and the success line `Translation key parity check passed (N keys).`.

**Pass criteria**:
- ✅ Parity script fails on missing-in-en gap.
- ✅ Parity script passes after restoration.

---

## Step 10 — Visual no-regression check on the existing PropertyCard surfaces (SC-007)

The Phase 2 `PropertyCard` golden suite is preserved unchanged but is **not required to run** as part of Phase 3 acceptance (per the durable no-new-tests rule and Q3 wording). This step is a **manual side-by-side review** instead.

1. Navigate to the Theme Gallery's PropertyCard preview section. Note the visual rendering at light × ar.
2. Toggle the locale to en (light × en); observe.
3. Toggle the theme to dark (dark × en); observe.
4. Toggle the locale back to ar (dark × ar); observe.
5. Mentally compare against the pre-Phase 3 baseline (which Phase 2 reviewers signed off on). Confirm: no visible regression in the PropertyCard surface — no new clipping, no font-stack flicker, no alignment shift.

**Pass criteria**:
- ✅ All four combinations look the same as the Phase 2 sign-off.
- ✅ No visible regression introduced by Phase 3 wiring.

If a regression IS detected, treat it as a Phase 3 defect — wire up the fix and re-walk this step before merging.

---

## Final sign-off

When all 10 steps pass:

1. Run BOTH lint scripts one final time on a clean tree to confirm green:
   - `dart run tool/lint_l10n_literals.dart` → exit 0.
   - `dart run tool/lint_l10n_parity.dart` → exit 0.
2. Confirm CI is green for the same commit (same two scripts run; `flutter test` is intentionally absent).
3. Update the spec's `## Status` line from `Draft` to `Implemented`, or open the PR per the durable git-workflow contract (one PR per spec).

**You are done with Phase 3.**

---

## Outstanding (low-impact, intentionally deferred)

These were called out during `/speckit-clarify` as Outstanding but low-impact; they are NOT acceptance gates for Phase 3 and do not need verification here:

- **Screen-reader (TalkBack) announcement on locale toggle** — accessibility polish; properly owned by Phase 23 (App Settings) when it builds the production-quality locale surface.
- **Locale-write failure UX** — the existing `LocaleCubit` log-and-swallow behavior is the documented MVP default; surfacing a toast on persistence failure is a Phase 23 enhancement.
