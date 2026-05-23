-- Phase 12 amendment (spec/012-listing-approval) — atomic wrappers for the
-- Edge-Function-driven approve / reject mutators.
--
-- Bug root-cause:
-- The Phase 2 migration `20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`
-- introduced `public.set_app_user_id_for_session(uuid)` and
-- `public.set_app_rejection_reason_for_session(text)` to be called by the
-- Edge Function before the UPDATE so the amended trigger functions
-- (`listing_status_transition_trigger_fn`, `listings_audit_trigger_fn`,
-- `log_audit`) could read the admin's UID via `current_setting(...)`.
--
-- Both setter functions use `set_config(..., is_local := true)`, which
-- persists ONLY for the current TRANSACTION. PostgREST runs each
-- `adminClient.rpc(...)` and `adminClient.from(...).update(...)` as a
-- separate transaction — so the GUC set in transaction A is gone by
-- transaction B. The trigger then reads NULL from the GUC, COALESCE falls
-- back to `auth.uid()` which is NULL under the service-role connection,
-- and `changed_by` + `actor_user_id` come out NULL.
--
-- Manual T044 verification on 2026-05-23 confirmed this: listing
-- `7d7c5da6-a329-4960-b5d3-ce68abfe5c93` was approved via the deployed
-- Edge Function, the audit row + status_history row were emitted, but both
-- attribution columns were NULL instead of the super_admin's UID.
--
-- Fix:
-- Two new SECURITY DEFINER wrappers — `approve_listing_internal` and
-- `reject_listing_internal` — that perform the GUC set + privileged
-- UPDATE in the SAME plpgsql block (same transaction). The amended
-- triggers fire inside this transaction and see the GUC successfully.
-- The original setter functions are KEPT (no breaking-change for any
-- direct-SQL use cases) but the Edge Functions will be refactored to
-- invoke these wrappers via a single RPC call.
--
-- Both wrappers are GRANT EXECUTE TO service_role ONLY (anon /
-- authenticated cannot invoke them directly).

-- ─── approve_listing_internal ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.approve_listing_internal(
  p_listing_id UUID,
  p_actor_user_id UUID
)
RETURNS TABLE(
  id UUID,
  status TEXT,
  published_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- 1. Set the FR-024 session variable LOCAL to this transaction.
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  -- 2. Status-guarded UPDATE in the SAME transaction. Triggers
  --    (listing_status_transition_trigger_fn + listings_audit_trigger_fn)
  --    fire here and read the GUC we just set.
  RETURN QUERY
  UPDATE public.listings AS l
     SET status = 'approved',
         published_at = now()
   WHERE l.id = p_listing_id
     AND l.status = 'pending_review'
  RETURNING l.id, l.status, l.published_at, l.expires_at;
END;
$$;

REVOKE ALL ON FUNCTION public.approve_listing_internal(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.approve_listing_internal(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.approve_listing_internal(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.approve_listing_internal(UUID, UUID) TO service_role;

-- ─── reject_listing_internal ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.reject_listing_internal(
  p_listing_id UUID,
  p_actor_user_id UUID,
  p_reason_json TEXT
)
RETURNS TABLE(
  id UUID,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- 1. Set the FR-024 session variables LOCAL to this transaction.
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);
  PERFORM set_config('app.current_rejection_reason', p_reason_json, true);

  -- 2. Status-guarded UPDATE in the SAME transaction.
  RETURN QUERY
  UPDATE public.listings AS l
     SET status = 'rejected'
   WHERE l.id = p_listing_id
     AND l.status = 'pending_review'
  RETURNING l.id, l.status;
END;
$$;

REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) TO service_role;
