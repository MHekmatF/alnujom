# Data Model: Design System & Theme Tokens

**Date**: 2026-05-02 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Phase 2 introduces no database tables, no Supabase schema, no RLS policies. The "data" Phase 2 owns is purely conceptual — typed enums, sealed classes, and preference keys consumed by the design system in memory and persisted via the existing Phase 1 `PreferencesStore`.

This file enumerates those entities so reviewers can map every typed value the system carries back to a named source.

## RLS posture

Not applicable — no tables. Constitution III's gate is N/A for this phase. (Phase 4's base-schema spec opens the RLS conversation.)

## Entities

### `ColorPalette` (sealed)

The primary-quintet variant axis the app supports.

| Member | Light primary | Dark primary | Default? |
|---|---|---|---|
| `Modern` | `#1D4ED8` | `#60A5FA` | ✅ — production renders Modern only (FR-015) |
| `Trust` | `#2457A6` | `#9FC5FF` | reachable only via the debug-build Palette Tester chip |

**Behavior**:

- `ColorPalette.modern.lightScheme` → `ColorScheme` with the Modern light primary quintet (`primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `accent`) plus the shared palette-agnostic light tokens.
- `ColorPalette.modern.darkScheme` → same shape, dark variants.
- `ColorPalette.trust.lightScheme` / `darkScheme` — same shape, Trust quintet.
- All four schemes share `secondary`, `tertiary`, `success`, `warning`, `error`, `surface`, `surfaceVariant`, `card`, `outline`, `onSurface`, `onSurfaceVariant`, `textMuted` — these are palette-agnostic per `decision.md` §"Shared tokens".
- Comparable / serializable as a name (`'modern'` / `'trust'`) for persistence.

**Source of truth**: `lib/core/theme/color_palette.dart` (created in Phase 2 implementation). Hex values come from `docs/design/decision.md` §"Color tokens".

### `AppThemeMode` (enum)

The user's persisted theme choice.

| Member | Behavior |
|---|---|
| `auto` | Defer to `ThemeMode.system` — Flutter resolves to light/dark via `MediaQuery.platformBrightnessOf(context)`. Live-updates on OS theme change without app restart (FR-016). |
| `light` | Force light theme regardless of OS. |
| `dark` | Force dark theme regardless of OS. |

**Default on first launch**: `auto` (FR-016).
**Persistence**: `PreferencesStore` under key `app.theme_mode`, value is the lowercased member name.
**Comparable / serializable**: trivially (enum name).

**Source of truth**: `lib/core/theme/theme_cubit.dart` (extended from Phase 1 in Phase 2 implementation).

### `AppLocale` (carryover from Phase 1)

| Member | Direction | Default? |
|---|---|---|
| `ar` | RTL | ✅ — Constitution V |
| `en` | LTR | |

No new behavior in Phase 2; included for completeness because the design system's components depend on `AppLocale` (RTL/LTR alignment, Arabic/Latin font selection).

**Source of truth**: `lib/core/localization/locale_cubit.dart` (Phase 1).

### `ComponentState` (enum)

The catalog of states FR-005 enforces. Not every component supports every state — the per-component state matrix lives in `screens-and-components.md` §5 and is restated in `contracts/component-library.md`.

| Member | Visual treatment guideline |
|---|---|
| `default` | At-rest. Documented per component. |
| `pressed` | Tap feedback — typically scale 0.95–0.98 for 80 ms; visually distinct from default. |
| `focused` | Keyboard / accessibility focus — typically a `primary` 1.5 px outline. |
| `disabled` | 50 % opacity; no shadow; not interactive. |
| `loading` | Inline spinner replacing primary affordance (button label, search-icon leading) — never a screen-blocking spinner. |
| `error` | Uses `error`/`danger` color paired with an icon or label (FR-012 — never color alone). |
| `empty` | Centered illustration → headline → body → CTA composition (`EmptyState` component). Renders on data-driven components when the data set is empty. |

**Source of truth**: `lib/core/widgets/<component>.dart` per component; the enum itself lives in a shared file (typically `lib/core/theme/component_state.dart`).

### `PreferencesKeys` (string constants)

The keys Phase 2 reads/writes through the Phase 1 `PreferencesStore` interface.

| Key | Type | Persisted in production? | Notes |
|---|---|---|---|
| `app.theme_mode` | `AppThemeMode` (serialized as enum name) | ✅ always | FR-016. Default value: `auto`. |
| `app.palette` | `ColorPalette` (serialized as name) | ❌ debug/QA builds only | FR-009. Production reads always return `Modern`; production writes are no-ops (or assertion-fail in debug-build assertions). |

**Source of truth**: `lib/core/storage/preferences_keys.dart` (Phase 2 implementation; extends the Phase 1 keys file if one exists).

### Per-component state matrix

Phase 2 ships 21 components plus the Palette Tester. The full matrix of component × applicable states × variants is kept canonical in `docs/design/screens-and-components.md` §5 and condensed for reviewer scan in `contracts/component-library.md`. To avoid duplication, this file does not restate it — see those two documents.

## Validation rules

These follow from spec FRs and are restated here so reviewers can map each to the entities above:

- **FR-002 / SC-002 — WCAG AA contrast**: For every `(palette, theme)` combination above, every text-token / background-token pair in the resulting `ColorScheme` MUST meet 4.5 : 1 (body) or 3 : 1 (large text & UI). Verified by `test/core/theme/color_scheme_contrast_test.dart`.
- **FR-005 — state coverage**: Each component MUST visibly support every state in its applicable subset. Verified by per-component widget tests under `test/core/widgets/`.
- **FR-006 — RTL/LTR correctness**: Every component renders correctly under both `Directionality.rtl` and `Directionality.ltr`; no left/right hardcoding. Verified by directional widget tests + golden tests on `PropertyCard`.
- **FR-009 / FR-015 — Palette Tester gating**: `kPaletteTesterEnabled` resolves to `false` in release; the chip widget is absent and `PreferencesStore` writes for `app.palette` are no-ops in release. Verified by tree-shake assertion in the quickstart.
- **FR-016 — theme-mode default + live update**: First-launch reads of `app.theme_mode` return `auto`; while `auto` is active, OS-theme changes re-render without app restart. Verified by `test/core/theme/theme_cubit_test.dart`.

## State transitions

### `ThemeCubit`

```
[no value persisted]  →  emit(auto)
auto                  →  emit(light)   when user picks "Light" in Settings
auto                  →  emit(dark)    when user picks "Dark" in Settings
light / dark          →  emit(auto)    when user picks "Automatic" in Settings
```

All transitions persist the new value to `app.theme_mode` immediately.

### `PaletteCubit`

```
[debug build, no value persisted]   →  emit(modern)
[release build, regardless of key]  →  emit(modern)   (FR-015; reads ignored)

modern  →  emit(trust)  on Palette Tester chip tap (debug only)
trust   →  emit(modern) on Palette Tester chip tap (debug only)
```

In debug builds, transitions persist to `app.palette` and a confirmation snackbar names the now-active palette. In release builds, the cubit accepts no transitions and remains pinned to `modern`.

## Non-DB persistence summary

| What | Where | When |
|---|---|---|
| Active theme mode | `PreferencesStore[app.theme_mode]` | Always — debug + release. |
| Active palette | `PreferencesStore[app.palette]` | Debug/QA builds only. Release: not read, not written. |

No SQL, no migration, no RLS. The `supabase/` tree is untouched in Phase 2.
