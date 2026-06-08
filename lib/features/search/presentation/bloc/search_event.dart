// lib/features/search/presentation/bloc/search_event.dart
//
// Phase 14 Sub-Phase F (T023) — sealed `SearchEvent` hierarchy consumed by
// [SearchBloc]. Each variant maps 1:1 to a user-driven action on the
// `/search` route per contracts/phase14-search-page-composition.md.
import '../../domain/entities/display_mode.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/sort_order.dart';

sealed class SearchEvent {
  const SearchEvent();
}

final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged({required this.query});
  final String query;
}

final class SearchFiltersApplied extends SearchEvent {
  const SearchFiltersApplied({required this.filters});
  final FilterState filters;
}

final class SearchSortChanged extends SearchEvent {
  const SearchSortChanged({required this.sort});
  final SortOrder sort;
}

final class SearchNextPageRequested extends SearchEvent {
  const SearchNextPageRequested();
}

final class SearchRefreshRequested extends SearchEvent {
  const SearchRefreshRequested();
}

/// Phase 25 — toggles list ⇄ embedded-map presentation WITHOUT re-running the
/// search. Updates only `state.filters.displayMode`; the already-loaded result
/// set drives both views.
final class SearchDisplayModeChanged extends SearchEvent {
  const SearchDisplayModeChanged({required this.mode});
  final DisplayMode mode;
}
