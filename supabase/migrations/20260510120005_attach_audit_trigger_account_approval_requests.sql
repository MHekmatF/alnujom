-- Phase 5 (spec/005-auth-profile) — Migration 5/5
-- Attaches a concrete audit trigger to account_approval_requests, reusing Phase 4's
-- log_audit() trigger function unchanged. This is the first reuse of the reusable
-- audit emitter and validates the Phase 4 reusability invariant (FR-010).
--
-- TG_ARGV per Phase 4 R-04:
--   [0] = action key:        'account_approval.status_changed'
--   [1] = column list:       'status,rejection_reason,reviewed_by,reviewed_at'
--   [2] = PK column for target_id: 'user_id'
--
-- WHEN clause prevents no-op UPDATEs (e.g., set_updated_at-only) from emitting spurious audit rows.

DROP TRIGGER IF EXISTS trg_account_approval_requests_audit_status ON account_approval_requests;
CREATE TRIGGER trg_account_approval_requests_audit_status
  AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at
  ON account_approval_requests
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    OR OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason
    OR OLD.reviewed_by IS DISTINCT FROM NEW.reviewed_by
    OR OLD.reviewed_at IS DISTINCT FROM NEW.reviewed_at
  )
  EXECUTE FUNCTION log_audit(
    'account_approval.status_changed',
    'status,rejection_reason,reviewed_by,reviewed_at',
    'user_id'
  );
