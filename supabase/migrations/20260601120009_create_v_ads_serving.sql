-- Phase 21 — public serving projection. SECURITY DEFINER (no security_invoker), so it
-- bypasses the admin-only base-table SELECT policy and returns ONLY eligible rows (R-166).
-- Exposes ONLY render+tap fields — no title/schedule/created_by/is_active (FR-020).
CREATE OR REPLACE VIEW public.v_ads_serving AS
SELECT
  a.id            AS ad_id,
  a.image_path,
  a.caption_ar,
  a.caption_en,
  a.link_kind,
  a.link_value,
  p.placement_key,
  p.priority
FROM public.ads a
JOIN public.ad_placements p ON p.ad_id = a.id
WHERE a.is_active = true
  AND a.archived_at IS NULL
  AND (a.start_at IS NULL OR a.start_at <= now())
  AND (a.end_at   IS NULL OR a.end_at   >  now());

-- New views default to anon EXECUTE/SELECT — keep it but be explicit (memory: project_supabase_view_rls_gotchas).
GRANT SELECT ON public.v_ads_serving TO anon, authenticated;
