// Phase 18 (spec/018-reports-moderation) — T033
// ReportsAdminRepository: abstract interface for the admin moderation
// data layer (data-model §2.6). Constitution IX: zero Supabase imports.
// Concrete implementation: ReportsAdminRepositoryImpl (T039).
import '../../../../../core/errors/result.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../entities/moderation_action_type.dart';
import '../entities/report_queue_item.dart';

abstract class ReportsAdminRepository {
  /// Loads one page of the moderation queue from public.v_reports.
  ///
  /// Filters are optional:
  ///   - [status] — restrict to a single [ReportStatus].
  ///   - [reason] — restrict to a single [ReportReason].
  ///   - [cursor] — opaque ISO-8601 `created_at` string from the last item
  ///     on the previous page; null for the first page.
  ///
  /// Results are ordered newest-first (`created_at DESC`), paginated to
  /// [limit] rows (FR-020 / SC-014).
  Future<Result<List<ReportQueueItem>>> loadQueue({
    ReportStatus? status,
    ReportReason? reason,
    String? cursor,
    int limit = 30,
  });

  /// Invokes `public.start_report_review(p_report_id)` — the Q4=B advisory
  /// soft-claim that sets `status='reviewing'` + `reviewing_by = auth.uid()`
  /// on a still-`new` report. The UPDATE is a no-op if the report is already
  /// `reviewing` (overridable lock per FR-036).
  Future<Result<void>> startReview(String reportId);

  /// Invokes the `resolve_report` Edge Function with the given [action] and
  /// optional [note]. Returns [void] on success (HTTP 200).
  ///
  /// Error codes the Edge Function may return (mapped to Failures in impl):
  ///   - 403 `permission_denied`
  ///   - 409 `already_resolved`   (SC-015)
  ///   - 404 `report_not_found`
  Future<Result<void>> resolve(
    String reportId,
    ModerationActionType action, {
    String? note,
  });
}
