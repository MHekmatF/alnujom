-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase D Migration 3/4
-- public.record_lead_event — lightweight lead-event capture for phone-reveal +
-- WhatsApp-click taps per FR-014 + FR-014b.
--
-- Scope:
--   - Allowed event types: 'phone_revealed', 'whatsapp_clicked' (snake_case wire).
--   - NOT allowed: 'inquiry_sent' (goes through submit_inquiry) or 'favorite_added'
--     (reserved for Phase 17 — no Phase 16 write path).
--
-- Per-event-type field check:
--   - phone_revealed → listings.phone must be non-empty (else phone_not_set).
--   - whatsapp_clicked → listings.whatsapp must be non-empty (else whatsapp_not_set).
--
-- IP + UA capture mirrors submit_inquiry (inet_client_addr + request.headers GUC).
--
-- GRANT EXECUTE to authenticated + anon — anonymous reveals are valid lead signal.

CREATE OR REPLACE FUNCTION public.record_lead_event(
  p_listing_id  UUID,
  p_event_type  TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_status        TEXT;
  v_phone         TEXT;
  v_whatsapp      TEXT;
  v_event_id      UUID;
  v_ip            INET;
  v_user_agent    TEXT;
BEGIN
  -- Restrict to the two Phase 16 tap-event types.
  IF p_event_type IS NULL OR p_event_type NOT IN ('phone_revealed', 'whatsapp_clicked') THEN
    RAISE EXCEPTION 'invalid_event_type' USING ERRCODE = '23514';
  END IF;

  SELECT l.status, l.phone, l.whatsapp
    INTO v_status, v_phone, v_whatsapp
    FROM public.listings l
    WHERE l.id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;
  IF p_event_type = 'phone_revealed' AND (v_phone IS NULL OR trim(v_phone) = '') THEN
    RAISE EXCEPTION 'phone_not_set' USING ERRCODE = '23514';
  END IF;
  IF p_event_type = 'whatsapp_clicked' AND (v_whatsapp IS NULL OR trim(v_whatsapp) = '') THEN
    RAISE EXCEPTION 'whatsapp_not_set' USING ERRCODE = '23514';
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;

  v_event_id := gen_random_uuid();
  INSERT INTO public.lead_events (
    id, listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    v_event_id, p_listing_id, auth.uid(), p_event_type,
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent),
    now()
  );

  RETURN v_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_lead_event(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_lead_event(UUID, TEXT) TO authenticated, anon;
