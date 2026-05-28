-- Phase 16 (spec/016-contact-inquiries) — Sub-Phase D Migration 1/4
-- public.decrypt_inquirer_phone(uuid) — SECURITY DEFINER decrypt function
-- with three-tier visibility check per FR-023, FR-026, ADR-0001.
--
-- Three-tier authorization (any of):
--   - Caller is the original signed-in sender (sender_user_id = auth.uid())
--   - Caller is the listing's publisher (listings.publisher_user_id = auth.uid())
--   - Caller holds the `inquiries.view_all` permission (admin tier)
--
-- Silent failure on unauthorized callers (RETURN NULL, no RAISE EXCEPTION)
-- per FR-026; the consumer renders a "Phone unavailable" placeholder.
--
-- Decryption pattern mirrors the project's established Vault + pgsodium
-- surface — `vault.decrypted_secrets` view lookup by `name` yields the
-- pgsodium key uuid (the Vault secret VALUE is a UUID string per the
-- Phase 16 key provisioning convention), then
-- `pgsodium.crypto_aead_det_decrypt(message bytea, additional bytea, key_uuid uuid, nonce bytea)`
-- returns the plaintext bytea, which we convert_from to utf8 text.
--
-- API surface choice: the 3-arg overload (..., key_uuid uuid) is restricted to
-- the `pgsodium_keymaker` role and not executable by `postgres` (the SECURITY
-- DEFINER owner). The 4-arg overload that takes an explicit nonce IS executable
-- by `postgres`. We derive the nonce deterministically from the inquiry id
-- (16-byte UUID bytes match the 16-byte nonce length) so ciphertext remains
-- bound to a specific inquiry row — the AEAD additional data (AAD) carries
-- the inquiry id's text form for belt-and-braces context binding.

CREATE OR REPLACE FUNCTION public.decrypt_inquirer_phone(p_inquiry_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, vault
STABLE
AS $$
DECLARE
  v_listing_id        UUID;
  v_sender_user_id    UUID;
  v_encrypted         BYTEA;
  v_key_name          TEXT;
  v_authorized        BOOLEAN := FALSE;
  v_key_id            UUID;
  v_plain             TEXT;
BEGIN
  -- Load the inquiry row (bypassing RLS via SECURITY DEFINER).
  SELECT i.listing_id, i.sender_user_id, i.inquirer_phone_encrypted, i.inquirer_phone_key_name
    INTO v_listing_id, v_sender_user_id, v_encrypted, v_key_name
    FROM public.inquiries i
    WHERE i.id = p_inquiry_id;

  IF NOT FOUND OR v_encrypted IS NULL THEN
    RETURN NULL;
  END IF;

  -- Three-tier visibility check.
  IF v_sender_user_id IS NOT NULL AND v_sender_user_id = auth.uid() THEN
    v_authorized := TRUE;
  ELSIF EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = v_listing_id AND l.publisher_user_id = auth.uid()
  ) THEN
    v_authorized := TRUE;
  ELSIF public.current_user_has_permission('inquiries.view_all') THEN
    v_authorized := TRUE;
  END IF;

  IF NOT v_authorized THEN
    RETURN NULL;
  END IF;

  -- Decrypt (catch any failure and return NULL per FR-026 — corrupt
  -- ciphertext, missing key, key version mismatch all fail silently).
  BEGIN
    SELECT decrypted_secret::uuid INTO v_key_id
      FROM vault.decrypted_secrets
      WHERE name = v_key_name;

    IF v_key_id IS NULL THEN
      RETURN NULL;
    END IF;

    v_plain := convert_from(
      pgsodium.crypto_aead_det_decrypt(
        v_encrypted,
        convert_to(p_inquiry_id::text, 'utf8'),    -- AAD (must match encrypt-time)
        v_key_id,
        pg_catalog.uuid_send(p_inquiry_id)         -- 16-byte deterministic nonce
      ),
      'utf8'
    );
    RETURN v_plain;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.decrypt_inquirer_phone(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decrypt_inquirer_phone(UUID) TO authenticated;
