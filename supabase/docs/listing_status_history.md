# listing_status_history

## Purpose

`listing_status_history` is the append-only operational status trail for Phase 10
listings. It is separate from the compliance-oriented `audit_logs` table.

## Shape

Defined in `supabase/migrations/20260519120006_create_listing_status_history.sql`.
Rows capture `previous_status`, `new_status`, `changed_by`, `changed_at`, and an
optional `reason`.

## Append-Only Invariant

RLS exposes an INSERT policy only for trigger-context writes via
`pg_trigger_depth() > 0`. There is no UPDATE policy and no DELETE policy.

## Triggers

`listing_status_transition_trigger` on `public.listings` appends one row on every
INSERT and every status-changing UPDATE. Phase 12 approve/reject work will reuse
this history surface for rejection-reason rendering.

## RLS Posture

Owners can read history for their own listings. Admins with
`listings.view_all` can read all history rows. Policies are mirrored in
`supabase/policies/listing_status_history_policies.sql`.

## Phase 12 amendments

**Spec**: `specs/012-listing-approval` (Phase 12 — Listing Approval Workflow)
**Migration**: `supabase/migrations/20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`
**Clarifications**: Q4=A (JSON-encoded TEXT reason), Q7=A (session-variable amendment)

Phase 12 amends `public.listing_status_transition_trigger_fn()` to:

1. **`changed_by` source** — COALESCE the session variable
   `app.current_user_id` (set by `set_app_user_id_for_session(UUID)` from the
   Edge Function service-role caller) against `auth.uid()`. Direct-JWT callers
   continue to attribute via `auth.uid()` (e.g., Phase 10's `submit_listing`
   RPC); Edge Function callers attribute via the session variable.
2. **`reason` source** — COALESCE the session variable
   `app.current_rejection_reason` (set by `set_app_rejection_reason_for_session(TEXT)`)
   against NULL. Only the `reject_listing` Edge Function populates this
   variable; every other status transition leaves `reason = NULL`.

### Reason storage shape (Q4=A)

When `new_status = 'rejected'` and the row was written by the `reject_listing`
Edge Function, `reason` is a JSON-encoded TEXT string of the form:

```json
{"preset":"<key>","detail":"<string|null>"}
```

Where `<key>` is one of the six Q3=A preset keys:

- `missing_or_low_quality_photos`
- `incorrect_location`
- `unrealistic_price`
- `incomplete_description`
- `duplicate_listing`
- `other`

The `detail` field is a free-text string up to 500 characters, or `null` if
the publisher-facing dialog left the optional field blank. When the preset is
`other`, the `detail` is UX-required to be a non-empty string (Q5=A enforced
client-side in the reject dialog).

### Read pattern

The column type remains `TEXT` in v1 (R-56 verified). Readers parse on demand
via `(reason::jsonb)->>'preset'` and `(reason::jsonb)->>'detail'`. Forward
compatibility: a future migration may `ALTER TABLE ALTER COLUMN reason TYPE
JSONB USING reason::jsonb` if cross-row analytic queries on the preset key
become hot — no row-by-row backfill needed because every Phase 12 reject row
is valid JSON.

### Session-variable handoff design (R-43)

The two setter functions `public.set_app_user_id_for_session(UUID)` and
`public.set_app_rejection_reason_for_session(TEXT)` are SECURITY DEFINER,
granted EXECUTE to `service_role` only, and `SET search_path = public, pg_temp`
per R-57 safety analysis. Both call `set_config(<name>, <value>, true)` where
the third argument scopes the variable to the current transaction — values do
NOT leak across requests or concurrent transactions.

The Phase 10 migration file
`20260519120006_create_listing_status_history.sql` remains UNEDITED.
