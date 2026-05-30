-- Phase 19 (spec/019-agencies) — Sub-Phase C, Migration 11
-- Agency audit triggers (data-model §1.11). Reuse the Phase 4 log_audit() trigger
-- function (20260506120004) unchanged — no parallel audit mechanism (FR-012/FR-041).
--
-- log_audit() TG_ARGV (Phase 4 R-04):
--   [0] = action key   [1] = audited column list   [2] = PK column for target_id.
-- Actor resolves from app.current_user_id (set by moderate_agency_internal, the
-- service-role path) or auth.uid() (the member-change RPC path).
-- WHEN clauses suppress no-op UPDATEs (e.g. set_updated_at-only) so no spurious rows.

-- ─── agencies: status transitions ───
DROP TRIGGER IF EXISTS trg_agencies_audit_status ON public.agencies;
CREATE TRIGGER trg_agencies_audit_status
  AFTER UPDATE OF status ON public.agencies
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('agency.status_changed', 'status', 'id');

-- ─── agency_members: membership changes ───
-- Split INSERT/DELETE from UPDATE OF (combining an `OF column-list` with INSERT/DELETE
-- in one CREATE TRIGGER is ambiguous — two triggers is unambiguous). pk_col = 'user_id'
-- (the affected member); the column list includes agency_id + user_id so the composite
-- identity survives in before/after (a bare 'agency_id' pk_col would lose which member changed).
DROP TRIGGER IF EXISTS trg_agency_members_audit_ins_del ON public.agency_members;
CREATE TRIGGER trg_agency_members_audit_ins_del
  AFTER INSERT OR DELETE ON public.agency_members
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('agency_member.changed', 'agency_id,user_id,member_role,status', 'user_id');

DROP TRIGGER IF EXISTS trg_agency_members_audit_upd ON public.agency_members;
CREATE TRIGGER trg_agency_members_audit_upd
  AFTER UPDATE OF member_role, status ON public.agency_members
  FOR EACH ROW
  WHEN (OLD.member_role IS DISTINCT FROM NEW.member_role OR OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION log_audit('agency_member.changed', 'agency_id,user_id,member_role,status', 'user_id');

-- ─── agency_verification_requests: decisions ───
DROP TRIGGER IF EXISTS trg_agency_verification_audit ON public.agency_verification_requests;
CREATE TRIGGER trg_agency_verification_audit
  AFTER UPDATE OF decision ON public.agency_verification_requests
  FOR EACH ROW WHEN (OLD.decision IS DISTINCT FROM NEW.decision)
  EXECUTE FUNCTION log_audit('agency_verification.decided', 'decision,decision_reason,reviewed_by', 'id');
