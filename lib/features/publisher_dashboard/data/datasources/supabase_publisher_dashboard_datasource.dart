import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/listing/rejection_reason.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/moderation_history_entry.dart';
import '../dtos/publisher_listing_dto.dart';

/// Sole importer of `package:supabase_flutter` in
/// `lib/features/publisher_dashboard/` per Constitution IX.
///
/// Reads the SQL view `public.v_publisher_listings` (created in Phase 2
/// migration 8). The view does the most-recent-history-row + primary-price
/// joins server-side, so this datasource is a single PostgREST query.
@injectable
class SupabasePublisherDashboardDatasource {
  SupabasePublisherDashboardDatasource(this._client);

  final SupabaseClient _client;

  Future<List<PublisherListingDto>> listMyListings({
    String? statusFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    // "My Listings" is always scoped to the signed-in user's OWN listings.
    // The view's RLS would otherwise surface EVERY listing to a moderator who
    // holds `listings.view_all`, so this screen must filter on
    // `publisher_user_id` explicitly — admins moderate other people's listings
    // through the separate admin review queue, not here. (Found in QA: another
    // user's listing appeared in an admin's "My Listings".)
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <PublisherListingDto>[];
    var query = _client
        .from('v_publisher_listings')
        .select()
        .eq('publisher_user_id', uid);
    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((r) => PublisherListingDto.fromMap(r)).toList();
  }

  /// Renews a listing by extending its `expires_at` by [days] days via the
  /// owner-gated `public.renew_listing` SECURITY DEFINER RPC. Returns the new
  /// `expires_at` timestamp (UTC). The RPC enforces `auth.uid()` == the
  /// listing's publisher, so no extra owner check is needed here.
  Future<DateTime?> renewListing({
    required String listingId,
    int days = 30,
  }) async {
    final result = await _client.rpc<dynamic>(
      'renew_listing',
      params: {'p_listing_id': listingId, 'p_days': days},
    );
    if (result == null) return null;
    return DateTime.parse(result as String);
  }

  // ─── Phase 12 / US2 — moderation history ────────────────────────────────

  /// Loads the full chronological moderation history for one listing.
  /// Contract: `contracts/phase12-moderation-history-page.md` §Data source.
  ///
  /// RLS on `public.listing_status_history` enforces
  /// `publisher_user_id = auth.uid()` — no extra owner check needed.
  Future<List<ModerationHistoryEntry>> loadModerationHistory(
    String listingId,
  ) async {
    final rows = await _client
        .from('listing_status_history')
        .select('id, previous_status, new_status, changed_at, reason')
        .eq('listing_id', listingId)
        .order('changed_at', ascending: true);
    return (rows as List<dynamic>)
        .map((r) => _mapRowToEntry(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  /// Returns the most recent `rejected` history row for a listing, or null
  /// when none exist. Indexed lookup per
  /// `contracts/phase12-publisher-rejection-banner.md`.
  Future<ModerationHistoryEntry?> loadMostRecentRejection(
    String listingId,
  ) async {
    final rows = await _client
        .from('listing_status_history')
        .select('id, previous_status, new_status, changed_at, reason')
        .eq('listing_id', listingId)
        .eq('new_status', 'rejected')
        .order('changed_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return _mapRowToEntry(Map<String, dynamic>.from(list.first as Map));
  }

  /// Decodes one history row, parsing Q4=A JSON `reason` defensively:
  /// only treats the column as JSON when it starts with `{` — guards
  /// against any pre-Phase-12 plain-text rows (none expected in prod;
  /// possible in development DBs).
  ModerationHistoryEntry _mapRowToEntry(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final newStatusRaw = row['new_status'] as String;
    final previousStatusRaw = row['previous_status'] as String?;
    final changedAtRaw = row['changed_at'] as String;
    final reasonRaw = row['reason'] as String?;

    RejectionReason? preset;
    String? detail;
    if (reasonRaw != null && reasonRaw.startsWith('{')) {
      try {
        final parsed = jsonDecode(reasonRaw);
        if (parsed is Map<String, dynamic>) {
          final presetKey = parsed['preset']?.toString();
          if (presetKey != null) {
            try {
              preset = RejectionReason.fromKey(presetKey);
            } on ArgumentError {
              preset = null;
            }
          }
          final detailRaw = parsed['detail'];
          detail = detailRaw is String ? detailRaw : null;
        }
      } on FormatException {
        // Legacy non-JSON row — preset/detail stay null.
      }
    }

    return ModerationHistoryEntry(
      id: id,
      previousStatus: previousStatusRaw == null
          ? null
          : ListingStatusDb.fromDbValue(previousStatusRaw),
      newStatus: ListingStatusDb.fromDbValue(newStatusRaw),
      changedAt: DateTime.parse(changedAtRaw),
      rejectionPreset: preset,
      rejectionDetail: detail,
    );
  }
}
