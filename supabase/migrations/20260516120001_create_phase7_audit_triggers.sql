-- Phase 7: Audit triggers for roles, role_permissions, and permissions.
-- Source: specs/007-super-admin-roles/contracts/phase7-audit-triggers.md
-- FR-001, FR-002, FR-003. Reuses Phase 4 public.log_audit() unchanged.

-- roles
DROP TRIGGER IF EXISTS trg_roles_audit_created ON public.roles;
CREATE TRIGGER trg_roles_audit_created
  AFTER INSERT ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_updated ON public.roles;
CREATE TRIGGER trg_roles_audit_updated
  AFTER UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_deleted ON public.roles;
CREATE TRIGGER trg_roles_audit_deleted
  AFTER DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.deleted', '*', 'id');

-- role_permissions
DROP TRIGGER IF EXISTS trg_role_permissions_audit_granted ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_granted
  AFTER INSERT ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.granted', '*', 'role_id');

DROP TRIGGER IF EXISTS trg_role_permissions_audit_revoked ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_revoked
  AFTER DELETE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.revoked', '*', 'role_id');

-- permissions (defensive coverage; v1 catalog is closed)
DROP TRIGGER IF EXISTS trg_permissions_audit_created ON public.permissions;
CREATE TRIGGER trg_permissions_audit_created
  AFTER INSERT ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_updated ON public.permissions;
CREATE TRIGGER trg_permissions_audit_updated
  AFTER UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_deleted ON public.permissions;
CREATE TRIGGER trg_permissions_audit_deleted
  AFTER DELETE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.deleted', '*', 'id');
