import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/listing_preview.dart';
import '../repositories/listing_review_repository.dart';

/// Phase 12 (spec/012-listing-approval) — loads the full listing preview
/// payload (parent listing + details + prices + media + location + publisher).
@injectable
class LoadListingPreviewUseCase {
  LoadListingPreviewUseCase(this._repository);

  final ListingReviewRepository _repository;

  Future<Result<ListingPreview>> call(String listingId) {
    return _repository.loadListingPreview(listingId);
  }
}
