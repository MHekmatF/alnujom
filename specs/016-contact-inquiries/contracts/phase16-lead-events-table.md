# Contract — `public.lead_events` table

**Owner**: Sub-Phase B (`supabase/migrations/20260527120002_create_lead_events_table.sql`).

**Consumers**: Sub-Phase C policies + views; Sub-Phase D RPCs; Sub-Phase E data source; Phase 17 favorites (writes `favorite_added` rows); Phase 20 admin dashboard.

## Columns (frozen surface)

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | UUID | PK, DEFAULT `gen_random_uuid()` | Stable identifier. |
| `listing_id` | UUID | NOT NULL, FK → `public.listings(id)` ON DELETE RESTRICT | Q4=C. |
| `user_id` | UUID | NULL, FK → `auth.users(id)` ON DELETE SET NULL | NULL = anonymous tap. |
| `event_type` | TEXT | NOT NULL, CHECK IN (phone_revealed, whatsapp_clicked, inquiry_sent, favorite_added) | FR-014. `favorite_added` reserved for Phase 17 — no Phase 16 write path. |
| `metadata` | JSONB | NULL | Populated by `submit_inquiry` and `record_lead_event` RPCs as `{ip, user_agent}` per Q5=B. Visible to admins only via column-masked views per FR-014b. |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()` | Server-generated. |

## Indexes

- `idx_lead_events_listing_created` on `(listing_id, created_at DESC)` — covers per-listing chronological reads.
- `idx_lead_events_listing_type` on `(listing_id, event_type, created_at DESC)` — covers per-event-type analytics aggregates (consumed by future Phase 19 agency analytics + Phase 20 admin dashboard).

## RLS

`ALTER TABLE public.lead_events ENABLE ROW LEVEL SECURITY` is set. Policies land in Sub-Phase C (`20260527120004_create_lead_events_policies.sql`); the metadata-masking is via the column projection in the publisher-tier view, not via RLS (because RLS partitions rows, not columns).

## Pre-conditions

- `public.listings` exists (Phase 10).
- `auth.users` exists (Supabase baseline).

## Post-conditions

- Every row's `metadata` (when non-null) carries `{ip: "...", user_agent: "..."}` populated from server-side trusted context.
- Publisher reads via `v_lead_events_publisher` NEVER include the `metadata` column (FR-014b).
- Admin reads via `v_lead_events_admin` ALWAYS include the `metadata` column.
- Anonymous reads return zero rows (no policy grants `anon` access).

## Failure modes

- Inserting a row with `event_type` outside the CHECK enum raises SQLSTATE 23514.
- Inserting a row with invalid `listing_id` raises SQLSTATE 23503.
- Direct INSERT/UPDATE/DELETE from authenticated/anon clients is rejected by REVOKE applied in Sub-Phase C.

## Stability surface

**Frozen**:

- Column names and types.
- The CHECK enum's first three values (`phone_revealed`, `whatsapp_clicked`, `inquiry_sent`).
- The FK ON DELETE RESTRICT on `listing_id`.

**Allowed to change in future phases**:

- Adding new event-types to the CHECK enum (Phase 17 will consume `favorite_added` — already pre-seeded).
- Adding new indexes.
- Adding new `metadata` keys (Phase 22 may add `device_id` for push-notification correlation).
- Adding new RLS policies (must not remove existing).
