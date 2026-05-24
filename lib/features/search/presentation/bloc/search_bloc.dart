// lib/features/search/presentation/bloc/search_bloc.dart
//
// Phase 14 Sub-Phase F (T025) — BLoC state machine driving the `/search`
// route. Route-scoped lifetime (R-77): @injectable (NOT @lazySingleton) so
// every push of /search gets a fresh BLoC instance.
//
// Invariants enforced here:
//  • SearchQueryChanged debounces 400 ms via `Timer` before dispatching
//    SearchFiltersApplied — does NOT itself emit `loading`.
//  • Fresh searches (filters / sort) reset the cursor to null + clear
//    `results`.
//  • SearchNextPageRequested is a no-op when already loading OR when
//    `hasNextPage` is false (concurrency guard).
//  • Pagination failures do NOT flip status to `failure` — they just stop
//    further pagination (the user keeps what they have).
//  • `_makeCursor` returns null on empty lists — last page is reached.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/search_cursor.dart';
import '../../domain/entities/search_result_item.dart';
import '../../domain/entities/sort_order.dart';
import '../../domain/usecases/search_listings_usecase.dart';
import 'search_event.dart';
import 'search_state.dart';

@injectable
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._useCase) : super(SearchState.initial()) {
    on<SearchFiltersApplied>(_onFiltersApplied);
    on<SearchSortChanged>(_onSortChanged);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchNextPageRequested>(_onNextPage);
    on<SearchRefreshRequested>(_onRefresh);
  }

  final SearchListingsUseCase _useCase;
  Timer? _debounce;

  static const int _pageSize = 20;

  Future<void> _onFiltersApplied(
    SearchFiltersApplied event,
    Emitter<SearchState> emit,
  ) async {
    _debounce?.cancel();
    emit(state.copyWith(
      filters: event.filters,
      status: SearchStatus.loading,
      results: const [],
      clearCursor: true,
      hasNextPage: false,
      clearFailure: true,
    ));
    final result = await _useCase(
      filters: event.filters,
      sort: state.sort,
      cursor: null,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<SearchResultItem>>(:final value):
        emit(state.copyWith(
          results: value,
          status: SearchStatus.success,
          cursor: _makeCursor(value, state.sort),
          clearCursor: value.isEmpty,
          hasNextPage: value.length == _pageSize,
        ));
      case FailureResult<List<SearchResultItem>>(:final failure):
        emit(state.copyWith(status: SearchStatus.failure, failure: failure));
    }
  }

  Future<void> _onSortChanged(
    SearchSortChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      sort: event.sort,
      status: SearchStatus.loading,
      results: const [],
      clearCursor: true,
      hasNextPage: false,
      clearFailure: true,
    ));
    final result = await _useCase(
      filters: state.filters,
      sort: event.sort,
      cursor: null,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<SearchResultItem>>(:final value):
        emit(state.copyWith(
          results: value,
          status: SearchStatus.success,
          cursor: _makeCursor(value, event.sort),
          clearCursor: value.isEmpty,
          hasNextPage: value.length == _pageSize,
        ));
      case FailureResult<List<SearchResultItem>>(:final failure):
        emit(state.copyWith(status: SearchStatus.failure, failure: failure));
    }
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    // 400 ms debounce per R-77 / T025 contract. Do NOT emit loading here —
    // the dispatched SearchFiltersApplied will set status=loading once the
    // debounce fires, which keeps the UI quiet while the user is still typing.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = event.query.trim();
      add(SearchFiltersApplied(
        filters: state.filters.copyWith(
          query: trimmed.isEmpty ? null : trimmed,
          clearQuery: trimmed.isEmpty,
        ),
      ));
    });
  }

  Future<void> _onNextPage(
    SearchNextPageRequested event,
    Emitter<SearchState> emit,
  ) async {
    // Concurrency guard: skip if already loading OR no more pages.
    if (state.status == SearchStatus.loading || !state.hasNextPage) return;
    final result = await _useCase(
      filters: state.filters,
      sort: state.sort,
      cursor: state.cursor,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<SearchResultItem>>(:final value):
        final combined = [...state.results, ...value];
        emit(state.copyWith(
          results: combined,
          status: SearchStatus.success,
          cursor: _makeCursor(value, state.sort),
          clearCursor: value.isEmpty,
          hasNextPage: value.length == _pageSize,
        ));
      case FailureResult<List<SearchResultItem>>():
        // Pagination failure: do NOT flip global status to failure (the user
        // keeps their existing results). Just stop further pagination.
        emit(state.copyWith(hasNextPage: false));
    }
  }

  Future<void> _onRefresh(
    SearchRefreshRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      status: SearchStatus.loading,
      results: const [],
      clearCursor: true,
      hasNextPage: false,
      clearFailure: true,
    ));
    final result = await _useCase(
      filters: state.filters,
      sort: state.sort,
      cursor: null,
      limit: _pageSize,
    );
    switch (result) {
      case Success<List<SearchResultItem>>(:final value):
        emit(state.copyWith(
          results: value,
          status: SearchStatus.success,
          cursor: _makeCursor(value, state.sort),
          clearCursor: value.isEmpty,
          hasNextPage: value.length == _pageSize,
        ));
      case FailureResult<List<SearchResultItem>>(:final failure):
        emit(state.copyWith(status: SearchStatus.failure, failure: failure));
    }
  }

  SearchCursor? _makeCursor(List<SearchResultItem> items, SortOrder sort) {
    if (items.isEmpty) return null;
    final last = items.last;
    switch (sort) {
      case SortOrder.newest:
        return NewestCursor(publishedAt: last.publishedAt, id: last.id);
      case SortOrder.priceAsc:
      case SortOrder.priceDesc:
        return PriceCursor(priceAmount: last.primaryAmount, id: last.id);
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
