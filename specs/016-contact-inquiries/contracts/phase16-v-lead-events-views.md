# Contract — `v_lead_events_publisher` + `v_lead_events_admin` views

**Owner**: Sub-Phase C (`supabase/migrations/20260527120008_create_v_lead_events_views.sql`).

**Consumers**: Sub-Phase E `loadLeadEventsByListing`; future Phase 19 agency analytics; Phase 20 admin dashboard counters.

## `v_lead_events_publisher` (publisher tier — `metadata` masked)

```sql
CREATE VIEW public.v_lead_events_publisher AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.created_at
FROM public.lead_events le;
-- NOTE: metadata column intentionally OMITTED per FR-014b + Q5=B.

GRANT SELECT ON public.v_lead_events_publisher TO authenticated;
```

A publisher reading this view sees rows on their own listings only (RLS on the base table — `lead_events_select_publisher` policy gates by ownership) and never sees the `metadata` column. Aggregate counts (e.g., "how many `phone_revealed` events on listing X this week") are computable from this view without any IP/UA exposure.

## `v_lead_events_admin` (admin tier — `metadata` included)

```sql
CREATE VIEW public.v_lead_events_admin AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.metadata,
  le.created_at
FROM public.lead_events le
WHERE public.current_user_has_permission('inquiries.view_all');

GRANT SELECT ON public.v_lead_events_admin TO authenticated;
```

The defensive `WHERE` clause means even if a non-admin somehow got SELECT access on this view, the query returns zero rows — fail-closed defense-in-depth. The view's row-level visibility also goes through `lead_events_select_admin` RLS policy on the base table.

## Pre-conditions

- `public.lead_events` table + its RLS policies exist (Sub-Phase B + C).
- `public.current_user_has_permission(text)` function exists (Phase 6).

## Post-conditions

- Publisher SELECT on `v_lead_events_publisher` → rows on their listings, no `metadata`.
- Admin SELECT on `v_lead_events_admin` → all rows across all listings, with `metadata`.
- Non-admin SELECT on `v_lead_events_admin` → zero rows (the WHERE predicate fails).
- Anonymous SELECT on either view → zero rows (no GRANT or RLS policy applies).

## Stability surface

**Frozen**: the masking rule — publisher view never includes `metadata`; admin view always does.

**Allowed**: adding new projected columns to either view when the base table grows.
