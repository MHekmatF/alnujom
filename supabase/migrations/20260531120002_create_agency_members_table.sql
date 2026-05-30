-- Phase 19 (spec/019-agencies) — Migration 2/13
-- Creates: public.agency_members roster table, idx_agency_members_user,
--          the SECURITY DEFINER is_agency_member/is_agency_admin predicates,
--          set_updated_at trigger (Phase 4 helper), RLS enable (policies in …005).
-- PK (agency_id,user_id) ⇒ one row per (agency,user). member_role admin|agent;
-- status pending(invited)→active→removed. The owner is seeded admin/active by
-- create_agency and is protected from role-change/removal.
-- Idempotent: re-applying this migration leaves the schema unchanged.
-- References: data-model.md §1.2; research.md R-140 (per-agency authorization
--             gate is membership, not a global role); contracts/phase19-agency-members-table.md.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Table: public.agency_members
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.agency_members (
  agency_id    UUID        NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  user_id      UUID        NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  member_role  TEXT        NOT NULL CHECK (member_role IN ('admin','agent')),
  status       TEXT        NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','active','removed')),
  invited_by   UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  joined_at    TIMESTAMPTZ,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  PRIMARY KEY (agency_id, user_id)
);

-- "My agencies" + "my pending invitations" lookup.
CREATE INDEX IF NOT EXISTS idx_agency_members_user
  ON public.agency_members (user_id, status);

-- ───────────────────────────────────────────────────────────────────────────
-- 2. set_updated_at trigger (reuses Phase 4 helper)
-- ───────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_agency_members_set_updated_at ON public.agency_members;
CREATE TRIGGER trg_agency_members_set_updated_at
  BEFORE UPDATE ON public.agency_members
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────────────────
-- 3. RLS enable (policies attach in 20260531120005_create_agency_policies.sql)
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE public.agency_members ENABLE ROW LEVEL SECURITY;

-- ───────────────────────────────────────────────────────────────────────────
-- 4. SECURITY DEFINER membership predicates — used by the RLS policies (avoids
--    the self-referential-RLS recursion an inline EXISTS on agency_members would
--    hit) and by the write RPCs. They bypass RLS (definer) and resolve auth.uid()
--    to the caller.
-- ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_agency_member(p_agency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id AND m.user_id = auth.uid() AND m.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_agency_admin(p_agency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id AND m.user_id = auth.uid()
      AND m.status = 'active' AND m.member_role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_agency_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_agency_admin(UUID)  TO authenticated;
