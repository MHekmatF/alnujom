-- Phase 18 (spec/018-reports-moderation) — Migration 6/8 — submit_report write path (FR-003, FR-004, FR-010).
-- SECURITY DEFINER: the ONLY report-creation path. No direct client INSERT grant
-- on public.reports (Migration 1/3), so the auth + reason + approved-listing +
-- open-report-dedup gates cannot be bypassed and reporter_user_id cannot be forged.
-- Authenticated-only. Mirrors record_lead_event / add_favorite IP/UA capture.

CREATE OR REPLACE FUNCTION public.submit_report(
  p_listing_id UUID,
  p_reason     TEXT,
  p_note       TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_status TEXT;
  v_id     UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  IF p_reason NOT IN ('fake_listing','wrong_price','already_sold_or_rented',
                      'duplicate','spam','wrong_location',
                      'inappropriate_content','other') THEN
    RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
  END IF;

  SELECT l.status INTO v_status FROM public.listings l WHERE l.id = p_listing_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;

  -- Open-report dedup (FR-004). The partial unique index is the race backstop.
  IF EXISTS (
    SELECT 1 FROM public.reports
    WHERE reporter_user_id = v_uid
      AND listing_id = p_listing_id
      AND status IN ('new','reviewing')
  ) THEN
    RAISE EXCEPTION 'already_reported' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.reports (listing_id, reporter_user_id, reason, note, status, metadata)
  VALUES (
    p_listing_id, v_uid, p_reason, NULLIF(p_note, ''), 'new',
    jsonb_build_object(
      'ip', inet_client_addr()::text,
      'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent'
    )                                            -- FR-010(e), mirrors record_lead_event
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_report(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_report(UUID, TEXT, TEXT) TO authenticated;
-- NOT granted to anon (FR-010(a)).
