-- Phase 19 follow-up (spec/019-agencies) — fix agency_assets_public_select policy.
--
-- On-device QA of the logo-upload UI surfaced a latent bug in the
-- agency_assets_public_select storage SELECT policy (20260531120013): it cast
-- the AGENCY'S NAME to uuid instead of the storage object's path prefix —
--   a.id = (split_part(a.name, '/', 1))::uuid     -- WRONG: a.name is the agency name
-- so for any agency whose name is not a bare UUID (always, e.g. "مكتب النجوم")
-- the cast raised `invalid input syntax for type uuid`, failing EVERY
-- agency-assets read/upsert with a 400 (the upsert's RETURNING * evaluates the
-- SELECT policy). It had never fired before because no asset had ever been
-- uploaded to the bucket.
--
-- Correct intent: an object at '<agencyId>/<file>' is publicly selectable iff
-- that agency is approved. Reference the STORAGE OBJECT's name (the path) and
-- compare ids as text to avoid the fragile ::uuid cast on arbitrary input.

DROP POLICY IF EXISTS agency_assets_public_select ON storage.objects;

CREATE POLICY agency_assets_public_select ON storage.objects
  FOR SELECT USING (
    bucket_id = 'agency-assets'
    AND EXISTS (
      SELECT 1 FROM public.agencies a
      WHERE a.id::text = split_part(storage.objects.name, '/', 1)
        AND a.status = 'approved'
    )
  );
