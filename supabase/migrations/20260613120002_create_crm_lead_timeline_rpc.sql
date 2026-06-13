-- Phase 029 (spec/029-crm-reels-growth) — F1 (W1): CRM RPCs.
--
-- 1) crm_lead_timeline(p_lead_id, p_limit) — a merged, newest-first activity
--    feed for a lead, unioning the inquiries / chat messages / viewings the
--    lead's contact has with the calling publisher. Read-side only; notes are
--    merged client-side from crm_notes.
-- 2) Three "upsert lead from source" helpers so the inquiry-detail / chat-thread
--    / viewings entry points can attach a lead while resolving the counterpart
--    (contact) user id SERVER-SIDE — the client never sees the counterpart's id
--    (RLS hides profiles). Each verifies the calling publisher owns the source.
--
-- All functions: SECURITY DEFINER, SET search_path = public, every table
-- aliased + every column qualified, REVOKE ALL FROM PUBLIC, anon then GRANT
-- EXECUTE TO authenticated.

-- ── Timeline ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crm_lead_timeline(
  p_lead_id uuid,
  p_limit   integer DEFAULT 100
)
RETURNS TABLE(
  event_kind    text,
  occurred_at   timestamptz,
  listing_id    uuid,
  listing_title text,
  snippet       text,
  ref_id        uuid
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner          uuid;
  v_contact        uuid;
  v_source_inquiry uuid;
BEGIN
  SELECT cl.publisher_user_id, cl.contact_user_id, cl.source_inquiry_id
    INTO v_owner, v_contact, v_source_inquiry
    FROM public.crm_leads cl
    WHERE cl.id = p_lead_id;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'lead not found' USING errcode = 'P0002';
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not authorized' USING errcode = '42501';
  END IF;

  RETURN QUERY
  -- Inquiries: those sent by the lead's contact OR the lead's source inquiry,
  -- restricted to listings the caller publishes.
  SELECT
    'inquiry'::text                AS event_kind,
    i.created_at                   AS occurred_at,
    i.listing_id                   AS listing_id,
    l.title                        AS listing_title,
    left(i.message, 140)           AS snippet,
    i.id                           AS ref_id
  FROM public.inquiries i
  JOIN public.listings l ON l.id = i.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND (
      (v_contact IS NOT NULL AND i.sender_user_id = v_contact)
      OR (v_source_inquiry IS NOT NULL AND i.id = v_source_inquiry)
    )

  UNION ALL

  -- Chat messages in conversations between the contact (buyer) and the caller.
  SELECT
    'message'::text                AS event_kind,
    m.created_at                   AS occurred_at,
    c.listing_id                   AS listing_id,
    l.title                        AS listing_title,
    left(m.body, 140)              AS snippet,
    m.id                           AS ref_id
  FROM public.messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  LEFT JOIN public.listings l ON l.id = c.listing_id
  WHERE v_contact IS NOT NULL
    AND c.buyer_user_id = v_contact
    AND c.publisher_user_id = auth.uid()

  UNION ALL

  -- Viewings requested by the contact on the caller's listings.
  SELECT
    ('viewing_' || v.status)::text AS event_kind,
    v.created_at                   AS occurred_at,
    v.listing_id                   AS listing_id,
    l.title                        AS listing_title,
    NULL::text                     AS snippet,
    v.id                           AS ref_id
  FROM public.viewings v
  LEFT JOIN public.listings l ON l.id = v.listing_id
  WHERE v_contact IS NOT NULL
    AND v.requester_user_id = v_contact
    AND v.publisher_user_id = auth.uid()

  ORDER BY occurred_at DESC
  LIMIT least(coalesce(p_limit, 100), 200);
END;
$$;

REVOKE ALL ON FUNCTION public.crm_lead_timeline(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_lead_timeline(uuid, integer) TO authenticated;

-- ── Upsert lead from an inquiry ────────────────────────────────────────────────
-- Attaches (or returns) a lead for the inquiry's sender. The caller must own
-- the inquiry's listing. display_name falls back to the inquiry sender_name.
CREATE OR REPLACE FUNCTION public.crm_upsert_lead_from_inquiry(
  p_inquiry_id uuid,
  p_display_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner       uuid := auth.uid();
  v_listing_id  uuid;
  v_sender      uuid;
  v_sender_name text;
  v_lead_id     uuid;
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING errcode = '42501';
  END IF;

  SELECT i.listing_id, i.sender_user_id, i.sender_name
    INTO v_listing_id, v_sender, v_sender_name
    FROM public.inquiries i
    JOIN public.listings l ON l.id = i.listing_id
    WHERE i.id = p_inquiry_id
      AND l.publisher_user_id = v_owner;

  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'inquiry not found or not owned' USING errcode = '42501';
  END IF;

  -- Prefer matching an existing lead for this same contact (when signed-in),
  -- else the source-inquiry unique. Insert otherwise.
  IF v_sender IS NOT NULL THEN
    SELECT cl.id INTO v_lead_id
      FROM public.crm_leads cl
      WHERE cl.publisher_user_id = v_owner AND cl.contact_user_id = v_sender
      LIMIT 1;
  END IF;

  IF v_lead_id IS NULL THEN
    SELECT cl.id INTO v_lead_id
      FROM public.crm_leads cl
      WHERE cl.publisher_user_id = v_owner AND cl.source_inquiry_id = p_inquiry_id
      LIMIT 1;
  END IF;

  IF v_lead_id IS NOT NULL THEN
    RETURN v_lead_id;
  END IF;

  INSERT INTO public.crm_leads
    (publisher_user_id, contact_user_id, source_inquiry_id, listing_id, display_name)
  VALUES (
    v_owner,
    v_sender,
    p_inquiry_id,
    v_listing_id,
    coalesce(nullif(trim(coalesce(p_display_name, '')), ''), nullif(trim(v_sender_name), ''), 'Lead')
  )
  RETURNING id INTO v_lead_id;

  RETURN v_lead_id;
END;
$$;

REVOKE ALL ON FUNCTION public.crm_upsert_lead_from_inquiry(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_upsert_lead_from_inquiry(uuid, text) TO authenticated;

-- ── Upsert lead from a conversation ────────────────────────────────────────────
-- Attaches (or returns) a lead for the conversation's buyer. The caller must be
-- the conversation's publisher.
CREATE OR REPLACE FUNCTION public.crm_upsert_lead_from_conversation(
  p_conversation_id uuid,
  p_display_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner      uuid := auth.uid();
  v_buyer      uuid;
  v_listing_id uuid;
  v_title      text;
  v_lead_id    uuid;
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING errcode = '42501';
  END IF;

  SELECT c.buyer_user_id, c.listing_id, l.title
    INTO v_buyer, v_listing_id, v_title
    FROM public.conversations c
    LEFT JOIN public.listings l ON l.id = c.listing_id
    WHERE c.id = p_conversation_id
      AND c.publisher_user_id = v_owner;

  IF v_buyer IS NULL THEN
    RAISE EXCEPTION 'conversation not found or not owned' USING errcode = '42501';
  END IF;

  SELECT cl.id INTO v_lead_id
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = v_owner AND cl.contact_user_id = v_buyer
    LIMIT 1;

  IF v_lead_id IS NOT NULL THEN
    RETURN v_lead_id;
  END IF;

  INSERT INTO public.crm_leads
    (publisher_user_id, contact_user_id, listing_id, display_name)
  VALUES (
    v_owner,
    v_buyer,
    v_listing_id,
    coalesce(nullif(trim(coalesce(p_display_name, '')), ''), nullif(trim(coalesce(v_title, '')), ''), 'Lead')
  )
  RETURNING id INTO v_lead_id;

  RETURN v_lead_id;
END;
$$;

REVOKE ALL ON FUNCTION public.crm_upsert_lead_from_conversation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_upsert_lead_from_conversation(uuid, text) TO authenticated;

-- ── Upsert lead from a viewing ─────────────────────────────────────────────────
-- Attaches (or returns) a lead for the viewing's requester. The caller must be
-- the viewing's publisher.
CREATE OR REPLACE FUNCTION public.crm_upsert_lead_from_viewing(
  p_viewing_id uuid,
  p_display_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner      uuid := auth.uid();
  v_requester  uuid;
  v_listing_id uuid;
  v_title      text;
  v_lead_id    uuid;
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING errcode = '42501';
  END IF;

  SELECT v.requester_user_id, v.listing_id, l.title
    INTO v_requester, v_listing_id, v_title
    FROM public.viewings v
    LEFT JOIN public.listings l ON l.id = v.listing_id
    WHERE v.id = p_viewing_id
      AND v.publisher_user_id = v_owner;

  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'viewing not found or not owned' USING errcode = '42501';
  END IF;

  SELECT cl.id INTO v_lead_id
    FROM public.crm_leads cl
    WHERE cl.publisher_user_id = v_owner AND cl.contact_user_id = v_requester
    LIMIT 1;

  IF v_lead_id IS NOT NULL THEN
    RETURN v_lead_id;
  END IF;

  INSERT INTO public.crm_leads
    (publisher_user_id, contact_user_id, listing_id, display_name)
  VALUES (
    v_owner,
    v_requester,
    v_listing_id,
    coalesce(nullif(trim(coalesce(p_display_name, '')), ''), nullif(trim(coalesce(v_title, '')), ''), 'Lead')
  )
  RETURNING id INTO v_lead_id;

  RETURN v_lead_id;
END;
$$;

REVOKE ALL ON FUNCTION public.crm_upsert_lead_from_viewing(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_upsert_lead_from_viewing(uuid, text) TO authenticated;
