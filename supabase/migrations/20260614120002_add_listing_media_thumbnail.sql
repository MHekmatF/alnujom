-- Phase 030 (W1 — Video compression + poster thumbnails) — adds a nullable
-- `thumbnail_path` column to public.listing_media.
--
-- For a video row this stores the storage path (in the `listing-images`
-- bucket) of a JPEG poster frame generated client-side by `video_compress`
-- at upload time, at `{listingId}/{suffix}_thumb.jpg`. It is NULL for image /
-- panorama rows and for any pre-migration video rows (the reels feed and the
-- listing-details gallery fall back to the first image when it is NULL).
--
-- Idempotent (IF NOT EXISTS) — safe to re-run.

ALTER TABLE public.listing_media
  ADD COLUMN IF NOT EXISTS thumbnail_path text;

COMMENT ON COLUMN public.listing_media.thumbnail_path IS
  'Phase 030 (W1) — storage path (in the listing-images bucket) of a JPEG '
  'poster frame for a video row, at {listingId}/{suffix}_thumb.jpg. NULL for '
  'images/panoramas and pre-migration videos; consumers fall back to the first '
  'image when NULL.';
