-- Phase 29 (029-crm-reels-growth) — W2: dashboard chart aggregates.
--
-- Two tiers, both SECURITY DEFINER + STABLE + SET search_path = public:
--   • publisher_* fns scope to auth.uid() (the caller's own listings/viewings).
--   • admin_* fns re-gate each query on current_user_has_permission(...) and
--     return ZERO rows when the caller lacks the permission (mirrors
--     admin_dashboard_counts / v_lead_events_admin). A partially-permissioned
--     admin therefore sees empty charts, never an error.
--
-- Every table is aliased and every column qualified so RETURNS TABLE OUT-params
-- never collide with same-named columns. All REVOKE ALL FROM PUBLIC, anon; then
-- GRANT EXECUTE to authenticated.

-- ── Publisher: inquiries on the caller's listings, by day ────────────────────
CREATE OR REPLACE FUNCTION public.publisher_inquiries_by_day(p_days integer DEFAULT 30)
RETURNS TABLE(day date, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT (i.created_at AT TIME ZONE 'UTC')::date AS day, count(*) AS total
  FROM public.inquiries i
  JOIN public.listings l ON l.id = i.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND i.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
  GROUP BY 1
  ORDER BY 1;
$$;
REVOKE ALL ON FUNCTION public.publisher_inquiries_by_day(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publisher_inquiries_by_day(integer) TO authenticated;

-- ── Publisher: lead events on the caller's listings, grouped by type ─────────
CREATE OR REPLACE FUNCTION public.publisher_leads_by_type(p_days integer DEFAULT 30)
RETURNS TABLE(event_type text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT e.event_type AS event_type, count(*) AS total
  FROM public.lead_events e
  JOIN public.listings l ON l.id = e.listing_id
  WHERE l.publisher_user_id = auth.uid()
    AND e.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
  GROUP BY e.event_type
  ORDER BY count(*) DESC;
$$;
REVOKE ALL ON FUNCTION public.publisher_leads_by_type(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publisher_leads_by_type(integer) TO authenticated;

-- ── Publisher: the caller's viewings, grouped by status ──────────────────────
CREATE OR REPLACE FUNCTION public.publisher_viewings_by_status()
RETURNS TABLE(status text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT v.status AS status, count(*) AS total
  FROM public.viewings v
  WHERE v.publisher_user_id = auth.uid()
  GROUP BY v.status
  ORDER BY count(*) DESC;
$$;
REVOKE ALL ON FUNCTION public.publisher_viewings_by_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publisher_viewings_by_status() TO authenticated;

-- ── Admin: listings created per month (gate listings.view_all) ───────────────
CREATE OR REPLACE FUNCTION public.admin_listings_by_month(p_months integer DEFAULT 6)
RETURNS TABLE(month date, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT date_trunc('month', l.created_at)::date AS month, count(*) AS total
  FROM public.listings l
  WHERE public.current_user_has_permission('listings.view_all')
    AND l.created_at >= date_trunc('month', now())
        - make_interval(months => greatest(coalesce(p_months, 6), 1) - 1)
  GROUP BY 1
  ORDER BY 1;
$$;
REVOKE ALL ON FUNCTION public.admin_listings_by_month(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_listings_by_month(integer) TO authenticated;

-- ── Admin: profiles created per month (gate users.view) ──────────────────────
CREATE OR REPLACE FUNCTION public.admin_profiles_by_month(p_months integer DEFAULT 6)
RETURNS TABLE(month date, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT date_trunc('month', p.created_at)::date AS month, count(*) AS total
  FROM public.profiles p
  WHERE public.current_user_has_permission('users.view')
    AND p.created_at >= date_trunc('month', now())
        - make_interval(months => greatest(coalesce(p_months, 6), 1) - 1)
  GROUP BY 1
  ORDER BY 1;
$$;
REVOKE ALL ON FUNCTION public.admin_profiles_by_month(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_profiles_by_month(integer) TO authenticated;

-- ── Admin: all lead events per day (gate inquiries.view_all) ─────────────────
CREATE OR REPLACE FUNCTION public.admin_lead_events_by_day(p_days integer DEFAULT 30)
RETURNS TABLE(day date, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT (e.created_at AT TIME ZONE 'UTC')::date AS day, count(*) AS total
  FROM public.lead_events e
  WHERE public.current_user_has_permission('inquiries.view_all')
    AND e.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
  GROUP BY 1
  ORDER BY 1;
$$;
REVOKE ALL ON FUNCTION public.admin_lead_events_by_day(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_lead_events_by_day(integer) TO authenticated;

-- ── Admin: active listings per governorate, top 10 (gate listings.view_all) ──
CREATE OR REPLACE FUNCTION public.admin_listings_by_governorate()
RETURNS TABLE(governorate_name_ar text, governorate_name_en text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    (g.display_name->>'ar') AS governorate_name_ar,
    (g.display_name->>'en') AS governorate_name_en,
    count(*) AS total
  FROM public.listings l
  JOIN public.governorates g ON g.id = l.governorate_id
  WHERE public.current_user_has_permission('listings.view_all')
    AND l.status = 'approved'
  GROUP BY g.id, g.display_name
  ORDER BY count(*) DESC
  LIMIT 10;
$$;
REVOKE ALL ON FUNCTION public.admin_listings_by_governorate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_listings_by_governorate() TO authenticated;
