import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/pending_listing_summary.dart';
import '../repositories/listing_review_repository.dart';

/// Phase 12 (spec/012-listing-approval) — loads one page of pending-review
/// listings. Cursor-paginated; first page passes `cursor: null` AND
/// subsequent pages pass the last item's `(submittedAt, id)` tuple.
@injectable
class LoadPendingQueueUseCase {
  LoadPendingQueueUseCase(this._repository);

  final ListingReviewRepository _repository;

  Future<Result<List<PendingListingSummary>>> call({
    PendingQueueCursor? cursor,
    int limit = 20,
  }) {
    return _repository.loadPendingQueue(cursor: cursor, limit: limit);
  }
}
