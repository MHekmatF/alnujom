import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/listing_review_repository.dart';

/// Phase 12 (spec/012-listing-approval) — calls the `approve_listing` Edge
/// Function via the repository. Returns the new `publishedAt` + `expiresAt`
/// on HTTP 200; the BLoC maps the typed `Failure` subtypes from
/// `lib/core/errors/failure.dart` onto user-facing toasts.
@injectable
class ApproveListingUseCase {
  ApproveListingUseCase(this._repository);

  final ListingReviewRepository _repository;

  Future<Result<ApproveResult>> call(String listingId) {
    return _repository.approveListing(listingId);
  }
}
