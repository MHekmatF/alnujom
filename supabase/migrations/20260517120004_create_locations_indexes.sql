-- Phase 8 — Locations Catalog: performance indexes
-- Performance Goals: support SC-006/SC-007 query latency targets.
-- Index strategy: composite (parent_id, position NULLS LAST, key) for the page-load
-- ORDER BY pattern; is_active for LocationPicker filtering; governorate_id/city_id
-- FK support for cascade lookups and city/area list queries.
-- See data-model.md § 2 and plan.md Performance Goals.

CREATE INDEX IF NOT EXISTS idx_governorates_position_key ON public.governorates(position NULLS LAST, key);
CREATE INDEX IF NOT EXISTS idx_governorates_is_active   ON public.governorates(is_active);
CREATE INDEX IF NOT EXISTS idx_cities_governorate_id    ON public.cities(governorate_id);
CREATE INDEX IF NOT EXISTS idx_cities_is_active         ON public.cities(is_active);
CREATE INDEX IF NOT EXISTS idx_cities_position_key      ON public.cities(governorate_id, position NULLS LAST, key);
CREATE INDEX IF NOT EXISTS idx_areas_city_id            ON public.areas(city_id);
CREATE INDEX IF NOT EXISTS idx_areas_is_active          ON public.areas(is_active);
CREATE INDEX IF NOT EXISTS idx_areas_position_key       ON public.areas(city_id, position NULLS LAST, key);
