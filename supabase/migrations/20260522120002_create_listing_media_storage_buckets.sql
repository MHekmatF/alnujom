-- Phase 11: Listing Media Upload, Client-Side Watermark & Storage Policies.
-- FR-008 (bucket configuration), SC-029 (bucket public flag verification).
-- Q4=A: bucket allowlist tightened to ['image/jpeg'] — the FR-014 pipeline normalises
--        broader source formats (JPEG/PNG/HEIC/HEIF/WebP) to JPEG before upload; the
--        bucket therefore never sees PNG/HEIC/WebP raw files.
-- Q8=A: public=true buckets; RLS on storage.objects (migration 20260522120003) is the
--        actual access boundary. Stable getPublicUrl() URLs for Phase 13 gallery (R-29).
-- R-26: idempotent upsert via ON CONFLICT (id) DO UPDATE — safe to re-apply.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('listing-images', 'listing-images', true, 10485760, ARRAY['image/jpeg']),
  ('listing-videos', 'listing-videos', true, 31457280, ARRAY['video/mp4'])
ON CONFLICT (id) DO UPDATE SET
  public            = EXCLUDED.public,
  file_size_limit   = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;
