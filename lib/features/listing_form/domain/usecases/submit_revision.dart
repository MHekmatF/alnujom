import 'package:injectable/injectable.dart';

import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — owner `submit_listing_revision`. Moves the revision to
/// pending_review; the live listing stays approved on its old content.
@injectable
class SubmitRevision {
  const SubmitRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<void> call(String revisionId) =>
      _repository.submitRevision(revisionId);
}
