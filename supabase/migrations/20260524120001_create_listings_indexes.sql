-- Phase 13 — Index migration. Per FR-001 + R-61.
-- Four composite indexes on public.listings supporting the home-feed read
-- pattern + the publisher/admin read patterns + two facet-prep patterns
-- forward-stated for Phase 14.
-- Idempotent via IF NOT EXISTS.

-- (1) Home-feed read pattern (Phase 13 FR-015): ORDER BY published_at DESC, id DESC
--     under the WHERE status='approved' filter applied by RLS.
CREATE INDEX IF NOT EXISTS idx_listings_status_published_at
  ON public.listings (status, published_at DESC, id DESC);

-- (2) Publisher / admin read pattern (Phase 10's MyListingsPage, Phase 12's queue):
--     ORDER BY created_at DESC, id DESC under WHERE status IN (...). Also aligns
--     with the IMPLEMENTATION_PLAN's literal "(status, created_at DESC)" text.
CREATE INDEX IF NOT EXISTS idx_listings_status_created_at
  ON public.listings (status, created_at DESC, id DESC);

-- (3) Forward-stated Phase 14 governorate-filter pattern (Phase 13 Q1=A leaves
--     governorate-shortcut UX unwired but the index is cheap to ship now).
CREATE INDEX IF NOT EXISTS idx_listings_governorate_status
  ON public.listings (governorate_id, status);

-- (4) Property-type-shortcut filter pattern (Phase 13 Q1=A stub + Phase 14 wire).
CREATE INDEX IF NOT EXISTS idx_listings_property_type_status
  ON public.listings (property_type, status);
