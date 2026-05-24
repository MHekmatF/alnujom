# Contract: Phase 14 Home Screen Rewiring

**Files Updated**:
- `lib/features/home/presentation/widgets/hero_search_bar.dart`
- `lib/features/home/presentation/widgets/property_type_shortcut_row.dart`

**Sub-Phase**: G (Wave 4)
**Created**: 2026-05-24

---

## Purpose

Phase 13 shipped these two widgets as Coming-soon stubs: tapping them showed a snackbar instead of navigating. Phase 14 (Sub-Phase G) replaces those snackbar handlers with real navigation calls, wiring the home screen entry points to the `/search` route.

---

## `hero_search_bar.dart` Change

### Before (Phase 13 Q1=A stub)
```dart
onTap: () {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.home_search_coming_soon)),
  );
},
```

### After (Phase 14)
```dart
onTap: () => context.go(AppRoutes.search),
```

**Behavioral change**:
- No `extra` parameter — `SearchPage` receives `initialPropertyType: null`.
- `SearchPage`'s `_SearchBar` auto-focuses the keyboard.
- No pre-applied filters.

**Imports added**: `AppRoutes` from `lib/core/routing/app_router.dart` (already imported by the home widget or available via `go_router`'s BuildContext extension).

**Imports removed**: The `l10n.home_search_coming_soon` ARB key reference is removed from this widget. The ARB key itself is NOT deleted from the ARB files — it may still be referenced elsewhere or in automated tests. If it is confirmed unused after Phase 14, it can be cleaned up in a separate pass.

---

## `property_type_shortcut_row.dart` Change

### Before (Phase 13 Q1=A stub — per chip)
```dart
onTap: () {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.home_property_shortcut_coming_soon)),
  );
},
```

### After (Phase 14 — per chip)
```dart
onTap: () => context.go(AppRoutes.search, extra: type),
```

where `type` is the `PropertyType` enum value for that chip (e.g., `PropertyType.apartment`, `PropertyType.villa`, etc.).

**Behavioral change**:
- `extra: type` is passed to the `/search` GoRoute builder as `GoRouterState.extra`.
- `SearchPage(initialPropertyType: state.extra as PropertyType?)` receives the enum value.
- `SearchBloc` is initialized with `FilterState(propertyType: initialPropertyType)`.
- Results are pre-filtered to that property type on page open.
- The filter sheet reflects the pre-applied property-type selection (because `SearchFilterSheet` is opened with `initialFilters: state.filters` which already has `propertyType` set).
- The `_SearchBar` does NOT auto-focus (because `initialPropertyType != null` → `autofocus: false`).

**Imports added**: `AppRoutes` (if not already present).

**Imports removed**: The `l10n.home_property_shortcut_coming_soon` ARB key reference from this widget (same caveat as above).

---

## Constraints

1. **No structural changes to surrounding widgets**: Only the `onTap` handler changes. The chip visual design, layout, and label strings are unchanged.

2. **No changes to the `home` feature's domain or data layers**: These are purely presentation-layer tap-handler replacements.

3. **ARB key preservation**: `home_search_coming_soon` and `home_property_shortcut_coming_soon` ARB keys are NOT deleted from `app_ar.arb` / `app_en.arb` in Phase 14 — only the widget references are removed. Key cleanup is deferred to avoid breaking any in-flight branch that references them.

4. **AppRoutes.search must be defined before Sub-Phase G executes**: Sub-Phase G depends on Sub-Phase F per the Phase Dependencies section. The `/wave` orchestrator must complete Sub-Phase F before dispatching Sub-Phase G.

---

## Verification

Manual check:
1. Tap hero search bar on Home → `SearchPage` opens with keyboard focus, no pre-applied filters.
2. Tap "Apartments" chip on Home → `SearchPage` opens with `PropertyType.apartment` pre-applied in filter sheet; results show only apartments; keyboard not auto-focused.
3. Verify no snackbar appears for either entry point.
