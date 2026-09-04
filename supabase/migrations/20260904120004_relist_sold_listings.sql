-- Let a publisher put a sold or rented listing back on the market.
--
-- `20260904120003` shipped the transition table with `sold` and `rented` as
-- terminal — the only move left was delete. That is wrong for this business: a
-- buyer backing out, a tenant not signing, or simply the wrong button tapped
-- are all ordinary, and the alternative was re-creating the whole listing from
-- scratch and waiting for moderation again.
--
-- The risk profile is identical to un-pausing, which was already allowed: the
-- listing was approved once, nothing about it can change without going through
-- the revision flow, and `published_at` is left alone so it does not jump to the
-- top of the feed.
--
-- The saved-search suppression widens with it. Every route to `approved`
-- through this RPC is a RE-appearance — paused, sold or rented, all of them
-- previously approved — so the guard now covers the whole branch instead of
-- naming one source status. A genuine first approval still goes through
-- `approve_listing_internal`, never here, and still alerts.
CREATE OR REPLACE FUNCTION public.set_own_listing_status(p_listing_id uuid, p_status text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_owner   uuid;
  v_current text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT publisher_user_id, status INTO v_owner, v_current
    FROM public.listings WHERE id = p_listing_id;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  -- The allowed moves, and nothing else. Note what is deliberately absent:
  --   * pending_review -> anything. A submission under review belongs to the
  --     moderator until they decide; letting it vanish mid-review would empty
  --     the admin queue from under them.
  --   * draft / rejected / expired -> approved. Re-publishing something that
  --     was never approved, or whose approval lapsed, would skip moderation.
  --     (`expired` is the renew RPC's job, which extends the existing approval.)
  --   * anything -> draft / pending_review. Editing is the revision flow's job.
  IF NOT (
       (v_current = 'approved' AND p_status IN ('sold', 'rented', 'paused'))
    OR (v_current IN ('paused', 'sold', 'rented') AND p_status = 'approved')
    OR (v_current IN ('draft', 'rejected', 'expired', 'sold', 'rented')
        AND p_status = 'deleted')
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '22023';
  END IF;

  -- Every path to `approved` from here is a return, not an arrival: the listing
  -- was approved before it was paused, sold or rented. Saved-search subscribers
  -- were told about it then and are not told again.
  IF p_status = 'approved' THEN
    PERFORM set_config('app.skip_saved_search_alert', '1', true);
  END IF;

  -- `published_at` is deliberately untouched, so a re-listed property keeps its
  -- original publication date instead of jumping to the top of the feed.
  -- The status-history, visibility-sync and audit triggers all fire from here.
  UPDATE public.listings SET status = p_status WHERE id = p_listing_id;

  RETURN p_status;
END;
$function$;
