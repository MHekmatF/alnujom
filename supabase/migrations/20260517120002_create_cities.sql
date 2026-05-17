-- Phase 8 — Locations Catalog: cities table
-- FRs: FR-001 (locations entity), FR-002 (hierarchical scoping — cities scoped to governorates),
--       FR-003 (bilingual display_name), FR-005 (governorate_id FK with ON DELETE CASCADE per Clarifications Q2),
--       FR-007 (audit trail), FR-007a (trigger-before-seed ordering per Clarifications Q5),
--       FR-008 (seeded-row protection via is_system + immutability trigger per Clarifications Q3),
--       FR-009 (RLS — read public, write gated by locations.manage per Phase 6 §9.1).
-- Anonymous SELECT carve-out — see research.md R-04 and R-16.
-- Codified GRANT in 20260517120005_phase8_advisor_hardening.sql.

-- ============================================================
-- 1. TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.cities (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate_id  UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE,
  key             TEXT NOT NULL,
  display_name    JSONB NOT NULL CHECK (
    jsonb_typeof(display_name) = 'object'
    AND coalesce(trim(display_name->>'ar'), '') <> ''
  ),
  description     JSONB,
  position        INTEGER,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  is_system       BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cities_key_format CHECK (key ~ '^[a-z0-9][a-z0-9-]*$'),
  CONSTRAINT cities_unique_key_per_governorate UNIQUE (governorate_id, key)
);

COMMENT ON TABLE public.cities IS
  'Phase 8 — cities scoped to governorates (~30–40 seeded with is_system=true per Clarifications Q4). RLS: public SELECT; write gated by locations.manage.';
COMMENT ON COLUMN public.cities.governorate_id IS
  'FK to public.governorates(id) ON DELETE CASCADE (Clarifications Q2). Deleting a governorate cascades to all its cities.';
COMMENT ON COLUMN public.cities.key IS
  'Stable lowercase slug, unique within the governorate. Cannot be UPDATEd on is_system=true rows (enforced by enforce_city_system_immutability).';
COMMENT ON COLUMN public.cities.display_name IS
  'Bilingual JSONB {"ar": "...", "en": "..."} — Arabic value required; English value optional.';
COMMENT ON COLUMN public.cities.position IS
  'Editorial ordering hint. ORDER BY position NULLS LAST, key ASC for display.';
COMMENT ON COLUMN public.cities.is_active IS
  'Soft-deactivation flag. LocationPicker filters out inactive cities.';
COMMENT ON COLUMN public.cities.is_system IS
  'TRUE for all 32 seeded cities. Refuses DELETE and key UPDATE via enforce_city_system_immutability.';

-- ============================================================
-- 2. RLS
-- ============================================================

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. TRIGGERS (attached BEFORE seed per R-08 / Clarifications Q5)
-- ============================================================

-- 3.1 set_updated_at (Phase 4 helper, reused)
DROP TRIGGER IF EXISTS trg_cities_set_updated_at ON public.cities;
CREATE TRIGGER trg_cities_set_updated_at
  BEFORE UPDATE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 3.2 Immutability trigger (Phase 8 — seeded-row protection, Clarifications Q3)
CREATE OR REPLACE FUNCTION public.enforce_city_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'city_system_immutable: cannot delete a system city (key=%)', OLD.key
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key THEN
      RAISE EXCEPTION 'city_system_immutable: cannot rename a system city''s key (was %, attempted %)', OLD.key, NEW.key
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cities_enforce_immutability ON public.cities;
CREATE TRIGGER trg_cities_enforce_immutability
  BEFORE UPDATE OR DELETE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.enforce_city_system_immutability();

-- 3.3 Audit triggers (Phase 4 log_audit(), 5th reuse — R-13)
DROP TRIGGER IF EXISTS trg_cities_audit_created ON public.cities;
CREATE TRIGGER trg_cities_audit_created
  AFTER INSERT ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('city.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_cities_audit_updated ON public.cities;
CREATE TRIGGER trg_cities_audit_updated
  AFTER UPDATE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('city.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_cities_audit_deleted ON public.cities;
CREATE TRIGGER trg_cities_audit_deleted
  AFTER DELETE ON public.cities
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('city.deleted', '*', 'id');

-- ============================================================
-- 4. RLS POLICIES
-- ============================================================

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS cities_select_public ON public.cities;
CREATE POLICY cities_select_public
  ON public.cities
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS cities_insert_locations_manage ON public.cities;
CREATE POLICY cities_insert_locations_manage
  ON public.cities
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS cities_update_locations_manage ON public.cities;
CREATE POLICY cities_update_locations_manage
  ON public.cities
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS cities_delete_locations_manage ON public.cities;
CREATE POLICY cities_delete_locations_manage
  ON public.cities
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));

-- ============================================================
-- 5. SEED (32 cities, all is_system=true — Clarifications Q3/Q4/Q5)
-- Target band: 30–40 rows (Clarifications Q4). 32 rows locked per data-model.md § 5.2.
-- Triggers fire BEFORE this block (R-08) → each row produces one city.created audit row.
-- governorate_id resolved via subquery on public.governorates.key.
-- ============================================================

