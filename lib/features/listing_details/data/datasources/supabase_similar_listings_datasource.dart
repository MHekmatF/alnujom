import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/similar_listing_card_dto.dart';

/// Premium uplift v2 — datasource for the "similar listings" carousel.
///
/// One of the files under `lib/features/listing_details/` importing
/// `package:supabase_flutter` per Constitution IX (alongside the existing
/// details datasource + video launcher).
///
/// Reads approved listings that share the source listing's [propertyType] (and,
/// when known, [governorateId]), excluding the source itself. RLS is the SOLE
/// `status = approved` gate (FR-018 discipline) — this method MUST NOT add an
/// application-layer status filter on `listings`.
@injectable
class SupabaseSimilarListingsDatasource {
  const SupabaseSimilarListingsDatasource(this._client);

  final supabase.SupabaseClient _client;

  Future<List<SimilarListingCardDto>> fetchSimilar({
    required String listingId,
    required String propertyType,
    String? governorateId,
    int limit = 8,
  }) async {
    // Embedded selects mirror the home-feed card query. `listing_prices!inner`
    // forces an INNER JOIN so rows without a primary price are excluded;
    // `listing_media` is a LEFT JOIN narrowed to is_main=true AND kind='image'
    // so a card surfaces at most one thumbnail row.
    final base = _client
        .from('listings')
        .select(
          'id, title, property_type, purpose, governorate_id, city_id, '
          'rooms, bathrooms, area_size, '
          'listing_prices!inner(currency_code, amount, is_primary), '
          'listing_media(storage_path, ordering, is_main, kind), '
          'governorate:governorates(display_name), '
          'city:cities(display_name)',
        );

    // Embedded-select filters apply to the JOINed tables, not to `listings`.
    var query = base
        .eq('listing_prices.is_primary', true)
        .eq('listing_media.is_main', true)
        .eq('listing_media.kind', 'image')
        // Same property type, never the source listing, only published rows.
        .eq('property_type', propertyType)
        .neq('id', listingId)
        .not('published_at', 'is', null);

    // Narrow to the same governorate when known (graceful when the source has
    // no governorate — broaden to the property-type pool instead).
    if (governorateId != null && governorateId.isNotEmpty) {
      query = query.eq('governorate_id', governorateId);
    }

    final rows = await query
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>).map((r) {
      final dto = SimilarListingCardDto.fromJson(
        Map<String, dynamic>.from(r as Map),
      );
      final path = dto.mainImageStoragePath;
      if (path == null) return dto;
      final url = _client.storage.from('listing-images').getPublicUrl(path);
      return dto.copyWithMainImageUrl(url);
    }).toList();
  }
}
