# Quickstart: Design System & Theme Tokens

**Phase**: 002 — Design System & Theme Tokens | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

This is the end-to-end recipe a reviewer (human or AI) runs to validate that Phase 2 has actually landed correctly. Each step has a clear pass / fail signal. Run on the **Infinix Note 8** reference device (Helio G80, 6 GB RAM, Android 10/11) — that is the device performance and visual sign-off are measured against.

## Prerequisites

- A working Flutter installation matching the version pinned in `pubspec.yaml` / `flutter_version` file.
- The `002-design-system` branch checked out, latest pull, no local diverged work.
- `adb` reachable; the reference device connected via USB with developer mode + USB debugging on, OR a host emulator with the equivalent screen density.
- Phase 1 has already landed (`tokens_stub.dart` exists in `lib/core/theme/` and the app boots — Phase 2 deletes the stub).

## 1. Install dependencies

```bash
flutter pub get
```

**Pass signal**: completes with no resolution conflicts; `pubspec.lock` matches checked-in version.

## 2. Run debug build on the reference device

```bash
flutter run --debug --dart-define=DESIGN_TOOLS=true
```

**Pass signal**: app launches to the Phase 1 shell home with the new typography + Modern palette visibly applied (no Phase 1 stub colors left). The Palette Tester chip is visible in the top-leading corner.

## 3. Reach the Theme Gallery

In the running debug app, navigate to `/_debug/theme-gallery` (via the debug navigation entry exposed at this phase, or by typing the route into the debug router console).

**Pass signal**: Theme Gallery page opens; the three switcher pills (locale, theme, palette) sit at the top; component sections scroll below.

## 4. Visual sweep — 8 environment combinations

For each combination of:

- Locale: `ar`, `en`
- Theme: `light`, `dark`
- Palette: `Modern`, `Trust`

…toggle to that combination via the Theme Gallery switchers AND scroll through every component section. Watch for:

- Clipped text or overflow.
- Untranslated strings or `key.like.this` placeholders.
- Wrong-direction padding (e.g., back arrow on the wrong side under `ar`).
- Missing component states (a button without a `loading` example, etc.).
- Color-only state signaling (badge that loses meaning if you turn it grayscale).

**Pass signal**: all 8 combinations render cleanly with no clipping, no untranslated strings, all states visible.

## 4b. System text-size sweep (SC-008)

Without leaving the Theme Gallery, change the Android system text size to **130 %** (Settings → Display → Font size), return to the app, and scroll the gallery again. Repeat at **200 %**.

**Pass signal**: at 130 % and at 200 %, every component still renders without clipped text, layout overflow, horizontal scroll, or `RenderFlex overflowed` exceptions. Touch targets remain ≥ 48 × 48 dp at all scales.

## 5. Palette Tester smoke

While on a non-gallery screen (e.g., the Phase 1 shell home), tap the Palette Tester chip.

**Pass signal**: the entire visible UI cross-fades from Modern's `#1D4ED8` to Trust's `#2457A6` (light theme) or `#9FC5FF` (dark theme) within ~240 ms. A snackbar at the bottom confirms `"Trust"`. Tap again → cross-fade back to Modern, snackbar `"Modern"`.

Then **kill the app** (swipe from recents) and relaunch via `adb shell am start ...`:

**Pass signal**: app reopens with the last-selected palette still active.

## 6. Run the test suite

```bash
flutter test
```

**Pass signal**:

- All component widget tests (`test/core/widgets/*_test.dart`) pass.
- `PropertyCard` golden suite (`test/widgets/property_card_golden_test.dart`) passes — 4 goldens match (`light_ar.png`, `light_en.png`, `dark_ar.png`, `dark_en.png`).
- WCAG floor test (`test/core/theme/color_scheme_contrast_test.dart`) passes for all (palette × theme) combinations.
- `ThemeCubit` tests (`test/core/theme/theme_cubit_test.dart`) pass including the `auto`-mode + live-OS-theme-flip case.
- `PaletteCubit` tests (`test/core/theme/palette_cubit_test.dart`) pass including the cycle and persistence cases.
- Lint integration test (`test/lint/design_tokens_lint_test.dart`) passes.

## 7. Run the design-token lint guard

```bash
dart run tool/lint_design_tokens.dart
```

**Pass signal**: exit code `0`, no output on stdout.

Then **deliberately** introduce a violation:

```bash
echo 'final c = Color(0xFFAA0000);' >> lib/shell/shell_home_page.dart
dart run tool/lint_design_tokens.dart ; echo "exit: $?"
git checkout -- lib/shell/shell_home_page.dart
```

**Pass signal** (deliberate-violation run): exit code `1`; stdout names `lib/shell/shell_home_page.dart` with the line and the offending pattern.

## 8. Tree-shake assertion (release build)

```bash
flutter build apk --release
flutter build apk --release --analyze-size
```

(Or extract the resulting APK and grep for the gallery route string.) Note: release builds omit `--dart-define=DESIGN_TOOLS=true`, so `kDesignToolsEnabled` defaults to `false` and tree-shakes both the chip and the gallery together.

**Pass signal**:

- `--analyze-size` output does NOT list `theme_gallery_page.dart` or `palette_tester.dart` under reachable code.
- Searching the unpacked APK for the literal route `_debug/theme-gallery` returns no hits.
- Installing the release APK, opening the app, and trying to navigate to `/_debug/theme-gallery` results in the router's "no route" handler (404 / fallback).

## 9. WCAG sign-off on the reference device

On the Infinix Note 8, with the Android system contrast checker (or a third-party AA-checker app):

- One Modern light screen (e.g., the Phase 1 shell home) → measure contrast on body text and primary button label → expect ≥ 4.5 : 1 and ≥ 3 : 1 respectively.
- One Trust dark screen (toggle Palette Tester to Trust + Theme Gallery switcher to dark) → repeat the measurements.

**Pass signal**: every measured pair clears the WCAG AA floor.

## 10. Performance sanity

Run a quick scroll test in `flutter run --profile`:

```bash
flutter run --profile --dart-define=DESIGN_TOOLS=true
```

In the running profile build, navigate to the Theme Gallery, scroll through the long components list with a fling.

**Pass signal**: DevTools Performance overlay shows no skipped frames during the scroll; rasterizer time stays under 16 ms; no memory growth between flings.

## What to report

After the recipe runs:

- ✅ All 10 steps passed → Phase 2 is verifiable; advance to `/speckit-tasks`.
- ❌ Any step failed → file the failure under the spec's relevant FR / SC, then either fix in this branch or open a follow-up task. Drift between the spec and the running build is a Constitution X violation.

## Appendix: full command sequence (CI-friendly)

```bash
flutter pub get
flutter analyze
dart run tool/lint_design_tokens.dart
flutter test
flutter build apk --debug --dart-define=DESIGN_TOOLS=true
flutter build apk --release
```

The CI workflow (`.github/workflows/ci.yml`) executes the first four lines on every push; the release-APK build is part of release polish (Phase 24).
