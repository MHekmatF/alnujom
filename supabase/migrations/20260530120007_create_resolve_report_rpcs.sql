-- Phase 18 (spec/018-reports-moderation) — Sub-Phase E (T019).
-- resolve_report_internal (service_role only) + start_report_review (authenticated).
-- Bodies are verbatim from data-model.md §1.7. Mirrors the Phase 12 atomic
-- wrappers (20260523120005): set_config('app.current_user_id', …, true) so the
-- existing listing triggers + the trg_reports_audit_resolution trigger attribute
-- the actor; report-resolve + listing transition + moderation_actions insert +
-- sibling auto-resolve all happen in ONE transaction (FR-013 / SC-006).
--
-- ─────────────────────────────────────────────────────────────────────────
-- T018 INTEGRATION CHECK (R-124) — listing status transition guard
-- ─────────────────────────────────────────────────────────────────────────
-- Read 20260519120006_create_listing_status_history.sql.
-- `listing_status_transition_trigger_fn` is a PURE LOGGING trigger: on any
-- status change it inserts a listing_status_history row (OLD.status → NEW.status)
-- and RETURN NEW. It does NOT reject any transition — there is no allowed-pair
-- guard on public.listings at all (the only transition-validation trigger in the
-- codebase is on public.inquiries, 20260527120005, which does NOT touch listings).
-- The only listings.status constraint is the column CHECK in 20260519120002,
-- which lists 'approved','paused','rejected','deleted' as valid values.
-- listings_audit_trigger_fn's status_verb CASE already maps paused/rejected/
-- deleted to audit verbs.
--
-- CONCLUSION: approved→paused, approved→rejected, approved→deleted, and
-- paused/rejected→deleted are ALL already permitted. NO guard amendment is
-- required, so this migration does NOT CREATE OR REPLACE the trigger fn.
-- ─────────────────────────────────────────────────────────────────────────

-- ─── resolve_report_internal (service_role only) ───
-- Mirrors the Phase 12 approve_reject_atomic_wrappers (20260523120005):
-- sets app.current_user_id so the existing listing triggers + the reports
-- audit trigger attribute the actor; performs report update + moderation_actions
-- insert + listing transition + sibling auto-resolve in ONE transaction.
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
    RAISE EXCEPTION 'already_resolved' USING ERRCODE = '23514';   -- SC-015
  END IF;

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_before FROM public.listings l WHERE l.id = v_listing_id;

  v_new_report := CASE WHEN p_action = 'dismiss' THEN 'dismissed' ELSE 'resolved' END;

  UPDATE public.reports
     SET status = v_new_report, resolved_by = p_actor_user_id,
         resolved_at = now(), resolution = p_action
   WHERE id = p_report_id;

  -- Listing transition (Q1=A). The existing listing triggers fire here.
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
  END IF;  -- dismiss: no listing change.

  SELECT jsonb_build_object('status', l.status, 'title', l.title)
    INTO v_after FROM public.listings l WHERE l.id = v_listing_id;

  INSERT INTO public.moderation_actions
    (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
  VALUES ('listing', v_listing_id, p_report_id, p_action, p_actor_user_id, p_note, v_before, v_after);

  -- Sibling auto-resolve (Q5=A) — only for listing-affecting actions.
  IF p_action <> 'dismiss' THEN
    FOR v_sib IN
      SELECT id FROM public.reports
      WHERE listing_id = v_listing_id AND id <> p_report_id
        AND status IN ('new','reviewing')
    LOOP
      UPDATE public.reports
         SET status = 'resolved', resolved_by = p_actor_user_id,
             resolved_at = now(), resolution = p_action
       WHERE id = v_sib.id;
      INSERT INTO public.moderation_actions
        (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
      VALUES ('listing', v_listing_id, v_sib.id, p_action, p_actor_user_id,
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

-- ─── start_report_review (authenticated; self-gates on reports.manage) ───
CREATE OR REPLACE FUNCTION public.start_report_review(p_report_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.current_user_has_permission('reports.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  -- Advisory soft lock: only claims a still-`new` report; an already-`reviewing`
  -- report is left to its current reviewer but remains resolvable by anyone.
  UPDATE public.reports
     SET status = 'reviewing', reviewing_by = auth.uid(), reviewing_started_at = now()
   WHERE id = p_report_id AND status = 'new';
END;
$$;

REVOKE ALL ON FUNCTION public.start_report_review(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_report_review(UUID) TO authenticated;
