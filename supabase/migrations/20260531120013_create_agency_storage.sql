-- Phase 19 (spec/019-agencies) — Migration 13/13 — storage buckets + policies (T030).
-- FR-033 (storage buckets) / FR-006 (private verification documents).
--
-- agency-assets    : PUBLIC bucket for logos/cover (image/jpeg, 5 MB). Path shape
--                    {agency_id}/filename. Public read gated on the parent agency being
--                    approved; agency-admin write via path-shape + is_agency_admin.
-- agency-documents : PRIVATE bucket for verification files (image/jpeg + application/pdf,
--                    10 MB). Read by the owning agency-admin OR an agencies.view holder;
--                    write by the owning agency-admin only.
--
-- Mirrors the Phase 11 listing-media storage template (20260522120002 buckets +
-- 20260522120003 path-shape policies). Depends on B's public.agencies (status gate) +
-- public.agency_members via the is_agency_admin predicate (20260531120002).
-- R-26: idempotent upsert via ON CONFLICT (id) DO UPDATE; each CREATE POLICY is
--       preceded by DROP POLICY IF EXISTS — safe to re-apply.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Buckets
-- ───────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('agency-assets',    'agency-assets',    true,  5242880,  ARRAY['image/jpeg']),
  ('agency-documents', 'agency-documents', false, 10485760, ARRAY['image/jpeg','application/pdf'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. agency-assets policies
-- ───────────────────────────────────────────────────────────────────────────

-- Public read of approved-agency logos (path shape: {agency_id}/filename).
DROP POLICY IF EXISTS "agency_assets_public_select" ON storage.objects;
CREATE POLICY "agency_assets_public_select" ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'agency-assets'
  AND EXISTS (SELECT 1 FROM public.agencies a
              WHERE a.id = split_part(name, '/', 1)::uuid AND a.status = 'approved')
);

-- Agency-admin write of own-agency assets (mirrors 20260522120003 path-shape + EXISTS gate).
DROP POLICY IF EXISTS "agency_assets_admin_write" ON storage.objects;
CREATE POLICY "agency_assets_admin_write" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'agency-assets'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND public.is_agency_admin(split_part(name, '/', 1)::uuid)
);

-- ───────────────────────────────────────────────────────────────────────────
-- 3. agency-documents policies (private verification files)
-- ───────────────────────────────────────────────────────────────────────────

-- agency-admin (own) OR agencies.view (platform admin) read.
DROP POLICY IF EXISTS "agency_documents_owner_admin_select" ON storage.objects;
CREATE POLICY "agency_documents_owner_admin_select" ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'agency-documents'
  AND (public.is_agency_admin(split_part(name, '/', 1)::uuid)
       OR public.current_user_has_permission('agencies.view'))
);

-- agency-admin (own) write.
DROP POLICY IF EXISTS "agency_documents_admin_write" ON storage.objects;
CREATE POLICY "agency_documents_admin_write" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'agency-documents'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND public.is_agency_admin(split_part(name, '/', 1)::uuid)
);
