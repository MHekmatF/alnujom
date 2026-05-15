-- Source-of-truth policies for audit_logs
-- Phase 4 — Supabase Foundation (FR-008)
-- Admin-read only; client INSERT/UPDATE/DELETE forbidden by absence of policies
-- (writes happen ONLY via the SECURITY DEFINER log_audit() trigger).
-- Inlined into 20260506120005_enable_rls_default.sql per R-02.

CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT TO authenticated
  USING (current_user_is_admin());
