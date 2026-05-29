// lib/features/favorites/presentation/bloc/favorites_cubit.dart
//
// Phase 17 Sub-Phase F (T030) — Shared-session cubit tracking the signed-in
// user's favorited listing IDs. Mirrors the Phase 16 InquiriesUnreadCubit
// @lazySingleton + AuthBloc-subscription pattern (R-110).
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/load_favorite_ids.dart';
import '../../domain/usecases/remove_favorite.dart';

part 'favorites_state.dart';

/// Session-scoped cubit holding the full set of favorited listing IDs for the
/// signed-in user (R-110 / FR-002 / FR-003).
///
/// Lifecycle:
/// - Constructed once via GetIt (@lazySingleton).
/// - Subscribes to [AuthBloc] at construction:
///   * Any non-Unauthenticated state → hydrate via [LoadFavoriteIds], emit
///     `isSignedIn=true`.
///   * [Unauthenticated] → clear the set, emit `isSignedIn=false`.
/// - [toggle]: optimistic add/remove → repo call → revert on failure.
/// - [isFavorited]: O(1) set lookup for [BlocSelector] hearts.
@lazySingleton
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(
    this._loadFavoriteIds,
    this._addFavorite,
    this._removeFavorite,
    this._authBloc,
  ) : super(const FavoritesState(favoritedIds: {}, isSignedIn: false)) {
    // Hydrate immediately if already signed in at construction time.
    _onAuthStateChanged(_authBloc.state);

    _authSub = _authBloc.stream.listen(_onAuthStateChanged);
  }

  final LoadFavoriteIds _loadFavoriteIds;
  final AddFavorite _addFavorite;
  final RemoveFavorite _removeFavorite;
  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _authSub;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns `true` when [listingId] is in the current session set.
  bool isFavorited(String listingId) => state.favoritedIds.contains(listingId);

  /// Optimistically toggles [listingId] in the session set, calls the
  /// appropriate use case, and reverts on failure (FR-006).
  ///
  /// Does nothing when the user is signed out (guard; callers should also
  /// check [state.isSignedIn] before calling).
  Future<void> toggle(String listingId) async {
    if (!state.isSignedIn) return;

    final wasFavorited = isFavorited(listingId);

    // Optimistic update — reset toggle-failure flag from any prior failure.
    final optimisticSet = Set<String>.from(state.favoritedIds);
    if (wasFavorited) {
      optimisticSet.remove(listingId);
    } else {
      optimisticSet.add(listingId);
    }
    emit(state.copyWith(favoritedIds: optimisticSet, lastToggleFailed: false));

    // Persist.
    final Result<void> result;
    if (wasFavorited) {
      result = await _removeFavorite(listingId);
    } else {
      result = await _addFavorite(listingId);
    }

    // Revert on failure and surface the error flag so UI can show the
    // `favorite_toggle_failed` snackbar (FR-006).
    if (result is FailureResult<void>) {
      final revertedSet = Set<String>.from(state.favoritedIds);
      if (wasFavorited) {
        revertedSet.add(listingId);
      } else {
        revertedSet.remove(listingId);
      }
      emit(state.copyWith(favoritedIds: revertedSet, lastToggleFailed: true));
    }
  }

  // ---------------------------------------------------------------------------
  // Auth subscription
  // ---------------------------------------------------------------------------

  Future<void> _onAuthStateChanged(AuthState authState) async {
    if (authState is Unauthenticated || authState is Authenticating) {
      emit(const FavoritesState(favoritedIds: {}, isSignedIn: false));
      return;
    }

    // Any other state (Authenticated, PendingApproval, Rejected, Suspended)
    // represents a live session — hydrate the set.
    final result = await _loadFavoriteIds();
    if (result is Success<List<String>>) {
      emit(
        FavoritesState(
          favoritedIds: Set<String>.from(result.value),
          isSignedIn: true,
        ),
      );
    } else {
      // Keep current set if load fails; mark signed in so the button toggles.
      emit(state.copyWith(isSignedIn: true));
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _authSub.cancel();
    await close();
  }
}
