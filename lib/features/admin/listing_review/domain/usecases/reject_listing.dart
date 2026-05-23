import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../repositories/listing_review_repository.dart';

/// Phase 12 (spec/012-listing-approval) — calls the `reject_listing` Edge
/// Function via the repository. Returns the confirmed preset + detail on
/// HTTP 200; the BLoC maps the typed `Failure` subtypes from
/// `lib/core/errors/failure.dart` onto user-facing toasts.
///
/// Per Q5=A, the dialog's UX gate enforces non-empty `detail` when
/// `preset == RejectionReason.other`. The server is permissive (FR-002(g)),
/// so this use case forwards `detail` verbatim — including the
/// already-trimmed-to-null case from `RejectReasonDialog._onConfirm`.
@injectable
class RejectListingUseCase {
  RejectListingUseCase(this._repository);

  final ListingReviewRepository _repository;

  Future<Result<RejectResult>> call(
    String listingId,
    RejectionReason preset,
    String? detail,
  ) {
    return _repository.rejectListing(listingId, preset, detail);
  }
}
