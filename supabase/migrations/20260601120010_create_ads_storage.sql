-- Phase 21 — public 'ads' banner bucket. Public read; ads.manage write; path {uuid}/{file} (R-174).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ads', 'ads', true, 5242880, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read of all banner images (non-sensitive promotional art; eligibility is filtered
-- at the data layer by v_ads_serving, so an archived ad's image is simply unreferenced).
DROP POLICY IF EXISTS "ads_public_select" ON storage.objects;
CREATE POLICY "ads_public_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'ads');

-- ads.manage write (insert/update/delete), path-shape {uuid}/{filename}.
DROP POLICY IF EXISTS "ads_admin_write" ON storage.objects;
CREATE POLICY "ads_admin_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'ads'
    AND public.current_user_has_permission('ads.manage')
    AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  );

DROP POLICY IF EXISTS "ads_admin_update" ON storage.objects;
CREATE POLICY "ads_admin_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'ads' AND public.current_user_has_permission('ads.manage'));

DROP POLICY IF EXISTS "ads_admin_delete" ON storage.objects;
CREATE POLICY "ads_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'ads' AND public.current_user_has_permission('ads.manage'));
