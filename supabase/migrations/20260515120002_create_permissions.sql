-- Phase 6: Create the `permissions` table with the seeded 24-key catalog.
-- Contract: contracts/permissions-table.md
-- FR-003, FR-004

CREATE TABLE IF NOT EXISTS public.permissions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT        NOT NULL UNIQUE,
  category    TEXT        NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- generated from supabase/policies/permissions_policies.sql
DROP POLICY IF EXISTS permissions_read_all_authenticated ON public.permissions;
CREATE POLICY permissions_read_all_authenticated
  ON public.permissions
  FOR SELECT
  TO authenticated
  USING (TRUE);

-- Seed: 24 permission keys from §9.1 (idempotent)
INSERT INTO public.permissions (key, category, description) VALUES
  ('users.view',          'users',      'Read other users'' profiles (cross-user).'),
  ('users.approve',       'users',      'Approve a pending account-approval request.'),
  ('users.reject',        'users',      'Reject a pending account-approval request.'),
  ('users.suspend',       'users',      'Suspend an approved user.'),
  ('listings.view_all',   'listings',   'Read all listings across publishers.'),
  ('listings.approve',    'listings',   'Approve a submitted listing.'),
  ('listings.reject',     'listings',   'Reject a submitted listing.'),
  ('listings.edit_any',   'listings',   'Edit any listing regardless of publisher.'),
  ('listings.delete_any', 'listings',   'Delete any listing regardless of publisher.'),
  ('roles.view',          'roles',      'Read the role catalog.'),
  ('roles.create',        'roles',      'Create custom roles.'),
  ('roles.update',        'roles',      'Edit roles and their permissions / assignments.'),
  ('roles.delete',        'roles',      'Delete non-system roles.'),
  ('permissions.manage',  'roles',      'Mutate the permissions table (post-v1 if ever).'),
  ('locations.manage',    'locations',  'Admin Syrian governorates, cities, areas.'),
  ('currencies.manage',   'currencies', 'Admin exchange rates and supported currencies.'),
  ('ads.manage',          'ads',        'Admin ads and banners.'),
  ('reports.manage',      'reports',    'Moderate reports.'),
  ('agencies.view',       'agencies',   'View agency directory.'),
  ('agencies.approve',    'agencies',   'Approve agency applications.'),
  ('agencies.suspend',    'agencies',   'Suspend an approved agency.'),
  ('settings.manage',     'settings',   'Mutate app-wide settings.'),
  ('audit_logs.view',     'audit',      'Read the audit_logs table.'),
  ('inquiries.view_all',  'inquiries',  'Cross-publisher inquiry read.')
ON CONFLICT (key) DO NOTHING;
