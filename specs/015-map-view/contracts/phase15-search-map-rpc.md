# Contract: `public.search_map(...)` RPC

**Phase**: 15 — Map View
**Owner**: Sub-Phase C (backend)
**Migration**: `supabase/migrations/20260526120003_create_search_map_rpc.sql`
**Spec refs**: FR-007a, SC-012, US6
**Sibling RPC**: `public.search_listings(...)` from Phase 14 (`supabase/migrations/20260525120003_create_search_listings_rpc.sql`)

## Signature (16 parameters)

```sql
public.search_map(
  -- Full-text keyword
  p_query              text       DEFAULT NULL,
  -- Facets
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  -- Price range (pre-converted to USD + SYP by client per R-75)
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  -- Rooms
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',   -- 'exactly' | 'at_least'
  -- Bathrooms
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',   -- 'exactly' | 'at_least'
  -- Area size
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL
) RETURNS SETOF public.v_listings_map_public
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
```

## Behavioral contract

1. **All-null parameters** → returns every row in `v_listings_map_public` (identical to `SELECT *`).
2. **Per-parameter null** → that dimension is inactive (no narrowing).
3. **Visibility gate composes**: The RPC's filter narrows the view; the view's WHERE narrows by approval + visibility. Both must pass for a row to appear. There is NO way for a non-approved or hidden listing to leak through the RPC.
4. **Keyword search**: Mirrors Phase 14 — `search_vector @@ plainto_tsquery('simple', p_query)` OR `description ILIKE '%' || p_query || '%'` (Arabic exact-token per Phase 14 FR-003).
5. **Price range**: Mirrors Phase 14 — match if EITHER the listing's USD or SYP price row falls within bounds. The client pre-converts the user's display-currency range into both currencies per R-75.
6. **Rooms / bathrooms mode**: Mirrors Phase 14 — `'exactly'` is `=`, `'at_least'` is `>=`. Default `'exactly'`.
7. **No sort, no cursor, no limit**: The map dataset is one-shot per FR-001a. The full filtered set returns in one call; the client clusters them.
8. **Return type**: `SETOF public.v_listings_map_public` — the row composite is exactly the view's projection. No new columns.

## Differences from `search_listings`

| Phase 14 `search_listings` | Phase 15 `search_map` |
|----------------------------|----------------------|
| 22 parameters | 16 parameters (no `p_sort`, no cursor pair × 2, no `p_limit`) |
| Returns `SETOF search_result_row` (12-column custom composite) | Returns `SETOF v_listings_map_public` (13-column view) |
| Paginated via cursor | One-shot (full filtered set) |
| `LANGUAGE plpgsql` (DECLARE + loop logic for cursor) | `LANGUAGE sql` (single SELECT, no procedural needs) |

## Permissions

- `REVOKE ALL ON FUNCTION public.search_map(...) FROM PUBLIC;`
- `GRANT EXECUTE ON FUNCTION public.search_map(...) TO authenticated, anon;`

## Smoke tests

```sql
-- All-null returns full dataset
SELECT count(*) FROM public.search_map();
SELECT count(*) FROM public.v_listings_map_public;
-- Expected: identical counts

-- Facet narrows the result
SELECT count(*) FROM public.search_map(p_purpose := 'sale');
-- Expected: <= count without filter

-- Visibility gate composes (hidden listing remains absent even if facet matches)
-- Setup: create one approved hidden listing of purpose=sale
SELECT count(*) FROM public.search_map(p_purpose := 'sale') v
  WHERE v.location_visibility = 'hidden';
-- Expected: 0

-- Combined filter
SELECT count(*) FROM public.search_map(
  p_purpose := 'sale',
  p_property_type := 'apartment',
  p_governorate_id := (SELECT id FROM public.governorates WHERE display_name->>'en' = 'Damascus'),
  p_rooms := 3, p_rooms_mode := 'at_least'
);
-- Expected: returns matching apartments-for-sale in Damascus with 3+ rooms
```
