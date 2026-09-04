-- Put a ceiling on the three endpoints a signed-out stranger can call.
--
-- `submit_inquiry`, `record_lead_event` and `record_ad_event` are deliberately
-- guest-callable and validate their inputs well, but nothing limited how OFTEN.
-- `submit_inquiry` also enqueues a push to the publisher, so one script could
-- flood a publisher's phone and fill three tables. Supabase rate-limits Auth
-- endpoints, not PostgREST RPC.
--
-- ---------------------------------------------------------------------------
-- Why these caps are per-listing and per-user, and NOT per-IP
-- ---------------------------------------------------------------------------
-- The obvious key is the caller's IP. It is not available. All three functions
-- already record `inet_client_addr()`, and every row they have ever written
-- says the same thing:
--
--     select metadata from public.lead_events;
--     -> {"ip": "::1/128", "user_agent": "Dart/3.9 (dart:io)"}
--
-- `::1` is PostgREST talking to Postgres over loopback — it is identical for
-- every caller on earth. A per-IP cap on that column would not throttle an
-- attacker; it would throttle *everyone at once*, as a single client. So the
-- caps below key on things that are real:
--
--   * per listing / per ad — bounds the harm to one publisher (the push flood)
--     and to table growth, whether the caller is signed in or not;
--   * per authenticated user — `auth.uid()` is trustworthy when present.
--
-- The limits are set as runaway-script guards, not business rules: 20 inquiries
-- on ONE listing in an hour is already implausible from real people. A
-- determined attacker can still burn a listing's hourly allowance and deny
-- genuine inquiries for that hour; that trade is deliberate, and far better
-- than the unbounded flood it replaces.
--
-- `app_client_fingerprint()` below resolves the forwarded client IP if the
-- gateway supplies one, and returns NULL when all it can see is loopback. It is
-- NOT used as a cap yet — the header's presence has to be observed on a real
-- device request first. It is recorded into `metadata->>'client'` from now on
-- so that after the next real use we can look, and then add the sharper per-IP
-- cap knowing it works. Recorded as A24 in DELIVERY_PLAN.md.

-- ---------------------------------------------------------------------------
-- Helper — best available client key, or NULL when there is none
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_client_fingerprint()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  h jsonb;
  v text;
BEGIN
  BEGIN
    h := current_setting('request.headers', true)::jsonb;
  EXCEPTION WHEN OTHERS THEN
    h := NULL;
  END;

  IF h IS NOT NULL THEN
    -- x-forwarded-for is a comma-separated chain; the first entry is the client.
    v := nullif(btrim(split_part(coalesce(h->>'x-forwarded-for', ''), ',', 1)), '');
    IF v IS NOT NULL THEN RETURN v; END IF;
    v := nullif(btrim(coalesce(h->>'cf-connecting-ip', '')), '');
    IF v IS NOT NULL THEN RETURN v; END IF;
    v := nullif(btrim(coalesce(h->>'x-real-ip', '')), '');
    IF v IS NOT NULL THEN RETURN v; END IF;
  END IF;

  -- Nothing usable. Do NOT fall back to inet_client_addr(): see the header
  -- comment — it is the API process's loopback address, the same for everyone.
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.app_client_fingerprint() FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.app_client_fingerprint() IS
  'Forwarded client IP when the gateway supplies one, else NULL. Called only from SECURITY DEFINER functions; never granted to anon/authenticated.';

