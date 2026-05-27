-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase C Migration 1/4
-- public.inquiries — RLS three-tier visibility policies.
--
-- Contracts:
--   - contracts/phase16-inquiries-policies.md
--   - data-model.md §2.3
--
-- Three-tier visibility rule (Constitution Principle III, FR-022, FR-024):
--   - publisher of the listing → SELECT + UPDATE
--   - signed-in original sender → SELECT only
--   - admin holding `inquiries.view_all` → SELECT only
--   - anon → no access at all
--
-- Write paths:
--   - INSERT: blocked at the table level; the only insert path is the
--     SECURITY DEFINER `submit_inquiry` RPC (Sub-Phase D).
--   - UPDATE: column-restricted to `status` by the advisor-hardening migration
--     (Sub-Phase D); the publisher-only UPDATE policy below gates the actor;
--     the `enforce_inquiry_transition` BEFORE UPDATE trigger (Sub-Phase B)
--     validates the new value against the FR-021a + Q2=B + Q3=B allowlist.
--   - DELETE: no policy; RLS default-deny applies — inquiries are immutable
--     historical records.

-- Defense-in-depth: ensure the `inquiries.view_all` permission row is
-- present. Phase 6's `20260515120002_create_permissions.sql` already seeds
-- this key, but the idempotent INSERT below is harmless if rerun and
-- forms a safety net if the catalog is ever rebuilt out of order.
INSERT INTO public.permissions (key, category, description) VALUES
  ('inquiries.view_all', 'inquiries', 'Cross-publisher inquiry read.')
ON CONFLICT (key) DO NOTHING;

-- SELECT: three-tier rule (publisher / sender / admin). Postgres RLS OR's
-- multiple policies on the same command, so a row is visible if ANY of the
-- three USING predicates returns true.

DROP POLICY IF EXISTS inquiries_select_publisher ON public.inquiries;
CREATE POLICY inquiries_select_publisher
  ON public.inquiries
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS inquiries_select_sender ON public.inquiries;
CREATE POLICY inquiries_select_sender
  ON public.inquiries
  FOR SELECT
  TO authenticated
  USING (sender_user_id = auth.uid() AND sender_user_id IS NOT NULL);

DROP POLICY IF EXISTS inquiries_select_admin ON public.inquiries;
CREATE POLICY inquiries_select_admin
  ON public.inquiries
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('inquiries.view_all'));

-- UPDATE: publisher only. The transition trigger validates the new status
-- independently — RLS validates the actor; the trigger validates the
-- transition.

DROP POLICY IF EXISTS inquiries_update_publisher ON public.inquiries;
CREATE POLICY inquiries_update_publisher
  ON public.inquiries
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = inquiries.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

-- INSERT: blocked at the table level. All inserts go through the
-- `submit_inquiry` SECURITY DEFINER RPC (Sub-Phase D), which is granted
-- EXECUTE to both `authenticated` and `anon`.
REVOKE INSERT ON public.inquiries FROM authenticated, anon;

-- DELETE: no policy; RLS default-deny applies.
