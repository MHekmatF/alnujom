-- Give a publisher a way to close their own listing.
--
-- Until now the only things a publisher could do to an APPROVED listing were
-- edit it (as a stay-live revision), renew it, or wait for it to expire. The
-- statuses `sold`, `rented` and `paused` existed in the schema and rendered
-- everywhere — status chips, filter tabs, moderation history — but **nothing
-- could ever set them**: no RPC, no UI, and `listings_update_owner` only allows
-- a direct UPDATE while the status is `draft` or `rejected`. The one path to
-- `paused` was an admin resolving a report. "Sold" is the most common thing a
-- publisher does after posting. (Review 2026-09-04, M1.)
--
-- Deleting had the mirror problem: `listings` has exactly one DELETE policy,
-- gated on `listings.delete_any`, so an ordinary publisher could delete nothing
-- at all. Both drafts in production belong to staff who hold that permission,
-- which is why it had never been noticed. (M2.)
--
-- This RPC is the owner's side of both, and it is a SOFT delete — `deleted` is
-- the same terminal status `request_account_deletion` uses, so the row and its
-- media survive for the purge job and for the audit trail.

-- ---------------------------------------------------------------------------
-- 1. Let a re-publish stay quiet
-- ---------------------------------------------------------------------------
-- `trg_listings_saved_search_alert` fires AFTER UPDATE and notifies every
-- matching saved search whenever a listing becomes `approved` from something
-- else. Un-pausing is exactly that shape, so without a guard a publisher could
-- pause and un-pause on a loop and blast everyone with a matching saved search
-- each time.
--
-- A saved-search alert should mean "a listing appeared that matches you", not
-- "one you were already told about came back". The transaction-local GUC below
-- lets `set_own_listing_status` say so. Nothing else sets it, and it is
-- `set_config(..., true)` — transaction-scoped, so it cannot leak into the next
-- statement on a pooled connection.
CREATE OR REPLACE FUNCTION public.notify_saved_search_matches()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  rec record;
BEGIN
  -- Set by set_own_listing_status() when the publisher un-pauses their own
  -- listing: it is re-appearing, not appearing, so nobody is alerted again.
  IF coalesce(current_setting('app.skip_saved_search_alert', true), '') = '1' THEN
    RETURN NEW;
  END IF;

  -- Only fire when the listing is (newly) publicly visible.
  IF NOT (NEW.status = 'approved'
          AND (NEW.published_at IS NULL OR NEW.published_at <= now())
          AND (NEW.expires_at IS NULL OR NEW.expires_at > now())) THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM 'approved' THEN
    RETURN NEW;  -- already approved before; not a new appearance
  END IF;

  FOR rec IN
    SELECT s.id, s.user_id, s.label, s.filters
    FROM public.saved_searches s
    WHERE s.user_id <> NEW.publisher_user_id
      AND (s.filters->>'purpose' IS NULL OR s.filters->>'purpose' = NEW.purpose)
      AND (s.filters->>'property_type' IS NULL OR s.filters->>'property_type' = NEW.property_type)
      AND (s.filters->>'governorate_id' IS NULL OR s.filters->>'governorate_id' = NEW.governorate_id::text)
      AND (s.filters->>'city_id' IS NULL OR s.filters->>'city_id' = NEW.city_id::text)
      AND (s.filters->>'area_id' IS NULL OR s.filters->>'area_id' = NEW.area_id::text)
      AND (s.filters->>'rooms' IS NULL OR (NEW.rooms IS NOT NULL AND
           CASE WHEN s.filters->>'rooms_mode' = 'atLeast'
                THEN NEW.rooms >= (s.filters->>'rooms')::int
                ELSE NEW.rooms = (s.filters->>'rooms')::int END))
      AND (s.filters->>'bathrooms' IS NULL OR (NEW.bathrooms IS NOT NULL AND
           CASE WHEN s.filters->>'bathrooms_mode' = 'atLeast'
                THEN NEW.bathrooms >= (s.filters->>'bathrooms')::int
                ELSE NEW.bathrooms = (s.filters->>'bathrooms')::int END))
      AND (s.filters->>'area_size_min' IS NULL OR (NEW.area_size IS NOT NULL AND NEW.area_size >= (s.filters->>'area_size_min')::numeric))
      AND (s.filters->>'area_size_max' IS NULL OR (NEW.area_size IS NOT NULL AND NEW.area_size <= (s.filters->>'area_size_max')::numeric))
  LOOP
    INSERT INTO public.notifications (recipient_user_id, type, params)
    VALUES (rec.user_id, 'saved_search_match', jsonb_build_object(
      'listing_id', NEW.id,
      'listing_title', NEW.title,
      'saved_search_id', rec.id,
      'saved_search_label', rec.label
    ));
  END LOOP;
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. The owner's status RPC
-- ---------------------------------------------------------------------------
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
  --   * anything -> approved except from `paused`. Re-publishing something that
  --     was never approved would skip moderation entirely.
  --   * anything -> draft / pending_review. Editing is the revision flow's job.
  IF NOT (
       (v_current = 'approved' AND p_status IN ('sold', 'rented', 'paused'))
    OR (v_current = 'paused'   AND p_status = 'approved')
    OR (v_current IN ('draft', 'rejected', 'expired', 'sold', 'rented')
        AND p_status = 'deleted')
  ) THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '22023';
  END IF;

  -- Re-publishing is a return, not an arrival — see the trigger above.
  IF v_current = 'paused' AND p_status = 'approved' THEN
    PERFORM set_config('app.skip_saved_search_alert', '1', true);
  END IF;

  -- `published_at` is deliberately untouched: a re-published listing keeps its
  -- original publication date, so it does not jump to the top of the feed.
  -- The status-history, visibility-sync and audit triggers all fire from here.
  UPDATE public.listings SET status = p_status WHERE id = p_listing_id;

  RETURN p_status;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_own_listing_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_own_listing_status(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.set_own_listing_status(uuid, text) IS
  'Owner-only listing lifecycle: approved->sold/rented/paused, paused->approved, dead statuses->deleted (soft). Added 2026-09-04 (plan A15).';

-- ---------------------------------------------------------------------------
-- 3. A deleted listing should stop being counted
-- ---------------------------------------------------------------------------
-- `total_listings` counted every row, so a publisher who deleted one would keep
-- seeing it in the tile. The client filters `deleted` out of the My Listings
-- query in the same change.
CREATE OR REPLACE FUNCTION public.publisher_dashboard_counts()
 RETURNS TABLE(total_listings bigint, active_listings bigint, pending_listings bigint, rejected_listings bigint, total_inquiries bigint, new_inquiries bigint, lead_events_total bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status <> 'deleted'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'approved'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'pending_review'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'rejected'),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid()),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid() and i.status = 'new'),
    (select count(*) from lead_events e join listings l on l.id = e.listing_id where l.publisher_user_id = auth.uid());
$function$;
