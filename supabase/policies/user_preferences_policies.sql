-- Source-of-truth policies for user_preferences
-- Phase 4 — Supabase Foundation (FR-007)
-- Self-only — no admin policy in Phase 4.
-- Inlined into 20260506120005_enable_rls_default.sql per R-02.

CREATE POLICY user_preferences_select_self ON user_preferences
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY user_preferences_insert_self ON user_preferences
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_preferences_update_self ON user_preferences
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_preferences_delete_self ON user_preferences
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
