-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase C Migration 4/4
-- public.v_lead_events_publisher + public.v_lead_events_admin — tiered views
-- with column-level metadata masking per FR-014b.
--
-- Contracts:
--   - contracts/phase16-v-lead-events-views.md
--   - data-model.md §2.8
--
-- RLS partitions rows, not columns. The `metadata` column carries
-- server-trusted IP + user-agent payload (Q5=B). Per FR-014b, publishers
-- MUST NOT see this metadata; only admins holding `inquiries.view_all` may.
-- The masking is enforced by view projection — the publisher view simply
-- omits the column from its SELECT clause, and the admin view adds a
-- defensive WHERE on the permission predicate as a second line of defense
-- (so a non-admin who somehow gets SELECT on the admin view still sees
-- zero rows).
--
-- DEPENDENCY: This migration is FILES-ONLY at Sub-Phase C apply time. It is
-- applied during the merge cascade alongside the inbox view (T025) for
-- ordering consistency, even though this view has no cross-dependency on
-- Phase 4 functions.

-- Publisher tier: metadata column INTENTIONALLY OMITTED from the projection.
CREATE OR REPLACE VIEW public.v_lead_events_publisher AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.created_at
FROM public.lead_events le;

GRANT SELECT ON public.v_lead_events_publisher TO authenticated;

-- Admin tier: every column INCLUDING metadata. Defensive WHERE on the
-- permission predicate so non-admin readers see zero rows even if SELECT
-- access is somehow granted to them on the view.
CREATE OR REPLACE VIEW public.v_lead_events_admin AS
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
