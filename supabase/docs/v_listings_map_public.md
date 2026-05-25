# `public.v_listings_map_public` — Phase 15 public map dataset view

## Purpose

The single read surface that the Flutter map page (`MapPage` + `MapBloc`) consumes for marker data. Returns one row per approved, in-publish-window, markerable listing whose `location_visibility` is `'exact'` or `'approximate'` — with coordinates server-side-jittered for the approximate tier so the publisher's true coords never leak to the wire.

## Column projection (13 columns)

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `id` | uuid | `l.id` | Listing identifier; used for marker tap → `/listings/:id` navigation |
| `title` | text | `l.title` | Localized in the publisher's submission language |
| `marker_lat` | numeric | CASE on visibility | `exact` → `l.latitude`; `approximate` → `map_jitter_coordinates(...).jittered_lat` |
| `marker_lng` | numeric | CASE on visibility | `exact` → `l.longitude`; `approximate` → `map_jitter_coordinates(...).jittered_lng` |
| `is_approximate` | boolean | `l.location_visibility = 'approximate'` | Drives the "Approximate location" visual indicator per FR-003a |
| `location_visibility` | text | `l.location_visibility` | Passthrough; always `'exact'` or `'approximate'` (others filtered out) |
| `primary_amount` | numeric | `listing_prices.amount` where `is_primary = true` | Joined via LATERAL; may be null if no primary price row |
| `primary_currency` | text | `listing_prices.currency_code` where `is_primary = true` | Same join |
| `main_image_path` | text | `listing_media.storage_path` for image-kind row with lowest `ordering` | May be null if no images exist |
| `property_type` | text | `l.property_type` | Maps to `PropertyType` Dart enum |
| `purpose` | text | `l.purpose` | Maps to `ListingPurpose` Dart enum |
| `governorate_name_ar` | text | `governorates.display_name->>'ar'` | Bilingual surface; client picks based on locale |
| `governorate_name_en` | text | `governorates.display_name->>'en'` | Same |

**Fields NOT projected** (per FR-001 minimal-projection + ADR-0001):
- Publisher contact details (`phone`, `whatsapp`, `legal_name`, `national_id`).
- Description (`listing_details.description`).
- Full media gallery (all `listing_media` rows beyond the first image).
- Full address (`l.address_text`, city display name, area display name).
- Pricing detail (only `primary_amount` + `primary_currency`).
- Status / status history.
- Created / updated / published / expires timestamps (except as filter WHERE inputs).

## WHERE gates (FR-002, FR-005)

```sql
WHERE l.status = 'approved'
  AND l.location_visibility IN ('exact', 'approximate')
  AND (l.published_at IS NULL OR l.published_at <= now())
  AND (l.expires_at   IS NULL OR l.expires_at   >  now())
  AND (
    (l.location_visibility = 'exact'       AND l.latitude IS NOT NULL AND l.longitude IS NOT NULL)
    OR
    (l.location_visibility = 'approximate' AND l.area_id  IS NOT NULL)
  );
```

All five predicate clauses live inside the view definition. No application-layer post-filter is permitted (FR-005). A quickstart grep gate verifies no client code applies `.eq('status', 'approved')` or `.neq('location_visibility', 'hidden')` filters.

The final markerable-row guard excludes legacy / seed data where an approved approximate listing has no `area_id` (the jitter function's area-centroid fallback requires it) or an approved exact listing has no `(latitude, longitude)` (nothing to project). Rows that violate these invariants cannot render on a map and are excluded for view robustness. Phase 10 R-12's auto-population guarantees new submissions always satisfy the invariant; the guard exists for pre-existing data only.

## RLS posture

```sql
GRANT SELECT ON public.v_listings_map_public TO authenticated, anon;
```

Views in Postgres inherit RLS from their underlying tables — they do not have their own policies. The base table `public.listings` has policy `listings_select_public` permitting anon/authenticated SELECT when `status = 'approved' AND publish-window holds`. The view re-applies the same gate plus the visibility-tier gate (defense in depth — even if a future RLS edit weakens `listings_select_public`, the view stays narrow).

## EXPLAIN expectations

```sql
EXPLAIN SELECT * FROM public.v_listings_map_public;
```

At v1 scale (≤40 listings as of Phase 15 ship):
- Sequential scan on `public.listings` with composite filter is acceptable and observed (test data set too small for index to beat seq scan).
- LATERAL joins for `listing_prices` and `listing_media` use the partial unique index `listing_prices_one_primary_idx` and the composite index `listing_media_listing_id_ordering_idx` respectively (memoized).
- LATERAL join for `map_jitter_coordinates` is a Function Scan; cost dominated by the SHA-256 digest call.
- Hash Left Join for `governorates` (14 rows, hashed once).

Once the catalog scales past ~1k approved listings, `idx_listings_status_created` (Phase 13 R-61, partial index on `status='approved'`) should be picked. PostGIS / spatial indexes are deferred per R-90 until ~10k approved listings.

## Wire-level grep gates (privacy invariant — Constitution III)

Run after every Phase 15 redeploy to verify no leak regression:

```sql
-- Hidden + admin_only never appear (FR-002, SC-003)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility IN ('hidden', 'admin_only');
-- Expected: 0

-- Non-approved never appear (FR-002)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.status != 'approved';
-- Expected: 0

-- Approximate listings never expose true coords (FR-003, SC-003)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'approximate'
    AND v.marker_lat = l.latitude
    AND v.marker_lng = l.longitude;
-- Expected: 0

-- Exact listings have passthrough coords (FR-004)
SELECT count(*) FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  WHERE l.location_visibility = 'exact'
    AND (v.marker_lat != l.latitude OR v.marker_lng != l.longitude);
-- Expected: 0

-- Same dataset for anon and authenticated (SC-011)
-- Run in separate transactions because SET LOCAL ROLE is transaction-scoped.
BEGIN; SET LOCAL ROLE anon; SELECT count(*) FROM public.v_listings_map_public; ROLLBACK;
BEGIN; SET LOCAL ROLE authenticated; SELECT count(*) FROM public.v_listings_map_public; ROLLBACK;
-- Expected: identical counts
```

## Idempotency

The migration uses `CREATE OR REPLACE VIEW`. Re-applying overwrites the view definition. Per project memory `project_supabase_mcp_apply_migration.md`: the MCP `apply_migration` tool does not dedupe by name — re-running adds a duplicate tracker row but the SQL effect is idempotent.

## Companion artifacts

- Function: `public.map_jitter_coordinates(uuid, uuid, numeric, numeric)` — see `supabase/docs/map_jitter_coordinates.md`.
- Filtered RPC: `public.search_map(...)` — wraps the view with a 16-parameter filter shape mirroring Phase 14's `search_listings`.
- Flutter consumer: `lib/features/map/data/datasources/supabase_map_datasource.dart` (Sub-Phase D).
