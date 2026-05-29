-- Phase 18 (spec/018-reports-moderation) — Migration 3/8
-- RLS policies for public.reports + public.moderation_actions (data-model §1.3).
--
-- Reader/writer matrix (load-bearing — Principle III, data-model §1.9):
--
--   | Actor                         | reports read | reports write | mod_actions read | mod_actions write |
--   |-------------------------------|--------------|---------------|------------------|-------------------|
--   | Anonymous                     | ❌ (no policy)| ❌            | ❌ (no policy)   | ❌                |
--   | Authenticated reporter        | own rows only| ❌ (RPC only) | ❌               | ❌                |
--   | Authenticated non-reporter    | own rows only| ❌            | ❌               | ❌                |
--   | reports.manage holder         | ALL rows     | ❌ (RPC/Edge) | ALL rows         | ❌ (RPC only)     |
--   | service_role (Edge Fn)        | bypasses RLS | via RPC       | bypasses RLS     | via RPC           |
--
-- No publisher path. No aggregate count. No admin client UPDATE.
-- Creation via submit_report (SECURITY DEFINER, Migration 6); resolution/claim
-- via resolve_report_internal / start_report_review (Migration 7).

-- ─── public.reports ───
-- SELECT: reporter reads their own rows; reports.manage holder reads all rows.
CREATE POLICY reports_select_self_or_admin
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (
    reporter_user_id = auth.uid()
    OR public.current_user_has_permission('reports.manage')
  );

-- No INSERT/UPDATE/DELETE policy and no grant: row creation is exclusively via
-- the submit_report SECURITY DEFINER RPC (Migration 6); resolution/claim flow
-- through resolve_report_internal / start_report_review (Migration 7). This makes
-- it impossible for any client to forge reporter_user_id or bypass the auth +
-- approved-listing + dedup gates (FR-010, FR-025).
REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated, anon;
-- (No anon SELECT policy ⇒ anonymous reads denied entirely — FR-027.)

-- ─── public.moderation_actions ───
-- SELECT: reports.manage holder only. No reporter, publisher, or anon reader.
CREATE POLICY moderation_actions_select_admin
  ON public.moderation_actions
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('reports.manage'));

-- No INSERT/UPDATE/DELETE policy and no grant: the append-only audit trail is
-- written only by the service-role resolve_report_internal RPC (Migration 7).
REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM authenticated, anon;
-- (No anon SELECT policy ⇒ anonymous reads denied entirely — FR-027.)
