# Contract: `ThemeCubit` (extended)

**Status**: Phase 2 deliverable — extends a Phase 1 cubit | **Spec**: [../spec.md](../spec.md) FR-016 | **Plan**: [../plan.md](../plan.md) | **Research**: [../research.md](../research.md) §R-08

## Purpose

Hold the user's persisted theme-mode choice (`auto` / `light` / `dark`) and project it into a `ThemeMode` value `MaterialApp.router` consumes. While the choice is `auto`, the rendered theme follows the OS theme live without app restart (FR-016).

## Surface

```
class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit({required PreferencesStore store, required AppLogger log});

  /// Loads the persisted choice (or `auto` if unset) and emits it. Idempotent.
  Future<void> initialize();

  /// User picked a new mode in Settings. Persists and emits.
  Future<void> setMode(AppThemeMode mode);
}

enum AppThemeMode { auto, light, dark }
```

`MaterialApp.router` reads `state` and maps:

| `state` | `MaterialApp.themeMode` |
|---|---|
| `auto` | `ThemeMode.system` |
| `light` | `ThemeMode.light` |
| `dark` | `ThemeMode.dark` |

Flutter's framework handles the OS-theme live-update path under `ThemeMode.system` automatically — no explicit listener inside the cubit (research R-08).

## States

- `auto` (default on first launch — FR-016).
- `light`.
- `dark`.

## Transitions

```
initialize() reads PreferencesStore[app.theme_mode] → emit(auto | light | dark)
                                                     → if missing, emit(auto)
setMode(m)  → persist PreferencesStore[app.theme_mode] = m
            → emit(m)
```

## Invariants

1. After `initialize()` completes, `state` is one of the three enum values — never null, never indeterminate.
2. `setMode()` MUST persist before emitting so a synchronous app restart sees the new value.
3. `setMode(state)` (no-change call) is a no-op (no persist write, no emit).
4. The cubit MUST NOT depend on `BuildContext`, `MediaQuery`, or `WidgetsBinding` — OS-theme observation lives in `MaterialApp` via `ThemeMode.system` (research R-08).

## Persistence

- Key: `app.theme_mode` (defined in `lib/core/storage/preferences_keys.dart`).
- Serialization: enum name (`'auto'` / `'light'` / `'dark'`).
- Read: `initialize()` once at app start.
- Write: every `setMode()` call where the value changes.
- On read, an unknown / corrupt value MUST be treated as `auto` (with a warning logged via `AppLogger`).

## Observable behaviors

- **Fresh install**: app boots, `ThemeCubit` emits `auto`, `MaterialApp.themeMode` is `system`, theme follows OS — FR-016 first-launch clause satisfied.
- **User picks "Dark" in Settings**: `setMode(dark)` runs, `app.theme_mode` is now `'dark'`, app re-renders in dark theme regardless of OS.
- **User picks "Automatic" again**: `setMode(auto)` runs, app re-renders following the OS — FR-016 reset clause satisfied.
- **OS theme flips while user choice is `auto`**: Flutter's `MediaQuery` rebuild path causes `MaterialApp` to re-render with the opposite theme — no app restart, no cubit emission.

## Test surface (`test/core/theme/theme_cubit_test.dart`)

- `initialize()` with no persisted value → emits `auto`.
- `initialize()` with `'light'` persisted → emits `light`.
- `initialize()` with `'corrupted'` persisted → emits `auto`, logs warning.
- `setMode(dark)` → state becomes `dark`, store now contains `'dark'`.
- `setMode(currentState)` → no emit, no store write.
- (Widget test) under `MaterialApp(themeMode: ThemeMode.system)`, simulated `MediaQueryData` brightness change re-renders with the opposite theme without rebuilding the cubit.

## Dependency on Phase 1

Reuses `PreferencesStore` (Phase 1 contract) and `AppLogger` (Phase 1 contract) unchanged. The Phase 1 `ThemeCubit` skeleton already exists; Phase 2 implementation extends it with the `auto` case and the persistence behavior above.
