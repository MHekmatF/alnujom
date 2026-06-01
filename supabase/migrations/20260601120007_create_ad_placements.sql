-- Phase 21 — ad ↔ placement mapping with per-placement carousel priority.
CREATE TABLE IF NOT EXISTS public.ad_placements (
  ad_id         UUID    NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  placement_key TEXT    NOT NULL
                  CHECK (placement_key IN (
                    'home_top_banner','home_middle_banner','search_results_banner',
                    'listing_details_banner','category_banner')),
  priority      INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (ad_id, placement_key)
);

CREATE INDEX IF NOT EXISTS idx_ad_placements_key_priority
  ON public.ad_placements (placement_key, priority DESC, created_at DESC);

ALTER TABLE public.ad_placements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ad_placements_select_admin ON public.ad_placements;
CREATE POLICY ad_placements_select_admin ON public.ad_placements
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

REVOKE INSERT, UPDATE, DELETE ON public.ad_placements FROM authenticated, anon;
