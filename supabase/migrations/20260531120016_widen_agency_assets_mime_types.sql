-- Phase 19 follow-up (spec/019-agencies) — widen agency-assets allowed MIME types.
--
-- The public `agency-assets` bucket (agency logos/covers) was created allowing
-- ONLY 'image/jpeg' (20260531120013_create_agency_storage.sql). On-device QA of
-- the new logo-upload UI surfaced that picking a PNG/WebP logo failed the upload
-- with a MIME rejection (the client correctly sends the real content-type, but
-- the bucket refused anything but JPEG). Broaden to the common web image types
-- so the logo picker accepts what a user would realistically choose.
--
-- Storage object RLS is unchanged (agency_assets_admin_write still gates writes
-- on is_agency_admin of the path-prefix UUID). The 5 MB size limit is unchanged.
-- Idempotent.

UPDATE storage.buckets
   SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
 WHERE id = 'agency-assets';
