# Contract: `PaletteCubit`

**Status**: Phase 2 deliverable — new in Phase 2 | **Spec**: [../spec.md](../spec.md) FR-009, FR-015 | **Plan**: [../plan.md](../plan.md) | **Research**: [../research.md](../research.md) §R-06, §R-07

## Purpose

Expose the active `ColorPalette` (`Modern` or `Trust`) to the widget tree. In debug / internal-QA builds the cubit reflects the user's most-recent Palette Tester chip selection and persists it. In release builds the cubit is pinned to `Modern` and ignores all transition requests (FR-015).

## Surface

```
class PaletteCubit extends Cubit<ColorPalette> {
  PaletteCubit({required PreferencesStore store, required AppLogger log});

  /// Loads the persisted choice in debug builds, or pins to Modern in release. Idempotent.
  Future<void> initialize();

  /// Cycle to the alternate palette (Modern → Trust → Modern).
  /// In release builds this is a no-op (FR-015).
  Future<void> cycle();
}

sealed class ColorPalette {
  ColorScheme lightScheme();
  ColorScheme darkScheme();
}

class ModernPalette extends ColorPalette { /* primary #1D4ED8 / #60A5FA */ }
class TrustPalette extends ColorPalette { /* primary #2457A6 / #9FC5FF */ }
```

## States

- `ModernPalette` (default, locked in release — FR-015).
- `TrustPalette` (debug/QA only).

## Transitions

```
initialize()
  if (kDesignToolsEnabled)
    read PreferencesStore[app.palette]
      → emit(ColorPalette.fromName(value)) // 'modern' | 'trust'
      → if missing, emit(ModernPalette)
  else
    emit(ModernPalette)                     // FR-015 — release pin

cycle()
  if (kDesignToolsEnabled)
    next = (current == ModernPalette) ? TrustPalette() : ModernPalette()
    persist PreferencesStore[app.palette] = next.name
    emit(next)
  else
    no-op (FR-015) // optionally log a warning at debug-assert level
```

## Invariants

1. **Release pin (FR-015)**: When `kPaletteTesterEnabled` (or the parallel `kDesignToolsEnabled`) is `false` at compile time, `state` MUST always be `ModernPalette`. `cycle()` MUST be a no-op. `PreferencesStore[app.palette]` MUST not be read.
2. **Tree-shake guarantee**: Because the `if (kDesignToolsEnabled)` branch is gated by a `const bool`, Dart's tree-shaker drops the persistence + cycle code paths from release bundles entirely (research R-07).
3. After `initialize()`, `state` is non-null and is a valid `ColorPalette` subclass — never indeterminate.
4. The cubit MUST NOT depend on `BuildContext` or `MediaQuery`.
5. Two consecutive `cycle()` calls MUST return to the original palette (the cycle is involutive at length 2).

## Persistence

- Key: `app.palette` (defined in `lib/core/storage/preferences_keys.dart`).
- Serialization: lowercased palette name (`'modern'` / `'trust'`).
- Read: only in debug/QA builds, only inside `initialize()`.
- Write: only in debug/QA builds, on every successful `cycle()`.
- On read, an unknown / corrupt value MUST be treated as `'modern'` (with a warning logged via `AppLogger`).

## Observable behaviors

- **Debug build, fresh install**: cubit emits `ModernPalette`. Tapping the Palette Tester chip emits `TrustPalette` and persists `'trust'`. Tapping again returns to `ModernPalette`.
- **Debug build, after restart with `'trust'` persisted**: cubit emits `TrustPalette` on `initialize()` — palette choice survives reload (US3 acceptance criterion 2).
- **Release build, regardless of any persisted value**: cubit emits `ModernPalette`. `cycle()` is a no-op. Palette never changes for end users.
- **Cross-fade timing (240 ms)**: owned by the chip's tap-feedback animation in `palette_tester.dart`, not the cubit. The cubit emits the new state synchronously; the chip drives the visual transition.

## Test surface (`test/core/theme/palette_cubit_test.dart`)

All tests run with `kDesignToolsEnabled = true` unless explicitly testing the release pin.

- `initialize()` with no persisted value → emits `ModernPalette`.
- `initialize()` with `'trust'` persisted → emits `TrustPalette`.
- `initialize()` with `'corrupted'` persisted → emits `ModernPalette`, logs warning.
- `cycle()` from `ModernPalette` → emits `TrustPalette`, store now `'trust'`.
- `cycle() × 2` → returns to `ModernPalette`, store now `'modern'`.
- (Compile-time guard) When `kDesignToolsEnabled = false`, `cycle()` is a no-op and `state` stays `ModernPalette` regardless of any direct `PreferencesStore` write — verified via a separate test build target or a runtime shim that mirrors the compile-time const.

## Dependency on Phase 1

Reuses `PreferencesStore` and `AppLogger` from Phase 1 unchanged. Adds two new keys to `lib/core/storage/preferences_keys.dart` (`app.theme_mode`, `app.palette`).
