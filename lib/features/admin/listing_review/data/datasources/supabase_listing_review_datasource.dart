import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
          'id, title, property_type, purpose, created_at, '
          'publisher:profiles!publisher_user_id(full_name,phone), '
          'governorate:governorates(display_name), '
          'city:cities(display_name), '
          'area:areas(display_name), '
          'prices:listing_prices(amount,currency_code,is_primary), '
          'media:listing_media(storage_path,is_main,ordering,kind)',
        )
        .eq('status', 'pending_review');

    // Cursor: created_at strictly greater than the cursor's value, OR equal
    // with id strictly greater. PostgREST .or filter expresses this pattern.
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

    return (rows as List<dynamic>).map((r) {
      final dto = PendingListingSummaryDto.fromMap(
        Map<String, dynamic>.from(r as Map),
      );
      // Resolve the public URL for the main image inside the datasource so
      // the queue card widget stays Constitution IX-clean (no Supabase
      // imports in presentation/).
      if (dto.mainImageStoragePath != null) {
        final url = _client.storage
            .from('listing-images')
            .getPublicUrl(dto.mainImageStoragePath!);
        return dto.copyWithMainImageUrl(url);
      }
      return dto;
    }).toList();
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
          'publisher:profiles!publisher_user_id(full_name,phone), '
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
    return Map<String, dynamic>.from(rows.first);
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
    return EdgeFunctionResponse(
      status: response.status,
      data: response.data,
    );
  }
}

/// Lightweight wrapper around the Supabase `FunctionResponse` so the
/// repository can branch on `status` without importing supabase_flutter.
class EdgeFunctionResponse {
  EdgeFunctionResponse({required this.status, required this.data});

  final int status;
  final dynamic data;
}
