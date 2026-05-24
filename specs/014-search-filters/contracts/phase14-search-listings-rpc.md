# Contract: Phase 14 `search_listings` RPC

**File**: `supabase/migrations/20260525120003_create_search_listings_rpc.sql`
**Sub-Phase**: A (Wave 1)
**Created**: 2026-05-24

---

## Purpose

The `search_listings` SECURITY DEFINER SQL function is the single server-side entry point for all Phase 14 search queries. It composes full-text matching, nine facet-filter dimensions, price-range currency conversion, dual-mode room/bathroom counting, cursor pagination, and three sort orders into one paginated result set.

---

## Return Type

```
Type: public.search_result_row (composite)
Fields:
  id                  uuid
  title               text
  property_type       text        -- matches public.listings.property_type enum values
  purpose             text        -- matches public.listings.purpose enum values
  governorate_name_ar text
  governorate_name_en text
  city_name_ar        text
  city_name_en        text
  primary_amount      numeric
  primary_currency    text        -- 'USD' | 'SYP'
  main_image_path     text        -- nullable; Storage path for use with Supabase.instance.storage.from('listing-images').getPublicUrl(path)
  published_at        timestamptz
```

---

## Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `p_query` | `text` | `NULL` | No | Keyword string; null = no keyword filter |
| `p_purpose` | `text` | `NULL` | No | Listing purpose enum string (`'sale'`, `'rent'`, `'daily_rent'`, `'investment'`) |
| `p_property_type` | `text` | `NULL` | No | Property type enum string (`'apartment'`, `'villa'`, `'land'`, etc.) |
| `p_governorate_id` | `uuid` | `NULL` | No | Phase 8 governorate ID |
| `p_city_id` | `uuid` | `NULL` | No | Phase 8 city ID; only valid if `p_governorate_id` is also set |
| `p_area_id` | `uuid` | `NULL` | No | Phase 8 area ID; only valid if `p_city_id` is also set |
| `p_price_min_usd` | `numeric` | `NULL` | No | Price min in USD (pre-converted by client) |
| `p_price_max_usd` | `numeric` | `NULL` | No | Price max in USD (pre-converted by client) |
| `p_price_min_syp` | `numeric` | `NULL` | No | Price min in SYP (pre-converted by client) |
| `p_price_max_syp` | `numeric` | `NULL` | No | Price max in SYP (pre-converted by client) |
| `p_rooms` | `integer` | `NULL` | No | Room count filter value; null = dimension inactive |
| `p_rooms_mode` | `text` | `'exactly'` | No | `'exactly'` or `'at_least'` |
| `p_bathrooms` | `integer` | `NULL` | No | Bathroom count filter value; null = dimension inactive |
| `p_bathrooms_mode` | `text` | `'exactly'` | No | `'exactly'` or `'at_least'` |
| `p_area_size_min` | `numeric` | `NULL` | No | Minimum area size (m²) |
| `p_area_size_max` | `numeric` | `NULL` | No | Maximum area size (m²) |
| `p_sort` | `text` | `'newest'` | No | `'newest'`, `'price_asc'`, or `'price_desc'` |
| `p_cursor_published_at` | `timestamptz` | `NULL` | No | Cursor for `newest` sort; null = first page |
| `p_cursor_id_newest` | `uuid` | `NULL` | No | Tie-breaker ID for `newest` cursor |
| `p_cursor_price_amount` | `numeric` | `NULL` | No | Cursor for price sorts; null = first page |
| `p_cursor_id_price` | `uuid` | `NULL` | No | Tie-breaker ID for price cursor |
| `p_limit` | `integer` | `20` | No | Page size; max 50 enforced in Dart datasource |

---

## Behavioral Contracts

### Security
- Function is `SECURITY DEFINER SET search_path = public`.
- The `v_listings_public` view (consumed by the function) already enforces `status = 'approved' AND (expires_at IS NULL OR expires_at > now())` — providing defense-in-depth per Constitution III.
- No mutation operations inside the function.
- GRANT `EXECUTE` to `authenticated, anon` — search is accessible to anonymous users (FR-015).

### Keyword Search
- When `p_query` is non-null and non-empty: matches listings where `search_vector @@ plainto_tsquery('simple', p_query)` OR `listing_details.description ILIKE '%' || p_query || '%'`.
- Arabic search: exact-token match only. `plainto_tsquery('simple', 'شقة')` matches the token "شقة" only — NOT "شقق", "شقتين", etc. (R-73, FR-003).
- Latin search: `plainto_tsquery` is case-insensitive for Latin scripts (FR-004).

### Facet Filters
- Each facet dimension is optional (null = inactive). Active dimensions are combined with AND logic (FR-009).
- Location cascade: `p_city_id` without `p_governorate_id` is technically valid SQL but logically inconsistent; the Dart datasource validates cascade ordering before calling the RPC.

