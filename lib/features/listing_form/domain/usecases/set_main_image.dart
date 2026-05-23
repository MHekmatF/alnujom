import 'package:injectable/injectable.dart';

import '../repositories/listings_repository.dart';

/// Phase 11 — Flips `is_main=true` on the target row and clears any prior main.
///
/// The partial unique index on `(listing_id) WHERE is_main=true AND kind='image'`
/// serializes set-main at the DB layer per FR-003.
@injectable
class SetMainImage {
  const SetMainImage(this._repository);

  final ListingsRepository _repository;

  Future<void> call({
    required String listingId,
    required String mediaId,
  }) {
    return _repository.setMainImage(listingId: listingId, mediaId: mediaId);
  }
}
