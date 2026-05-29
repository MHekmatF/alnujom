// Phase 18 (spec/018-reports-moderation) — T039
// ReportsAdminRepositoryImpl: concrete implementation of
// ReportsAdminRepository. Maps Edge Function HTTP error envelopes
// (contracts/phase18-resolve-report-edge-function.md) onto typed Failures.
// Constitution IX: the only Supabase import lives in the datasource.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../domain/entities/moderation_action_type.dart';
import '../../domain/entities/report_queue_item.dart';
import '../../domain/repositories/reports_admin_repository.dart';
import '../datasources/supabase_reports_admin_datasource.dart';

/// Phase 18 — admin moderation repository.
///
/// Error-code → Failure mapping for the resolve_report Edge Function
/// (mirrors Phase 12 _mapEdgeFunctionError pattern):
///   403 permission_denied → PermissionDeniedFailure
///   409 already_resolved  → AlreadyResolvedFailure
///   404 report_not_found  → ReportNotFoundFailure
///   other                 → UnknownFailure
@LazySingleton(as: ReportsAdminRepository)
class ReportsAdminRepositoryImpl implements ReportsAdminRepository {
  ReportsAdminRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'ReportsAdminRepositoryImpl';

  final SupabaseReportsAdminDatasource _datasource;
  final AppLogger _logger;

  // ─── loadQueue ────────────────────────────────────────────────────────────

  @override
  Future<Result<List<ReportQueueItem>>> loadQueue({
    ReportStatus? status,
    ReportReason? reason,
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final dtos = await _datasource.loadQueue(
        statusWire: status?.wireValue,
        reasonWire: reason?.wireValue,
        cursor: cursor,
        limit: limit,
      );
      return Success(dtos.map((dto) => dto.toEntity()).toList(growable: false));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadQueue failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── startReview ──────────────────────────────────────────────────────────

  @override
  Future<Result<void>> startReview(String reportId) async {
    try {
      await _datasource.startReview(reportId);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'startReview failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── resolve ──────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> resolve(
    String reportId,
    ModerationActionType action, {
    String? note,
  }) async {
    try {
      final response = await _datasource.resolve(
        reportId,
        action.wireValue,
        note: note,
      );
      final httpStatus = response.status;
      final data = response.data;

      if (httpStatus == 200) {
        return const Success(null);
      }

      return FailureResult(_mapEdgeFunctionError(httpStatus, data));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'resolve failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  // ─── Edge Function error mapping ──────────────────────────────────────────

  Failure _mapEdgeFunctionError(int httpStatus, dynamic data) {
    final code = data is Map ? data['code']?.toString() : null;

    switch (code) {
      case 'permission_denied':
        return const PermissionDeniedFailure();
      case 'already_resolved':
        return const AlreadyResolvedFailure();
      case 'report_not_found':
        return const ReportNotFoundFailure();
      case 'invalid_action':
      case 'invalid_report_id':
      case 'invalid_request':
        return const UnknownFailure('invalid_request');
      default:
        return UnknownFailure(
          'resolve_report: http=$httpStatus code=$code',
        );
    }
  }
}

// Phase 18 typed Failures for the resolve_report Edge Function error codes.

final class AlreadyResolvedFailure extends Failure {
  const AlreadyResolvedFailure()
      : super('Report has already been resolved.');
}

final class ReportNotFoundFailure extends Failure {
  const ReportNotFoundFailure() : super('Report not found.');
}
