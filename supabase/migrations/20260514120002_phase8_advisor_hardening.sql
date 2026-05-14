-- Phase 8 (spec/005-auth-profile) — Advisor hardening (T091)
-- Resolves two actionable advisor warnings first surfaced after Phase 5 landed:
--   1. account_approval_requests_reviewed_by_fkey unindexed → add covering index
--   2. account_approval_requests_self_read auth_rls_initplan → use (SELECT auth.uid()) pattern
-- Other new Phase 5 advisor warnings are by-design (documented in 20260510120006_phase5_advisor_hardening):
--   - authenticated_security_definer for Vault PII helpers (users call these directly by design)
--   - authenticated_security_definer for approve/reject RPCs (admin-guarded internally via current_user_is_admin())
--   - current_user_is_admin() anon-callable (always returns FALSE for anon; required for RLS recursion safety)
--   - multiple_permissive_policies on account_approval_requests (separate self+admin SELECT policies needed)

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Index for reviewed_by FK
--    Performance advisor: unindexed_foreign_keys on account_approval_requests_reviewed_by_fkey.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_account_approval_requests_reviewed_by
  ON account_approval_requests(reviewed_by);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fix RLS initplan on account_approval_requests_self_read
--    Performance advisor: auth_rls_initplan — auth.uid() re-evaluated per row.
--    Fix: wrap in (SELECT ...) so the planner evaluates it once per query.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS account_approval_requests_self_read ON account_approval_requests;
CREATE POLICY account_approval_requests_self_read
  ON account_approval_requests
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
