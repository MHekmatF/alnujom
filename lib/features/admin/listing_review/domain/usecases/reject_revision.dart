import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../../../../listing_form/domain/repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — admin: rejects a pending revision
/// (`reject_listing_revision`). The reason is encoded as the same
/// `{"preset": "<key>", "detail": "<string|null>"}` JSON shape used by
/// `listing_status_history.reason`, so existing parsers line up. The live
/// listing stays approved on its old content.
@injectable
class RejectRevision {
  const RejectRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<Result<void>> call({
    required String revisionId,
    required RejectionReason preset,
    String? detail,
  }) async {
    try {
      final trimmed = detail?.trim();
      await _repository.rejectRevision(
        revisionId: revisionId,
        reason: <String, dynamic>{
          'preset': preset.key,
          'detail': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        },
      );
      return const Success<void>(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
