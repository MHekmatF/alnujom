import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/review_dto.dart';

/// Seller-trust datasource — the SOLE importer of `package:supabase_flutter`
/// under `lib/features/reviews/` per the Constitution (data/ only).
///
/// Reads recent reviews + aggregate rating + response stats for a seller and
/// submits a new review. RLS owns all access control:
///   - `reviews`: public SELECT; authenticated INSERT own (reviewer_user_id
///     DEFAULTs to auth.uid()); UNIQUE(reviewer_user_id, target_user_id).
///   - `v_publisher_ratings`: public SELECT.
///   - `publisher_response_stats`: SECURITY-checked RPC.
@injectable
class SupabaseReviewsDatasource {
  const SupabaseReviewsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Recent reviews for [targetUserId], newest-first. Does NOT join `profiles`
  /// (no reviewer display name surfaced).
  Future<List<ReviewDto>> fetchReviews(
    String targetUserId, {
    int limit = 20,
  }) async {
    final rows = await _client
        .from('reviews')
        .select('id, rating, comment, created_at')
        .eq('target_user_id', targetUserId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((r) => ReviewDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Aggregate rating from `v_publisher_ratings`. Null when the seller has no
  /// rating row yet (no reviews).
  Future<PublisherRatingDto?> fetchRating(String targetUserId) async {
    final row = await _client
        .from('v_publisher_ratings')
        .select('avg_rating, review_count')
        .eq('target_user_id', targetUserId)
        .maybeSingle();
    if (row == null) return null;
    return PublisherRatingDto.fromJson(Map<String, dynamic>.from(row));
  }

  /// Rating distribution (star → count) via the `publisher_rating_distribution`
  /// RPC. An empty map when the seller has no reviews. Only ratings 1..5 kept.
  Future<Map<int, int>> fetchRatingDistribution(String targetUserId) async {
    final result = await _client.rpc(
      'publisher_rating_distribution',
      params: {'p_user_id': targetUserId},
    );
    final rows = result as List<dynamic>;
    final out = <int, int>{};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final rating = int.tryParse('${map['rating']}') ?? 0;
      final total = int.tryParse('${map['total']}') ?? 0;
      if (rating >= 1 && rating <= 5) out[rating] = total;
    }
    return out;
  }

  /// Responsiveness stats via the `publisher_response_stats` RPC. Returns the
  /// first row; null when the RPC yields no rows.
  Future<ResponseStatsDto?> fetchResponseStats(String targetUserId) async {
    final result = await _client.rpc(
      'publisher_response_stats',
      params: {'p_user_id': targetUserId},
    );
    final rows = result as List<dynamic>?;
    if (rows == null || rows.isEmpty) return null;
    return ResponseStatsDto.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  /// Inserts a review. Does NOT send `reviewer_user_id` — the DB defaults it to
  /// `auth.uid()`. A unique-violation (already reviewed this seller) surfaces as
  /// a [supabase.PostgrestException] with code '23505', mapped by the repository.
  Future<void> submitReview({
    required String targetUserId,
    String? listingId,
    required int rating,
    String? comment,
  }) async {
    await _client.from('reviews').insert({
      'target_user_id': targetUserId,
      if (listingId != null) 'listing_id': listingId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }
}