-- ---------------------------------------------------------------------------
-- submit_inquiry — unchanged except the guard and the recorded client key
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_inquiry(p_listing_id uuid, p_sender_name text, p_inquirer_phone text, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'vault'
AS $function$
DECLARE
  v_listing_status       TEXT;
  v_publisher_user_id    UUID;
  v_inquiry_id           UUID;
  v_phone_normalized     TEXT;
  v_key_id               UUID;
  v_encrypted            BYTEA;
  v_ip                   INET;
  v_user_agent           TEXT;
  v_client               TEXT;
  v_recent               INT;
BEGIN
  -- 1. Validate p_sender_name length 1..100.
  IF p_sender_name IS NULL OR length(trim(p_sender_name)) < 1 OR length(trim(p_sender_name)) > 100 THEN
    RAISE EXCEPTION 'invalid_sender_name' USING ERRCODE = '23514';
  END IF;

  -- 2. Validate p_inquirer_phone — E.164: + then [1-9] then 6..14 digits.
  IF p_inquirer_phone IS NULL OR p_inquirer_phone !~ '^\+[1-9]\d{6,14}$' THEN
    RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '23514';
  END IF;
  v_phone_normalized := p_inquirer_phone;

  -- 3. Validate p_message length 1..2000.
  IF p_message IS NULL OR length(trim(p_message)) < 1 OR length(trim(p_message)) > 2000 THEN
    RAISE EXCEPTION 'invalid_message_length' USING ERRCODE = '23514';
  END IF;

  -- 4 + 5 + 6. Validate listing exists, is approved, and the caller is not the publisher.
  SELECT l.status, l.publisher_user_id
    INTO v_listing_status, v_publisher_user_id
    FROM public.listings l
    WHERE l.id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_listing_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;
  IF auth.uid() IS NOT NULL AND v_publisher_user_id = auth.uid() THEN
    RAISE EXCEPTION 'self_contact_blocked' USING ERRCODE = '23514';
  END IF;

  -- 6b. Rate guard (added 2026-09-04). Uses idx_inquiries_listing_created.
  SELECT count(*) INTO v_recent
    FROM public.inquiries i
    WHERE i.listing_id = p_listing_id
      AND i.created_at > now() - interval '1 hour';
  IF v_recent >= 20 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT count(*) INTO v_recent
      FROM public.inquiries i
      WHERE i.sender_user_id = auth.uid()
        AND i.created_at > now() - interval '1 hour';
    IF v_recent >= 10 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
    END IF;
  END IF;

  -- Fetch Vault key (its decrypted_secret value is the pgsodium key uuid).
  SELECT decrypted_secret::uuid INTO v_key_id
    FROM vault.decrypted_secrets
    WHERE name = 'app-inquirer-phone-key';

  IF v_key_id IS NULL THEN
    RAISE EXCEPTION 'vault_key_missing' USING ERRCODE = 'P0001';
  END IF;

  -- Pre-generate the inquiry id so it can serve as deterministic AEAD AAD.
  v_inquiry_id := gen_random_uuid();
  v_encrypted := pgsodium.crypto_aead_det_encrypt(
    convert_to(v_phone_normalized, 'utf8'),
    convert_to(v_inquiry_id::text, 'utf8'),    -- AAD (context binds ciphertext to inquiry row)
    v_key_id,
    pg_catalog.uuid_send(v_inquiry_id)         -- 16-byte deterministic nonce
  );

  -- Capture IP + UA from server-side request context (Q5=B).
  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;
  v_client := public.app_client_fingerprint();

  -- Atomic two-row INSERT (single PL/pgSQL transaction).
  INSERT INTO public.inquiries (
    id, listing_id, sender_user_id, sender_name,
    inquirer_phone_encrypted, inquirer_phone_key_name,
    message, status, created_at, updated_at
  ) VALUES (
    v_inquiry_id, p_listing_id, auth.uid(), trim(p_sender_name),
    v_encrypted, 'app-inquirer-phone-key',
    trim(p_message), 'new', now(), now()
  );

  INSERT INTO public.lead_events (
    listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    p_listing_id, auth.uid(), 'inquiry_sent',
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent, 'client', v_client),
    now()
  );

  -- Phase 22 fan-out: notify the listing's publisher (server-resolved recipient — FR-002);
  -- params carry UUIDs only for the deep link (FR-004). v_publisher_user_id already in scope.
  PERFORM public.enqueue_notification(
    v_publisher_user_id, 'inquiry_received',
    jsonb_build_object('listing_id', p_listing_id, 'inquiry_id', v_inquiry_id));

  RETURN v_inquiry_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- record_lead_event — unchanged except the guard and the recorded client key
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_lead_event(p_listing_id uuid, p_event_type text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_status        TEXT;
  v_phone         TEXT;
  v_whatsapp      TEXT;
  v_event_id      UUID;
  v_ip            INET;
  v_user_agent    TEXT;
  v_client        TEXT;
  v_recent        INT;
BEGIN
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

  -- Rate guard (added 2026-09-04). Uses idx_lead_events_listing_created.
  -- The client discards this call's result (the dialer opens either way — see
  -- contact_actions.dart), so a rejection costs an analytics row, not a call.
  SELECT count(*) INTO v_recent
    FROM public.lead_events e
    WHERE e.listing_id = p_listing_id
      AND e.created_at > now() - interval '1 hour';
  IF v_recent >= 60 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT count(*) INTO v_recent
      FROM public.lead_events e
      WHERE e.user_id = auth.uid()
        AND e.created_at > now() - interval '1 hour';
    IF v_recent >= 120 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
    END IF;
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;
  v_client := public.app_client_fingerprint();

  v_event_id := gen_random_uuid();
  INSERT INTO public.lead_events (
    id, listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    v_event_id, p_listing_id, auth.uid(), p_event_type,
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent, 'client', v_client),
    now()
  );

  RETURN v_event_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- record_ad_event — unchanged except the guard and the recorded client key
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_ad_event(p_ad_id uuid, p_placement_key text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_event_id   UUID;
  v_ip         INET;
  v_user_agent TEXT;
  v_client     TEXT;
  v_recent     INT;
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

  -- Rate guard (added 2026-09-04). Uses idx_ad_impressions_ad_kind. Deliberately
  -- loose: an ad is shown to everyone, so this is a runaway-script ceiling, not
  -- a traffic limit. Revisit if a single ad ever legitimately nears it.
  SELECT count(*) INTO v_recent
    FROM public.ad_impressions i
    WHERE i.ad_id = p_ad_id
      AND i.occurred_at > now() - interval '1 hour';
  IF v_recent >= 500 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT count(*) INTO v_recent
      FROM public.ad_impressions i
      WHERE i.user_id = auth.uid()
        AND i.occurred_at > now() - interval '1 hour';
    IF v_recent >= 200 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
    END IF;
  END IF;

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN v_user_agent := NULL;
  END;
  v_client := public.app_client_fingerprint();

  v_event_id := gen_random_uuid();
  INSERT INTO public.ad_impressions (id, ad_id, placement_key, user_id, kind, metadata, occurred_at)
  VALUES (v_event_id, p_ad_id, p_placement_key, auth.uid(), 'click',
          jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent, 'client', v_client), now());

  RETURN v_event_id;
END;
$function$;
