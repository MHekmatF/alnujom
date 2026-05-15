-- Migration 5: Enable RLS by Default + apply policies
-- Phase 4 — Supabase Foundation (specs/004-supabase-foundation)
-- See: spec.md, plan.md, research.md
-- Apply via: Supabase MCP apply_migration(name='20260506120005_enable_rls_default', query='<file body>')
-- Note: current_user_is_admin() ships in 0002, NOT here, because R-12's
-- enforce_status trigger in 0002 calls it.

-- (1) Enable RLS on every Phase 4 table
ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs        ENABLE ROW LEVEL SECURITY;

-- (2a) -- generated from supabase/policies/profiles_policies.sql
DROP POLICY IF EXISTS profiles_select_self ON profiles;
CREATE POLICY profiles_select_self ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS profiles_select_admin ON profiles;
CREATE POLICY profiles_select_admin ON profiles
  FOR SELECT TO authenticated
  USING (current_user_is_admin());

DROP POLICY IF EXISTS profiles_update_self ON profiles;
CREATE POLICY profiles_update_self ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS profiles_update_admin ON profiles;
CREATE POLICY profiles_update_admin ON profiles
  FOR UPDATE TO authenticated
  USING (current_user_is_admin())
  WITH CHECK (current_user_is_admin());

-- (2b) -- generated from supabase/policies/user_preferences_policies.sql
DROP POLICY IF EXISTS user_preferences_select_self ON user_preferences;
CREATE POLICY user_preferences_select_self ON user_preferences
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_insert_self ON user_preferences;
CREATE POLICY user_preferences_insert_self ON user_preferences
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_update_self ON user_preferences;
CREATE POLICY user_preferences_update_self ON user_preferences
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_delete_self ON user_preferences;
CREATE POLICY user_preferences_delete_self ON user_preferences
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- (2c) -- generated from supabase/policies/audit_logs_policies.sql
DROP POLICY IF EXISTS audit_logs_select_admin ON audit_logs;
CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT TO authenticated
  USING (current_user_is_admin());
