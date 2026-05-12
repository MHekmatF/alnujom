-- Phase 5 (spec/005-auth-profile) — Migration 6/5 (advisor hardening)
-- Address security advisor warnings surfaced by mcp__supabase__get_advisors after applying
-- migrations 1-5. Two categories:
--   1. Add SET search_path = public to current_user_is_admin (the body swap in
--      20260510120003 used LANGUAGE SQL without an explicit search_path → mutable).
--   2. REVOKE EXECUTE on Phase 5 SECURITY DEFINER functions:
--        - Trigger-only: revoke from anon AND authenticated (auto_create_account_approval_request).
--        - User-callable: revoke from anon (defense-in-depth; body already rejects anon).
--          Keep granted to authenticated since these helpers need to be callable from the app.
-- Pre-existing Phase 4 advisor warnings (set_updated_at, handle_new_auth_user) are baseline
-- per Phase 4 R-01 and NOT touched here (FR-007 / R-05 central-helper invariant).

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Re-create current_user_is_admin with explicit search_path AND SECURITY DEFINER.
--    SECURITY DEFINER is required: when this function is called inside admin-gated
--    RLS policies on profiles, it must bypass RLS itself to query is_admin —
--    otherwise the profiles_select_admin policy recurses into this function
--    and triggers PostgreSQL's stack depth limit.
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Trigger-only function: revoke from anon + authenticated
-- ───────────────────────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION auto_create_account_approval_request() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION auto_create_account_approval_request() FROM anon;
REVOKE EXECUTE ON FUNCTION auto_create_account_approval_request() FROM authenticated;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. User-callable SECURITY DEFINER functions: revoke from anon (keep authenticated)
-- ───────────────────────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION app_vault_secret_for_self(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION app_vault_secret_for_user(UUID, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION app_vault_set_secret_for_self(TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION app_vault_set_secret_for_user(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION app_vault_set_private_contact_methods_for_self(JSONB) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION approve_account_approval_request(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION reject_account_approval_request(UUID, TEXT) FROM PUBLIC, anon;

-- Explicit GRANT to authenticated (PUBLIC was the prior default; restoring it explicitly).
GRANT EXECUTE ON FUNCTION app_vault_secret_for_self(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_vault_secret_for_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_vault_set_secret_for_self(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_vault_set_secret_for_user(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION app_vault_set_private_contact_methods_for_self(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_account_approval_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_account_approval_request(UUID, TEXT) TO authenticated;
