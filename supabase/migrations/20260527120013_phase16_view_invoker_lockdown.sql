-- Phase 16 (spec/016-contact-inquiries) — Final-phase hardening fix
-- Lock down the three Phase 16 views: make them honor caller RLS,
-- and revoke anon's default-granted privileges.
--
-- BACKGROUND (discovered in T085 wire-level verification):
--   Postgres views default to security_invoker = false, meaning they
--   execute with the view OWNER's privileges (postgres = superuser).
--   This BYPASSES the RLS policies on public.inquiries / public.lead_events.
--   In T085(a) verification, a user who was NEITHER sender NOR publisher
--   was able to read inquiry 444f71ce through v_inquiries_inbox.
--
--   Separately, CREATE VIEW + Supabase's default schema-level grants give
--   anon (and authenticated, service_role) ALL privileges on every view.
--   In T085(b) verification, anon could SELECT from all three Phase 16
--   views even though phase16_advisor_hardening (T033) explicitly granted
--   SELECT only to authenticated.
--
-- FIX:
--   1. ALTER VIEW … SET (security_invoker = true) — make the view honor
--      the caller's role + RLS, not the owner's.
--   2. REVOKE ALL … FROM PUBLIC, anon — strip the default-grant ladder.
--      Re-grant SELECT to authenticated explicitly (idempotent with T033).

ALTER VIEW public.v_inquiries_inbox       SET (security_invoker = true);
ALTER VIEW public.v_lead_events_publisher SET (security_invoker = true);
ALTER VIEW public.v_lead_events_admin     SET (security_invoker = true);

REVOKE ALL ON public.v_inquiries_inbox       FROM PUBLIC, anon;
REVOKE ALL ON public.v_lead_events_publisher FROM PUBLIC, anon;
REVOKE ALL ON public.v_lead_events_admin     FROM PUBLIC, anon;

GRANT SELECT ON public.v_inquiries_inbox       TO authenticated;
GRANT SELECT ON public.v_lead_events_publisher TO authenticated;
GRANT SELECT ON public.v_lead_events_admin     TO authenticated;
