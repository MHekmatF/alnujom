// lib/features/favorites/presentation/bloc/favorites_page_bloc.dart
//
// Phase 17 Sub-Phase F (T032) — Paginated BLoC for FavoritesPage.
// Events: FavoritesPageOpened / FavoritesPageRefreshRequested / FavoritesPageMoreLoaded.
// States: FavoritesPageLoading / FavoritesPageLoaded / FavoritesPageError.
// Cursor on `favorited_at DESC`, limit 30 per R-117 / FR-027.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/favorite_listing.dart';
import '../../domain/entities/favorites_sort.dart';
import '../../domain/usecases/load_favorites.dart';

part 'favorites_page_event.dart';
part 'favorites_page_state.dart';

/// Page-scoped BLoC that loads the user's favorite listings from
/// `public.v_favorites` (newest-first, cursor-paginated).
///
/// Registered as `@injectable` (one instance per page, not a singleton).
@injectable
class FavoritesPageBloc extends Bloc<FavoritesPageEvent, FavoritesPageState> {
  FavoritesPageBloc(this._loadFavorites) : super(const FavoritesPageLoading()) {
    on<FavoritesPageOpened>(_onOpened);
    on<FavoritesPageRefreshRequested>(_onRefresh);
    on<FavoritesPageMoreLoaded>(_onMoreLoaded);
    on<FavoritesPageSortChanged>(_onSortChanged);
  }

  final LoadFavorites _loadFavorites;

  static const int _pageSize = 30;

  /// The raw, server-ordered (`favorited_at DESC`) accumulation of loaded
  /// pages. Kept separate from the displayed (sorted) list so re-sorting and
  /// keyset pagination both stay correct without re-fetching.
  ///
  /// BACKEND FOLLOW-UP: when `v_favorites`/the favorites datasource gains a
  /// server-side sort parameter, push [_sort] down and drop this client-side
  /// reorder so price sorts span all pages, not just the loaded ones.
  final List<FavoriteListing> _rawItems = [];

  /// The active sort selection (defaults to newest-saved).
  FavoritesSort _sort = FavoritesSort.recentlySaved;

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onOpened(
    FavoritesPageOpened event,
    Emitter<FavoritesPageState> emit,
  ) async {
    emit(const FavoritesPageLoading());
    await _fetchFirstPage(emit);
  }

  Future<void> _onRefresh(
    FavoritesPageRefreshRequested event,
    Emitter<FavoritesPageState> emit,
  ) async {
    emit(const FavoritesPageLoading());
    await _fetchFirstPage(emit);
  }

  Future<void> _onMoreLoaded(
    FavoritesPageMoreLoaded event,
    Emitter<FavoritesPageState> emit,
  ) async {
    final current = state;
    if (current is! FavoritesPageLoaded || !current.hasMore) return;

    // Cursor: ISO-8601 `favorited_at` of the last RAW item — pagination always
    // follows the true server order, independent of the display sort.
    final cursor = _rawItems.isNotEmpty
        ? _rawItems.last.favoritedAt.toIso8601String()
        : null;

    final result = await _loadFavorites(cursor: cursor, limit: _pageSize);

    if (result is Success<List<FavoriteListing>>) {
      final newItems = result.value;
      _rawItems.addAll(newItems);
      emit(
        FavoritesPageLoaded(
          items: _sortedItems(),
          hasMore: newItems.length == _pageSize,
          sort: _sort,
        ),
      );
    }
    // On error during pagination: silently keep current page (no error state
    // so the user doesn't lose their list; they can pull-to-refresh to retry).
  }

  void _onSortChanged(
    FavoritesPageSortChanged event,
    Emitter<FavoritesPageState> emit,
  ) {
    if (event.sort == _sort) return;
    _sort = event.sort;

    final current = state;
    if (current is! FavoritesPageLoaded) return;

    // Re-order the already-loaded items in place; no re-fetch (FR additive,
    // behavior-preserving — see the BACKEND FOLLOW-UP on [_rawItems]).
    emit(
      FavoritesPageLoaded(
        items: _sortedItems(),
        hasMore: current.hasMore,
        sort: _sort,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchFirstPage(Emitter<FavoritesPageState> emit) async {
    final result = await _loadFavorites(cursor: null, limit: _pageSize);
    switch (result) {
      case Success<List<FavoriteListing>>(:final value):
        _rawItems
          ..clear()
          ..addAll(value);
        emit(
          FavoritesPageLoaded(
            items: _sortedItems(),
            hasMore: value.length == _pageSize,
            sort: _sort,
          ),
        );
      case FailureResult<List<FavoriteListing>>(:final failure):
        emit(FavoritesPageError(failure));
    }
  }

  /// Returns a copy of [_rawItems] re-ordered for the active [_sort]. The raw
  /// list is always kept in server order (`favorited_at DESC`).
  List<FavoriteListing> _sortedItems() {
    switch (_sort) {
      case FavoritesSort.recentlySaved:
        return List<FavoriteListing>.from(_rawItems);
      case FavoritesSort.priceDesc:
        return _byPrice(descending: true);
      case FavoritesSort.priceAsc:
        return _byPrice(descending: false);
    }
  }

  /// Stable price sort. Items without a price (RLS-hidden / unavailable rows)
  /// always sort last, keeping their relative server order.
  List<FavoriteListing> _byPrice({required bool descending}) {
    final priced = <FavoriteListing>[];
    final unpriced = <FavoriteListing>[];
    for (final item in _rawItems) {
      (item.primaryAmount == null ? unpriced : priced).add(item);
    }
    priced.sort((a, b) {
      final cmp = a.primaryAmount!.compareTo(b.primaryAmount!);
      return descending ? -cmp : cmp;
    });
    return [...priced, ...unpriced];
  }
}
