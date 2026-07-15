import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/publisher_rating.dart';
import '../entities/response_stats.dart';
import '../entities/review.dart';
import '../repositories/reviews_repository.dart';

/// Loads the three seller-trust signals for a seller in one call: aggregate
/// rating, responsiveness stats, and recent reviews. Each is independently
/// [Result]-wrapped so a partial failure (e.g. stats RPC down) still surfaces
/// the rest.
@injectable
class LoadSellerTrust {
  const LoadSellerTrust(this._repository);

  final ReviewsRepository _repository;

  Future<({
    Result<PublisherRating?> rating,
    Result<ResponseStats?> stats,
    Result<List<Review>> reviews,
    Result<Map<int, int>> distribution,
  })> call(String targetUserId, {int reviewsLimit = 20}) async {
    final results = await Future.wait([
      _repository.fetchRating(targetUserId),
      _repository.fetchResponseStats(targetUserId),
      _repository.fetchReviews(targetUserId, limit: reviewsLimit),
      _repository.fetchRatingDistribution(targetUserId),
    ]);
    return (
      rating: results[0] as Result<PublisherRating?>,
      stats: results[1] as Result<ResponseStats?>,
      reviews: results[2] as Result<List<Review>>,
      distribution: results[3] as Result<Map<int, int>>,
    );
  }
}
