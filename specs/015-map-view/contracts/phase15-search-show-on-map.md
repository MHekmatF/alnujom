# Contract: Search results "Show on map" affordance

**Phase**: 15 — Map View
**Owner**: Sub-Phase G3 (entry-point wiring)
**File**: `lib/features/search/presentation/pages/search_page.dart` (UPDATE only — `_SortAndFiltersRow` at lines 176–233)
**Spec refs**: FR-007 (entry point c), FR-007a, FR-020, US6, Q2=A clarification
**Phase 14 contract preserved**: existing `InlineSortControl` and `Filters` button are not modified

## Insertion point in `_SortAndFiltersRow`

Locate the existing row (Phase 14 ships it as `MainAxisAlignment.spaceBetween` with sort label + InlineSortControl on the start and Filters button on the end):

```dart
// BEFORE (Phase 14 state):
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(l10n.search_sort_label, style: ...),
            const SizedBox(width: AppSpacing.xs),
            const InlineSortControl(),
          ],
        ),
        TextButton.icon(
          onPressed: () => _openFilterSheet(context),
          icon: const Icon(Icons.tune),
          label: Text(l10n.search_filters_button_label),
        ),
      ],
    ),
  );
}

// AFTER (Phase 15 G3 addition):
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(l10n.search_sort_label, style: ...),
            const SizedBox(width: AppSpacing.xs),
            const InlineSortControl(),
          ],
        ),
        Row(
          children: [
            // Phase 15 G3: Show-on-map button
            TextButton.icon(
              onPressed: () => _openMap(context),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.search_results_show_on_map_action),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => _openFilterSheet(context),
              icon: const Icon(Icons.tune),
              label: Text(l10n.search_filters_button_label),
            ),
          ],
        ),
      ],
    ),
  );
}

void _openMap(BuildContext context) {
  final filterState = context.read<SearchBloc>().state.filters;
  context.go(
    AppRoutes.map,
    extra: MapEntryFromSearch(
      filterState: filterState,
      showFilterAlert: filterState.hasAnyActiveFilter,
    ),
  );
}
```

## `FilterState.hasAnyActiveFilter` getter (Phase 14 file UPDATE)

Add a small getter to `lib/features/search/domain/entities/filter_state.dart`:

```dart
bool get hasAnyActiveFilter =>
    purpose != null ||
    propertyType != null ||
    governorateId != null ||
    cityId != null ||
    areaId != null ||
    priceRange != null ||
    roomsFilter != null ||
    bathroomsFilter != null ||
    areaSizeRange != null ||
    (keyword != null && keyword!.isNotEmpty);
```

If a similar getter already exists, reuse it; otherwise add this one. Phase 14's `FilterState` already exposes the per-dimension non-null fields so the implementation is mechanical.

## Behavioral contract

1. **Always visible**: The "Show on map" button MUST be visible on every search-results render (not gated by whether filters are active). When no filters are active, the map opens at Syria-wide overview without the filter alert (consistent with US1).
2. **Filter handoff**: When the user taps the button, the current `FilterState` from `SearchBloc.state.filters` is captured AND passed as `MapEntryFromSearch.filterState`. `showFilterAlert` is derived from `filterState.hasAnyActiveFilter`.
3. **No state mutation**: Tapping the button does NOT alter `SearchBloc` state. The user can press back from the map and return to identical search results.
4. **Localization**: Button label flows through `l10n.search_results_show_on_map_action` (e.g., "اعرض على الخريطة" / "Show on map" — same copy as the listing-details button, OR distinct if desired; plan-time copy decision).
5. **Theming**: `TextButton.icon` consumes default Phase 2 button theme; padding uses `AppSpacing` tokens.
6. **Navigation**: `context.go(AppRoutes.map, extra: ...)` — using `go` (not `push`) so the back button on `MapPage` lands on the search page (per Phase 13 Q4=D pattern: `Navigator.canPop()` is false → routes to home; the search page's own back-button handling decides whether to pop to home or to a deeper history).

## Acceptance test (manual)

- Open search page. Apply filters: purpose=sale, property_type=apartment, governorate=Damascus. Tap "Show on map." Confirm:
  - Map opens with only apartment-for-sale-in-Damascus markers.
  - Filter-active alert dialog appears with a chip-list summary + "Reset filters" + "Keep filters" actions.
  - Tap "Reset filters" → dialog dismisses, map reloads with the full unfiltered set, marker count grows.
- Repeat the same flow, but tap "Keep filters" instead → dialog dismisses, map stays filtered.
- Open search page with no filters applied. Tap "Show on map." Confirm map opens at Syria-wide overview WITHOUT a filter alert.
- Press back from map → search page renders with identical state (filters intact, sort order intact, result list intact — Phase 14 R-77 BLoC lifetime preserved).
