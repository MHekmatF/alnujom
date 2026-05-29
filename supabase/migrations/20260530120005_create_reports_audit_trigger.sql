-- Phase 18 (spec/018-reports-moderation) — Migration 5/8
-- Reports resolution-audit trigger (data-model §1.5, FR-035).
--
-- Reuses the Phase 4 log_audit() trigger function (20260506120004): TG_ARGV[0]
-- is the action label, [1] the comma-separated column list captured into
-- before/after_state, [2] the PK column resolving target_id. Fires only on a
-- real status transition INTO a terminal state ('resolved' / 'dismissed'); the
-- WHEN guard plus log_audit's own changed-column filter keep audit noise out.
--
-- Actor attribution: log_audit writes auth.uid() into audit_logs.actor_user_id.
-- The terminal transition is performed by resolve_report_internal (service-role
-- RPC, Migration 7), which sets app.current_user_id for the listing triggers;
-- the moderator's identity is also captured in the row's resolved_by column
-- (included in the audited column list below) and in moderation_actions.

DROP TRIGGER IF EXISTS trg_reports_audit_resolution ON public.reports;
CREATE TRIGGER trg_reports_audit_resolution
  AFTER UPDATE OF status ON public.reports
  FOR EACH ROW
  WHEN (NEW.status IN ('resolved','dismissed')
        AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('report.resolved', 'status,resolution,resolved_by', 'id');
