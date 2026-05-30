// Phase 19 (spec/019-agencies) — T043
// AgenciesAdminRepositoryImpl: concrete implementation of
// AgenciesAdminRepository. Maps moderate_agency Edge Function HTTP error
// envelopes (contracts/phase19-moderate-agency-edge-function.md) onto typed
// Failures. Constitution IX: the only Supabase import lives in the datasource.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../../domain/entities/agency_verification_item.dart';
import '../../domain/repositories/agencies_admin_repository.dart';
import '../datasources/supabase_agencies_admin_datasource.dart';

/// Phase 19 — admin agencies moderation repository.
///
/// Error-code → Failure mapping for the moderate_agency Edge Function
/// (mirrors Phase 12 / Phase 18 _mapEdgeFunctionError pattern):
///   403 permission_denied          → AgencyAdminPermissionDeniedFailure
///   404 agency_not_found           → AgencyNotFoundFailure
///   409 invalid_transition         → AgencyInvalidTransitionFailure
///   409 name_taken                 → AgencyNameTakenFailure
///   409 no_pending_verification    → AgencyNoPendingVerificationFailure
///   400 rejection_reason_required  → AgencyRejectionReasonRequiredFailure
///   other                          → AgencyAdminUnknownFailure
@LazySingleton(as: AgenciesAdminRepository)
class AgenciesAdminRepositoryImpl implements AgenciesAdminRepository {
  AgenciesAdminRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'AgenciesAdminRepositoryImpl';

  final SupabaseAgenciesAdminDatasource _datasource;
  final AppLogger _logger;

  // ─── loadQueue ────────────────────────────────────────────────────────────

  @override
  Future<Result<List<AgencyVerificationItem>>> loadQueue({
    AgencyStatus? status,
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final dtos = await _datasource.loadQueue(
        statusWire: status?.wireValue,
        cursor: cursor,
        limit: limit,
      );
      return Success(
        dtos.map((dto) => dto.toEntity()).toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadQueue failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        AgencyAdminUnknownFailure(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ─── loadDetail ───────────────────────────────────────────────────────────

  @override
  Future<Result<AgencyVerificationItem>> loadDetail(String agencyId) async {
    try {
      final dto = await _datasource.loadDetail(agencyId);
      return Success(dto.toEntity());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadDetail failed for agencyId=$agencyId.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        AgencyAdminUnknownFailure(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ─── approve ──────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> approve(String agencyId) async {
    return _callModerate(agencyId, 'approve');
  }

  // ─── reject ───────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> reject(
    String agencyId, {
    required String preset,
    String? detail,
  }) async {
    return _callModerate(agencyId, 'reject', preset: preset, detail: detail);
  }

  // ─── suspend ──────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> suspend(String agencyId, {String? reason}) async {
    return _callModerate(agencyId, 'suspend', preset: reason);
  }

  // ─── reinstate ────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> reinstate(String agencyId) async {
    return _callModerate(agencyId, 'reinstate');
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  Future<Result<void>> _callModerate(
    String agencyId,
    String action, {
    String? preset,
    String? detail,
  }) async {
    try {
      final response = await _datasource.moderate(
        agencyId,
        action,
        preset: preset,
        detail: detail,
      );

      if (response.status == 200) {
        return const Success(null);
      }

      return FailureResult(_mapEdgeFunctionError(response.status, response.data));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        '$action failed for agencyId=$agencyId.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        AgencyAdminUnknownFailure(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Maps Edge Function HTTP error responses to typed Failures.
  ///
  /// Contract (phase19-moderate-agency-edge-function.md):
  ///   403 → permission_denied
  ///   404 → agency_not_found
  ///   409 → invalid_transition | name_taken | no_pending_verification
  ///   400 → rejection_reason_required
  Failure _mapEdgeFunctionError(int httpStatus, dynamic data) {
    final code = data is Map ? data['code']?.toString() : null;

    switch (code) {
      case 'permission_denied':
        return const AgencyAdminPermissionDeniedFailure();
      case 'agency_not_found':
        return const AgencyNotFoundFailure();
      case 'invalid_transition':
        return const AgencyInvalidTransitionFailure();
      case 'name_taken':
        return const AgencyNameTakenFailure();
      case 'no_pending_verification':
        return const AgencyNoPendingVerificationFailure();
      case 'rejection_reason_required':
        return const AgencyRejectionReasonRequiredFailure();
      default:
        return AgencyAdminUnknownFailure(
          'moderate_agency: http=$httpStatus code=$code',
        );
    }
  }
}
