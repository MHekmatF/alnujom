-- Phase 17 (spec/017-favorites) — Migration 4/5 — add_favorite write path (FR-011, FR-014, FR-015).
-- SECURITY DEFINER: inserts the favorite AND (deduped) the favorite_added
-- lead event atomically. Authenticated-only. Validates approved listing.

CREATE OR REPLACE FUNCTION public.add_favorite(p_listing_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_status TEXT;
  v_ip     INET;
  v_ua     TEXT;
BEGIN
  -- Favorites are authenticated-only (FR-011).
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;

  -- Listing must exist and be approved (mirrors record_lead_event).
  SELECT l.status INTO v_status FROM public.listings l WHERE l.id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;

  -- Idempotent favorite insert (FR-007 composite PK).
  INSERT INTO public.favorites (user_id, listing_id)
  VALUES (v_uid, p_listing_id)
  ON CONFLICT (user_id, listing_id) DO NOTHING;

  -- Deduped favorite_added: once per (user, listing) ever (Q3=B / FR-015).
  IF NOT EXISTS (
    SELECT 1 FROM public.lead_events
    WHERE user_id = v_uid
      AND listing_id = p_listing_id
      AND event_type = 'favorite_added'
  ) THEN
    v_ip := inet_client_addr();
    BEGIN
      v_ua := current_setting('request.headers', true)::jsonb->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
      v_ua := NULL;
    END;

    INSERT INTO public.lead_events (listing_id, user_id, event_type, metadata, created_at)
    VALUES (
      p_listing_id, v_uid, 'favorite_added',
      jsonb_build_object('ip', v_ip::text, 'user_agent', v_ua),
      now()
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.add_favorite(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_favorite(UUID) TO authenticated;
-- NOT granted to anon (FR-011).
