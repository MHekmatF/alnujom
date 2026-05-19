# Contract: `public.v_publisher_listings` View

**Owner**: Phase 10, migration `20260519120008_create_v_publisher_listings.sql`.
**Consumers**: `lib/features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart` (T086 reads this view as a single PostgREST relation); Phase 12 admin queue MAY reuse it (read-only) to project pending_review listings alongside their latest history rows; Phase 22 Realtime MAY subscribe to the underlying tables and re-query the view on changes.

## Obligations

The view MUST be defined with the body captured in [data-model.md § View: public.v_publisher_listings](../data-model.md). Highlights:

1. **Composition**: a `LEFT JOIN LATERAL (... ORDER BY changed_at DESC LIMIT 1)` against `public.listing_status_history` yields the most-recent history row per listing; a `LEFT JOIN public.listing_prices ON ... AND is_primary=true` yields the single primary-price row per Q3 / R-12.
2. **Filter**: `WHERE l.status <> 'deleted'` — soft-deleted listings are excluded at the view level so consumers don't need to filter again.
3. **Column inventory** (~30 columns): all 24 columns from `public.listings` (with `listings.id` renamed to `listing_id` to avoid ambiguity with the joined-row IDs), 6 history columns prefixed `latest_history_*`, 3 primary-price columns prefixed `primary_price_*`. The `latest_history_*` and `primary_price_*` columns are NULLABLE because the LEFT JOINs may not match (a brand-new draft has 1 history row + 0 price rows → primary_price_* are NULL; a draft saved through step 4 has 1 history row + 1 price row → both populated).
4. **RLS inheritance**: the view does NOT carry its own RLS policies. PostgreSQL's view-RLS semantics propagate the underlying tables' policies — a publisher querying the view sees only their own rows (per `listings_select_owner`); an admin holding `listings.view_all` sees all rows; an anonymous client sees only rows where the listings's `listings_select_public` policy admits the row. This is by design — the view is a query helper, NOT a security boundary.
5. **Grant**: `GRANT SELECT ON public.v_publisher_listings TO authenticated;` — authenticated callers can SELECT from the view. PostgREST exposes it as `GET /rest/v1/v_publisher_listings`.

## Verification

```sql
-- View exists
SELECT count(*) FROM pg_views WHERE viewname='v_publisher_listings' AND schemaname='public';
-- Expected: 1

-- Column count matches data-model.md (about 30 columns)
SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='v_publisher_listings';
-- Expected: ~33 (24 listings cols renumbered + 6 latest_history_* + 3 primary_price_*)

-- Grant is present
SELECT grantee FROM information_schema.role_table_grants
WHERE table_name='v_publisher_listings' AND privilege_type='SELECT';
-- Expected: includes 'authenticated'

-- RLS inheritance works (verified using Pattern A from tasks.md implementer briefing):
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"<APPROVED_PUBLISHER_UUID>","role":"authenticated"}';
SELECT count(*) FROM public.v_publisher_listings;
-- Expected: matches the publisher's non-deleted listings count (likely 1 after the Phase-10-MVP smoke test)
ROLLBACK;
```

## Forbidden

- Adding INSERT / UPDATE / DELETE policies on the view (it is a SELECT-only artifact; mutations belong to the underlying tables).
- Renaming the view (downstream consumers and the Phase 10 contracts cite this exact name).
- Adding columns from tables outside the three already joined (`listings`, `listing_status_history`, `listing_prices`). Forward-stated phases that need additional projections should create a SEPARATE view (e.g., Phase 12 may add `v_admin_listings` joining moderation_actions; Phase 13 may add `v_public_listings` for the home feed).
- Querying the view from anonymous sessions for any purpose other than verifying the RLS inheritance (the anon role gets only approved+publish-window listings; this is the same behavior as querying `public.listings` directly).
- Caching the view's result client-side beyond the BLoC's in-memory state (per R-20 — listings reads are fresh on each mount).

## Performance notes

- The `LEFT JOIN LATERAL ... LIMIT 1` is the canonical "most-recent per group" pattern in PostgreSQL; it uses the `idx_listing_status_history_listing` composite index `(listing_id, changed_at DESC)` from migration 6 for efficient lookup.
- The `LEFT JOIN public.listing_prices ON l.id = p.listing_id AND p.is_primary=true` uses the partial unique index `listing_prices_one_primary_idx` for sub-millisecond match — there is at most one is_primary=true row per listing per Q3 / R-12.
- For a publisher with 1000 listings, the view-backed query runs in <10ms; with 10000 listings the latency stays under 50ms on the reference Supabase project.
