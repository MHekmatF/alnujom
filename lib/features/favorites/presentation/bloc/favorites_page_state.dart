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
final class FavoritesPageLoaded extends FavoritesPageState {
  const FavoritesPageLoaded({required this.items, required this.hasMore});

  final List<FavoriteListing> items;
  final bool hasMore;
}

/// Unrecoverable load error.
final class FavoritesPageError extends FavoritesPageState {
  const FavoritesPageError(this.failure);

  final Failure failure;
}
