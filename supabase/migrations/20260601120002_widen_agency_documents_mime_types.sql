-- Phase 19 follow-up (D-2): widen agency-documents allowed MIME types.
--
-- The private agency-documents bucket (verification document files) allowed only
-- 'image/jpeg' + 'application/pdf' (20260531120013). The new in-app document
-- picker uploads a photo of the ID / registration document via image_picker,
-- which can yield PNG/WebP — those were rejected (the same JPEG-only trap fixed
-- for agency-assets in 20260531120016). Add the common web image types; PDF and
-- the 10 MB size limit are unchanged. Storage RLS (admin-write / owner-admin
-- read on the path-prefix UUID) is unchanged. Idempotent.

UPDATE storage.buckets
   SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
 WHERE id = 'agency-documents';
