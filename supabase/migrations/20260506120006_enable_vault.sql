-- Migration 6: Enable Vault scaffolding (forward-prep, no secrets stored)
-- Phase 4 — Supabase Foundation (FR-012, FR-013)
-- See: research.md R-06 (app_vault_secret signature), R-08 (pgsodium baseline).
-- ADR-0001: Vault is the canonical store for backend secrets and admin-only PII.
-- Phase 4 ships ONLY the scaffolding — zero secrets are stored here.
-- Phases 5/16/19/21/22 add their first real Vault entries on top.

CREATE EXTENSION IF NOT EXISTS pgsodium;

CREATE OR REPLACE FUNCTION app_vault_secret(p_name TEXT) RETURNS TEXT
LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name LIMIT 1;
$$;

-- Revoke EXECUTE from REST-exposed roles — app_vault_secret returns decrypted
-- secrets and must NEVER be reachable via /rest/v1/rpc/app_vault_secret.
-- Only privileged sessions (postgres, service_role) may invoke it directly,
-- and Phase 5+ SECURITY DEFINER helpers may invoke it from inside their own bodies.
REVOKE EXECUTE ON FUNCTION app_vault_secret(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_vault_secret(TEXT) FROM anon, authenticated;
