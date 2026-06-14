import 'package:injectable/injectable.dart';

import '../entities/listing_revision.dart';
import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — returns the open (draft|pending_review) revision for a
/// listing, or null. Used by My Listings to surface the "edit in review" badge.
@injectable
class FindOpenRevision {
  const FindOpenRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<ListingRevision?> call(String listingId) =>
      _repository.findOpenRevision(listingId);
}
