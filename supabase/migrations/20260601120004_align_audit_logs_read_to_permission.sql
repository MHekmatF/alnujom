-- Phase 20: align the audit_logs read gate with the data-driven audit_logs.view permission.
-- File: supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql
-- Spec: specs/020-admin-dashboard/spec.md (FR-021, FR-003); Principle VII (no role-based gates).
-- Was: USING (current_user_is_admin())  [role-based, Phase 4 + Phase 6 swap]
-- Now: USING (current_user_has_permission('audit_logs.view'))  [data-driven]
-- Read-only: NO insert/update/delete policy — log_audit() (SECURITY DEFINER) remains the only writer.

DROP POLICY IF EXISTS audit_logs_select_admin ON public.audit_logs;
CREATE POLICY audit_logs_select_admin
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (current_user_has_permission('audit_logs.view'));

-- Reuses existing idx_audit_logs_created_at (created_at DESC) for newest-first pagination.
