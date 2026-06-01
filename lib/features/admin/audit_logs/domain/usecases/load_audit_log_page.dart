// Phase 20 (spec/020-admin-dashboard) — T022
// LoadAuditLogPage: loads one bounded page of the audit-log viewer.
// Cursor-paginated; first page passes cursor: null.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/audit_log_entry.dart';
import '../repositories/audit_log_repository.dart';

@injectable
class LoadAuditLogPage {
  LoadAuditLogPage(this._repository);

  final AuditLogRepository _repository;

  Future<Result<List<AuditLogEntry>>> call({
    String? cursor,
    int limit = 30,
  }) {
    return _repository.loadPage(cursor: cursor, limit: limit);
  }
}
