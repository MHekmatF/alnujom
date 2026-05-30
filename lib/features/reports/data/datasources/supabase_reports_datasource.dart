// Phase 18 (spec/018-reports-moderation) — SupabaseReportsDatasource.
//
// SOLE importer of supabase_flutter under lib/features/reports/ per
// Constitution IX. All Supabase I/O for the reporter-facing reports feature:
//   - submit_report RPC (FR-003)
//   - v_reports view SELECT + cursor pagination (FR-022)
//   - v_reports view SELECT by listing_id (FR-023 banner)

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/report_dto.dart';

@injectable
class SupabaseReportsDatasource {
  SupabaseReportsDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Write path
  // ---------------------------------------------------------------------------

  /// Calls the `submit_report(p_listing_id, p_reason, p_note)` SECURITY DEFINER
  /// RPC. Returns the newly-created report UUID string.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - auth_required (28000) — caller is anonymous
  ///   - invalid_reason (22023) — unknown reason value
  ///   - listing_not_found (23503) — listing id does not exist
  ///   - listing_not_approved (23514) — listing is not in approved status
  ///   - already_reported (23505) — open report already exists for this
  ///     reporter+listing pair
  Future<String> submitReport(
    String listingId,
    String reasonWireValue,
    String? note,
  ) async {
    final result = await _client.rpc(
      'submit_report',
      params: {
        'p_listing_id': listingId,
        'p_reason': reasonWireValue,
        'p_note': note,
      },
    );
    return result as String;
  }

  // ---------------------------------------------------------------------------
  // Read path
  // ---------------------------------------------------------------------------

  /// Pages through the current user's reports via `public.v_reports`.
  ///
  /// Ordered newest-first by `created_at DESC`. [cursor] is an ISO-8601
  /// timestamp used as an exclusive upper bound for keyset pagination (mirrors
  /// the Phase 13 home-feed + Phase 17 favorites convention). Pass `null` for
  /// the first page.
  Future<List<ReportDto>> loadMyReports({
    String? cursor,
    int limit = 30,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <ReportDto>[];

    // Explicit self-scope: v_reports returns ALL rows to a reports.manage holder
    // (for the admin queue), so "My Reports" must filter to the caller's own
    // reports regardless of role (FR-022/FR-024).
    var query = _client
        .from('v_reports')
        .select()
        .eq('reporter_user_id', uid);

    if (cursor != null) {
      query = query.lt('created_at', cursor);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (row) =>
              ReportDto.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Returns the most-recent report the current user filed against [listingId],
  /// or `null` when none exists. Used to drive the reporter-status banner
  /// (FR-023).
  Future<ReportDto?> loadMyReportForListing(String listingId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    // Self-scope: the banner is shown ONLY for the caller's OWN report (FR-023),
    // so filter by reporter_user_id — v_reports would otherwise return any
    // user's report on this listing to a reports.manage holder.
    final rows = await _client
        .from('v_reports')
        .select()
        .eq('reporter_user_id', uid)
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return ReportDto.fromJson(
      Map<String, dynamic>.from(list.first as Map),
    );
  }
}
