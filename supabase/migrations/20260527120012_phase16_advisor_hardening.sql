-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase D Advisor Hardening
-- Safety-net hardening matching the Phase 9/10/11/14/15 advisor recommendations.
--
-- APPLY ORDER NOTE: this migration references views CREATED by Phase 3
-- (v_inquiries_inbox, v_lead_events_publisher, v_lead_events_admin). It can
-- ONLY be applied after Phase 3's view migrations have been applied. The
-- orchestrator handles this during the merge cascade — Phase 4's worktree
-- ships the file on disk but does NOT call apply_migration on it.

-- Re-assert search_path on every Phase 16 function (defense-in-depth against
-- schema-injection / search-path shadowing).
ALTER FUNCTION public.enforce_inquiry_transition()           SET search_path = pg_catalog, public;
ALTER FUNCTION public.decrypt_inquirer_phone(UUID)           SET search_path = pg_catalog, public, vault;
ALTER FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) SET search_path = pg_catalog, public, vault;
ALTER FUNCTION public.record_lead_event(UUID, TEXT)          SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_inbox_unread_count()               SET search_path = pg_catalog, public;

-- Table-level: deny direct table access; all reads/writes flow through views + RPCs.
REVOKE ALL ON TABLE public.inquiries   FROM PUBLIC, authenticated, anon;
REVOKE ALL ON TABLE public.lead_events FROM PUBLIC, authenticated, anon;

-- Column-restricted UPDATE: publishers may transition status only. The
-- transition trigger (Phase 2) joint-enforces which transitions are legal,
-- and the inquiries_update_publisher RLS policy (Phase 3) gates row access.
GRANT SELECT, UPDATE (status) ON TABLE public.inquiries TO authenticated;

-- Read access via the projection views (these views are created by Phase 3 —
-- this GRANT will fail until those view migrations are applied first).
GRANT SELECT ON public.v_inquiries_inbox       TO authenticated;
GRANT SELECT ON public.v_lead_events_publisher TO authenticated;
GRANT SELECT ON public.v_lead_events_admin     TO authenticated;
