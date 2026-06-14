import 'package:injectable/injectable.dart';

import '../entities/listing_revision.dart';
import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — loads a revision (proposed snapshot + manifest + status).
@injectable
class LoadRevision {
  const LoadRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<ListingRevision?> call(String revisionId) =>
      _repository.loadRevision(revisionId);
}
