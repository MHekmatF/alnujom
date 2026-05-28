-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase C Migration 2/4
-- public.lead_events — RLS publisher + admin tier policies.
--
-- Contracts:
--   - contracts/phase16-lead-events-policies.md
--   - data-model.md §2.4
--
-- Visibility:
--   - publisher of the listing → SELECT on the base table; reads in production
--     go through `public.v_lead_events_publisher` which masks the `metadata`
--     column per FR-014b (column-level masking is enforced by view projection,
--     not RLS — RLS partitions rows, not columns).
--   - admin holding `inquiries.view_all` → SELECT on the base table; reads in
--     production go through `public.v_lead_events_admin` which projects the
--     `metadata` column AND adds a defensive WHERE on the permission predicate
--     as second-line defense.
--   - anon → no access.
--
-- Write paths:
--   - INSERT: blocked at the table level. The only insert paths are the
--     `submit_inquiry` RPC (writes `inquiry_sent`) and the `record_lead_event`
--     RPC (writes `phone_revealed` and `whatsapp_clicked`), both SECURITY
--     DEFINER (Sub-Phase D).
--   - UPDATE / DELETE: blocked at the table level. Lead events are immutable
--     historical signals.

DROP POLICY IF EXISTS lead_events_select_publisher ON public.lead_events;
CREATE POLICY lead_events_select_publisher
  ON public.lead_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings l
      WHERE l.id = lead_events.listing_id
        AND l.publisher_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS lead_events_select_admin ON public.lead_events;
CREATE POLICY lead_events_select_admin
  ON public.lead_events
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('inquiries.view_all'));

-- INSERT / UPDATE / DELETE: all blocked at the table level.
REVOKE INSERT, UPDATE, DELETE ON public.lead_events FROM authenticated, anon;
