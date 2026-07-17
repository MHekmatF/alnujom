import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/listing_details_aggregate_dto.dart';

/// Phase 13 (spec/013-home-and-details) — the ONLY file under
/// `lib/features/listing_details/` importing `package:supabase_flutter`
/// per Constitution IX + FR-030.
///
/// Issues the embedded-selects query per R-64 + data-model.md §3.1.
///
/// RLS-only filter discipline — NO `.eq('status', 'approved')` per FR-018.
/// `.maybeSingle()` returns null when RLS hides the row (listing is
/// non-approved for this caller) OR the row doesn't exist. Both cases are
/// indistinguishable per Constitution III + FR-024.
///
/// Projects ONLY `full_name` + `username` from profiles (private Vault
/// fields explicitly excluded per ADR-0001 + contracts/phase13-listing-
/// details-query.md).
@injectable
class SupabaseListingDetailsDatasource {
  const SupabaseListingDetailsDatasource(this._client);

  final supabase.SupabaseClient _client;

  Future<ListingDetailsAggregateDto?> fetchListing(String listingId) async {
    final row = await _client
        .from('listings')
        .select('''
      id, title, property_type, purpose, governorate_id, city_id, area_id,
      phone, whatsapp, contact_name_visibility, location_visibility,
      area_size, rooms, bathrooms, floor, published_at,
      publisher_user_id, agency_id, address_text,
      status, created_at, updated_at, expires_at,
      deed_type, finish_level, verification_status, verified_at,
      listing_details(listing_id, description, amenities, year_built, furnished, parking, created_at, updated_at),
      listing_prices(id, listing_id, currency_code, amount, is_primary, created_at),
      listing_media(id, listing_id, storage_path, ordering, is_main, kind, external_url, watermarked, created_at, updated_at),
      governorate:governorates(id, key, display_name, is_active, is_system, created_at, updated_at),
      city:cities(id, key, display_name, is_active, is_system, created_at, updated_at),
      area:areas(id, key, display_name, is_active, created_at, updated_at)
    ''')
        .eq('id', listingId)
        .maybeSingle();
    // Note: publisher embedded select removed at Phase 13 verification time —
    // public.listings has no FK from publisher_user_id (the data-model.md §3.1
    // assumption was wrong; profiles has zero FKs to auth.users either, so
    // PostgREST can't embed via FK hint). DTO's empty-publisher fallback
    // handles the missing key. See DEFERRED.md D-02 for the follow-up fix.
    // RLS-only filter — NO application-layer status='approved' per FR-018.
    // .maybeSingle() returns null when RLS hides the row OR row doesn't exist.
    if (row == null) return null;

    // SEC-I1: never read raw latitude/longitude from the base table here — that
    // would hand the EXACT spot to any viewer (anon included) even for a listing
    // the publisher set to `approximate`. Source the map marker from the
    // visibility-gated `v_listings_map_public` instead: exact only when the
    // publisher chose 'exact', jittered for 'approximate', absent when hidden /
    // not-yet-approved. Anon's SELECT on listings.latitude/longitude is revoked
    // in migration 20260717120007 so this is the only client coordinate path.
    final map = Map<String, dynamic>.from(row);
    final marker = await _client
        .from('v_listings_map_public')
        .select('marker_lat, marker_lng')
        .eq('id', listingId)
        .maybeSingle();
    map['latitude'] = marker?['marker_lat'];
    map['longitude'] = marker?['marker_lng'];
    return ListingDetailsAggregateDto.fromJson(map);
  }
}
