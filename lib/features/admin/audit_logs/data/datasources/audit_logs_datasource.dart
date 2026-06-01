// Phase 20 (spec/020-admin-dashboard) — T022
// AuditLogsDatasource: sole importer of package:supabase_flutter in
// lib/features/admin/audit_logs/ (Constitution IX).
//
// Reads public.audit_logs (gated by the audit_logs.view RLS policy
// swapped in 20260601120004) newest-first with bounded cursor
// pagination — no unbounded scan (contract phase20-audit-logs-read).
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/audit_log_entry_dto.dart';

@injectable
class AuditLogsDatasource {
  AuditLogsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Returns one bounded page of audit_logs rows ordered newest-first.
  ///
  /// [cursor] — ISO-8601 `created_at` of the last row on the previous
  ///            page; null for the first page. Pagination is bounded by
  ///            [limit] (no unbounded scan).
  Future<List<AuditLogEntryDto>> loadPage({
    String? cursor,
    int limit = 30,
  }) async {
    var query = _client.from('audit_logs').select(
          'id,actor_user_id,action,target_type,target_id,'
          'before_state,after_state,created_at',
        );

    if (cursor != null) {
      query = query.lt('created_at', cursor);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (r) => AuditLogEntryDto.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList(growable: false);
  }
}
