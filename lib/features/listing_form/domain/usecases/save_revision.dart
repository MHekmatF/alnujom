import 'package:injectable/injectable.dart';

import '../entities/revision_manifest_item.dart';
import '../repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — owner `save_listing_revision`. Replaces the staged
/// proposal + media manifest (no live listing write).
@injectable
class SaveRevision {
  const SaveRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<void> call({
    required String revisionId,
    required Map<String, dynamic> proposed,
    required List<RevisionManifestItem> manifest,
  }) {
    return _repository.saveRevision(
      revisionId: revisionId,
      proposed: proposed,
      manifest: manifest,
    );
  }
}
