-- Wave E (Phase 25 uplift v3) — publisher lead-analytics (free, auth.uid()-scoped).
-- Aggregations over lead_events for the signed-in publisher's own listings.

-- Per-listing lead breakdown by source.
CREATE OR REPLACE FUNCTION public.publisher_lead_analytics_by_listing()
RETURNS TABLE(
  listing_id uuid,
  title text,
  status text,
  featured boolean,
  phone_count bigint,
  whatsapp_count bigint,
  inquiry_count bigint,
  favorite_count bigint,
  total bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    l.id,
    l.title,
    l.status,
    (l.featured_until IS NOT NULL AND l.featured_until > now()),
    count(*) FILTER (WHERE e.event_type = 'phone_revealed'),
    count(*) FILTER (WHERE e.event_type = 'whatsapp_clicked'),
    count(*) FILTER (WHERE e.event_type = 'inquiry_sent'),
    count(*) FILTER (WHERE e.event_type = 'favorite_added'),
    count(e.id)
  FROM public.listings l
  LEFT JOIN public.lead_events e ON e.listing_id = l.id
  WHERE l.publisher_user_id = auth.uid()
  GROUP BY l.id
  ORDER BY count(e.id) DESC, l.created_at DESC;
$$;

-- Daily lead totals over the last p_days (days with zero events are omitted;
-- the client fills gaps for the chart).
CREATE OR REPLACE FUNCTION public.publisher_lead_totals_by_day(p_days integer DEFAULT 30)
RETURNS TABLE(day date, total bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (e.created_at AT TIME ZONE 'UTC')::date AS day, count(*)
  FROM public.lead_events e
  JOIN public.listings l ON l.id = e.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND e.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
  GROUP BY 1
  ORDER BY 1;
$$;

REVOKE ALL ON FUNCTION public.publisher_lead_analytics_by_listing() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publisher_lead_analytics_by_listing() TO authenticated;
REVOKE ALL ON FUNCTION public.publisher_lead_totals_by_day(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publisher_lead_totals_by_day(integer) TO authenticated;
