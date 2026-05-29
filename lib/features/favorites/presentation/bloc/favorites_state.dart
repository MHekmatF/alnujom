// lib/features/favorites/presentation/bloc/favorites_state.dart
//
// Phase 17 Sub-Phase F (T030) — Immutable state for FavoritesCubit.

part of 'favorites_cubit.dart';

/// Session-scoped state for [FavoritesCubit].
///
/// [favoritedIds] — the set of listing IDs the signed-in user has saved.
///   Empty when the user is signed out or when loading is in progress.
/// [isSignedIn] — true when there is an active, approved auth session.
///   Drives the anonymous branch in [FavoriteHeartButton].
/// [lastToggleFailed] — set to `true` for exactly one emission after a
///   toggle RPC/DELETE call fails. [FavoriteHeartButton] listens for this
///   to show the `favorite_toggle_failed` snackbar (FR-006). Resets to
///   `false` on the next state transition.
class FavoritesState {
  const FavoritesState({
    required this.favoritedIds,
    required this.isSignedIn,
    this.lastToggleFailed = false,
  });

  final Set<String> favoritedIds;
  final bool isSignedIn;
  final bool lastToggleFailed;

  FavoritesState copyWith({
    Set<String>? favoritedIds,
    bool? isSignedIn,
    bool? lastToggleFailed,
  }) {
    return FavoritesState(
      favoritedIds: favoritedIds ?? this.favoritedIds,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      lastToggleFailed: lastToggleFailed ?? false,
    );
  }
}
