// lib/features/favorites/presentation/bloc/favorites_page_event.dart
//
// Phase 17 Sub-Phase F (T032) — Events for FavoritesPageBloc.

part of 'favorites_page_bloc.dart';

sealed class FavoritesPageEvent {
  const FavoritesPageEvent();
}

/// Fired when the page first mounts (BlocProvider.create callback).
final class FavoritesPageOpened extends FavoritesPageEvent {
  const FavoritesPageOpened();
}

/// Fired by the RefreshIndicator pull-to-refresh gesture.
final class FavoritesPageRefreshRequested extends FavoritesPageEvent {
  const FavoritesPageRefreshRequested();
}

/// Fired when the user scrolls to the bottom of the list while [hasMore].
final class FavoritesPageMoreLoaded extends FavoritesPageEvent {
  const FavoritesPageMoreLoaded();
}

/// Fired when the user picks a new sort order from the inline sort control
/// (Phase 25 uplift v2). Re-orders the already-loaded items client-side.
final class FavoritesPageSortChanged extends FavoritesPageEvent {
  const FavoritesPageSortChanged(this.sort);

  final FavoritesSort sort;
}
