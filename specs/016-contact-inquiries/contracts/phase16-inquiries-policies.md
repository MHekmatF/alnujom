# Contract — `public.inquiries` RLS policies (three-tier rule)

**Owner**: Sub-Phase C (`supabase/migrations/20260527120003_create_inquiries_policies.sql`).

**Consumers**: every read/write path on the table — this is the load-bearing security contract per Constitution Principle III + FR-022 + FR-024.

## SELECT policies (three independent OR'd predicates)

Per Postgres RLS, multiple SELECT policies on the same table are OR'd. A row is visible if ANY policy's USING returns true.

1. `inquiries_select_publisher` — `EXISTS (SELECT 1 FROM listings l WHERE l.id = inquiries.listing_id AND l.publisher_user_id = auth.uid())`. Covers the publisher inbox.
2. `inquiries_select_sender` — `sender_user_id = auth.uid() AND sender_user_id IS NOT NULL`. Covers the signed-in inquirer's self-read.
3. `inquiries_select_admin` — `public.current_user_has_permission('inquiries.view_all')`. Covers admin oversight per US7.

Each policy is granted to the `authenticated` role only; `anon` cannot read at all.

## UPDATE policy

- `inquiries_update_publisher` — `USING (EXISTS (... publisher_user_id = auth.uid()))` AND `WITH CHECK (same)`. Both USING and WITH CHECK applied so updates can't reach unowned rows.
- Sender-side updates: NOT allowed (no sender UPDATE policy).
- Anonymous updates: NOT allowed.
- The `enforce_inquiry_transition` trigger (Sub-Phase B) validates the new `status` value independently — RLS validates the actor; the trigger validates the transition.

## INSERT

- Table-level `REVOKE INSERT ON public.inquiries FROM authenticated, anon`.
- The only insert path is the `submit_inquiry` SECURITY DEFINER RPC (Sub-Phase D) which is granted to both authenticated and anon.

## DELETE

- No DELETE policy; RLS default-deny applies. Inquiries are immutable historical records.

## Pre-conditions

- `public.inquiries` table exists (Sub-Phase B).
- `public.current_user_has_permission(text)` function exists (Phase 6).
- The `inquiries.view_all` permission row is present in `public.permissions` — the migration's preamble idempotently inserts it if missing.

## Post-conditions

- A publisher session sees ALL inquiries on listings they own, ZERO inquiries on listings they don't own (verified by SC-006 wire-level capture).
- A signed-in sender sees ONLY their own outbound inquiries (verified by US3 acceptance scenario 5).
- An admin holding `inquiries.view_all` sees ALL inquiries across all publishers (verified by US7 + SC-008).
- An anonymous client receives ZERO rows from any SELECT against `public.inquiries` directly (verified by SC-007).
- A publisher attempting to UPDATE an unowned inquiry receives 0 rows affected (verified by SC-015).

## Failure modes

- Direct INSERT attempt from a non-RPC path returns "permission denied for table inquiries" (the REVOKE blocks).
- Cross-tenant UPDATE attempt returns "0 rows affected" (the USING predicate hides the row).
- A publisher attempting an invalid status transition receives SQLSTATE 23514 from the BEFORE UPDATE trigger.

## Stability surface

**Frozen**:

- The three SELECT policies' predicates (changes would alter the security boundary).
- The UPDATE policy's actor restriction (publisher-only).
- The DELETE no-op (no deletion ever).

**Allowed to change in future phases**:

- Adding new SELECT policies for new reader classes (e.g., a future "team member" tier per Phase 19 agency context).
- Adding new permission keys that participate in the admin predicate.
