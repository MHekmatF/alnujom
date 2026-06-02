-- Phase 22 (spec/022-notifications-realtime) — Migration 7/11.
-- Re-based CREATE-OR-REPLACE amendment (R-183) of the Phase 12 atomic listing wrappers
-- approve_listing_internal / reject_listing_internal (base 20260523120005). Additive ONLY:
-- every existing line preserved verbatim (RETURNS TABLE shape, search_path, the FR-024
-- set_config GUC, the status-guarded RETURN QUERY UPDATE) and the SERVICE-ROLE-ONLY grants
-- stay UNCHANGED. Inserts exactly ONE PERFORM public.enqueue_notification(...) addressed to
-- the listing's publisher AFTER the status UPDATE — guarded by GET DIAGNOSTICS row-count so
-- it fires ONLY when the pending_review→approved/rejected transition actually occurred
-- (exactly-once on a no-op re-save — FR-003 / SC-009). NO reason text in params (FR-004).
-- Note: RETURN QUERY does NOT terminate the function — execution continues to the PERFORM,
-- and the accumulated result set is returned at function end.
-- Idempotent: create-or-replace + re-asserted grants; safely re-runnable.

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
DECLARE
  v_rows BIGINT;
  v_publisher UUID;
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

  -- 3. Phase 22 fan-out: only when the transition actually occurred (exactly-once — FR-003).
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    SELECT l.publisher_user_id INTO v_publisher FROM public.listings l WHERE l.id = p_listing_id;
    PERFORM public.enqueue_notification(
      v_publisher, 'listing_approved', jsonb_build_object('listing_id', p_listing_id));
  END IF;
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
DECLARE
  v_rows BIGINT;
  v_publisher UUID;
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

  -- 3. Phase 22 fan-out: only on a real transition (exactly-once — FR-003); NO reason in
  --    params — full rejection reason stays in-app behind the deep link only (FR-004).
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    SELECT l.publisher_user_id INTO v_publisher FROM public.listings l WHERE l.id = p_listing_id;
    PERFORM public.enqueue_notification(
      v_publisher, 'listing_rejected', jsonb_build_object('listing_id', p_listing_id));
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.reject_listing_internal(UUID, UUID, TEXT) TO service_role;
