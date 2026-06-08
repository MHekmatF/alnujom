import '../../../../core/errors/failure.dart';

/// Emitted when a buyer tries to review a seller they have already reviewed
/// (the `reviews` UNIQUE(reviewer_user_id, target_user_id) constraint —
/// PostgREST/SQLSTATE 23505). The UI shows a friendly "already reviewed" message
/// rather than a generic error.
final class AlreadyReviewedFailure extends Failure {
  const AlreadyReviewedFailure() : super('You have already reviewed this seller.');
}
