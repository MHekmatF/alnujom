import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../listing_form/domain/repositories/listing_revisions_repository.dart';

/// Phase 031 (WS-B) — admin: applies a pending revision (`apply_listing_revision`),
/// writing the proposal back onto the live listing + reconciling media. Requires
/// `listings.review` (enforced inside the SECURITY DEFINER RPC).
@injectable
class ApplyRevision {
  const ApplyRevision(this._repository);

  final ListingRevisionsRepository _repository;

  Future<Result<void>> call(String revisionId) async {
    try {
      await _repository.applyRevision(revisionId);
      return const Success<void>(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