INSERT INTO public.cities (governorate_id, key, display_name, position, is_system)
VALUES
  -- Damascus (1 seat city)
  ((SELECT id FROM public.governorates WHERE key='damascus'),    'damascus',        '{"ar":"دمشق","en":"Damascus"}',              10, true),
  -- Aleppo (4 cities)
  ((SELECT id FROM public.governorates WHERE key='aleppo'),      'aleppo',          '{"ar":"حلب","en":"Aleppo"}',                 10, true),
  ((SELECT id FROM public.governorates WHERE key='aleppo'),      'manbij',          '{"ar":"منبج","en":"Manbij"}',                NULL, true),
  ((SELECT id FROM public.governorates WHERE key='aleppo'),      'afrin',           '{"ar":"عفرين","en":"Afrin"}',                NULL, true),
  ((SELECT id FROM public.governorates WHERE key='aleppo'),      'azaz',            '{"ar":"أعزاز","en":"Azaz"}',                 NULL, true),
  -- Homs (3 cities)
  ((SELECT id FROM public.governorates WHERE key='homs'),        'homs',            '{"ar":"حمص","en":"Homs"}',                   10, true),
  ((SELECT id FROM public.governorates WHERE key='homs'),        'palmyra',         '{"ar":"تدمر","en":"Palmyra"}',               NULL, true),
  ((SELECT id FROM public.governorates WHERE key='homs'),        'talkalakh',       '{"ar":"تلكلخ","en":"Talkalakh"}',            NULL, true),
  -- Latakia (2 cities)
  ((SELECT id FROM public.governorates WHERE key='latakia'),     'latakia',         '{"ar":"اللاذقية","en":"Latakia"}',           10, true),
  ((SELECT id FROM public.governorates WHERE key='latakia'),     'jableh',          '{"ar":"جبلة","en":"Jableh"}',                NULL, true),
  -- Tartus (2 cities)
  ((SELECT id FROM public.governorates WHERE key='tartus'),      'tartus',          '{"ar":"طرطوس","en":"Tartus"}',               10, true),
  ((SELECT id FROM public.governorates WHERE key='tartus'),      'banias',          '{"ar":"بانياس","en":"Banias"}',              NULL, true),
  -- Hama (3 cities)
  ((SELECT id FROM public.governorates WHERE key='hama'),        'hama',            '{"ar":"حماة","en":"Hama"}',                  10, true),
  ((SELECT id FROM public.governorates WHERE key='hama'),        'salamiya',        '{"ar":"سلمية","en":"Salamiya"}',             NULL, true),
  ((SELECT id FROM public.governorates WHERE key='hama'),        'masyaf',          '{"ar":"مصياف","en":"Masyaf"}',               NULL, true),
  -- Rif Dimashq (3 cities)
  ((SELECT id FROM public.governorates WHERE key='rif-dimashq'), 'douma',           '{"ar":"دوما","en":"Douma"}',                 10, true),
  ((SELECT id FROM public.governorates WHERE key='rif-dimashq'), 'yabroud',         '{"ar":"يبرود","en":"Yabroud"}',              NULL, true),
  ((SELECT id FROM public.governorates WHERE key='rif-dimashq'), 'qatana',          '{"ar":"قطنا","en":"Qatana"}',                NULL, true),
  -- Idlib (2 cities)
  ((SELECT id FROM public.governorates WHERE key='idlib'),       'idlib',           '{"ar":"إدلب","en":"Idlib"}',                 10, true),
  ((SELECT id FROM public.governorates WHERE key='idlib'),       'maaret-al-numan', '{"ar":"معرة النعمان","en":"Maaret al-Numan"}', NULL, true),
  -- Daraa (2 cities)
  ((SELECT id FROM public.governorates WHERE key='daraa'),       'daraa',           '{"ar":"درعا","en":"Daraa"}',                 10, true),
  ((SELECT id FROM public.governorates WHERE key='daraa'),       'bosra',           '{"ar":"بصرى","en":"Bosra"}',                 NULL, true),
  -- Deir ez-Zor (3 cities)
  ((SELECT id FROM public.governorates WHERE key='deir-ez-zor'), 'deir-ez-zor',     '{"ar":"دير الزور","en":"Deir ez-Zor"}',      10, true),
  ((SELECT id FROM public.governorates WHERE key='deir-ez-zor'), 'albu-kamal',      '{"ar":"البوكمال","en":"Albu Kamal"}',        NULL, true),
  ((SELECT id FROM public.governorates WHERE key='deir-ez-zor'), 'mayadeen',        '{"ar":"الميادين","en":"Mayadeen"}',          NULL, true),
  -- Al-Hasakah (2 cities)
  ((SELECT id FROM public.governorates WHERE key='al-hasakah'),  'al-hasakah',      '{"ar":"الحسكة","en":"Al-Hasakah"}',          10, true),
  ((SELECT id FROM public.governorates WHERE key='al-hasakah'),  'qamishli',        '{"ar":"القامشلي","en":"Qamishli"}',          NULL, true),
  -- Al-Raqqah (2 cities)
  ((SELECT id FROM public.governorates WHERE key='al-raqqah'),   'al-raqqah',       '{"ar":"الرقة","en":"Al-Raqqah"}',            10, true),
  ((SELECT id FROM public.governorates WHERE key='al-raqqah'),   'tabqa',           '{"ar":"الطبقة","en":"Tabqa"}',               NULL, true),
  -- As-Suwayda (2 cities)
  ((SELECT id FROM public.governorates WHERE key='as-suwayda'),  'as-suwayda',      '{"ar":"السويداء","en":"As-Suwayda"}',        10, true),
  ((SELECT id FROM public.governorates WHERE key='as-suwayda'),  'shahba',          '{"ar":"شهبا","en":"Shahba"}',                NULL, true),
  -- Quneitra (1 seat city)
  ((SELECT id FROM public.governorates WHERE key='quneitra'),    'quneitra',        '{"ar":"القنيطرة","en":"Quneitra"}',          10, true)
ON CONFLICT (governorate_id, key) DO NOTHING;
