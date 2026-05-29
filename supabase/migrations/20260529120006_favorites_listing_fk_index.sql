-- Phase 17 (spec/017-favorites) — Migration 6/6 — performance-advisor remediation.
-- The composite PK (user_id, listing_id) covers user_id-prefix lookups but NOT
-- listing_id-only access, leaving favorites_listing_id_fkey unindexed (Supabase
-- performance advisor 0001_unindexed_foreign_keys). This covering index speeds
-- the ON DELETE RESTRICT FK check and the v_favorites favorites→listings join.
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id
  ON public.favorites (listing_id);
