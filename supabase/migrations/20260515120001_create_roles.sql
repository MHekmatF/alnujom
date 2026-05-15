-- Phase 6: Create the `roles` table with system-role immutability trigger and seeded catalog.
-- Contracts: contracts/roles-table.md, contracts/system-role-immutability-trigger.md
-- FR-001, FR-002, FR-020

CREATE TABLE IF NOT EXISTS public.roles (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  key          TEXT        NOT NULL UNIQUE,
  display_name JSONB       NOT NULL,
  description  TEXT,
  is_system    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- generated from supabase/policies/roles_policies.sql
DROP POLICY IF EXISTS roles_read_all_authenticated ON public.roles;
CREATE POLICY roles_read_all_authenticated
  ON public.roles
  FOR SELECT
  TO authenticated
  USING (TRUE);

-- set_updated_at trigger (reuses Phase 4 helper)
DROP TRIGGER IF EXISTS trg_roles_set_updated_at ON public.roles;
CREATE TRIGGER trg_roles_set_updated_at
  BEFORE UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- System-role immutability: blocks DELETE and key rename on is_system=TRUE rows.
-- display_name / description updates are still permitted.
CREATE OR REPLACE FUNCTION public.enforce_role_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF (TG_OP = 'DELETE' AND OLD.is_system) THEN
    RAISE EXCEPTION 'cannot delete system role: %', OLD.key
      USING ERRCODE = '42501';
  END IF;

  IF (TG_OP = 'UPDATE' AND OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key) THEN
    RAISE EXCEPTION 'cannot rename system role: % (attempted new key: %)', OLD.key, NEW.key
      USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_roles_enforce_system_immutability ON public.roles;
CREATE TRIGGER trg_roles_enforce_system_immutability
  BEFORE UPDATE OR DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_role_system_immutability();

-- Seed: 7 system roles with bilingual display_name (idempotent)
INSERT INTO public.roles (key, display_name, is_system) VALUES
  ('user',         '{"ar": "مستخدم", "en": "User"}'::jsonb,              TRUE),
  ('owner',        '{"ar": "مالك", "en": "Owner"}'::jsonb,               TRUE),
  ('agent',        '{"ar": "وكيل", "en": "Agent"}'::jsonb,               TRUE),
  ('agency_admin', '{"ar": "مدير وكالة", "en": "Agency Admin"}'::jsonb,  TRUE),
  ('moderator',    '{"ar": "مشرف", "en": "Moderator"}'::jsonb,           TRUE),
  ('admin',        '{"ar": "مدير", "en": "Admin"}'::jsonb,               TRUE),
  ('super_admin',  '{"ar": "مدير عام", "en": "Super Admin"}'::jsonb,     TRUE)
ON CONFLICT (key) DO NOTHING;
