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
  }

  final LoadFavorites _loadFavorites;

  static const int _pageSize = 30;

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

    // Cursor: ISO-8601 `favorited_at` of the last item.
    final cursor = current.items.isNotEmpty
        ? current.items.last.favoritedAt.toIso8601String()
        : null;

    final result = await _loadFavorites(cursor: cursor, limit: _pageSize);

    if (result is Success<List<FavoriteListing>>) {
      final newItems = result.value;
      emit(FavoritesPageLoaded(
        items: [...current.items, ...newItems],
        hasMore: newItems.length == _pageSize,
      ));
    }
    // On error during pagination: silently keep current page (no error state
    // so the user doesn't lose their list; they can pull-to-refresh to retry).
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchFirstPage(Emitter<FavoritesPageState> emit) async {
    final result = await _loadFavorites(cursor: null, limit: _pageSize);
    switch (result) {
      case Success<List<FavoriteListing>>(:final value):
        emit(FavoritesPageLoaded(
          items: value,
          hasMore: value.length == _pageSize,
        ));
      case FailureResult<List<FavoriteListing>>(:final failure):
        emit(FavoritesPageError(failure));
    }
  }
}
