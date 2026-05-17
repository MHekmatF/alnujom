-- Phase 8 — Locations Catalog: governorates table
-- FRs: FR-001 (governorates entity), FR-003 (bilingual display_name), FR-004 (is_active soft-deactivation),
--       FR-007 (audit trail), FR-007a (trigger-before-seed ordering per Clarifications Q5),
--       FR-008 (seeded-row protection via is_system + immutability trigger per Clarifications Q3),
--       FR-009 (RLS — read public, write gated by locations.manage per Phase 6 §9.1).
-- Anonymous SELECT carve-out — see research.md R-04 and R-16.
-- Codified GRANT in 20260517120005_phase8_advisor_hardening.sql.

-- ============================================================
-- 1. TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.governorates (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key          TEXT NOT NULL UNIQUE,
  display_name JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description  JSONB,
  position     INTEGER,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  is_system    BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT governorates_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$')
);

COMMENT ON TABLE public.governorates IS
  'Phase 8 — Syrian first-level administrative divisions (14 seeded with is_system=true). RLS: public SELECT (anon + authenticated); write gated by locations.manage per the Phase 6 permission catalog.';
COMMENT ON COLUMN public.governorates.key IS
  'Stable lowercase slug (e.g., damascus, aleppo, rif-dimashq). Unique. Cannot be UPDATEd on is_system=true rows (enforced by enforce_governorate_system_immutability).';
COMMENT ON COLUMN public.governorates.display_name IS
  'Bilingual JSONB {"ar": "...", "en": "..."} — Arabic value required; English value optional. Phase 6 roles.display_name pattern.';
COMMENT ON COLUMN public.governorates.position IS
  'Editorial ordering hint. ORDER BY position NULLS LAST, key ASC for display.';
COMMENT ON COLUMN public.governorates.is_active IS
  'Soft-deactivation flag. Admin pages show inactive rows with a Hidden badge; LocationPicker filters them out.';
COMMENT ON COLUMN public.governorates.is_system IS
  'TRUE for the 14 seeded governorates. Refuses DELETE and key UPDATE via enforce_governorate_system_immutability.';

-- ============================================================
-- 2. RLS
-- ============================================================

ALTER TABLE public.governorates ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. TRIGGERS (attached BEFORE seed per R-08 / Clarifications Q5)
-- ============================================================

-- 3.1 set_updated_at (Phase 4 helper, reused)
DROP TRIGGER IF EXISTS trg_governorates_set_updated_at ON public.governorates;
CREATE TRIGGER trg_governorates_set_updated_at
  BEFORE UPDATE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3.2 Immutability trigger (Phase 8 — seeded-row protection, Clarifications Q3)
CREATE OR REPLACE FUNCTION public.enforce_governorate_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot delete a system governorate (key=%)', OLD.key
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key THEN
      RAISE EXCEPTION 'governorate_system_immutable: cannot rename a system governorate''s key (was %, attempted %)', OLD.key, NEW.key
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_governorates_enforce_immutability ON public.governorates;
CREATE TRIGGER trg_governorates_enforce_immutability
  BEFORE UPDATE OR DELETE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.enforce_governorate_system_immutability();

-- 3.3 Audit triggers (Phase 4 log_audit(), 5th reuse — R-13)
DROP TRIGGER IF EXISTS trg_governorates_audit_created ON public.governorates;
CREATE TRIGGER trg_governorates_audit_created
  AFTER INSERT ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_governorates_audit_updated ON public.governorates;
CREATE TRIGGER trg_governorates_audit_updated
  AFTER UPDATE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_governorates_audit_deleted ON public.governorates;
CREATE TRIGGER trg_governorates_audit_deleted
  AFTER DELETE ON public.governorates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('governorate.deleted', '*', 'id');

-- ============================================================
-- 4. RLS POLICIES
-- ============================================================

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS governorates_select_public ON public.governorates;
CREATE POLICY governorates_select_public
  ON public.governorates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS governorates_insert_locations_manage ON public.governorates;
CREATE POLICY governorates_insert_locations_manage
  ON public.governorates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS governorates_update_locations_manage ON public.governorates;
CREATE POLICY governorates_update_locations_manage
  ON public.governorates
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS governorates_delete_locations_manage ON public.governorates;
CREATE POLICY governorates_delete_locations_manage
  ON public.governorates
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));

-- ============================================================
-- 5. SEED (14 governorates, all is_system=true — Clarifications Q3/Q5)
-- Triggers fire BEFORE this block (R-08) → each row produces one governorate.created audit row.
-- ============================================================

INSERT INTO public.governorates (key, display_name, position, is_system)
VALUES
  ('damascus',    '{"ar":"دمشق","en":"Damascus"}',       10,  true),
  ('aleppo',      '{"ar":"حلب","en":"Aleppo"}',           20,  true),
  ('homs',        '{"ar":"حمص","en":"Homs"}',             30,  true),
  ('latakia',     '{"ar":"اللاذقية","en":"Latakia"}',     40,  true),
  ('tartus',      '{"ar":"طرطوس","en":"Tartus"}',         50,  true),
  ('hama',        '{"ar":"حماة","en":"Hama"}',            60,  true),
  ('rif-dimashq', '{"ar":"ريف دمشق","en":"Rif Dimashq"}', 70,  true),
  ('idlib',       '{"ar":"إدلب","en":"Idlib"}',           80,  true),
  ('daraa',       '{"ar":"درعا","en":"Daraa"}',           90,  true),
  ('deir-ez-zor', '{"ar":"دير الزور","en":"Deir ez-Zor"}', 100, true),
  ('al-hasakah',  '{"ar":"الحسكة","en":"Al-Hasakah"}',   110, true),
  ('al-raqqah',   '{"ar":"الرقة","en":"Al-Raqqah"}',     120, true),
  ('as-suwayda',  '{"ar":"السويداء","en":"As-Suwayda"}', 130, true),
  ('quneitra',    '{"ar":"القنيطرة","en":"Quneitra"}',   140, true)
ON CONFLICT (key) DO NOTHING;