### Price Range
- Price bounds are pre-converted by the client to USD and SYP (R-75). The RPC compares against the listing's `primary_currency` — USD listings use `p_price_min_usd` / `p_price_max_usd`; SYP listings use `p_price_min_syp` / `p_price_max_syp`.
- If `p_price_min_usd` is null OR `p_price_max_usd` is null: price filter is inactive for that currency. The datasource passes both bounds together or neither.

### Rooms / Bathrooms
- `p_rooms_mode = 'exactly'`: matches `listing_details.rooms = p_rooms`.
- `p_rooms_mode = 'at_least'`: matches `listing_details.rooms >= p_rooms`.
- Same logic for bathrooms.
- When `p_rooms` is null, the rooms filter is inactive regardless of `p_rooms_mode`.

### Cursor Pagination
- **Newest sort**: cursor is `(p_cursor_published_at, p_cursor_id_newest)`. WHERE predicate: `(published_at, id) < (p_cursor_published_at, p_cursor_id_newest)`. NULL cursor = first page.
- **Price sorts**: cursor is `(p_cursor_price_amount, p_cursor_id_price)`. WHERE predicate for `price_asc`: `(primary_amount, id::text) > (p_cursor_price_amount, p_cursor_id_price::text)`. For `price_desc`: `<`. NULL cursor = first page.
- Cursor values are taken from the LAST row of the current page by the Dart datasource.
- If the returned row count is less than `p_limit`, there are no more pages.

### Sort Order
- `'newest'`: ORDER BY `published_at DESC, id ASC` (id ASC for stable tie-breaking).
- `'price_asc'`: ORDER BY `primary_amount ASC, id ASC`.
- `'price_desc'`: ORDER BY `primary_amount DESC, id ASC`.

---

## Dart Datasource Usage Pattern

```dart
// SupabaseSearchDatasource.fetchPage() — pseudo-code
final response = await _client.rpc('search_listings', params: {
  if (filters.query != null) 'p_query': filters.query,
  if (filters.purpose != null) 'p_purpose': filters.purpose!.name,
  if (filters.propertyType != null) 'p_property_type': filters.propertyType!.name,
  if (filters.governorateId != null) 'p_governorate_id': filters.governorateId,
  if (filters.cityId != null) 'p_city_id': filters.cityId,
  if (filters.areaId != null) 'p_area_id': filters.areaId,
  if (priceMinUsd != null) 'p_price_min_usd': priceMinUsd,
  if (priceMaxUsd != null) 'p_price_max_usd': priceMaxUsd,
  if (priceMinSyp != null) 'p_price_min_syp': priceMinSyp,
  if (priceMaxSyp != null) 'p_price_max_syp': priceMaxSyp,
  if (filters.rooms != null) 'p_rooms': filters.rooms,
  'p_rooms_mode': filters.roomsMode == CountFilterMode.exactly ? 'exactly' : 'at_least',
  if (filters.bathrooms != null) 'p_bathrooms': filters.bathrooms,
  'p_bathrooms_mode': filters.bathroomsMode == CountFilterMode.exactly ? 'exactly' : 'at_least',
  if (filters.areaSizeMin != null) 'p_area_size_min': filters.areaSizeMin,
  if (filters.areaSizeMax != null) 'p_area_size_max': filters.areaSizeMax,
  'p_sort': sort.toRpcString(),    // 'newest' | 'price_asc' | 'price_desc'
  if (cursor is NewestCursor) 'p_cursor_published_at': cursor.publishedAt.toIso8601String(),
  if (cursor is NewestCursor) 'p_cursor_id_newest': cursor.id,
  if (cursor is PriceCursor) 'p_cursor_price_amount': cursor.priceAmount,
  if (cursor is PriceCursor) 'p_cursor_id_price': cursor.id,
  'p_limit': 20,
});
```

---

## Smoke Test Queries

Run via `execute_sql` after applying the migration:

```sql
-- Smoke test 1: keyword search
SELECT * FROM public.search_listings(p_query => 'شقة', p_limit => 5);

-- Smoke test 2: property_type facet
SELECT * FROM public.search_listings(p_property_type => 'apartment', p_limit => 5);

-- Smoke test 3: rooms = exactly 3
SELECT * FROM public.search_listings(p_rooms => 3, p_rooms_mode => 'exactly', p_limit => 5);

-- Smoke test 4: rooms >= 2
SELECT * FROM public.search_listings(p_rooms => 2, p_rooms_mode => 'at_least', p_limit => 5);

-- Smoke test 5: price sort ascending
SELECT * FROM public.search_listings(p_sort => 'price_asc', p_limit => 5);

-- Smoke test 6: second page (newest sort) — replace with actual cursor values from test 5
-- SELECT * FROM public.search_listings(p_sort => 'newest',
--   p_cursor_published_at => '2026-05-20 12:00:00+00',
--   p_cursor_id_newest => '<last-id-from-page-1>', p_limit => 5);
```
