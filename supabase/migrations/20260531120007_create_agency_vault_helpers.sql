-- Phase 19 (spec/019-agencies) — Sub-Phase D, migration 7/13.
-- Agency Vault helpers (data-model §1.7 / contracts/phase19-agency-write-rpcs.md /
-- R-141 / ADR-0001). Mirrors the Phase 5 app_vault_set_secret_for_self /
-- app_vault_secret_for_user pattern (20260510120004): per-agency-per-field identity
-- PII (id_document_number + commercial_registration_number) stored in Vault under the
-- namespace 'pii.agency.{agency_id}.{field}', NEVER as a plaintext column or view field.
-- Decrypt is admin-only (agencies.view); write is agency-admin-only (is_agency_admin).

-- Admin/agency-admin write of agency identity PII to Vault (ADR-0001 + R-141),
-- mirroring app_vault_set_secret_for_self (20260510120004). secret_name namespace:
-- 'pii.agency.{agency_id}.{field}'. Re-submission overwrites via vault create/update.
CREATE OR REPLACE FUNCTION public.app_vault_set_agency_secret(
  p_agency_id UUID, field_name TEXT, p_value TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, vault AS $$
DECLARE secret_name TEXT; v_secret_id UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  IF field_name NOT IN ('id_document_number','commercial_registration_number') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.agency.%s.%s', p_agency_id, field_name);
  -- Idempotent: a re-submission after a rejection updates the existing secret rather than
  -- erroring on the duplicate name (vault.create_secret rejects an existing name).
  SELECT id INTO v_secret_id FROM vault.secrets WHERE name = secret_name;
  IF v_secret_id IS NOT NULL THEN
    PERFORM vault.update_secret(v_secret_id, p_value);
  ELSE
    PERFORM vault.create_secret(p_value, secret_name, 'AlNujom agency PII per-agency-per-field');
  END IF;
END;
$$;

-- Admin-only decrypt (R-141 / FR-005). Returns NULL for non-admins (never raises a leak).
CREATE OR REPLACE FUNCTION public.app_vault_secret_for_agency(
  p_agency_id UUID, field_name TEXT
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('agencies.view') THEN RETURN NULL; END IF;
  IF field_name NOT IN ('id_document_number','commercial_registration_number') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN public.app_vault_secret(format('pii.agency.%s.%s', p_agency_id, field_name));  -- Phase 4 read helper
END;
$$;

REVOKE ALL ON FUNCTION public.app_vault_set_agency_secret(UUID,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_vault_set_agency_secret(UUID,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.app_vault_secret_for_agency(UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_vault_secret_for_agency(UUID,TEXT) TO authenticated;  -- self-gates on agencies.view
