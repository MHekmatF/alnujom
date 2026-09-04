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

  /// The embedded-selects projection shared by the regular feed
  /// ([fetchPage]) and the FEATURED query ([fetchFeatured]) so both parse
  /// into the identical [HomeListingCardDto] shape. Keep these in lockstep.
  static const String _cardSelect =
      'id, title, property_type, purpose, governorate_id, city_id, published_at, '
      'rooms, bathrooms, area_size, floor, phone, whatsapp, '
      'featured_until, deed_type, finish_level, verification_status, verified_at, '
      'listing_prices!inner(currency_code, amount, is_primary), '
      'listing_media(storage_path, thumbnail_path, ordering, is_main, kind), '
      'governorate:governorates(display_name), '
      'city:cities(display_name), '
      'area:areas(display_name), '
      'agency:agencies(id, name, logo_path, status)';

  /// Fetches one page of the home feed. Returns at most 20 rows ordered by
  /// `(published_at DESC, id DESC)`.
  ///
  /// RLS is the SOLE filter for `status = approved` per FR-018 — this
  /// method MUST NOT add an application-layer status filter on the listings
  /// table.
  Future<List<HomeListingCardDto>> fetchPage({Cursor? cursor}) async {
    // Shared embedded-selects projection per R-63 ([_cardSelect]). It now
    // also projects `featured_until` (Phase 25 featured treatment) so a
    // promoted listing surfacing in the NORMAL feed parses
    // isFeatured = (featured_until != null && future). `listing_prices!inner`
    // forces an INNER JOIN so rows without a primary price are excluded
    // (defensive — Phase 10's submit_listing RPC always inserts a primary
    // price). `listing_media` is a LEFT JOIN; the `.eq()` filters below narrow
    // it to is_main=true AND kind='image' so a card surfaces at most one
    // thumbnail row.
    final base = _client.from('listings').select(_cardSelect);

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

    return (rows as List<dynamic>)
        .map((r) => _mapRowWithUrls(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Fetches up to [limit] currently-FEATURED listings for the home carousel.
  ///
  /// Uses the SAME embedded selects as [fetchPage] (so the rows parse into the
  /// identical card shape), but filters to PUBLISHED rows whose `featured_until`
  /// is still in the future and orders by the soonest-to-expire-last (most
  /// recently/longest-featured first) per `featured_until DESC`. Every returned
  /// DTO is forced `isFeatured = true` (featured by construction).
  ///
  /// RLS remains the SOLE filter for `status = approved` (FR-018) — the
  /// `published_at IS NOT NULL` predicate only excludes the caller's own
  /// unpublished rows, mirroring [fetchPage].
  Future<List<HomeListingCardDto>> fetchFeatured({int limit = 10}) async {
    final rows = await _client
        .from('listings')
        .select(_cardSelect)
        .eq('listing_prices.is_primary', true)
        .eq('listing_media.is_main', true)
        .eq('listing_media.kind', 'image')
        .not('published_at', 'is', null)
        .gt('featured_until', DateTime.now().toUtc().toIso8601String())
        .order('featured_until', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (r) => _mapRowWithUrls(
            Map<String, dynamic>.from(r as Map),
          ).copyWithIsFeatured(true),
        )
        .toList();
  }

  /// Maps one PostgREST row to a [HomeListingCardDto] and resolves the public
  /// URLs for the main image (listing-images bucket) and the agency logo
  /// (agency-assets bucket). Shared by [fetchPage] and [fetchFeatured].
  HomeListingCardDto _mapRowWithUrls(Map<String, dynamic> row) {
    var dto = HomeListingCardDto.fromJson(row);
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
  }
}
