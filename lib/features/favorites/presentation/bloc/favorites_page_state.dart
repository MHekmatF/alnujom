// lib/features/favorites/presentation/bloc/favorites_page_state.dart
//
// Phase 17 Sub-Phase F (T032) — States for FavoritesPageBloc.

part of 'favorites_page_bloc.dart';

sealed class FavoritesPageState {
  const FavoritesPageState();
}

/// Initial / refresh-in-progress state.
final class FavoritesPageLoading extends FavoritesPageState {
  const FavoritesPageLoading();
}

/// Successful load: [items] may be empty (empty-state widget shown).
/// [hasMore] true means there is a next page available.
///
/// [items] is the list AS DISPLAYED — it has already had the active [sort]
/// applied client-side. The bloc keeps the raw server order internally so it
/// can re-sort without re-fetching and so keyset pagination keeps using the
/// true `favorited_at` cursor.
final class FavoritesPageLoaded extends FavoritesPageState {
  const FavoritesPageLoaded({
    required this.items,
    required this.hasMore,
    this.sort = FavoritesSort.recentlySaved,
  });

  final List<FavoriteListing> items;
  final bool hasMore;

  /// The sort order currently applied to [items] (Phase 25 uplift v2).
  final FavoritesSort sort;
}

/// Unrecoverable load error.
final class FavoritesPageError extends FavoritesPageState {
  const FavoritesPageError(this.failure);

  final Failure failure;
}
