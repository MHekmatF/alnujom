// Phase 18 (spec/018-reports-moderation) — T038
// SupabaseReportsAdminDatasource: sole importer of package:supabase_flutter
// in lib/features/admin/reports/ (Constitution IX).
//
// Three methods:
//   - loadQueue   — v_reports PostgREST select + optional status/reason
//                   filters + cursor pagination (FR-020 / SC-014).
//   - startReview — rpc('start_report_review', …) soft-claim (Q4=B, FR-036).
//   - resolve     — functions.invoke('resolve_report', …) Edge Function call
//                   mirroring the Phase 12 approveListing/rejectListing pattern.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/report_queue_item_dto.dart';

/// Lightweight wrapper around the Supabase FunctionResponse so the repository
/// can branch on `status` without importing supabase_flutter itself.
class AdminEdgeFunctionResponse {
  AdminEdgeFunctionResponse({required this.status, required this.data});

  final int status;
  final dynamic data;
}

@injectable
class SupabaseReportsAdminDatasource {
  SupabaseReportsAdminDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ─── loadQueue ────────────────────────────────────────────────────────────

  /// Returns one page of v_reports rows ordered newest-first.
  ///
  /// [statusWire]  — `status` column wire value (e.g. 'new', 'reviewing').
  /// [reasonWire]  — `reason` column wire value (e.g. 'spam').
  /// [cursor]      — ISO-8601 `created_at` of the last item on the previous
  ///                 page; null for the first page.
  Future<List<ReportQueueItemDto>> loadQueue({
    String? statusWire,
    String? reasonWire,
    String? cursor,
    int limit = 30,
  }) async {
    var query = _client.from('v_reports').select();

    if (statusWire != null) {
      query = query.eq('status', statusWire);
    }
    if (reasonWire != null) {
      query = query.eq('reason', reasonWire);
    }
    if (cursor != null) {
      query = query.lt('created_at', cursor);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (r) => ReportQueueItemDto.fromJson(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();
  }

  // ─── startReview ──────────────────────────────────────────────────────────

  /// Invokes `public.start_report_review(p_report_id)`.
  /// The RPC self-gates on reports.manage and is a no-op if the report is
  /// already `reviewing` (advisory soft lock, FR-036).
  Future<void> startReview(String reportId) async {
    await _client.rpc(
      'start_report_review',
      params: <String, dynamic>{'p_report_id': reportId},
    );
  }

  // ─── resolve ──────────────────────────────────────────────────────────────

  /// Invokes the `resolve_report` Edge Function.
  /// Returns the raw HTTP status + response data; the repository maps errors
  /// to typed Failures (mirrors Phase 12 approveListing pattern).
  Future<AdminEdgeFunctionResponse> resolve(
    String reportId,
    String actionWire, {
    String? note,
  }) async {
    final body = <String, dynamic>{
      'report_id': reportId,
      'action': actionWire,
    };
    if (note != null && note.isNotEmpty) {
      body['note'] = note;
    }

    final response = await _client.functions.invoke(
      'resolve_report',
      body: body,
    );
    return AdminEdgeFunctionResponse(
      status: response.status,
      data: response.data,
    );
  }
}
