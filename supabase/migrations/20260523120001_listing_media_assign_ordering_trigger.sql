-- Phase 11 follow-up fix (task #29): client-side nextOrdering is racy across
-- BLoC events when state.media goes stale (load handler can overwrite with
-- mid-flight DB state). Move ordering assignment to a BEFORE INSERT trigger
-- so the database is the single source of truth.
--
-- Behavior:
--   - If NEW.ordering = 0 (sentinel) or NULL, compute max(ordering)+1
--     partitioned by (listing_id, kind) and assign it.
--   - If NEW.ordering > 0, leave it as-is (preserves explicit-ordering paths
--     like the reorder UPDATEs in supabase_listing_media_datasource.reorder).
--
-- Order vs cap trigger:
--   Trigger name "listing_media_assign_ordering" sorts alphabetically before
--   "listing_media_cap_trigger"; both are BEFORE INSERT FOR EACH ROW. Cap
--   trigger reads count(*) from existing rows — independent of NEW.ordering —
--   so the order doesn't affect cap enforcement.

CREATE OR REPLACE FUNCTION public.listing_media_assign_ordering()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.ordering IS NULL OR NEW.ordering = 0 THEN
    SELECT COALESCE(MAX(ordering), 0) + 1
      INTO NEW.ordering
      FROM public.listing_media
      WHERE listing_id = NEW.listing_id AND kind = NEW.kind;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS listing_media_assign_ordering ON public.listing_media;
CREATE TRIGGER listing_media_assign_ordering
  BEFORE INSERT ON public.listing_media
  FOR EACH ROW
  EXECUTE FUNCTION public.listing_media_assign_ordering();

COMMENT ON FUNCTION public.listing_media_assign_ordering() IS
'Phase 11 follow-up — auto-assigns NEW.ordering = max(ordering)+1 per (listing_id, kind) when client sends 0/NULL. Removes the client-side race between BLoC state and DB state.';
