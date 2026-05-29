// Phase 18 (spec/018-reports-moderation) — ReportsRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.

import '../../../../core/errors/result.dart';
import '../entities/report.dart';
import '../entities/report_reason.dart';

abstract interface class ReportsRepository {
  /// Calls the `submit_report(p_listing_id, p_reason, p_note)` SECURITY DEFINER
  /// RPC. Authenticated-only; approved listings only; deduped (at most one open
  /// report per reporter+listing).
  ///
  /// Returns [Success] with the new report UUID on success.
  /// Returns [FailureResult] on:
  ///   - auth_required (28000)
  ///   - invalid_reason (22023)
  ///   - listing_not_found (23503)
  ///   - listing_not_approved (23514)
  ///   - already_reported (23505) — open report already exists
  ///   - network / unknown errors
  Future<Result<String>> submitReport(
    String listingId,
    ReportReason reason,
    String? note,
  );

  /// Pages through the authenticated user's own reports via `public.v_reports`
  /// (self-scoped by RLS), ordered newest-first by `created_at DESC`.
  ///
  /// [cursor] is an ISO-8601 `created_at` timestamp used as an exclusive upper
  /// bound for keyset pagination (mirrors Phase 13 home-feed + Phase 17
  /// favorites pattern). Pass `null` for the first page.
  /// [limit] defaults to 30 (FR-022 / R-117 convention).
  Future<Result<List<Report>>> loadMyReports({
    String? cursor,
    int limit = 30,
  });

  /// Returns the most-recent report the current user filed against [listingId],
  /// or `null` when no such report exists.
  ///
  /// Used by [ListingReportStatusCubit] to drive the reporter-status banner on
  /// the listing-details page (FR-023).
  Future<Result<Report?>> loadMyReportForListing(String listingId);
}
