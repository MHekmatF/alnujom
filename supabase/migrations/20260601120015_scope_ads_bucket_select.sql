-- Phase 21 follow-up (spec/021-ads-banners) — scope the 'ads' bucket SELECT policy.
--
-- get_advisors (post-…010) flagged `public_bucket_allows_listing` on the `ads` bucket:
-- the original ads_public_select policy granted a BROAD `bucket_id = 'ads'` SELECT to
-- anon+authenticated, letting any client enumerate (list) every ad image filename.
-- Every OTHER public bucket in this project scopes its storage.objects SELECT to the
-- eligibility condition (agency-assets → approved agency; listing-images/videos →
-- approved+published listing / owner / admin). The broad ads policy was the lone outlier.
--
-- Public image RENDERING is unaffected: the app reads ad images via getPublicUrl(), i.e.
-- the public CDN object path, which bypasses RLS for a public bucket. The SELECT policy on
-- storage.objects only governs the authenticated object API + list() + the upsert RETURNING.
--
-- Replacement (mirrors listing_images_*):
--   • ads_admin_select  — ads.manage holders select ALL ad objects (drives the editor preview
--     and the upload upsert's RETURNING, incl. scheduled/inactive/archived ads).
--   • ads_public_select — anon+authenticated may select an object ONLY when its path-prefix
--     ad id belongs to an ELIGIBLE (active + not-archived + in-window) ad — the serving set.

DROP POLICY IF EXISTS "ads_public_select" ON storage.objects;

-- Admin (ads.manage): full read of the bucket — management, editor preview, upload RETURNING.
DROP POLICY IF EXISTS "ads_admin_select" ON storage.objects;
CREATE POLICY "ads_admin_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'ads' AND public.current_user_has_permission('ads.manage'));

-- Public: only images of currently-eligible ads (the same window v_ads_serving exposes).
CREATE POLICY "ads_public_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (
    bucket_id = 'ads'
    AND EXISTS (
      SELECT 1 FROM public.ads a
      WHERE a.id::text = split_part(storage.objects.name, '/', 1)
        AND a.is_active = true
        AND a.archived_at IS NULL
        AND (a.start_at IS NULL OR a.start_at <= now())
        AND (a.end_at   IS NULL OR a.end_at   >  now())
    )
  );
