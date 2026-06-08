import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/reviews_repository.dart';

/// Submits a review for a seller. The DB defaults `reviewer_user_id` to
/// `auth.uid()`, so callers never pass it. A duplicate review surfaces as an
/// [AlreadyReviewedFailure] via the repository.
@injectable
class SubmitReview {
  const SubmitReview(this._repository);

  final ReviewsRepository _repository;

  Future<Result<void>> call({
    required String targetUserId,
    String? listingId,
    required int rating,
    String? comment,
  }) {
    return _repository.submitReview(
      targetUserId: targetUserId,
      listingId: listingId,
      rating: rating,
      comment: comment,
    );
  }
}
