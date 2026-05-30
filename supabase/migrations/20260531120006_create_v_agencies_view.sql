-- Phase 19 (spec/019-agencies) — Sub-Phase C, Migration 6
-- public.v_agencies SECURITY DEFINER view + the additive v_listings_public badge
-- amendment (data-model §1.6).

-- ─── v_agencies (SECURITY DEFINER) ───
-- Views are SECURITY DEFINER unless security_invoker is set (the Phase 18
-- 20260530120010 fix idiom). The EXPLICIT WHERE reproduces the public/owner/
-- member/admin read matrix so a member's own PENDING agency stays visible to them
-- (an invoker view would re-apply the agencies RLS and hide it — memory
-- project_supabase_view_rls_gotchas). auth.uid() / current_user_has_permission()
-- still resolve to the CALLER inside a definer view (they read the request JWT),
-- so cross-user isolation (SC-009) is preserved by the WHERE clause. anon sees only
-- approved rows because the membership/permission predicates are false for anon.
-- NEVER projects the Vault id/registration numbers (those live only in Vault).
CREATE OR REPLACE VIEW public.v_agencies AS
SELECT
  a.id, a.owner_user_id, a.name, a.description, a.phone, a.whatsapp, a.address,
  a.logo_path, a.cover_path, a.status, a.created_at, a.updated_at
FROM public.agencies a
WHERE a.status = 'approved'
   OR a.owner_user_id = auth.uid()
   OR public.is_agency_member(a.id)
   OR public.current_user_has_permission('agencies.view');

GRANT SELECT ON public.v_agencies TO anon, authenticated;

-- ─── v_listings_public badge amendment (additive) ───
-- CREATE OR REPLACE re-asserting the Phase 14 body (20260525120002) VERBATIM
-- (same projection + LATERAL joins + governorate/city joins + WHERE + the existing
-- default security setting — the original sets no security_invoker, so none is added
-- here) PLUS the additive LEFT JOIN to APPROVED agencies projecting the three badge
-- fields (FR-022). Only listings under an approved agency carry the badge fields;
-- all others (pending/suspended/rejected agency, or agency_id NULL) get NULLs, so
-- no card reflows (FR-023).
CREATE OR REPLACE VIEW public.v_listings_public AS
SELECT
  l.id,
  l.title,
  l.address_text,
  l.property_type,
  l.purpose,
  l.governorate_id,
  l.city_id,
  l.area_id,
  l.rooms,
  l.bathrooms,
  l.area_size,
  l.published_at,
  l.expires_at,
  l.search_vector,
  -- Primary price (is_primary = true row)
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  -- Main image (lowest ordering value among image-kind rows)
  lm.storage_path  AS main_image_path,
  -- Bilingual location names (JSONB display_name -> separate columns)
  g.display_name->>'ar' AS governorate_name_ar,
  g.display_name->>'en' AS governorate_name_en,
  c.display_name->>'ar' AS city_name_ar,
  c.display_name->>'en' AS city_name_en,
  -- Agency verified-badge fields (NEW — FR-022; approved agencies only via the LEFT JOIN below)
  ag.id            AS agency_id,
  ag.name          AS agency_name,
  ag.logo_path     AS agency_logo_path
FROM public.listings l
LEFT JOIN LATERAL (
  SELECT amount, currency_code
  FROM public.listing_prices
  WHERE listing_id = l.id
    AND is_primary = true
  LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path
  FROM public.listing_media
  WHERE listing_id = l.id
    AND kind = 'image'
  ORDER BY ordering ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities       c ON c.id = l.city_id
LEFT JOIN public.agencies     ag ON ag.id = l.agency_id AND ag.status = 'approved'   -- NEW
WHERE l.status = 'approved'
  AND (l.expires_at IS NULL OR l.expires_at > now());
