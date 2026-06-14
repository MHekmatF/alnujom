import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../listing_form/domain/entities/pending_revision.dart';
import '../../../../listing_form/domain/repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — admin: lists `pending_review` listing revisions for the
/// moderation queue. Wraps the listing_form revisions repository (the sole
/// Supabase importer) and surfaces a typed [Result].
@injectable
class LoadPendingRevisions {
  const LoadPendingRevisions(this._repository);

  final ListingRevisionsRepository _repository;

  Future<Result<List<PendingRevision>>> call({int limit = 50}) async {
    try {
      final rows = await _repository.listPendingRevisions(limit: limit);
      return Success(rows);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
