# Contract: Phase 14 `SearchPage` Composition

**File**: `lib/features/search/presentation/pages/search_page.dart`
**Sub-Phase**: F (Wave 3)
**Created**: 2026-05-24

---

## Purpose

`SearchPage` is the root widget of the `/search` route. It composes the search text field, inline sort control, filters button, paginated results list, empty state, error state, and loading indicator. It owns the `SearchBloc` via `BlocProvider`.

---

## Route Contract

```
Route path    : /search
AppRoutes key : AppRoutes.search = '/search'
GoRoute builder:
  GoRoute(
    path: AppRoutes.search,
    builder: (context, state) => SearchPage(
      initialPropertyType: state.extra as PropertyType?,
    ),
  )
```

`GoRouterState.extra` carries a `PropertyType?` value when the user arrives from a property-type chip (R-80). Null when entered from the hero search bar.

---

## Widget Signature

```dart
class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialPropertyType,
  });

  final PropertyType? initialPropertyType;
}
```

---

## Widget Tree

```
BlocProvider<SearchBloc>(
  create: (_) => GetIt.I<SearchBloc>()
    ..add(SearchFiltersApplied(
      initialPropertyType != null
        ? FilterState(propertyType: initialPropertyType)
        : FilterState.empty,
    )),
  child: Scaffold(
    appBar: AppBar(
      leading: BackButton (or DeepLinkAwareBackButton per Phase 13 Q4=D convention),
    ),
    body: Column(
      children: [
        _SearchBar(),                    // text input, auto-focus from hero entry
        _SortAndFiltersRow(),            // InlineSortControl + FiltersButton
        Expanded(
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) => switch(state.status) {
              SearchStatus.initial  => _EmptyPrompt(),
              SearchStatus.loading  => _LoadingIndicator(),
              SearchStatus.success  => _ResultsListView(state),
              SearchStatus.failure  => _ErrorState(state.failure),
            },
          ),
        ),
      ],
    ),
  ),
)
```

---

## `_SearchBar` Contract

- `TextField` with `autofocus: initialPropertyType == null` — auto-focuses keyboard when entered from hero search bar; does NOT auto-focus when entered from a property-type chip.
- Hint text: `search_placeholder` ARB key.
- Clear button (×) visible when text is non-empty. Tapping clear: dispatches `SearchQueryChanged('')` which triggers a full unfiltered re-fetch (FR-004 / US1 scenario 4).
- `onSubmitted` + `onChanged` (debounced ~400ms): dispatches `SearchQueryChanged(value)`.
- `textDirection: TextDirection.inherit` — allows Arabic RTL input.

---

## `_SortAndFiltersRow` Contract

```
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(  // sort prefix + control
      children: [
        Text('search_sort_label'),   // ARB key: "ترتيب: / Sort:"
        InlineSortControl(),
      ],
    ),
    FiltersButton(
      hasActiveFilters: !state.filters.isEmpty,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => SearchFilterSheet(
          initialFilters: state.filters,
          onApply: (newFilters) =>
            context.read<SearchBloc>().add(SearchFiltersApplied(newFilters)),
        ),
      ),
    ),
  ],
)
```

`FiltersButton` shows a badge/indicator when `!state.filters.isEmpty` (one or more filters active).

---

## `InlineSortControl` Contract

**File**: `lib/features/search/presentation/widgets/inline_sort_control.dart`

```dart
class InlineSortControl extends StatelessWidget {
  const InlineSortControl({super.key});
}
```

- `BlocBuilder<SearchBloc, SearchState>` inside.
- Renders a `DropdownButton<SortOrder>` (R-84).
- Three items:
  - `SortOrder.newest` → label `search_sort_newest` ARB key
  - `SortOrder.priceAsc` → label `search_sort_price_asc` ARB key
  - `SortOrder.priceDesc` → label `search_sort_price_desc` ARB key
- `value`: `state.sort`.
- `onChanged`: dispatches `SearchSortChanged(newSort)` to `SearchBloc`. This resets the cursor and triggers a fresh query.

---

## `_ResultsListView` Contract

```dart
ListView.builder(
  itemCount: state.results.length + (state.hasNextPage ? 1 : 0),
  itemBuilder: (_, index) {
    if (index == state.results.length) {
      // Load-more trigger
      context.read<SearchBloc>().add(const SearchNextPageRequested());
      return const CircularProgressIndicator();
    }
    return SearchResultCard(item: state.results[index]);
  },
)
```

- `state.hasNextPage` is true when the last RPC response returned exactly `p_limit` rows.
- `SearchNextPageRequested` is dispatched when the trailing item becomes visible (auto-pagination per FR-014 / SC-010).

---

## `SearchResultCard` Contract

**File**: `lib/features/search/presentation/widgets/search_result_card.dart`

```dart
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item});
  final SearchResultItem item;
}
```

Visual design mirrors Phase 13's `HomeListingCard` widget (same card proportions, image / title / location / price layout). Does NOT import from `lib/features/home/` — uses `SearchResultItem` types directly.

On tap: `context.go('${AppRoutes.listingDetails}/${item.id}')`.

---

## Empty and Error States

### Empty State (`SearchStatus.success` with zero results)
```
Column(
  children: [
    Icon(Icons.search_off),
    Text('search_empty_title'),     // ARB key
    Text('search_empty_subtitle'),  // ARB key
    TextButton(
      onPressed: () => context.read<SearchBloc>()
        .add(SearchFiltersApplied(FilterState.empty)),
      child: Text('search_empty_clear_filters'),  // ARB key
    ),
    // Arabic hint (FR-019): shown when query non-null + results < 3
    if (state.isArabicQuery && state.results.length < 3)
      Text('search_arabic_hint', args: [_arabicSuggestion(state.filters.query)]),
  ],
)
```

### Error State (`SearchStatus.failure`)
```
Column(
  children: [
    Text('search_error_message'),   // ARB key
    TextButton(
      onPressed: () => context.read<SearchBloc>().add(SearchRefreshRequested()),
      child: Text('search_error_retry'),  // ARB key
    ),
  ],
)
```

---

## Entry-Point Behavior Summary

| Entry Point | `initialPropertyType` | Auto-focus keyboard | Pre-applied filter |
|-------------|----------------------|---------------------|--------------------|
| Hero search bar | null | Yes | None |
| Property-type chip | PropertyType value | No | `propertyType` filter active |

---

## Dependency Summary

| Dependency | From |
|------------|------|
| `SearchBloc` / `SearchState` / events | `lib/features/search/presentation/bloc/` (this sub-phase) |
| `FilterState` | `lib/features/search/domain/entities/filter_state.dart` (Sub-Phase B) |
| `SortOrder` | `lib/features/search/domain/entities/sort_order.dart` (Sub-Phase B) |
| `SearchResultItem` | `lib/features/search/domain/entities/search_result_item.dart` (Sub-Phase B) |
| `SearchFilterSheet` | `lib/features/search/presentation/widgets/search_filter_sheet.dart` (Sub-Phase E) |
| `AppRoutes.search` | `lib/core/routing/app_router.dart` (this sub-phase) |
| `AppRoutes.listingDetails` | `lib/core/routing/app_router.dart` (Phase 13) |
| `PropertyType` | `lib/features/listing_form/domain/entities/listing.dart` (Phase 10) |
| ARB keys | `app_ar.arb` / `app_en.arb` (Sub-Phase C) |
