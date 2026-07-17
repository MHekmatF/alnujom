// lib/features/favorites/data/datasources/supabase_favorites_datasource.dart
//
// Phase 17 — SOLE importer of the supabase_flutter package under
// `lib/features/favorites/` per Constitution IX.
//
// All Supabase I/O for the favorites feature:
//   - add_favorite RPC (FR-011)
//   - favorites table DELETE (FR-012)
//   - favorites table SELECT listing_id (FavoritesCubit hydration, R-110)
//   - v_favorites view SELECT + cursor pagination (FR-021, FR-027, R-117)

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/favorite_listing_dto.dart';

@injectable
class SupabaseFavoritesDatasource {
  SupabaseFavoritesDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Calls the `add_favorite(p_listing_id)` SECURITY DEFINER RPC.
  ///
  /// The RPC is idempotent (ON CONFLICT DO NOTHING) and also co-transactionally
  /// inserts the deduped `favorite_added` lead event (FR-014 / FR-015).
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - auth_required (28000) — caller is anonymous
  ///   - listing_not_found (23503) — bad listing id
  ///   - listing_not_approved (23514) — listing not in `approved` status
  Future<void> addFavorite(String listingId) async {
    await _client.rpc('add_favorite', params: {'p_listing_id': listingId});
  }

  /// Deletes the row from `public.favorites` for the current user via the
  /// `favorites_delete_self` self-only RLS DELETE policy (Q5=A).
  ///
  /// Silent no-op when the row does not exist (already un-favorited).
  Future<void> removeFavorite(String listingId) async {
    await _client.from('favorites').delete().eq('listing_id', listingId);
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Loads the current user's favorited listing IDs from `public.favorites`.
  ///
  /// Returns a flat list of UUID strings. Used by [FavoritesCubit] to hydrate
  /// the session `Set<String>` on sign-in (R-110).
  Future<List<String>> loadFavoriteIds() async {
    final rows = await _client.from('favorites').select('listing_id');
    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['listing_id'] as String)
        .toList();
  }

  /// Pages through the user's favorites via `public.v_favorites`.
  ///
  /// Ordered newest-first by `favorited_at DESC`. [cursor] is an ISO-8601
  /// timestamp used as an exclusive upper bound for keyset pagination (mirrors
  /// the Phase 13 home-feed pattern). Pass `null` for the first page.
  Future<List<FavoriteListingDto>> loadFavorites({
    String? cursor,
    int limit = 30,
  }) async {
    var query = _client.from('v_favorites').select();

    if (cursor != null) {
      query = query.lt('favorited_at', cursor);
    }

    final rows = await query
        .order('favorited_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      // FUNC-M1: `v_favorites.main_image_path` is a raw storage path; resolve it
      // to a full public URL here — mirroring the home / search / chat
      // datasources — so the favorites card shows the real cover photo instead of
      // a placeholder. Already-absolute URLs pass through unchanged.
      final path = map['main_image_path'];
      if (path is String && path.isNotEmpty && !path.startsWith('http')) {
        map['main_image_path'] = _client.storage
            .from('listing-images')
            .getPublicUrl(path);
      }
      return FavoriteListingDto.fromJson(map);
    }).toList();
  }
}
