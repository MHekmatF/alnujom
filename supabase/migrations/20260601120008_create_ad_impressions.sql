-- Phase 21 — click events (clicks ONLY in v1; kind CHECK locked to 'click', R-168).
-- Named ad_impressions per plan §6.2; admin-read-only; RPC-only write (record_ad_event).
CREATE TABLE IF NOT EXISTS public.ad_impressions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_id         UUID        NOT NULL REFERENCES public.ads(id) ON DELETE CASCADE,
  placement_key TEXT        NOT NULL
                  CHECK (placement_key IN (
                    'home_top_banner','home_middle_banner','search_results_banner',
                    'listing_details_banner','category_banner')),
  user_id       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,  -- null = anonymous
  kind          TEXT        NOT NULL DEFAULT 'click' CHECK (kind IN ('click')),
  metadata      JSONB,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ad_impressions_ad_kind
  ON public.ad_impressions (ad_id, kind, occurred_at DESC);

ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ad_impressions_select_admin ON public.ad_impressions;
CREATE POLICY ad_impressions_select_admin ON public.ad_impressions
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

-- Writes ONLY via record_ad_event SECURITY DEFINER RPC (…012). No client write.
REVOKE INSERT, UPDATE, DELETE ON public.ad_impressions FROM authenticated, anon;
