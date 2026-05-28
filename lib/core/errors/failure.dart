// Phase 5 (spec/005-auth-profile) loosened from `sealed` to `abstract` so
// feature folders can define their own typed failure hierarchies (AuthFailure,
// ProfileFailure) that still slot into `Result<T>` / `FailureResult<T>`.
// The four general failures below remain `final` and Phase 4's call sites are
// unchanged.
abstract class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause, super.stackTrace});
}

final class ConfigFailure extends Failure {
  const ConfigFailure(super.message, {super.cause, super.stackTrace});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}

// Phase 12 (spec/012-listing-approval) — 5 typed Failure subtypes for the
// approve_listing / reject_listing Edge Function error codes (R-52).
// Each maps to a specific HTTP error code returned by the Edge Functions.

final class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure() : super('Permission denied.');
}

final class InvalidStatusTransitionFailure extends Failure {
  const InvalidStatusTransitionFailure({required this.currentStatus})
    : super('Invalid status transition.');
  final String currentStatus;
}

final class AlreadyActedOnFailure extends Failure {
  const AlreadyActedOnFailure({required this.currentStatus})
    : super('Listing has already been acted on.');
  final String currentStatus;
}

final class InvalidReasonPresetFailure extends Failure {
  const InvalidReasonPresetFailure()
    : super('Invalid rejection reason preset.');
}

final class ReasonDetailTooLongFailure extends Failure {
  const ReasonDetailTooLongFailure({required this.max})
    : super('Rejection reason detail exceeds maximum length.');
  final int max;
}

// Phase 13 (spec/013-home-and-details) — emitted when
// ListingDetailsBloc's data source returns null from .maybeSingle().
// The two cases (RLS hides the row OR row doesn't exist) are
// indistinguishable per Constitution III + FR-024. Per R-68.
final class ListingNotFoundFailure extends Failure {
  const ListingNotFoundFailure() : super('Listing not found.');
}

// Phase 16 (spec/016-contact-inquiries) — validation failure for
// InquirySubmission.validate() + RPC-level input validation codes.
// [code] carries a localization key (e.g. 'invalid_sender_name').
final class ValidationFailure extends Failure {
  const ValidationFailure(this.code) : super('Validation failed: $code');
  final String code;
}

// Phase 16 (spec/016-contact-inquiries) — emitted when the
// enforce_inquiry_transition trigger rejects a status mutation
// (SQLSTATE 23514 with 'invalid_inquiry_transition' in the message).
final class TransitionInvalidFailure extends Failure {
  const TransitionInvalidFailure()
    : super('Invalid inquiry status transition.');
}
