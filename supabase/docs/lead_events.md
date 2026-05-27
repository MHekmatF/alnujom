# lead_events

## Purpose

`public.lead_events` is the Phase 16 lightweight engagement-signal stream. Each
row records one tap/submission event on one listing, used to feed future
analytics surfaces (Phase 19 agency analytics, Phase 20 admin dashboard). The
write paths are intentionally narrow — only Phase 16 SECURITY DEFINER RPCs
emit rows.

Authoritative interface contract:
[`specs/016-contact-inquiries/contracts/phase16-lead-events-table.md`](../../specs/016-contact-inquiries/contracts/phase16-lead-events-table.md).

## Shape

Defined in `supabase/migrations/20260527120002_create_lead_events_table.sql`.
Six columns; client writes are blocked at the table level (Sub-Phase C) so
every row originates from `submit_inquiry` (for `inquiry_sent` events) or
`record_lead_event` (for `phone_revealed` and `whatsapp_clicked` events).
The `favorite_added` event_type is reserved for Phase 17.

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | `uuid` | PK, DEFAULT `gen_random_uuid()` | Stable identifier. |
| `listing_id` | `uuid` | NOT NULL, FK → `public.listings(id)` ON DELETE RESTRICT | Q4=C — consistent with `public.inquiries`. |
| `user_id` | `uuid` | NULL, FK → `auth.users(id)` ON DELETE SET NULL | NULL = anonymous tap. |
| `event_type` | `text` | NOT NULL, CHECK IN (`'phone_revealed'`,`'whatsapp_clicked'`,`'inquiry_sent'`,`'favorite_added'`) | FR-014. `favorite_added` reserved for Phase 17 — no Phase 16 write path emits it. |
| `metadata` | `jsonb` | NULL | Server-side trusted-context payload `{ip, user_agent}` per Q5=B. |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated. |

## CHECK constraint on `event_type`

