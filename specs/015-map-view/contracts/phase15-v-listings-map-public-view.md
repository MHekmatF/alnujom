# Contract: `public.v_listings_map_public` view

**Phase**: 15 — Map View
**Owner**: Sub-Phase C (backend)
**Migration**: `supabase/migrations/20260526120002_create_v_listings_map_public.sql`
**Spec refs**: FR-001, FR-001a, FR-002, FR-003, FR-004, FR-005, FR-006, SC-002, SC-003, SC-010, SC-011

## Column projection (13 columns)

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `id` | uuid | `l.id` | The listing identifier; used for marker tap → `/listings/:id` navigation |
| `title` | text | `l.title` | Localized in the publisher's submission language |
| `marker_lat` | numeric(9,6) | CASE on visibility | `exact` → `l.latitude`; `approximate` → `map_jitter_coordinates(...).jittered_lat` |
| `marker_lng` | numeric(9,6) | CASE on visibility | `exact` → `l.longitude`; `approximate` → `map_jitter_coordinates(...).jittered_lng` |
| `is_approximate` | boolean | `l.location_visibility = 'approximate'` | Drives the "Approximate location" visual indicator per FR-003a |
| `location_visibility` | text | `l.location_visibility` | Passthrough; always one of `'exact'` / `'approximate'` (other values are filtered out) |
| `primary_amount` | numeric | `listing_prices.amount` where `is_primary = true` | Joined via LATERAL; may be null if no primary price row exists |
| `primary_currency` | text | `listing_prices.currency_code` where `is_primary = true` | Same join |
| `main_image_path` | text | `listing_media.storage_path` where `kind = 'image'` ORDER BY `ordering ASC` LIMIT 1 | May be null if no images exist |
| `property_type` | text | `l.property_type` | Maps to `PropertyType` Dart enum |
| `purpose` | text | `l.purpose` | Maps to `ListingPurpose` Dart enum |
| `governorate_name_ar` | text | `governorates.display_name->>'ar'` | Bilingual surface; client picks based on locale |
| `governorate_name_en` | text | `governorates.display_name->>'en'` | Same |

**Fields NOT projected** (per FR-001 minimal-projection rule):
- Publisher contact details (`phone`, `whatsapp`, `legal_name`, `national_id`).
- Description (`listing_details.description`).
- Full media gallery (`listing_media.storage_path` for all rows).
- Full address (`l.address_text`, `c.display_name`, `area.display_name`).
- Pricing detail (only `primary_amount` + `primary_currency`).
- Status / status history.
- Created/updated/published/expires timestamps (except as filter-WHERE inputs).

## WHERE gates (FR-002, FR-005)

```sql
WHERE l.status = 'approved'
  AND l.location_visibility IN ('exact', 'approximate')
  AND (l.expires_at IS NULL OR l.expires_at > now())
```

All three predicates MUST be inside the view definition. No application-layer post-filter is permitted (FR-005); a quickstart grep gate verifies no client code applies `.eq('status', 'approved')` or `.neq('location_visibility', 'hidden')` filters.

## Permissions

- `GRANT SELECT ON public.v_listings_map_public TO authenticated, anon;`

Views in Postgres do not have RLS policies of their own; they inherit RLS from the underlying tables. The base table (`public.listings`) RLS for SELECT permits anon/authenticated when `status = 'approved'` AND publish-window — the view re-applies the same gate, so the policy and the view's WHERE are aligned.

## Idempotency

The migration uses `CREATE OR REPLACE VIEW`. Re-applying overwrites the view definition.

## Smoke tests

```sql
-- Hidden + admin_only never appear (FR-002, SC-003)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility IN ('hidden', 'admin_only');
-- Expected: 0

-- Non-approved listings never appear (FR-002)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.status != 'approved';
-- Expected: 0

-- Approximate coords differ from true coords (FR-003, SC-003)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'approximate'
    AND v.marker_lat = l.latitude
    AND v.marker_lng = l.longitude;
-- Expected: 0  (zero rows where jittered = original)

-- Exact coords passthrough (FR-004)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'exact'
    AND (v.marker_lat != l.latitude OR v.marker_lng != l.longitude);
-- Expected: 0

-- Same dataset for authenticated and anon (SC-011)
SET ROLE anon;
SELECT count(*) FROM public.v_listings_map_public;
SET ROLE authenticated;
SELECT count(*) FROM public.v_listings_map_public;
-- Expected: identical counts
```

## EXPLAIN expectations

```sql
EXPLAIN SELECT * FROM public.v_listings_map_public;
```

Expected plan elements:
- Sequential scan or index scan on `public.listings` using `idx_listings_status_created` (`status = 'approved'` partial index)
- LEFT JOIN LATERAL for `listing_prices` (using `listing_prices_one_primary_idx` partial unique index)
- LEFT JOIN LATERAL for `listing_media` (using `listing_media_listing_kind_ordering` composite index if present)
- LEFT JOIN LATERAL for `map_jitter_coordinates` (function call; cost dominated by `digest()`)
- Hash join or nested loop join for `governorates`

For v1 scale (hundreds of listings), the plan does NOT need to be optimal — a sequential scan is acceptable. PostGIS / spatial indexes are deferred per R-90.
