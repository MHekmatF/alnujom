// Phase 20 (spec/020-admin-dashboard) — T022
// AuditLogRepository: abstract interface for the read-only audit-log
// data layer. Constitution IX: zero Supabase imports.
// Concrete implementation: AuditLogRepositoryImpl.
import '../../../../../core/errors/result.dart';
import '../entities/audit_log_entry.dart';

abstract class AuditLogRepository {
  /// Loads one bounded page of audit_logs entries newest-first
  /// (`created_at DESC`).
  ///
  ///   - [cursor] — opaque ISO-8601 `created_at` string from the last
  ///     entry on the previous page; null for the first page.
  ///   - [limit] — bounded page size (no unbounded scan).
  ///
  /// The table is gated read-only by the `audit_logs.view` RLS policy;
  /// callers without the permission receive zero rows at the wire level.
  Future<Result<List<AuditLogEntry>>> loadPage({
    String? cursor,
    int limit = 30,
  });
}
