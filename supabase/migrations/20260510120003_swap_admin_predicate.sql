-- Phase 5 (spec/005-auth-profile) — Migration 3/5
-- Swaps current_user_is_admin() body from the Phase 4 placeholder (SELECT FALSE)
-- to read profiles.is_admin for the calling auth.uid().
-- Per contracts/admin-predicate-v5.md and research R-12.
--
-- INVARIANT (FR-007 / SC-015): NO Phase 4 policy file is edited in this migration.
-- Every Phase 4 admin-gated policy that calls current_user_is_admin() picks up the
-- new behavior automatically. This is the central-helper invariant Phase 5 preserves.

CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
$$;
