-- Phase 21 — audit ad creation + soft-delete (FR-007 / §9.4). Reuses Phase 4 log_audit().
-- Actor = auth.uid() (admin RPCs run under the admin's JWT; SECURITY DEFINER changes role, not uid).
DROP TRIGGER IF EXISTS trg_ads_audit_created ON public.ads;
CREATE TRIGGER trg_ads_audit_created
  AFTER INSERT ON public.ads
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('ad.created', 'title,link_kind,is_active', 'id');

DROP TRIGGER IF EXISTS trg_ads_audit_deleted ON public.ads;
CREATE TRIGGER trg_ads_audit_deleted
  AFTER UPDATE OF archived_at ON public.ads
  FOR EACH ROW
  WHEN (OLD.archived_at IS NULL AND NEW.archived_at IS NOT NULL)
  EXECUTE FUNCTION log_audit('ad.deleted', 'archived_at', 'id');

-- Additive (per Assumptions): activation/deactivation audit.
DROP TRIGGER IF EXISTS trg_ads_audit_activation ON public.ads;
CREATE TRIGGER trg_ads_audit_activation
  AFTER UPDATE OF is_active ON public.ads
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION log_audit('ad.activation_changed', 'is_active', 'id');
