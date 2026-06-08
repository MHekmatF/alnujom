import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/listing_review_repository.dart';

/// Phase 25 — calls the admin RPC `set_listing_featured` via the repository to
/// feature (or un-feature) a listing. Returns the new `featured_until` on
/// success; the BLoC maps the typed `Failure` subtypes from
/// `lib/core/errors/failure.dart` onto user-facing toasts.
///
/// `days <= 0` removes the featuring (the RPC clears `featured_until` to NULL).
@injectable
class FeatureListingUseCase {
  FeatureListingUseCase(this._repository);

  final ListingReviewRepository _repository;

  Future<Result<FeatureResult>> call({
    required String listingId,
    required int days,
  }) {
    return _repository.featureListing(listingId: listingId, days: days);
  }
}
