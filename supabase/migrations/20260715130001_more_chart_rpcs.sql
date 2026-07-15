-- Phase 035 — additional dashboard/profile chart aggregates.
--
-- Same conventions as 20260613120003_create_dashboard_chart_rpcs.sql:
-- SECURITY DEFINER + STABLE + SET search_path = public. admin_* re-gate each
-- query on current_user_has_permission(...) and return ZERO rows when the caller
-- lacks it (a partially-permissioned admin sees an empty chart, never an error).
-- Every column is qualified; REVOKE ALL FROM PUBLIC, anon then GRANT to the
-- intended role(s). No new data collected — all series derive from existing
-- columns (listings.property_type, lead_events.created_at, reviews.rating).

-- ── Admin: approved listings grouped by property type (gate listings.view_all) ─
CREATE OR REPLACE FUNCTION public.admin_listings_by_category()
RETURNS TABLE(property_type text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT l.property_type AS property_type, count(*) AS total
  FROM public.listings l
  WHERE public.current_user_has_permission('listings.view_all')
    AND l.status = 'approved'
  GROUP BY l.property_type
  ORDER BY count(*) DESC;
$$;
REVOKE ALL ON FUNCTION public.admin_listings_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_listings_by_category() TO authenticated;

-- ── Admin: lead-event activity by ISO day-of-week × 4-hour bucket ─────────────
-- (gate inquiries.view_all). dow: 1=Mon .. 7=Sun. hour_bucket: 0..5 (each spans
-- 4 hours), extracted in UTC for a stable grid.
CREATE OR REPLACE FUNCTION public.admin_activity_by_dow_hour(p_days integer DEFAULT 30)
RETURNS TABLE(dow integer, hour_bucket integer, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    EXTRACT(isodow FROM (e.created_at AT TIME ZONE 'UTC'))::int AS dow,
    (EXTRACT(hour FROM (e.created_at AT TIME ZONE 'UTC'))::int / 4) AS hour_bucket,
    count(*) AS total
  FROM public.lead_events e
  WHERE public.current_user_has_permission('inquiries.view_all')
    AND e.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
  GROUP BY 1, 2
  ORDER BY 1, 2;
$$;
REVOKE ALL ON FUNCTION public.admin_activity_by_dow_hour(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_activity_by_dow_hour(integer) TO authenticated;

-- ── Public: a seller's review rating distribution (1..5 → count) ──────────────
-- reviews are public (reviews_select_public USING true), so this aggregate is
-- readable by anon + authenticated (a guest viewing a seller/agency profile).
CREATE OR REPLACE FUNCTION public.publisher_rating_distribution(p_user_id uuid)
RETURNS TABLE(rating integer, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT r.rating AS rating, count(*) AS total
  FROM public.reviews r
  WHERE r.target_user_id = p_user_id
  GROUP BY r.rating
  ORDER BY r.rating DESC;
$$;
REVOKE ALL ON FUNCTION public.publisher_rating_distribution(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publisher_rating_distribution(uuid) TO anon, authenticated;
