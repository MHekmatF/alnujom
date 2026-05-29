-- Phase 18 (spec/018-reports-moderation) — Migration 4/8
-- public.v_reports — the single projection serving BOTH the reporter
-- ("My Reports") and the admin (queue / report detail). Row visibility differs
-- naturally by RLS (data-model §1.4, contracts/phase18-v-reports-view.md).
--
-- SECURITY INVOKER so the base-table reports RLS (Migration 3) scopes view reads:
-- a reporter sees only their own report rows; a reports.manage holder sees all.
-- NOT filtered on listing status — reports about non-approved (paused / rejected
-- / deleted / expired) listings still appear, with listing_status reflecting the
-- current state. INNER JOIN to listings: a report always references a real
-- listing (listing_id FK ON DELETE RESTRICT), so the join never drops a row;
-- listing_status carries the lifecycle state the UI renders.
--
-- Projects NO publisher private field and NO aggregate count (FR-028).
-- Join set mirrors v_listings_public (20260525120002): listings (INNER),
-- governorates / cities (LEFT, display_name JSONB), listing_media main image
-- (LATERAL, is_main).
CREATE OR REPLACE VIEW public.v_reports
WITH (security_invoker = true) AS
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
) lm ON true;

GRANT SELECT ON public.v_reports TO authenticated;
-- NOT granted to anon.
