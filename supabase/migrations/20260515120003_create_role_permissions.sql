-- Phase 6: Create the `role_permissions` junction table with seeded default mappings.
-- Contract: contracts/role-permissions-table.md
-- FR-005, FR-006, R-04

CREATE TABLE IF NOT EXISTS public.role_permissions (
  role_id       UUID        NOT NULL REFERENCES public.roles(id)       ON DELETE CASCADE,
  permission_id UUID        NOT NULL REFERENCES public.permissions(id)  ON DELETE RESTRICT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- generated from supabase/policies/role_permissions_policies.sql
DROP POLICY IF EXISTS role_permissions_read_all_authenticated ON public.role_permissions;
CREATE POLICY role_permissions_read_all_authenticated
  ON public.role_permissions
  FOR SELECT
  TO authenticated
  USING (TRUE);

-- Seed: moderator — 5 rows
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'moderator'),
  p.id
FROM public.permissions p
WHERE p.key IN (
  'users.view',
  'listings.view_all',
  'listings.approve',
  'listings.reject',
  'reports.manage'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Seed: admin — 17 rows (moderator's 5 + admin-only writes + agencies.view + inquiries.view_all per R-04)
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'admin'),
  p.id
FROM public.permissions p
WHERE p.key IN (
  'users.view',
  'listings.view_all',
  'listings.approve',
  'listings.reject',
  'reports.manage',
  'users.approve',
  'users.reject',
  'users.suspend',
  'listings.edit_any',
  'locations.manage',
  'currencies.manage',
  'ads.manage',
  'agencies.approve',
  'agencies.suspend',
  'audit_logs.view',
  'agencies.view',
  'inquiries.view_all'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Seed: super_admin — all 24 rows
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'super_admin'),
  p.id
FROM public.permissions p
ON CONFLICT (role_id, permission_id) DO NOTHING;
