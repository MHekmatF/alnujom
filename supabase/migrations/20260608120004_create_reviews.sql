-- Wave D (Phase 25 uplift v3) — seller trust layer: reviews + ratings + response stats.

CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewer_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES public.listings(id) ON DELETE SET NULL,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text CHECK (comment IS NULL OR char_length(comment) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviews_no_self CHECK (reviewer_user_id <> target_user_id),
  CONSTRAINT reviews_unique_per_reviewer UNIQUE (reviewer_user_id, target_user_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_target ON public.reviews (target_user_id, created_at DESC);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY reviews_select_public ON public.reviews FOR SELECT USING (true);
CREATE POLICY reviews_insert_own ON public.reviews FOR INSERT TO authenticated
  WITH CHECK (reviewer_user_id = auth.uid() AND reviewer_user_id <> target_user_id);
CREATE POLICY reviews_update_own ON public.reviews FOR UPDATE TO authenticated
  USING (reviewer_user_id = auth.uid()) WITH CHECK (reviewer_user_id = auth.uid());
CREATE POLICY reviews_delete_own ON public.reviews FOR DELETE TO authenticated
  USING (reviewer_user_id = auth.uid());

GRANT SELECT ON public.reviews TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.reviews TO authenticated;

CREATE TRIGGER trg_reviews_set_updated_at BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE VIEW public.v_publisher_ratings
  WITH (security_invoker = true) AS
SELECT
  target_user_id,
  round(avg(rating)::numeric, 2) AS avg_rating,
  count(*)::int AS review_count
FROM public.reviews
GROUP BY target_user_id;

GRANT SELECT ON public.v_publisher_ratings TO anon, authenticated;

-- Response stats for a seller (aggregates only). updated_at is a proxy for
-- "responded at"; response_rate = share of inquiries moved off 'new'.
CREATE OR REPLACE FUNCTION public.publisher_response_stats(p_user_id uuid)
RETURNS TABLE(
  total_inquiries bigint,
  responded bigint,
  response_rate numeric,
  avg_response_hours numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    count(*),
    count(*) FILTER (WHERE i.status <> 'new'),
    CASE WHEN count(*) = 0 THEN NULL
         ELSE round((count(*) FILTER (WHERE i.status <> 'new'))::numeric / count(*), 2) END,
    round((avg(EXTRACT(EPOCH FROM (i.updated_at - i.created_at)) / 3600.0)
           FILTER (WHERE i.status <> 'new'))::numeric, 1)
  FROM public.inquiries i
  JOIN public.listings l ON l.id = i.listing_id
  WHERE l.publisher_user_id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.publisher_response_stats(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publisher_response_stats(uuid) TO anon, authenticated;
