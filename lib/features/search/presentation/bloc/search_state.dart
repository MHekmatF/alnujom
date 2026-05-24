// lib/features/search/presentation/bloc/search_state.dart
//
// Phase 14 Sub-Phase F (T024) — state surface for [SearchBloc] per
// contracts/phase14-search-page-composition.md + data-model.md §2.5
// (NewestCursor / PriceCursor live in domain/entities/search_cursor.dart
// — imported here, NOT redeclared).
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/search_cursor.dart';
import '../../domain/entities/search_result_item.dart';
import '../../domain/entities/sort_order.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  const SearchState({
    this.results = const [],
    this.filters = FilterState.empty,
    this.sort = SortOrder.newest,
    this.cursor,
    this.status = SearchStatus.initial,
    this.failure,
    this.hasNextPage = false,
  });

  final List<SearchResultItem> results;
  final FilterState filters;
  final SortOrder sort;
  final SearchCursor? cursor;
  final SearchStatus status;
  final Failure? failure;
  final bool hasNextPage;

  /// FR-019 — Arabic exact-token user-education hint trigger. True when the
  /// current query contains at least one character in the Arabic Unicode
  /// block (U+0600..U+06FF).
  bool get isArabicQuery =>
      filters.query != null &&
      filters.query!.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

  factory SearchState.initial() => const SearchState();

  SearchState copyWith({
    List<SearchResultItem>? results,
    FilterState? filters,
    SortOrder? sort,
    SearchCursor? cursor,
    bool clearCursor = false,
    SearchStatus? status,
    Failure? failure,
    bool clearFailure = false,
    bool? hasNextPage,
  }) {
    return SearchState(
      results: results ?? this.results,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }

  @override
  List<Object?> get props => [
        results,
        filters,
        sort,
        cursor,
        status,
        failure,
        hasNextPage,
      ];
}
