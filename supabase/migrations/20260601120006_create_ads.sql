-- Phase 21 (spec/021-ads-banners) — ads table. First-party banner ads.
-- RLS on; admin-only SELECT; all client writes REVOKEd (RPC-only, R-165).
CREATE TABLE IF NOT EXISTS public.ads (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT         NOT NULL CHECK (char_length(title) BETWEEN 1 AND 200),
  image_path  TEXT         NOT NULL CHECK (char_length(image_path) BETWEEN 1 AND 400),
  caption_ar  TEXT         CHECK (caption_ar IS NULL OR char_length(caption_ar) <= 200),
  caption_en  TEXT         CHECK (caption_en IS NULL OR char_length(caption_en) <= 200),
  link_kind   TEXT         NOT NULL
                CHECK (link_kind IN ('external','listing','search','category','agency')),
  link_value  TEXT         NOT NULL CHECK (char_length(link_value) BETWEEN 1 AND 2000),
  start_at    TIMESTAMPTZ,
  end_at      TIMESTAMPTZ,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  archived_at TIMESTAMPTZ,                              -- soft-delete marker (R-170)
  created_by  UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  -- Both-or-neither bilingual caption (R-172).
  CONSTRAINT ads_caption_both_or_neither CHECK (
    (caption_ar IS NULL AND caption_en IS NULL)
    OR (caption_ar IS NOT NULL AND caption_en IS NOT NULL)
  ),
  -- Valid schedule window (R-170 / edge case): start strictly before end when both set.
  CONSTRAINT ads_window_valid CHECK (start_at IS NULL OR end_at IS NULL OR start_at < end_at)
);

-- Index supporting the serving-view eligibility filter.
CREATE INDEX IF NOT EXISTS idx_ads_active_window
  ON public.ads (is_active, archived_at, start_at, end_at);

ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- Admin-only direct table read (drafts/inactive/expired/archived). Public reads via v_ads_serving.
DROP POLICY IF EXISTS ads_select_admin ON public.ads;
CREATE POLICY ads_select_admin ON public.ads
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('ads.manage'));

-- No INSERT/UPDATE/DELETE policy: writes are exclusively via the SECURITY DEFINER
-- RPCs (create_ad/update_ad/set_ad_active/archive_ad, migration …011). RPC-only (R-165, FR-019).
REVOKE INSERT, UPDATE, DELETE ON public.ads FROM authenticated, anon;

-- Reuse the Phase 4 updated_at trigger fn.
DROP TRIGGER IF EXISTS trg_ads_updated_at ON public.ads;
CREATE TRIGGER trg_ads_updated_at
  BEFORE UPDATE ON public.ads
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
