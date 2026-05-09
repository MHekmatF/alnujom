-- Migration 2: Create Profiles + admin helper + status-enforcement trigger
-- Phase 4 — Supabase Foundation (FR-001, FR-006, FR-020, Q2, Q4)
-- See: research.md R-05 (admin predicate moved here from 0005), R-12 (enforce_status trigger).
-- Apply via: Supabase MCP apply_migration(name='20260506120002_create_profiles', query='<file body>')

-- (a) profiles table
CREATE TABLE IF NOT EXISTS profiles (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name        TEXT,
  username         TEXT UNIQUE,
  phone            TEXT UNIQUE,
  email            TEXT,
  avatar_url       TEXT,
  account_status   account_status_enum   NOT NULL DEFAULT 'pending',
  publisher_status publisher_status_enum NOT NULL DEFAULT 'pending',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- (b) set_updated_at() helper — reused by user_preferences in 0003
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- (c) updated_at trigger on profiles
DROP TRIGGER IF EXISTS trg_profiles_set_updated_at ON profiles;
CREATE TRIGGER trg_profiles_set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- (d) current_user_is_admin() placeholder helper (R-05)
-- Phase 4 body returns FALSE; Phase 5 swaps to `is_admin` lookup; Phase 6 swaps to permission check.
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT FALSE;
$$;

-- (e) enforce_profile_status_admin_only() function (R-12)
-- Privileged-session bypass list per R-12 rationale.
CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF current_user IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin') THEN
    RETURN NEW;
  END IF;
  IF (OLD.account_status IS DISTINCT FROM NEW.account_status
      OR OLD.publisher_status IS DISTINCT FROM NEW.publisher_status)
     AND NOT current_user_is_admin() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Only admins can change account_status or publisher_status',
      HINT    = 'Status fields are admin-only per FR-006; current_user_is_admin() returned FALSE.';
  END IF;
  RETURN NEW;
END;
$$;

-- (f) enforce_status trigger
DROP TRIGGER IF EXISTS trg_profiles_enforce_status_admin_only ON profiles;
CREATE TRIGGER trg_profiles_enforce_status_admin_only
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION enforce_profile_status_admin_only();

-- (g) header comment is at the top; nothing else here.
