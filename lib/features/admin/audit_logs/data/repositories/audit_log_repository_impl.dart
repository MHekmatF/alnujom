// Phase 20 (spec/020-admin-dashboard) — T022
// AuditLogRepositoryImpl: concrete read-only implementation of
// AuditLogRepository. Maps datasource errors onto typed Failures.
// Constitution IX: the only Supabase import lives in the datasource.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/audit_log_repository.dart';
import '../datasources/audit_logs_datasource.dart';

@LazySingleton(as: AuditLogRepository)
class AuditLogRepositoryImpl implements AuditLogRepository {
  AuditLogRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'AuditLogRepositoryImpl';

  final AuditLogsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<AuditLogEntry>>> loadPage({
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final dtos = await _datasource.loadPage(cursor: cursor, limit: limit);
      return Success(dtos.map((dto) => dto.toEntity()).toList(growable: false));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'loadPage failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
