-- Phase 11 follow-up fix (task #31): consolidate the N sequential UPDATEs
-- in supabase_listing_media_datasource.reorder into a single SECURITY DEFINER
-- RPC for one round-trip + atomic re-sequence under one transaction.
--
-- The Phase 7/9 R-06 RPC-over-Edge-Function precedent applies: caller
-- authorization is enforced inside the function body via auth.uid().
--
-- Guards:
--   1. Listing must exist.
--   2. Caller is either the listing's publisher OR has 'listings.edit_any'.
--   3. Listing status is in ('draft','rejected') — same edit-window as
--      the storage RLS policy.
--   4. Every id in ordered_ids must belong to the listing (so a malicious
--      caller can't reach across listings via a forged id list).

CREATE OR REPLACE FUNCTION public.reorder_listing_media(
  p_listing_id UUID,
  p_ordered_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_listing       public.listings;
  v_can_edit_any  BOOLEAN;
BEGIN
  SELECT * INTO v_listing FROM public.listings WHERE id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'listing not found';
  END IF;

  SELECT public.current_user_has_permission('listings.edit_any')
    INTO v_can_edit_any;
  IF NOT v_can_edit_any AND v_listing.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  IF v_listing.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'listing not in editable status';
  END IF;

  -- Guard against cross-listing id smuggling.
  IF EXISTS (
    SELECT 1 FROM unnest(p_ordered_ids) AS u(id)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.listing_media lm
      WHERE lm.id = u.id AND lm.listing_id = p_listing_id
    )
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'one or more media ids do not belong to this listing';
  END IF;

  -- Atomic re-sequence: WITH ORDINALITY gives us the new position per id.
  UPDATE public.listing_media lm
  SET ordering = ranked.new_ord
  FROM (
    SELECT u.id, u.ord AS new_ord
    FROM unnest(p_ordered_ids) WITH ORDINALITY AS u(id, ord)
  ) AS ranked
  WHERE lm.id = ranked.id;
END;
$$;

REVOKE ALL ON FUNCTION public.reorder_listing_media(UUID, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reorder_listing_media(UUID, UUID[]) TO authenticated;

COMMENT ON FUNCTION public.reorder_listing_media(UUID, UUID[]) IS
'Phase 11 follow-up — single-round-trip atomic re-sequence of listing_media.ordering for a listing. Replaces the per-row UPDATE loop in supabase_listing_media_datasource.reorder. SECURITY DEFINER with explicit caller-authorization guards per Phase 7/9 R-06 precedent.';
