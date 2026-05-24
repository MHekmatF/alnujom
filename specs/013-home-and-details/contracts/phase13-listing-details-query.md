# Contract: Listing-Details Query

**Path**: `lib/features/listing_details/data/datasources/supabase_listing_details_datasource.dart`
**Implements**: FR-022, FR-023, FR-024, FR-025
**Verifies**: SC-006, SC-007, SC-008

## Query

```dart
Future<ListingDetailsAggregateDto?> fetchListing(String listingId) async {
  final row = await _client.from('listings').select('''
    id, title, property_type, purpose, governorate_id, city_id, area_id,
    phone, whatsapp, contact_name_visibility, location_visibility,
    area_size, rooms, bathrooms, floor, published_at,
    listing_details(description, amenities, year_built, furnished, parking),
    listing_prices(currency_code, amount, is_primary, created_at),
    listing_media(id, storage_path, ordering, is_main, kind, external_url),
    governorate:governorates(name_ar, name_en),
    city:cities(name_ar, name_en),
    area:areas(name_ar, name_en),
    publisher:profiles!listings_publisher_user_id_fkey(full_name, username)
  ''').eq('id', listingId).maybeSingle();

  if (row == null) return null;
  return ListingDetailsAggregateDto.fromJson(row);
}
```

## RLS-only filter discipline

Same as the home-feed query: NO `.eq('status', 'approved')` filter. RLS is the sole gate. Plan-time grep enforces:

```bash
grep -RE "\.eq\('status'" lib/features/listing_details/data/
# Expected: 0 matches.
```

## Null handling — "Listing not found" semantics

`.maybeSingle()` returns `null` in three cases:

1. **RLS hides the row** — the listing exists but its `status != 'approved'` (draft / pending / rejected / paused / sold / rented / expired / deleted) AND the caller is anonymous OR not the owner / admin.
2. **Row doesn't exist** — the supplied UUID doesn't match any `public.listings.id`.
3. **Invalid UUID format** — depending on how `go_router` resolves the route, either the router's `errorBuilder` catches the malformed UUID (preferred per FR-011), OR the query fails with a `PostgrestException` that maps to `ListingNotFoundFailure`.

All three cases map to the SAME UI state — the FR-024 "Listing not found" page. Constitution III requires this indistinguishability to prevent information leaks (an attacker probing UUIDs should NOT be able to tell which UUIDs exist-but-hidden vs don't-exist).

## Aggregate composition

The DTO `ListingDetailsAggregateDto.fromJson()` decomposes the response into:

- `listing` — Phase 10 `Listing` entity (id, title, type, purpose, area_size, rooms, bathrooms, floor, phone, whatsapp, visibility flags, published_at, etc.)
- `details` — Phase 10 `ListingDetails` entity (description, amenities, year_built, furnished, parking)
- `prices` — `List<ListingPrice>` (Phase 10) — ordered with `is_primary=true` first (BLoC sorts client-side for stable rendering)
- `media` — `List<ListingMedia>` (Phase 11) — ordered by `ordering ASC` with `is_main=true` first per the Phase 12 Q8=A `ListingGallery` contract
- `governorate` / `city` / `area` — Phase 8 entities
- `publisher` — `PublisherSummary` (Phase 5-compatible projection: `full_name` + `username` only; private fields NOT projected per Constitution III)

## Visibility-flag respect

The page MUST honor `contact_name_visibility` AND `location_visibility` from the `Listing` entity:

- `contact_name_visibility = 'public'` → publisher name visible in `_ContactBlock` / page chrome.
- `contact_name_visibility = 'admin_only'` → publisher name HIDDEN from anonymous + non-admin authenticated users; the Contact block renders a localized "Contact the publisher" generic label instead of `cta_call` parameterized with the name.
- `location_visibility = 'exact'` → full address_text + governorate/city/area shown.
- `location_visibility = 'approximate'` → governorate/city/area shown; address_text suppressed.
- `location_visibility = 'hidden'` → no location block rendered.
- `location_visibility = 'admin_only'` → same as `hidden` for anonymous + non-admin authenticated.

Plan-time research at implementation MAY simplify these branches for v1 if Phase 10's listing form doesn't surface all four `location_visibility` options to publishers (most listings will be `exact` or `approximate` in v1).

## Network failure mapping

Same as home-feed: `PostgrestException` / `SocketException` → `NetworkFailure` → `ListingDetailsBloc` emits `ListingDetailsStatus.error` → page renders FR-025 "Could not load listing" + Retry button.
