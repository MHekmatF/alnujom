-- Phase 22 (spec/022-notifications-realtime) — Migration 5/11.
-- Re-based CREATE-OR-REPLACE amendment (R-183) of the Phase 16 submit_inquiry RPC
-- (base 20260527120009). Additive ONLY: every existing line preserved verbatim
-- (4-param signature, search_path, validations, encryption, atomic two-row INSERT,
-- REVOKE/GRANT). Inserts exactly ONE PERFORM public.enqueue_notification(...) after
-- the inquiry INSERT, addressed to the listing's publisher. The publisher
-- (v_publisher_user_id) and the inquiry id (v_inquiry_id) are ALREADY in scope from the
-- validation SELECT + pre-generated id — no extra lookup needed (re-base discipline §4).
-- Idempotent: create-or-replace + re-asserted grants; safely re-runnable.

CREATE OR REPLACE FUNCTION public.submit_inquiry(
  p_listing_id      UUID,
  p_sender_name     TEXT,
  p_inquirer_phone  TEXT,
  p_message         TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, vault
AS $$
DECLARE
  v_listing_status       TEXT;
  v_publisher_user_id    UUID;
  v_inquiry_id           UUID;
  v_phone_normalized     TEXT;
  v_key_id               UUID;
  v_encrypted            BYTEA;
  v_ip                   INET;
  v_user_agent           TEXT;
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
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent),
    now()
  );

  -- Phase 22 fan-out: notify the listing's publisher (server-resolved recipient — FR-002);
  -- params carry UUIDs only for the deep link (FR-004). v_publisher_user_id already in scope.
  PERFORM public.enqueue_notification(
    v_publisher_user_id, 'inquiry_received',
    jsonb_build_object('listing_id', p_listing_id, 'inquiry_id', v_inquiry_id));

  RETURN v_inquiry_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) TO authenticated, anon;
