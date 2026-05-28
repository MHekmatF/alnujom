// Phase 17 — FavoritesRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.

import '../../../../core/errors/result.dart';
import '../entities/favorite_listing.dart';

abstract interface class FavoritesRepository {
  /// Calls the `add_favorite(p_listing_id)` SECURITY DEFINER RPC.
  ///
  /// Returns [Success] on insert (idempotent: already-favorited is also success).
  /// Returns [FailureResult] on network error or RPC rejection
  /// (auth_required / listing_not_found / listing_not_approved).
  Future<Result<void>> addFavorite(String listingId);

  /// Deletes the row from `public.favorites` via the `favorites_delete_self`
  /// RLS DELETE policy (Q5=A). Emits no lead event.
  Future<Result<void>> removeFavorite(String listingId);

  /// Loads the authenticated user's favorited listing IDs from
  /// `public.favorites`. Used by [FavoritesCubit] to hydrate the session set.
  Future<Result<List<String>>> loadFavoriteIds();

  /// Pages through the user's favorites via `public.v_favorites`, ordered
  /// newest-first by `favorited_at DESC`.
  ///
  /// [cursor] is an ISO-8601 timestamp used as a `lt` upper bound (keyset
  /// pagination on `favorited_at`). Pass `null` for the first page.
  /// [limit] defaults to 30 (FR-027 / R-117).
  Future<Result<List<FavoriteListing>>> loadFavorites({
    String? cursor,
    int limit,
  });
}
