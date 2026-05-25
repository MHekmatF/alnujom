# Contract — `public.lead_events` RLS policies + metadata masking

**Owner**: Sub-Phase C (`supabase/migrations/20260527120004_create_lead_events_policies.sql` + `20260527120008_create_v_lead_events_views.sql`).

## SELECT policies

1. `lead_events_select_publisher` — `EXISTS (SELECT 1 FROM listings l WHERE l.id = lead_events.listing_id AND l.publisher_user_id = auth.uid())`. Returns the row to the publisher.
2. `lead_events_select_admin` — `public.current_user_has_permission('inquiries.view_all')`. Returns the row to the admin.

## Column-level masking (NOT done via RLS)

RLS partitions rows, not columns. The `metadata` masking per FR-014b is enforced via view projections:

- **Publisher tier**: `v_lead_events_publisher` projects `(id, listing_id, user_id, event_type, created_at)` — the `metadata` column is OMITTED from the SELECT clause. A publisher reading this view never sees the IP/UA.
- **Admin tier**: `v_lead_events_admin` projects every column INCLUDING `metadata`. The view body adds `WHERE public.current_user_has_permission('inquiries.view_all')` as a defensive predicate so a non-admin reading the admin view receives zero rows even though they got SELECT access on the view.

## INSERT / UPDATE / DELETE

All revoked at the table level (`REVOKE INSERT, UPDATE, DELETE ON public.lead_events FROM authenticated, anon`). The only write paths are `submit_inquiry` (inserts `inquiry_sent` events) and `record_lead_event` (inserts `phone_revealed`/`whatsapp_clicked` events), both SECURITY DEFINER.

## Pre-conditions

- `public.lead_events` table exists (Sub-Phase B).
- `public.current_user_has_permission(text)` function exists (Phase 6).

## Post-conditions

- Publisher SELECT against `v_lead_events_publisher` returns rows for their listings only, WITHOUT the `metadata` column.
- Admin SELECT against `v_lead_events_admin` returns ALL rows across ALL listings WITH the `metadata` column.
- Direct SELECT against `public.lead_events` table (bypassing the views) returns rows per the table-level policies, but the `metadata` column is still returned because RLS doesn't mask columns — this is why `quickstart.md` instructs the data layer to always read through the views and the advisor-hardening migration revokes table-level SELECT to force view-only access.

## Failure modes

- Direct INSERT/UPDATE/DELETE attempts return "permission denied for table lead_events" (REVOKE blocks).
- Non-admin SELECT against `v_lead_events_admin` returns zero rows (defensive WHERE clause).

## Stability surface

**Frozen**: column-level masking rule (publisher view omits `metadata`; admin view includes it).

**Allowed**: adding new tier views in future phases (e.g., a future `v_lead_events_agency_member` for Phase 19 agency analytics).
