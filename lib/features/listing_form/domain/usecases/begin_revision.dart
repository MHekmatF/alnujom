import 'package:injectable/injectable.dart';

import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — owner-gated `begin_listing_revision`. Returns the open
/// revision id for an approved listing.
@injectable
class BeginRevision {
  const BeginRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<String> call(String listingId) =>
      _repository.beginRevision(listingId);
}
