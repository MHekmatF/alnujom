-- Phase 20 (spec/020-admin-dashboard) — Migration 1 (plan-phase P1)
-- public.admin_dashboard_counts() — the single bounded aggregate that backs the
-- admin dashboard's five operational counters (FR-006, FR-007, FR-008, FR-013, FR-014).
-- File: supabase/migrations/20260601120003_create_admin_dashboard_counts.sql
-- Contract: contracts/phase20-admin-dashboard-counts-rpc.md ; body: data-model.md §1.1
--
-- SECURITY DEFINER so it can read the admin-only source tables; STABLE because it
-- only reads. Each counter is independently re-gated on current_user_has_permission()
-- and returned as NULL when the caller lacks the section permission — so a partial
-- admin sees only the counters they may see (Principle III "checks at both ends";
-- mirrors the resolve_report_internal / agency moderation posture). A NULL means
-- "not permitted" (the client omits the counter); a 0 is a real count (rendered).
--
-- REVOKE from PUBLIC + anon, GRANT to authenticated (Phase 6/18 advisor posture).
--
-- Column facts verified against the live schema before writing:
--   * pending users  → account_approval_requests.status = 'pending'
--                      (status is an account_approval_status ENUM —
--                       20260510120001_create_account_approval_requests.sql:13,22 —
--                       NOT the legacy "decision" column the IMPLEMENTATION_PLAN wrote)
--   * pending/active listings → public.listings.status TEXT-CHECK enum
--                      ('pending_review' / 'approved') + expires_at/published_at
--                      (20260519120002_create_listings.sql:11,32)
--   * open reports   → public.reports.status TEXT IN ('new','reviewing')
--                      (20260530120001_create_reports_table.sql:41-42)
--   * new inquiries  → public.inquiries.created_at TIMESTAMPTZ
--                      (20260527120001_create_inquiries_table.sql:30)
--   * active_listings window re-based (R-158) on the LIVE listings public-read RLS
--     `listings_select_public` (20260519120002:50-52): status = 'approved'
--     AND (published_at IS NULL OR published_at <= now())
--     AND (expires_at  IS NULL OR expires_at  >  now()).

CREATE OR REPLACE FUNCTION public.admin_dashboard_counts()
RETURNS TABLE (
  pending_users     BIGINT,
  pending_listings  BIGINT,
  open_reports      BIGINT,
  new_inquiries_24h BIGINT,
  active_listings   BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- pending users — gate users.view / users.approve
    CASE WHEN current_user_has_permission('users.view')
           OR current_user_has_permission('users.approve')
         THEN (SELECT count(*) FROM public.account_approval_requests
                WHERE status = 'pending')
         ELSE NULL END,
    -- pending listings — gate listings.view_all / listings.approve
    CASE WHEN current_user_has_permission('listings.view_all')
           OR current_user_has_permission('listings.approve')
         THEN (SELECT count(*) FROM public.listings
                WHERE status = 'pending_review')
         ELSE NULL END,
    -- open reports — gate reports.manage
    CASE WHEN current_user_has_permission('reports.manage')
         THEN (SELECT count(*) FROM public.reports
                WHERE status IN ('new','reviewing'))
         ELSE NULL END,
    -- new inquiries last 24h — gate inquiries.view_all
    CASE WHEN current_user_has_permission('inquiries.view_all')
         THEN (SELECT count(*) FROM public.inquiries
                WHERE created_at >= now() - interval '24 hours')
         ELSE NULL END,
    -- active listings (live publish window) — gate listings.view_all / listings.approve
    CASE WHEN current_user_has_permission('listings.view_all')
           OR current_user_has_permission('listings.approve')
         THEN (SELECT count(*) FROM public.listings
                WHERE status = 'approved'
                  AND (published_at IS NULL OR published_at <= now())
                  AND (expires_at  IS NULL OR expires_at  >  now()))
         ELSE NULL END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_dashboard_counts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_dashboard_counts() TO authenticated;
