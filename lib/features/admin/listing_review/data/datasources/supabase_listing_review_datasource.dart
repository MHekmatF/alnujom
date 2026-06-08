import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../../core/listing/rejection_reason.dart';
import '../dtos/pending_listing_summary_dto.dart';

/// Phase 12 (spec/012-listing-approval) — sole importer of
/// `package:supabase_flutter` in `lib/features/admin/listing_review/`
/// per Constitution IX.
///
/// Three methods:
/// - `loadPendingQueue` — admin queue page (one PostgREST nested-select).
/// - `loadListingPreview` — admin preview page (one PostgREST nested-select
///    joining details + prices + media + location + publisher snippet).
/// - `approveListing` — invokes the Phase 12 `approve_listing` Edge Function.
///
/// Phase 4 (US2) extends with `rejectListing(...)` calling the
/// `reject_listing` Edge Function. The methods are intentionally non-private
/// so Phase 4 can extend without refactor.
@injectable
class SupabaseListingReviewDatasource {
  SupabaseListingReviewDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ─── loadPendingQueue ──────────────────────────────────────────────────

  /// Fetches one page of `pending_review` listings ordered oldest-first
  /// per analysis finding C8 (cursor field = `listings.created_at`).
  /// `cursor` represents the (createdAt, id) tuple of the last item from
  /// the previous page; first page passes `null`.
  Future<List<PendingListingSummaryDto>> loadPendingQueue({
    DateTime? cursorCreatedAt,
    String? cursorId,
    int limit = 20,
  }) async {
    final query = _client
        .from('listings')
        .select(
          'id, title, property_type, purpose, created_at, publisher_user_id, '
          'governorate:governorates(display_name), '
          'city:cities(display_name), '
          'area:areas(display_name), '
          'prices:listing_prices(amount,currency_code,is_primary), '
          'media:listing_media(storage_path,is_main,ordering,kind)',
        )
        .eq('status', 'pending_review');

    final filtered = cursorCreatedAt != null && cursorId != null
        ? query.or(
            'created_at.gt.${cursorCreatedAt.toIso8601String()},'
            'and(created_at.eq.${cursorCreatedAt.toIso8601String()},'
            'id.gt.$cursorId)',
          )
        : query;

    final rows = await filtered
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);

    final rowMaps = (rows as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    // Phase 5+ pattern: listings.publisher_user_id FKs to auth.users.id, not
    // profiles.id, so PostgREST nested-resource syntax cannot pivot to
    // profiles. Batch-fetch profiles in a second query and merge in Dart.
    final publisherIds = rowMaps
        .map((r) => r['publisher_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profilesByUserId = await _loadProfiles(publisherIds);

    for (final row in rowMaps) {
      final uid = row['publisher_user_id'] as String?;
      row['publisher'] = uid != null ? profilesByUserId[uid] : null;
    }

    return rowMaps.map((row) {
      final dto = PendingListingSummaryDto.fromMap(row);
      if (dto.mainImageStoragePath != null) {
        final url = _client.storage
            .from('listing-images')
            .getPublicUrl(dto.mainImageStoragePath!);
        return dto.copyWithMainImageUrl(url);
      }
      return dto;
    }).toList();
  }

  /// Batch-loads profile snippets for the given publisher user-ids.
  /// Returns a map keyed by `user_id`; missing ids resolve to null at call-site.
  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('user_id, full_name, phone')
        .inFilter('user_id', userIds);
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['user_id'] as String?;
      if (uid != null) map[uid] = m;
    }
    return map;
  }

  // ─── loadListingPreview ────────────────────────────────────────────────

  /// Fetches the full preview payload for one listing. Returns the raw
  /// nested-row map; the repository assembles the domain `ListingPreview`
  /// from this shape using Phase 8/9/10/11 DTO factories.
  Future<Map<String, dynamic>?> loadListingPreview(String listingId) async {
    final rows = await _client
        .from('listings')
        .select(
          '*, '
          'governorate:governorates(*), '
          'city:cities(*), '
          'area:areas(*), '
          'listing_details(*), '
          'prices:listing_prices(*), '
          'media:listing_media(*)',
        )
        .eq('id', listingId)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first);

    // Same two-step join as loadPendingQueue — see _loadProfiles dartdoc.
    final uid = row['publisher_user_id'] as String?;
    if (uid != null) {
      final profiles = await _loadProfiles([uid]);
      row['publisher'] = profiles[uid];
    } else {
      row['publisher'] = null;
    }
    return row;
  }

  // ─── approveListing ────────────────────────────────────────────────────

  /// Invokes the Phase 12 `approve_listing` Edge Function. Returns the raw
  /// response data and HTTP status code; the repository maps the response
  /// onto the typed `Failure` subtypes per R-52.
  ///
  /// The Edge Function is responsible for the JWT-bound permission check,
  /// the FR-024 session-variable handoff, and the status-guarded UPDATE.
  Future<EdgeFunctionResponse> approveListing(String listingId) async {
    final response = await _client.functions.invoke(
      'approve_listing',
      body: <String, dynamic>{'listing_id': listingId},
    );
    return EdgeFunctionResponse(status: response.status, data: response.data);
  }

  // ─── rejectListing ─────────────────────────────────────────────────────

  /// Invokes the Phase 12 `reject_listing` Edge Function. The function
  /// validates the preset key + detail length, then writes the Q4=A
  /// JSON-encoded reason into `listing_status_history.reason` via the
  /// FR-024 session-variable handoff.
  ///
  /// Detail is sent only when non-null AND non-empty (trimmed). The server
  /// is permissive on empty detail per FR-002(g) — the UX dialog gates the
  /// non-empty detail for `RejectionReason.other` (FR-013(d)).
  Future<EdgeFunctionResponse> rejectListing(
    String listingId,
    RejectionReason preset,
    String? detail,
  ) async {
    final body = <String, dynamic>{
      'listing_id': listingId,
      'reason_preset': preset.key,
    };
    if (detail != null && detail.trim().isNotEmpty) {
      body['reason_detail'] = detail;
    }
    final response = await _client.functions.invoke(
      'reject_listing',
      body: body,
    );
    return EdgeFunctionResponse(status: response.status, data: response.data);
  }

  // ─── featureListing ────────────────────────────────────────────────────

  /// Calls the admin RPC `set_listing_featured(p_listing_id, p_days)` which
  /// sets `listings.featured_until` to `now() + p_days` (or clears it to NULL
  /// when `p_days <= 0`). The RPC is SECURITY DEFINER and internally gated on
  /// the `listings.edit_any` permission; it returns the new `featured_until`
  /// (a `timestamptz`, or NULL when featuring was removed).
  ///
  /// Returns the parsed `featured_until` as a `DateTime?` — null means the
  /// listing is no longer featured.
  Future<DateTime?> featureListing({
    required String listingId,
    required int days,
  }) async {
    final result = await _client.rpc(
      'set_listing_featured',
      params: <String, dynamic>{
        'p_listing_id': listingId,
        'p_days': days,
      },
    );
    // Scalar RETURNS timestamptz → the client yields the ISO-8601 string
    // (or null when p_days <= 0 cleared the featuring).
    if (result == null) return null;
    final raw = result.toString();
    if (raw.isEmpty) return null;
    return DateTime.parse(raw);
  }
}

/// Lightweight wrapper around the Supabase `FunctionResponse` so the
/// repository can branch on `status` without importing supabase_flutter.
class EdgeFunctionResponse {
  EdgeFunctionResponse({required this.status, required this.data});

  final int status;
  final dynamic data;
}
