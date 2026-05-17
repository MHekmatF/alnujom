-- Phase 8 — Locations Catalog: areas table
-- FRs: FR-001 (locations entity), FR-002 (hierarchical scoping — areas scoped to cities),
--       FR-003 (bilingual display_name), FR-006 (city_id FK with ON DELETE CASCADE per Clarifications Q2),
--       FR-007 (audit trail), FR-007a (trigger-before-seed ordering per Clarifications Q5),
--       FR-009 (RLS — read public, write gated by locations.manage per Phase 6 §9.1).
-- No is_system column — areas have no protected seed; full CRUD on every row (Clarifications Q3).
-- Anonymous SELECT carve-out — see research.md R-04 and R-16.
-- Codified GRANT in 20260517120005_phase8_advisor_hardening.sql.

-- ============================================================
-- 1. TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.areas (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id      UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  key          TEXT NOT NULL,
  display_name JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description  JSONB,
  position     INTEGER,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT areas_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$'),
  CONSTRAINT areas_unique_key_per_city UNIQUE (city_id, key)
);

COMMENT ON TABLE public.areas IS
  'Phase 8 — areas scoped to cities (starter set seeded). No is_system column — areas have no protected seed; full CRUD on every row.';
COMMENT ON COLUMN public.areas.city_id IS
  'FK to public.cities(id) ON DELETE CASCADE (Clarifications Q2). Deleting a city cascades to all its areas.';
COMMENT ON COLUMN public.areas.key IS
  'Stable lowercase slug, unique within the city. Fully mutable — no immutability trigger on areas.';
COMMENT ON COLUMN public.areas.display_name IS
  'Bilingual JSONB {"ar": "...", "en": "..."} — Arabic value required; English value optional.';
COMMENT ON COLUMN public.areas.position IS
  'Editorial ordering hint. ORDER BY position NULLS LAST, key ASC for display.';
COMMENT ON COLUMN public.areas.is_active IS
  'Soft-deactivation flag. LocationPicker filters out inactive areas.';

-- ============================================================
-- 2. RLS
-- ============================================================

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. TRIGGERS (attached BEFORE seed per R-08 / Clarifications Q5)
-- NOTE: NO immutability trigger — areas have no protected seed (Clarifications Q3).
-- ============================================================

-- 3.1 set_updated_at (Phase 4 helper, reused)
DROP TRIGGER IF EXISTS trg_areas_set_updated_at ON public.areas;
CREATE TRIGGER trg_areas_set_updated_at
  BEFORE UPDATE ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3.2 Audit triggers (Phase 4 log_audit(), 5th reuse — R-13)
DROP TRIGGER IF EXISTS trg_areas_audit_created ON public.areas;
CREATE TRIGGER trg_areas_audit_created
  AFTER INSERT ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('area.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_areas_audit_updated ON public.areas;
CREATE TRIGGER trg_areas_audit_updated
  AFTER UPDATE ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('area.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_areas_audit_deleted ON public.areas;
CREATE TRIGGER trg_areas_audit_deleted
  AFTER DELETE ON public.areas
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('area.deleted', '*', 'id');

-- ============================================================
-- 4. RLS POLICIES
-- ============================================================

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS areas_select_public ON public.areas;
CREATE POLICY areas_select_public
  ON public.areas
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS areas_insert_locations_manage ON public.areas;
CREATE POLICY areas_insert_locations_manage
  ON public.areas
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS areas_update_locations_manage ON public.areas;
CREATE POLICY areas_update_locations_manage
  ON public.areas
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS areas_delete_locations_manage ON public.areas;
CREATE POLICY areas_delete_locations_manage
  ON public.areas
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));

-- ============================================================
-- 5. SEED (9 starter areas — data-model.md § 5.3)
-- Areas have NO is_system column — every area row is fully editable/deletable.
-- Triggers fire BEFORE this block (R-08) → each row produces one area.created audit row.
-- city_id resolved via nested subquery (city.key + governorate.key).
-- ============================================================

INSERT INTO public.areas (city_id, key, display_name)
VALUES
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='damascus' AND g.key='damascus'),
    'old-city-damascus',
    '{"ar":"المدينة القديمة","en":"Old City Damascus"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='damascus' AND g.key='damascus'),
    'mezzeh',
    '{"ar":"المزة","en":"Mezzeh"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='damascus' AND g.key='damascus'),
    'mashrouh-dummar',
    '{"ar":"مشروع دمر","en":"Mashrouh Dummar"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='aleppo' AND g.key='aleppo'),
    'aleppo-old-city',
    '{"ar":"حلب القديمة","en":"Aleppo Old City"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='aleppo' AND g.key='aleppo'),
    'sulaymaniyah',
    '{"ar":"السليمانية","en":"Sulaymaniyah"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='homs' AND g.key='homs'),
    'homs-old-city',
    '{"ar":"حمص القديمة","en":"Homs Old City"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='latakia' AND g.key='latakia'),
    'latakia-corniche',
    '{"ar":"كورنيش اللاذقية","en":"Latakia Corniche"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='tartus' AND g.key='tartus'),
    'tartus-corniche',
    '{"ar":"كورنيش طرطوس","en":"Tartus Corniche"}'
  ),
  (
    (SELECT c.id FROM public.cities c
     JOIN public.governorates g ON g.id = c.governorate_id
     WHERE c.key='hama' AND g.key='hama'),
    'hama-norias',
    '{"ar":"منطقة النواعير","en":"Hama Norias"}'
  )
ON CONFLICT (city_id, key) DO NOTHING;
