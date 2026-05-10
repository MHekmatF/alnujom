-- Phase 5 (spec/005-auth-profile) — Migration 2/5
-- Adds: profiles.is_admin BOOLEAN NOT NULL DEFAULT FALSE,
--       extends enforce_profile_status_admin_only() to also reject is_admin mutations
--       from non-privileged sessions (FR-009, R-12 privileged-role bypass preserved).
-- Idempotent: ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE FUNCTION.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN profiles.is_admin IS
  'Phase 5 interim admin flag. Replaced by Phase 6 role/permission system; column dropped in 006-roles-permissions.';

-- Extend Phase 4's enforce_profile_status_admin_only() to also block is_admin mutations
-- from non-privileged callers. Privileged-role list per Phase 4 R-12 unchanged.
CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = public
AS $$
DECLARE
  caller_role TEXT := current_setting('role', true);
  is_privileged BOOLEAN := caller_role IN ('postgres', 'supabase_admin', 'service_role');
BEGIN
  IF is_privileged THEN
    RETURN NEW;
  END IF;

  -- Phase 4: block account_status / publisher_status mutation from non-privileged callers.
  IF NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status THEN
    RAISE EXCEPTION 'cannot mutate account_status / publisher_status from a non-privileged session'
      USING ERRCODE = '42501';
  END IF;

  -- Phase 5 addition (FR-009): block is_admin mutation from non-privileged callers.
  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'cannot mutate is_admin from a non-privileged session'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;
