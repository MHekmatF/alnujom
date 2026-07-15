import '../../../../core/errors/result.dart';
import '../entities/publisher_rating.dart';
import '../entities/response_stats.dart';
import '../entities/review.dart';

/// Seller-trust repository for the listing-details page.
///
/// Mirrors the `SimilarListingsRepository` idiom: every method returns a
/// [Result] so the cubit never sees a raw exception. A network/PostgREST error
/// surfaces as a [FailureResult]; an absent rating/stats row is a [Success] with
/// a null payload (the UI omits the corresponding chrome gracefully).
abstract class ReviewsRepository {
  /// Recent reviews for the seller, newest-first.
  Future<Result<List<Review>>> fetchReviews(
    String targetUserId, {
    int limit,
  });

  /// Aggregate rating — null when the seller has no reviews yet.
  Future<Result<PublisherRating?>> fetchRating(String targetUserId);

  /// Responsiveness stats — null when the RPC yields no row.
  Future<Result<ResponseStats?>> fetchResponseStats(String targetUserId);

  /// Rating distribution (star 1..5 → count) for [targetUserId]; empty when the
  /// seller has no reviews.
  Future<Result<Map<int, int>>> fetchRatingDistribution(String targetUserId);

  /// Submits a review. A unique-violation (already reviewed) surfaces as an
  /// [AlreadyReviewedFailure].
  Future<Result<void>> submitReview({
    required String targetUserId,
    String? listingId,
    required int rating,
    String? comment,
  });
}
