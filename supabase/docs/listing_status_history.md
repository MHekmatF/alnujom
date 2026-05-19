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
