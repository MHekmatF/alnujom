// Phase 19 (spec/019-agencies) — T039
// AgenciesAdminRepository: abstract interface for the admin verification-queue
// data layer (data-model §2.7). Constitution IX: zero Supabase imports.
// Concrete implementation: AgenciesAdminRepositoryImpl (T043).
import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../entities/agency_verification_item.dart';

abstract class AgenciesAdminRepository {
  /// Loads one page of the admin verification queue.
  ///
  /// [status]  — optional filter on `agency_status` wire value.
  /// [cursor]  — opaque ISO-8601 `submitted_at` string from the last item
  ///             on the previous page; null for the first page.
  ///
  /// Returns the list ordered newest-first (`submitted_at DESC`), paginated
  /// to [limit] rows (FR-007 / SC-015).
  Future<Result<List<AgencyVerificationItem>>> loadQueue({
    AgencyStatus? status,
    String? cursor,
    int limit = 30,
  });

  /// Loads the full detail for a single agency, including the admin-only
  /// decrypted `idDocumentNumber` and `commercialRegistrationNumber` from
  /// Vault (via `app_vault_secret_for_agency`). Only populated for
  /// `agencies.view` holders.
  Future<Result<AgencyVerificationItem>> loadDetail(String agencyId);

  /// Invokes `moderate_agency` Edge Function with action=`approve`.
  /// Precondition: agency has a pending verification request.
  Future<Result<void>> approve(String agencyId);

  /// Invokes `moderate_agency` Edge Function with action=`reject`.
  /// [reason] must carry a non-empty `preset` and optional `detail`.
  Future<Result<void>> reject(
    String agencyId, {
    required String preset,
    String? detail,
  });

  /// Invokes `moderate_agency` Edge Function with action=`suspend`.
  /// Precondition: agency is currently `approved`.
  Future<Result<void>> suspend(String agencyId, {String? reason});

  /// Invokes `moderate_agency` Edge Function with action=`reinstate`.
  /// Precondition: agency is currently `suspended`.
  Future<Result<void>> reinstate(String agencyId);
}

// ─── Failure hierarchy ────────────────────────────────────────────────────────

sealed class AgenciesAdminFailure extends Failure {
  const AgenciesAdminFailure(super.message, {super.cause, super.stackTrace});
}

final class AgencyNotFoundFailure extends AgenciesAdminFailure {
  const AgencyNotFoundFailure({super.cause, super.stackTrace})
      : super('agency_not_found');
}

final class AgencyInvalidTransitionFailure extends AgenciesAdminFailure {
  const AgencyInvalidTransitionFailure({super.cause, super.stackTrace})
      : super('invalid_transition');
}

final class AgencyNameTakenFailure extends AgenciesAdminFailure {
  const AgencyNameTakenFailure({super.cause, super.stackTrace})
      : super('name_taken');
}

final class AgencyNoPendingVerificationFailure extends AgenciesAdminFailure {
  const AgencyNoPendingVerificationFailure({super.cause, super.stackTrace})
      : super('no_pending_verification');
}

final class AgencyRejectionReasonRequiredFailure extends AgenciesAdminFailure {
  const AgencyRejectionReasonRequiredFailure({super.cause, super.stackTrace})
      : super('rejection_reason_required');
}

final class AgencyAdminPermissionDeniedFailure extends AgenciesAdminFailure {
  const AgencyAdminPermissionDeniedFailure({super.cause, super.stackTrace})
      : super('permission_denied');
}

final class AgencyAdminUnknownFailure extends AgenciesAdminFailure {
  const AgencyAdminUnknownFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}
