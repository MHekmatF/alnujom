-- Find the files nobody owns, and finish what a delete started.
--
-- Review 2026-09-05 §2.1 (plan A25). Storage held 22 MB, and 12.5 MB of it —
-- 29 images and 2 videos — matched no `listing_media` row: files left behind
-- by hard-deleted listings from before A15, originals of replaced photos, and
-- one video whose upload never reached its row. And since A15 made publisher
-- delete a SOFT delete (`status = 'deleted'`, so the account purge can still
-- find the files), a listing deleted on a *living* account keeps its photos
-- forever: `purge_deleted_accounts` is account-scoped and nothing else looks.
-- Storage is the first Free-plan wall (1 GB), so this is cost, not tidiness.
--
-- Files can only be removed through the Storage API, never by deleting rows
-- from `storage.objects` — so the removal lives in the `sweep_storage` edge
-- function (service role, inside Supabase's own runtime; ADR-0001 is about the
-- key leaving the build machine, and it does not). This migration gives that
-- function two read-only lists and a way to recognise the scheduler:
--
--   list_orphan_media_objects(grace)   objects in the two listing buckets that
--                                      no media row references, older than the
--                                      grace (default 7 days — an upload in
--                                      flight is not an orphan yet)
--   list_purgeable_listing_media(grace) media rows of listings soft-deleted
--                                      longer ago than the grace (default 30
--                                      days, the same window the account purge
--                                      honours), EXCLUDING listings whose owner
--                                      has a pending account purge — those are
--                                      that job's, and it must find its files
--   housekeeping_token_matches(token)  true when the bearer equals the Vault
--                                      secret `housekeeping_token` (created by
--                                      the scheduling migration, plan A32)
--
-- All three are SECURITY DEFINER, callable by `service_role` only. Nothing
-- here deletes anything.

CREATE OR REPLACE FUNCTION public.list_orphan_media_objects(p_grace interval DEFAULT interval '7 days')
RETURNS TABLE(bucket_id text, name text, size_bytes bigint, created_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'storage'
AS $function$
BEGIN
  IF p_grace IS NULL OR p_grace < interval '1 hour' THEN
    RAISE EXCEPTION 'grace must be at least 1 hour, got %', p_grace USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    SELECT o.bucket_id::text,
           o.name::text,
           coalesce((o.metadata->>'size')::bigint, 0),
           o.created_at
      FROM storage.objects o
     WHERE o.bucket_id IN ('listing-images', 'listing-videos')
       AND o.created_at < now() - p_grace
       AND NOT EXISTS (
             SELECT 1 FROM public.listing_media m
              WHERE m.storage_path = o.name OR m.thumbnail_path = o.name)
     ORDER BY o.bucket_id, o.name;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_orphan_media_objects(interval) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_orphan_media_objects(interval) TO service_role;
COMMENT ON FUNCTION public.list_orphan_media_objects(interval) IS
  'Objects in listing-images / listing-videos that no listing_media row references (storage_path or thumbnail_path), older than the grace. Read-only; service_role only; consumed by the sweep_storage edge function (plan A25).';

CREATE OR REPLACE FUNCTION public.list_purgeable_listing_media(p_grace interval DEFAULT interval '30 days')
RETURNS TABLE(media_id uuid, listing_id uuid, bucket_id text, name text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF p_grace IS NULL OR p_grace < interval '1 day' THEN
    RAISE EXCEPTION 'grace must be at least 1 day, got %', p_grace USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    WITH gone AS (
      SELECT l.id
        FROM public.listings l
       WHERE l.status = 'deleted'
         AND l.updated_at < now() - p_grace
         AND NOT EXISTS (
               SELECT 1 FROM public.account_deletion_requests r
                WHERE r.user_id = l.publisher_user_id
                  AND r.purge_status = 'pending_auth_purge')
    )
    SELECT m.id, m.listing_id,
           CASE m.kind WHEN 'video' THEN 'listing-videos' ELSE 'listing-images' END,
           m.storage_path
      FROM public.listing_media m JOIN gone g ON g.id = m.listing_id
     WHERE m.storage_path IS NOT NULL
    UNION ALL
    SELECT m.id, m.listing_id, 'listing-images', m.thumbnail_path
      FROM public.listing_media m JOIN gone g ON g.id = m.listing_id
     WHERE m.thumbnail_path IS NOT NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_purgeable_listing_media(interval) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_purgeable_listing_media(interval) TO service_role;
COMMENT ON FUNCTION public.list_purgeable_listing_media(interval) IS
  'Media rows (originals and thumbnails) of listings soft-deleted longer ago than the grace, excluding listings whose owner has a pending account purge. Read-only; service_role only; consumed by the sweep_storage edge function (plan A25).';

CREATE OR REPLACE FUNCTION public.housekeeping_token_matches(p_token text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT p_token IS NOT NULL
     AND length(p_token) >= 32
     AND p_token = (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'housekeeping_token' LIMIT 1);
$$;

REVOKE ALL ON FUNCTION public.housekeeping_token_matches(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.housekeeping_token_matches(text) TO service_role;
COMMENT ON FUNCTION public.housekeeping_token_matches(text) IS
  'True when the given bearer equals the Vault secret housekeeping_token, which pg_cron presents when it calls the housekeeping edge functions (plan A32). False when the secret does not exist. service_role only.';

NOTIFY pgrst, 'reload schema';
