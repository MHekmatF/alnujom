-- Phase 18 (spec/018-reports-moderation) — forward fix for resolve_report_internal.
--
-- Bug (found in device QA): the function RETURNS TABLE(..., listing_id UUID, ...),
-- so `listing_id` is an OUT parameter name. The sibling auto-resolve loop used a
-- BARE `WHERE listing_id = v_listing_id`, which PL/pgSQL flags as
-- `column reference "listing_id" is ambiguous` (OUT param vs reports.listing_id).
-- This broke every listing-affecting action (hide / mark_duplicate / delete),
-- which all run the sibling loop; dismiss (no loop) was unaffected.
--
-- Fix: alias the reports table in the sibling SELECT so the column refs are
-- unambiguous. Body is otherwise identical to 20260530120007 (data-model §1.7).

CREATE OR REPLACE FUNCTION public.resolve_report_internal(
  p_report_id     UUID,
  p_actor_user_id UUID,
  p_action        TEXT,
  p_note          TEXT DEFAULT NULL
)
RETURNS TABLE(report_id UUID, report_status TEXT, listing_id UUID, listing_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_listing_id   UUID;
  v_open_status  TEXT;
  v_before       JSONB;
  v_after        JSONB;
  v_new_report   TEXT;
  v_sib          RECORD;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  IF p_action NOT IN ('dismiss','hide','mark_duplicate','delete') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT r.listing_id, r.status INTO v_listing_id, v_open_status
  FROM public.reports r WHERE r.id = p_report_id;
  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'report_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_open_status NOT IN ('new','reviewing') THEN
    RAISE EXCEPTION 'already_resolved' USING ERRCODE = '23514';
  END IF;

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_before FROM public.listings l WHERE l.id = v_listing_id;

  v_new_report := CASE WHEN p_action = 'dismiss' THEN 'dismissed' ELSE 'resolved' END;

  UPDATE public.reports
     SET status = v_new_report, resolved_by = p_actor_user_id,
         resolved_at = now(), resolution = p_action
   WHERE id = p_report_id;

  IF p_action = 'hide' THEN
    UPDATE public.listings SET status = 'paused'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'mark_duplicate' THEN
    PERFORM set_config('app.current_rejection_reason', 'duplicate', true);
    UPDATE public.listings SET status = 'rejected'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'delete' THEN
    UPDATE public.listings SET status = 'deleted'
      WHERE id = v_listing_id AND status IN ('approved','paused','rejected');
  END IF;

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_after FROM public.listings l WHERE l.id = v_listing_id;

  INSERT INTO public.moderation_actions
    (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
  VALUES ('listing', v_listing_id, p_report_id, p_action, p_actor_user_id, p_note, v_before, v_after);

  -- Sibling auto-resolve (Q5=A) — only for listing-affecting actions.
  -- NOTE: alias the reports table (sib) so column refs do not collide with the
  -- OUT parameter `listing_id`.
  IF p_action <> 'dismiss' THEN
    FOR v_sib IN
      SELECT sib.id AS sib_id
      FROM public.reports sib
      WHERE sib.listing_id = v_listing_id
        AND sib.id <> p_report_id
        AND sib.status IN ('new','reviewing')
    LOOP
      UPDATE public.reports
         SET status = 'resolved', resolved_by = p_actor_user_id,
             resolved_at = now(), resolution = p_action
       WHERE id = v_sib.sib_id;
      INSERT INTO public.moderation_actions
        (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
      VALUES ('listing', v_listing_id, v_sib.sib_id, p_action, p_actor_user_id,
              'auto-resolved: listing actioned via report ' || p_report_id::text,
              v_before, v_after);
    END LOOP;
  END IF;

  RETURN QUERY
    SELECT p_report_id, v_new_report, v_listing_id,
           (SELECT l.status FROM public.listings l WHERE l.id = v_listing_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) TO service_role;
