-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase D Migration 2/4
-- public.submit_inquiry — atomic inquiry submission per FR-009 + FR-017.
--
-- SECURITY DEFINER + 4-param signature per contracts/phase16-submit-inquiry-rpc.md.
--
-- Validation flow:
--   1. sender_name length 1..100        → invalid_sender_name (SQLSTATE 23514)
--   2. phone matches E.164 strict regex → invalid_phone        (23514)
--   3. message length 1..2000           → invalid_message_length (23514)
--   4. listing exists                   → listing_not_found    (23503)
--   5. listing.status = 'approved'      → listing_not_approved (23514)
--   6. publisher_user_id <> auth.uid()  → self_contact_blocked (23514)
--
-- Encryption:
--   - Pre-generate inquiry id so it can serve as deterministic AEAD AAD + nonce.
--   - Vault key resolution: name='app-inquirer-phone-key' →
--     decrypted_secret holds the pgsodium key UUID (provisioned out-of-band).
--   - `pgsodium.crypto_aead_det_encrypt(message bytea, additional bytea, key_uuid uuid, nonce bytea)`.
--     The 4-arg overload (with explicit nonce) is the variant `postgres` can
--     execute; the 3-arg overload is restricted to `pgsodium_keymaker`. We use
--     uuid_send(inquiry_id) (16 bytes) as the deterministic nonce so ciphertext
--     remains bound to a single inquiry row.
--
-- Atomic two-row INSERT: inquiry row + companion lead_events row (event_type='inquiry_sent').
-- PL/pgSQL function body is one transaction by default — both-or-neither on any RAISE.
--
-- IP + UA capture: inet_client_addr() + request.headers GUC (PostgREST sets this).
-- Both land in lead_events.metadata as a JSONB {ip, user_agent} object per Q5=B.
--
-- GRANT EXECUTE to authenticated + anon (FR-008 — anonymous submission allowed).

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

  RETURN v_inquiry_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_inquiry(UUID, TEXT, TEXT, TEXT) TO authenticated, anon;
