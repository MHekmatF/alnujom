# Contract: Design Tokens API

**Status**: Phase 2 deliverable | **Spec**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md) | **Research**: [../research.md](../research.md) §R-01

## Purpose

Provide the only legitimate source of color, typography, spacing, radii, and elevation/shadow values used anywhere in the AlNujom Flutter app. Feature code MUST reach for these wrappers; reaching past them (raw hex, raw `TextStyle`, raw pixel padding) is forbidden by FR-007 and enforced by the lint guard contract (`lint-guard.md`).

## Surface (5 typed wrappers)

### `AppColors`

```
AppColors AppColors.of(BuildContext context)
```

Resolves through `Theme.of(context).colorScheme` plus extensions for project-specific tokens. The active `ColorPalette` (Modern or Trust) determines the primary quintet; the active `ThemeMode` determines light vs dark variants.

**Returned shape** (all `Color` values):

- Palette-specific: `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `accent`.
- Shared: `secondary`, `onSecondary`, `tertiary`, `success`, `warning`, `error`, `surface`, `surfaceVariant`, `card`, `outline`, `outlineStrong`, `onSurface`, `onSurfaceVariant`, `textMuted`.
- Convenience: `divider` (alias of `outline`), `disabledOverlay` (semi-transparent overlay used by disabled states).

### `AppTextStyles`

```
AppTextStyles AppTextStyles.of(BuildContext context)
```

Returns locale-correct `TextStyle` instances for every named role. The active locale determines the font family (Cairo / IBM Plex Sans Arabic for Arabic; Inter for Latin), per `decision.md` §"Typography".

**Returned roles**: `displayLarge`, `displayMedium`, `headlineLarge`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `labelLarge`, `labelMedium`, `priceLarge`, `priceMedium`.

### `AppSpacing`

```
abstract final class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 48;
}
```

Palette-agnostic. Locked from `screens-and-components.md` §2.4.

### `AppRadii`

```
abstract final class AppRadii {
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double pill = 999;
}
```

Palette-agnostic. Locked from `screens-and-components.md` §2.5 (research R-10 reconciles vs `decision.md`'s legacy scale).

### `AppElevation`

```
AppElevation AppElevation.of(BuildContext context)

class AppElevation {
  List<BoxShadow> get level0;          // none
  List<BoxShadow> get level1;          // cards at rest
  List<BoxShadow> get level2;          // floating bars, sticky CTAs
  List<BoxShadow> get level3;          // sheets, dialogs, FAB
  BoxBorder get hairline;              // dark-mode card delineation (1 px outline)
}
```

In light theme, `level{1,2,3}` return shadow lists with the values from `screens-and-components.md` §2.6. In dark theme, `level{1,2,3}` return `[]` and `hairline` returns a 1-px `outline`-coloured border (compensating for invisible shadows per `decision.md` §Elevation note).

## Invariants

1. Feature code (anything outside `lib/core/theme/` and `lib/core/widgets/`) MUST consume tokens exclusively through these five wrappers. The lint guard fails the build on:
   - Raw `Color(0x...)` literals.
   - Inline `TextStyle(` constructors.
   - Raw integer-literal padding/margin/radius arguments in `EdgeInsets`/`EdgeInsetsDirectional`/`BorderRadius` constructors.
2. `AppColors.of(context)` and `AppTextStyles.of(context)` MUST be cheap — O(1) per call — so widgets MAY call them per-frame without memoization concerns.
3. The `AppColors` returned for the same `(BuildContext, ColorPalette, Brightness)` combination MUST be value-equal across calls (so widget tests can assert exact-color expectations deterministically).
4. Adding a new token (color role, type style, radius step) MUST land in this contract first, then in the implementation file, then be consumed.

## Observable behaviors

- Switching the OS theme while `ThemeMode.auto` is active causes `AppColors.of(context)` to return the dark variants on the next frame. No rebuild beyond Flutter's standard `MediaQuery` rebuild path is required.
- Tapping the Palette Tester chip causes `AppColors.of(context)` to return the alternate palette's primary quintet within 240 ms (cross-fade timing owned by the chip's snackbar; tokens themselves switch atomically).
- In release builds, `AppColors.of(context)` always returns Modern-derived values regardless of any persisted `app.palette` value (FR-015 — `PaletteCubit` ignores reads in release).

## Test surface

- `test/core/theme/color_scheme_contrast_test.dart` — every text-token / background-token pair in all 8 (palette × theme × locale-agnostic) `ColorScheme`s passes WCAG AA ratios.
- `test/core/theme/color_palette_test.dart` — `ColorPalette.modern` and `ColorPalette.trust` resolve to the locked hex quintets in light + dark.
- Widget tests for individual components assert that their rendered colors / styles match `AppColors.of(context)` / `AppTextStyles.of(context)` outputs (no inline literals).

## Files (Phase 2 implementation)

- `lib/core/theme/colors.dart` — `AppColors` + `.of(BuildContext)`.
- `lib/core/theme/typography.dart` — `AppTextStyles` + `.of(BuildContext)`.
- `lib/core/theme/spacing.dart` — `AppSpacing`.
- `lib/core/theme/radii.dart` — `AppRadii`.
- `lib/core/theme/elevation.dart` — `AppElevation` + `.of(BuildContext)`.
- `lib/core/theme/color_palette.dart` — `ColorPalette` sealed class producing the 4 `ColorScheme`s consumed by `AppColors`.
- `lib/core/theme/app_theme.dart` — builds `ThemeData.light()` / `ThemeData.dark()` from a given `ColorPalette` + base `TextTheme` (locale-aware).
- `lib/core/theme/tokens_stub.dart` — **deleted** in Phase 2 (replaced by the files above).
