-- Source-of-truth policies for profiles
-- Phase 4 — Supabase Foundation (FR-006)
-- Inlined into 20260506120005_enable_rls_default.sql per R-02.
-- Column-level enforcement of "self can't change status" lives in the R-12
-- BEFORE UPDATE trigger enforce_profile_status_admin_only() (in 0002), NOT here.

CREATE POLICY profiles_select_self ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY profiles_select_admin ON profiles
  FOR SELECT TO authenticated
  USING (current_user_is_admin());

CREATE POLICY profiles_update_self ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY profiles_update_admin ON profiles
  FOR UPDATE TO authenticated
  USING (current_user_is_admin())
  WITH CHECK (current_user_is_admin());
