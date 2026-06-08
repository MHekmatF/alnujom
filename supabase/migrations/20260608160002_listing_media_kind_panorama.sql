-- Wave G7 (growth) — allow 'panorama' as a listing_media kind (360° tours).
ALTER TABLE public.listing_media DROP CONSTRAINT IF EXISTS listing_media_kind_check;
ALTER TABLE public.listing_media
  ADD CONSTRAINT listing_media_kind_check
  CHECK (kind = ANY (ARRAY['image'::text, 'video'::text, 'external_link'::text, 'panorama'::text]));

-- A panorama is a stored equirectangular image (storage_path, like image/video).
ALTER TABLE public.listing_media DROP CONSTRAINT IF EXISTS listing_media_path_xor_url_chk;
ALTER TABLE public.listing_media
  ADD CONSTRAINT listing_media_path_xor_url_chk
  CHECK (
    ((kind = 'external_link'::text) AND (external_url IS NOT NULL) AND (storage_path IS NULL))
    OR ((kind = ANY (ARRAY['image'::text, 'video'::text, 'panorama'::text])) AND (storage_path IS NOT NULL) AND (external_url IS NULL))
  );
