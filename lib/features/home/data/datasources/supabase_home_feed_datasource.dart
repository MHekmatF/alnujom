import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/cursor.dart';
import '../dtos/home_listing_card_dto.dart';

/// Phase 13 (spec/013-home-and-details) — sole importer of
/// `package:supabase_flutter` under `lib/features/home/` per Constitution IX
/// + FR-030.
///
/// Implements the home-feed read per data-model.md §2.1 + contracts/
/// phase13-home-feed-query.md + research.md R-62 (CORRECTED) + R-63.
///
/// CRITICAL — cursor predicate is a SINGLE `.or()` filter expressing the
/// lexicographic strict-less-than tuple compare on (published_at, id):
///
///     WHERE (published_at < X) OR (published_at = X AND id < Y)
///
/// per research.md R-62. Do NOT replace with two chained less-than filters
/// on published_at and id — that approach was REJECTED at /speckit-analyze
/// 2026-05-23 because it skips rows that should appear on the next page
/// (specifically, rows with id >= Y and published_at < X), breaking US5.
@injectable
class SupabaseHomeFeedDatasource {
  SupabaseHomeFeedDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Fetches one page of the home feed. Returns at most 20 rows ordered by
  /// `(published_at DESC, id DESC)`.
  ///
  /// RLS is the SOLE filter for `status = approved` per FR-018 — this
  /// method MUST NOT add an application-layer status filter on the listings
  /// table.
  Future<List<HomeListingCardDto>> fetchPage({Cursor? cursor}) async {
    // Embedded selects per R-63. `listing_prices!inner` forces an INNER JOIN
    // so rows without a primary price are excluded (defensive — Phase 10's
    // submit_listing RPC always inserts a primary price). `listing_media`
    // is a LEFT JOIN; the `.eq()` filters below narrow it to is_main=true
    // AND kind='image' so a card surfaces at most one thumbnail row.
    final base = _client
        .from('listings')
        .select(
          'id, title, property_type, purpose, governorate_id, city_id, published_at, '
          // Phase 25 uplift v2 — surface the key facts (beds·baths·area) on the
          // card. Columns live directly on `listings`; no migration needed.
          'rooms, bathrooms, area_size, floor, '
          'listing_prices!inner(currency_code, amount, is_primary), '
          'listing_media(storage_path, ordering, is_main, kind), '
          'governorate:governorates(display_name), '
          'city:cities(display_name), '
          // Phase 19 (FR-022) — embed the owning agency for the verified badge.
          // LEFT JOIN (no !inner) so non-agency listings are unaffected; the
          // DTO renders the badge only when the agency status is 'approved'.
          'agency:agencies(id, name, logo_path, status)',
        );

    // Embedded-select filters (PostgREST syntax) — apply to the JOINed
    // tables, not to `listings`.
    //
    // `published_at IS NOT NULL` keeps the public feed to PUBLISHED rows only.
    // This is NOT a status-column filter (FR-018 keeps status gating in RLS) —
    // it excludes the caller's OWN draft/pending listings, which the listings
    // RLS surfaces to owners and which carry a null published_at. Without it,
    // a signed-in publisher's unpublished row reaches HomeListingCardDto.fromJson
    // and crashes the whole feed on `DateTime.parse(null)`.
    var query = base
        .eq('listing_prices.is_primary', true)
        .eq('listing_media.is_main', true)
        .eq('listing_media.kind', 'image')
        .not('published_at', 'is', null);

    // R-62 (CORRECTED) cursor predicate. Single `.or()` filter; do NOT use
    // two chained less-than filters on (published_at, id) — that silently
    // skips rows on tied published_at boundaries, breaking US5.
    if (cursor != null) {
      final pubAt = cursor.publishedAt.toIso8601String();
      query = query.or(
        'published_at.lt.$pubAt,'
        'and(published_at.eq.$pubAt,id.lt.${cursor.id})',
      );
    }

    final rows = await query
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(20);

    return (rows as List<dynamic>).map((r) {
      var dto = HomeListingCardDto.fromJson(
        Map<String, dynamic>.from(r as Map),
      );
      // Resolve the agency logo public URL (agency-assets bucket) when present.
      // Guard against double-prefix: logo_path may already be a full public URL
      // (stored by uploadAgencyAsset which calls getPublicUrl at upload time).
      // When it starts with 'http', use it as-is; otherwise call getPublicUrl.
      final logoPath = dto.agencyLogoPath;
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoUrl = logoPath.startsWith('http')
            ? logoPath
            : _client.storage.from('agency-assets').getPublicUrl(logoPath);
        dto = dto.copyWithAgencyLogoUrl(logoUrl);
      }
      final path = dto.mainImage?.storagePath;
      if (path == null) return dto;
      final url = _client.storage.from('listing-images').getPublicUrl(path);
      return dto.copyWithMainImageUrl(url);
    }).toList();
  }
}