The CHECK enumerates four values: `phone_revealed`, `whatsapp_clicked`,
`inquiry_sent`, `favorite_added`. The first three are written by Phase 16
RPCs; the fourth is reserved for Phase 17's favorites feature. The CHECK is
pre-seeded with all four values so Phase 17 does not need to ALTER the
constraint (frozen surface per the contract's Stability section).

## Indexes

- `idx_lead_events_listing_created` on `(listing_id, created_at DESC)` — covers
  per-listing chronological reads (FR-015).
- `idx_lead_events_listing_type` on `(listing_id, event_type, created_at DESC)`
  — covers per-event-type analytics aggregates (counts of `phone_revealed` vs
  `whatsapp_clicked` vs `inquiry_sent` per listing).

## IP / UA capture convention

The `metadata` column carries server-side trusted-context fields populated
inside the Sub-Phase D RPCs via:

```sql
v_ip         := inet_client_addr();
v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
```

The RPCs wrap the `current_setting` call in a `BEGIN ... EXCEPTION WHEN OTHERS
THEN v_user_agent := NULL; END;` block so missing/malformed request headers
do not abort the insert. The captured payload is `{"ip": "...", "user_agent":
"..."}` (JSONB). Client-supplied IP/UA values are NEVER accepted — the RPCs
do not declare parameters for these fields.

## Metadata column masking rule (FR-014b)

The `metadata` column is intentionally shielded from publisher-tier reads. The
masking is enforced by Sub-Phase C views, not by RLS (RLS partitions rows, not
columns):

- `public.v_lead_events_publisher` projects five columns (`id`, `listing_id`,
  `user_id`, `event_type`, `created_at`) — explicitly OMITS `metadata`.
- `public.v_lead_events_admin` projects six columns including `metadata`, and
  is self-gated by `WHERE public.current_user_has_permission('inquiries.view_all')`
  so a non-admin session that mis-SELECTs the admin view sees zero rows
  (defense-in-depth on top of the table-level RLS policies).

Clients MUST NOT query `public.lead_events` directly; both the publisher and
admin tiers go through their respective views.

## RLS posture

- **Phase 2 (this migration)**: `ALTER TABLE public.lead_events ENABLE ROW
  LEVEL SECURITY` is set. NO policies are attached. The default-deny posture
  means direct reads from any client session return zero rows.
- **Phase 3 (Sub-Phase C, `20260527120004_create_lead_events_policies.sql`)**
  will add two SELECT policies (`lead_events_select_publisher`,
  `lead_events_select_admin`) and a blanket `REVOKE INSERT, UPDATE, DELETE ON
  public.lead_events FROM authenticated, anon` so writes only land via the
  SECURITY DEFINER RPCs.

## Write path

All client-side writes go through SECURITY DEFINER RPCs in Sub-Phase D:

- `public.submit_inquiry(...)` — writes a companion `inquiry_sent` row atomically
  with the `public.inquiries` insert.
- `public.record_lead_event(p_listing_id, p_event_type)` — writes `phone_revealed`
  or `whatsapp_clicked` events captured from the listing-details CTA taps.
  Refuses `inquiry_sent` (that path goes through `submit_inquiry`) and
  `favorite_added` (Phase 17).

## Failure modes

- CHECK violation on `event_type` (unknown enum value) → SQLSTATE 23514.
- FK violation on `listing_id` → SQLSTATE 23503.
- Direct `INSERT`/`UPDATE`/`DELETE` from `authenticated` or `anon` clients is
  rejected by Sub-Phase C's REVOKE.

## RLS Matrix (Sub-Phase C, `20260527120004_create_lead_events_policies.sql`)

Defined by Sub-Phase C; authoritative contract at
[`specs/016-contact-inquiries/contracts/phase16-lead-events-policies.md`](../../specs/016-contact-inquiries/contracts/phase16-lead-events-policies.md).

The visibility rule is **two-tier** on SELECT (publisher of the listing,
admin holding `inquiries.view_all`). All client-facing writes are blocked
at the table level — every row originates from a Sub-Phase D SECURITY
DEFINER RPC. The `metadata` column (server-side trusted `{ip, user_agent}`
payload per Q5=B) MUST NOT be exposed to publisher-tier readers per
FR-014b, but RLS partitions rows, not columns — the masking is enforced
by **view projection** in `20260527120008_create_v_lead_events_views.sql`:
the publisher view OMITS the column from its SELECT clause; the admin view
projects it AND adds a defensive `WHERE
public.current_user_has_permission('inquiries.view_all')` predicate.

| Actor                          | SELECT (base table) | SELECT (`v_lead_events_publisher`) | SELECT (`v_lead_events_admin`) | INSERT       | UPDATE       | DELETE       |
|--------------------------------|---------------------|------------------------------------|--------------------------------|--------------|--------------|--------------|
| `anon`                         | none                | none (no GRANT)                    | none (no GRANT)                | RPC only     | none         | none         |
| `authenticated` — publisher    | own listings' events| own listings' events (no `metadata`) | zero rows (defensive WHERE)  | RPC only     | none         | none         |
| `authenticated` — admin (`inquiries.view_all`) | all events | all events (no `metadata`)    | all events (with `metadata`)   | RPC only     | none         | none         |
| `authenticated` — other        | none                | none                               | zero rows (defensive WHERE)    | RPC only     | none         | none         |

Notes:

- **Publisher tier reads via `v_lead_events_publisher`**: the view projects
  five columns (`id, listing_id, user_id, event_type, created_at`) — the
  `metadata` column is intentionally absent from the SELECT clause, so
  publisher-side analytics queries (counts, time series) can be computed
  without any IP/UA exposure. The Sub-Phase D advisor-hardening migration
  also REVOKEs base-table SELECT from `authenticated` so the view is the
  only readable surface.
- **Admin tier reads via `v_lead_events_admin`**: the view projects all
  six columns AND adds `WHERE public.current_user_has_permission('inquiries.view_all')`
  as a second line of defense. A non-admin who somehow obtains SELECT on
  this view still gets zero rows.
- **No direct table writes from clients**: `REVOKE INSERT, UPDATE, DELETE
  ON public.lead_events FROM authenticated, anon` means every row
  originates from `public.submit_inquiry` (writes `inquiry_sent`) or
  `public.record_lead_event` (writes `phone_revealed` / `whatsapp_clicked`),
  both SECURITY DEFINER. The `favorite_added` event type is reserved for
  Phase 17 — no Phase 16 RPC emits it.
- **`metadata` is server-trusted**: the RPCs capture IP via
  `inet_client_addr()` and UA via `current_setting('request.headers',
  true)::jsonb->>'user-agent'` — client-supplied values are NEVER
  accepted (the RPCs do not declare parameters for these fields).
