import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../listing_form/domain/entities/listing_revision.dart';
import '../../../../listing_form/domain/repositories/listing_revisions_repository.dart';
import '../entities/revision_diff.dart';

/// Phase 031 (WS-B) — admin: loads a revision plus the CURRENT live listing
/// snapshot so the review screen can render a compact current-vs-proposed diff.
@injectable
class LoadRevisionDiff {
  const LoadRevisionDiff(this._repository);

  final ListingRevisionsRepository _repository;

  Future<Result<RevisionDiff>> call({
    required String revisionId,
    required String listingId,
  }) async {
    try {
      final ListingRevision? revision = await _repository.loadRevision(
        revisionId,
      );
      if (revision == null) {
        return const FailureResult(UnknownFailure('revision not found'));
      }
      final current =
          await _repository.loadCurrentSnapshot(listingId) ??
          const <String, dynamic>{};
      return Success(
        RevisionDiff(
          revision: revision,
          current: current,
          proposed: revision.proposed,
        ),
      );
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
