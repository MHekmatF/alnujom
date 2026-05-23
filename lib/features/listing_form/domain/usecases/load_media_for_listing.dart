import 'package:injectable/injectable.dart';

import '../entities/listing_media.dart';
import '../repositories/listings_repository.dart';

/// Phase 11 — Loads every `listing_media` row for a listing, sorted by
/// `ordering ASC`. Consumed by the BLoC's draft-load handlers to populate
/// `state.media` per Q3=A's edit-in-place resubmit flow.
@injectable
class LoadMediaForListing {
  const LoadMediaForListing(this._repository);

  final ListingsRepository _repository;

  Future<List<ListingMedia>> call({required String listingId}) {
    return _repository.loadMediaForListing(listingId);
  }
}
