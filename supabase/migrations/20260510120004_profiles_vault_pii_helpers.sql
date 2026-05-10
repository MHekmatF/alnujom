-- Phase 5 (spec/005-auth-profile) — Migration 4/5
-- Vault PII helpers — five SECURITY DEFINER functions that mediate every read and write
-- of legal_name, national_id, private_contact_methods stored as per-user secrets in
-- vault.secrets keyed `pii.<user_id>.<field_name>`.
-- Per contracts/vault-pii-helpers.md, research R-13, FR-005, FR-006.
--
-- IMPORTANT (per R-13):
--   - All helpers validate field_name against an allowlist; callers cannot construct
--     arbitrary secret names like `pii.<other_user>.legal_name`.
--   - Self helpers bind to auth.uid(); admin helpers gate on current_user_is_admin().
--   - Reads delegate to Phase 4's app_vault_secret(name) helper unchanged.
--   - Writes call vault.create_secret(value, name, description); vault.create_secret
--     is idempotent on `name` per Supabase Vault docs (second calls update value).

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Read self
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_vault_secret_for_self(field_name TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN NULL; END IF;
  IF field_name NOT IN ('legal_name', 'national_id', 'private_contact_methods') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN app_vault_secret(format('pii.%s.%s', uid, field_name));
END;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Read admin (returns NULL silently for non-admin — no info leak)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_vault_secret_for_user(p_user_id UUID, field_name TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  IF NOT current_user_is_admin() THEN RETURN NULL; END IF;
  IF field_name NOT IN ('legal_name', 'national_id', 'private_contact_methods') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN app_vault_secret(format('pii.%s.%s', p_user_id, field_name));
END;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Write self (TEXT-typed fields: legal_name, national_id)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_vault_set_secret_for_self(field_name TEXT, p_value TEXT)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  uid UUID := auth.uid();
  secret_name TEXT;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF field_name NOT IN ('legal_name', 'national_id') THEN
    RAISE EXCEPTION 'use app_vault_set_private_contact_methods_for_self for private_contact_methods, or invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.%s.%s', uid, field_name);
  PERFORM vault.create_secret(p_value, secret_name, 'AlNujom PII per-user-per-field');
END;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 4. Write admin (TEXT-typed fields)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_vault_set_secret_for_user(p_user_id UUID, field_name TEXT, p_value TEXT)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  secret_name TEXT;
BEGIN
  IF NOT current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF field_name NOT IN ('legal_name', 'national_id') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.%s.%s', p_user_id, field_name);
  PERFORM vault.create_secret(p_value, secret_name, 'AlNujom PII per-user-per-field (admin write)');
END;
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 5. Write self for private_contact_methods (JSON-typed; keys allowlisted)
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app_vault_set_private_contact_methods_for_self(p_methods JSONB)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  uid UUID := auth.uid();
  secret_name TEXT;
  k TEXT;
  ALLOWED CONSTANT TEXT[] := ARRAY['whatsapp','telegram','signal','private_email','secondary_phone'];
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_methods) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'private_contact_methods must be a JSON object' USING ERRCODE = '22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(p_methods) LOOP
    IF k <> ALL(ALLOWED) THEN
      RAISE EXCEPTION 'unknown channel key: %', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  secret_name := format('pii.%s.private_contact_methods', uid);
  PERFORM vault.create_secret(p_methods::TEXT, secret_name, 'AlNujom PII private_contact_methods JSON');
END;
$$;
