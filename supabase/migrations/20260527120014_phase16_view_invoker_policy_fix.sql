-- Phase 16 (spec/016-contact-inquiries) — Follow-up hardening
-- Properly partition the lead-events visibility model.
--
-- BACKGROUND (continuation of 20260527120013):
--   After 20260527120013 set security_invoker = true on all three views,
--   the lead-events views broke (the underlying lead_events table is
--   REVOKEd from authenticated per phase16_advisor_hardening, so the
--   security_invoker views can no longer read it).
--
--   Separately, the original v_lead_events_publisher had no publisher
--   scoping — it returned ALL publishers' rows. With security_invoker = false,
--   that was a real cross-tenant leak; with security_invoker = true + a
--   revoke, it crashed instead of leaking.
--
-- FIX:
--   1. v_inquiries_inbox stays at security_invoker = true — the RLS
--      policies on public.inquiries (inquiries_select_publisher / sender /
--      admin) handle row gating. authenticated already has SELECT on
--      public.inquiries per phase16_advisor_hardening.
--
--   2. v_lead_events_publisher and v_lead_events_admin REVERT to
--      security_invoker = false (the postgres-owner default) so the view
--      bodies can read public.lead_events directly. They impose their own
--      WHERE filters:
--      - v_lead_events_publisher: WHERE listing.publisher_user_id = auth.uid()
--      - v_lead_events_admin:     WHERE current_user_has_permission(...)
--
--   3. v_lead_events_publisher is RE-CREATED with the missing publisher
--      JOIN + WHERE that the original migration omitted.

-- (1) Inbox view: confirm security_invoker = true and that RLS-gated reads on
--     public.inquiries are the only filter the view relies on.
ALTER VIEW public.v_inquiries_inbox SET (security_invoker = true);

-- (2 + 3) Lead-events publisher view: drop and recreate with publisher scope,
-- security_invoker = false.
DROP VIEW IF EXISTS public.v_lead_events_publisher;

CREATE VIEW public.v_lead_events_publisher
WITH (security_invoker = false) AS
SELECT
  le.id,
  le.listing_id,
  le.user_id,
  le.event_type,
  le.created_at
FROM public.lead_events le
JOIN public.listings l ON l.id = le.listing_id
WHERE l.publisher_user_id = auth.uid();

-- Lead-events admin view: keep its current body (defensive WHERE on
-- inquiries.view_all), just flip back to security_invoker = false.
ALTER VIEW public.v_lead_events_admin SET (security_invoker = false);

-- Re-apply post-DROP grants (DROP/CREATE forgets ACLs).
REVOKE ALL ON public.v_lead_events_publisher FROM PUBLIC, anon;
GRANT SELECT ON public.v_lead_events_publisher TO authenticated;
