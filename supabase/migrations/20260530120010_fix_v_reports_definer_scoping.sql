-- Phase 18 (spec/018-reports-moderation) — forward fix for v_reports scoping.
--
-- Bug (found in device QA): v_reports was SECURITY INVOKER and INNER-JOINed
-- public.listings. Under invoker semantics the listings RLS (public read only
-- for status='approved'; owner; listings.view_all admins) applies to the join,
-- so a NON-admin reporter could NOT see their own report once the reported
-- listing left 'approved' (hide/mark_duplicate/delete) — the inner join dropped
-- the row. That breaks the spec's "reports about non-approved listings still
-- appear with listing_status reflecting current state" (data-model §1.4) and the
-- reporter "My Reports" + details-banner (SC-007 / SC-008) for exactly the
-- post-moderation case the reporter most wants to see.
--
-- Fix: recreate v_reports as a SECURITY DEFINER view with an EXPLICIT
-- self-scoping WHERE (reporter-self OR reports.manage) that re-imposes the same
-- visibility the base-table RLS provided, while the definer context lets the
-- listings join return non-approved listings' display fields. This is the same
-- idiom v_listings_public uses. auth.uid() / current_user_has_permission()
-- still resolve to the CALLER inside a definer view (they read the request JWT),
-- so cross-user isolation (SC-009) is preserved by the WHERE clause.

DROP VIEW IF EXISTS public.v_reports;

CREATE VIEW public.v_reports AS
SELECT
  r.id,
  r.listing_id,
  r.reporter_user_id,
  r.reason,
  r.note,
  r.status,
  r.reviewing_by,
  r.resolved_by,
  r.resolution,
  r.created_at,
  r.resolved_at,
  l.title                              AS listing_title,
  l.status                             AS listing_status,
  lm.storage_path                      AS main_image_path,
  g.display_name->>'ar'                AS governorate_name_ar,
  g.display_name->>'en'                AS governorate_name_en,
  c.display_name->>'ar'                AS city_name_ar,
  c.display_name->>'en'                AS city_name_en
FROM public.reports r
JOIN public.listings l        ON l.id = r.listing_id
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities      c ON c.id = l.city_id
LEFT JOIN LATERAL (
  SELECT m.storage_path
  FROM public.listing_media m
  WHERE m.listing_id = l.id AND m.is_main = true
  ORDER BY m.ordering
  LIMIT 1
) lm ON true
WHERE r.reporter_user_id = auth.uid()
   OR public.current_user_has_permission('reports.manage');

REVOKE ALL ON public.v_reports FROM anon;
GRANT SELECT ON public.v_reports TO authenticated;
