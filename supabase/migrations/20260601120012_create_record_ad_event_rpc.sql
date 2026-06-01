-- Phase 21 — public click recorder. Mirrors Phase 16 record_lead_event (R-167).
-- Validates the ad is eligible + assigned to the placement, then inserts a 'click'.
CREATE OR REPLACE FUNCTION public.record_ad_event(
  p_ad_id        UUID,
  p_placement_key TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
  v_event_id   UUID;
  v_ip         INET;
  v_user_agent TEXT;
BEGIN
  -- Eligibility + assignment gate (no permission needed — public recorder).
  IF NOT EXISTS (
    SELECT 1
    FROM public.ads a
    JOIN public.ad_placements p ON p.ad_id = a.id
    WHERE a.id = p_ad_id
      AND p.placement_key = p_placement_key
      AND a.is_active = true
      AND a.archived_at IS NULL
      AND (a.start_at IS NULL OR a.start_at <= now())
      AND (a.end_at   IS NULL OR a.end_at   >  now())
  ) THEN
    RAISE EXCEPTION 'ad_not_eligible' USING ERRCODE = '23514';
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN v_user_agent := NULL;
  END;

  v_event_id := gen_random_uuid();
  INSERT INTO public.ad_impressions (id, ad_id, placement_key, user_id, kind, metadata, occurred_at)
  VALUES (v_event_id, p_ad_id, p_placement_key, auth.uid(), 'click',
          jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent), now());

  RETURN v_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_ad_event(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_ad_event(UUID, TEXT) TO authenticated, anon;
