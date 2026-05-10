-- Phase 5 (spec/005-auth-profile FR-008) — RLS policies for account_approval_requests.
-- Authoring file: this is the human-reviewable, per-table policy SQL.
-- The bodies below are inlined into 20260510120001_create_account_approval_requests.sql
-- (with a `# generated from …` header comment) so the apply step is atomic per Phase 4 R-02.
-- Idempotent via DROP POLICY IF EXISTS … CREATE POLICY ….
--
-- Posture summary:
--   SELECT (self):       authenticated; user_id = auth.uid()
--   SELECT (admin all):  authenticated; current_user_is_admin()
--   UPDATE (admin):      authenticated; current_user_is_admin()  (USING + WITH CHECK)
--   INSERT:              none — the auto_create_account_approval_request trigger is the only writer
--   DELETE:              none — rows kept for audit; cascade-only via auth.users(id) ON DELETE CASCADE

ALTER TABLE account_approval_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS account_approval_requests_self_read ON account_approval_requests;
CREATE POLICY account_approval_requests_self_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS account_approval_requests_admin_read ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_read
  ON account_approval_requests
  FOR SELECT
  TO authenticated
  USING (current_user_is_admin());

DROP POLICY IF EXISTS account_approval_requests_admin_update ON account_approval_requests;
CREATE POLICY account_approval_requests_admin_update
  ON account_approval_requests
  FOR UPDATE
  TO authenticated
  USING (current_user_is_admin())
  WITH CHECK (current_user_is_admin());

-- No INSERT policy: the auto_create_account_approval_request trigger is the only writer.
-- No DELETE policy: rows are kept for audit; cascade from auth.users(id) ON DELETE CASCADE.
