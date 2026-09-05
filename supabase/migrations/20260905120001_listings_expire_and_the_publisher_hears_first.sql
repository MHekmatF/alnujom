-- Listings expire, and the publisher hears first.
--
-- Review 2026-09-05 (docs/ops/REVIEW_2026-09-05.md §2.2, §2.3, §4 G5; plan A26).
--
-- Every public read policy has always hidden a listing once `expires_at` is in
-- the past — but NOTHING EVER WROTE `expires_at`. Not `submit_listing`, not
-- `approve_listing_internal`, not the relist path; only `renew_listing`
-- extended it, and only the deletion path set it (to `now()`). So:
--
--   * the sixteen demo listings all carry a hand-set `2026-10-06` and go dark
--     together on that date, and
--   * every listing approved after them carries NULL, which every policy reads
--     as "never expires". A year in, the feed is old sold flats with no
--     freshness signal, and review §1 M5's "no expiry reminder" had nothing to
--     remind about.
--
-- What this migration does, in one pass:
--
--   1. The validity period is an app setting (`listing_validity_days`, 60 by
--      default, clamped 7–365) so the owner changes it from the admin screen,
--      not from a migration. `listing_validity_days()` reads it safely.
--   2. First approval stamps `expires_at = now() + validity`. Re-listing a
--      paused / sold / rented listing whose validity has lapsed stamps a fresh
--      one; one still in date keeps it. `renew_listing` defaults to the
--      setting, is limited to `approved` and `expired`, and turns an `expired`
--      listing back into `approved` (with the saved-search re-alert suppressed,
--      exactly as the relist path does — this is a return, not an arrival).
--   3. `sweep_listing_expiry()` — run hourly by the scheduler (plan A32) —
--      warns the publisher three days out with a `listing_expiring`
--      notification (once per expiry date, so a renewal earns a fresh warning
--      later), and flips listings past their date to `status = 'expired'` with
--      a `listing_expired` notification. `expired` was already in the status
--      CHECK, already rendered by the app, already allowed to go to `deleted`,
--      and already the renew RPC's job — it just never happened.
--
-- The read-time hiding is untouched, so a listing that passes its date between
-- two sweeps is hidden immediately and merely relabelled on the next run.
--
-- Nothing here touches the demo rows: they keep their 2026-10-06 and the sweep
-- will retire them on that date unless B7 replaces them or the owner renews.

-- ---------------------------------------------------------------------------
-- 1. The validity period, as a setting
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value, description, is_public) VALUES
  ('listing_validity_days', '60'::jsonb,
   'Days a listing stays public after approval or renewal (7–365). The publisher is warned 3 days before it lapses and can renew.',
   true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.listing_validity_days()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT LEAST(365, GREATEST(7, COALESCE(
    (SELECT CASE WHEN (value #>> '{}') ~ '^[0-9]{1,3}$' THEN (value #>> '{}')::int END
       FROM public.app_settings
      WHERE key = 'listing_validity_days'),
    60)));
$$;

REVOKE ALL ON FUNCTION public.listing_validity_days() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.listing_validity_days() IS
  'The listing_validity_days app setting, clamped to 7–365 and defaulting to 60. Read by the approval, relist, renew and expiry-sweep functions; not callable by clients (the setting itself is public and readable directly).';

-- ---------------------------------------------------------------------------
-- 2a. First approval stamps the validity
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_listing_internal(p_listing_id uuid, p_actor_user_id uuid)
 RETURNS TABLE(id uuid, status text, published_at timestamp with time zone, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows BIGINT;
  v_publisher UUID;
BEGIN
  -- 1. Set the FR-024 session variable LOCAL to this transaction.
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  -- 2. Status-guarded UPDATE in the SAME transaction. Triggers fire here and read the GUC.
  --    A26: the approval is what starts the clock.
  RETURN QUERY
  UPDATE public.listings AS l
     SET status = 'approved',
         published_at = now(),
         expires_at = now() + make_interval(days => public.listing_validity_days())
   WHERE l.id = p_listing_id
     AND l.status = 'pending_review'
  RETURNING l.id, l.status, l.published_at, l.expires_at;

  -- 3. Phase 22 fan-out: only when the transition actually occurred (exactly-once — FR-003).
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    SELECT l.publisher_user_id INTO v_publisher FROM public.listings l WHERE l.id = p_listing_id;
    PERFORM public.enqueue_notification(
      v_publisher, 'listing_approved', jsonb_build_object('listing_id', p_listing_id));
  END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2b. Re-listing stamps a fresh validity only when the old one has lapsed
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
  -- A26: a return whose validity has lapsed (or never had one) gets a fresh
  -- period; one still in date keeps what it had.
  -- The status-history, visibility-sync and audit triggers all fire from here.
  UPDATE public.listings
     SET status = p_status,
         expires_at = CASE
           WHEN p_status = 'approved' AND (expires_at IS NULL OR expires_at < now())
             THEN now() + make_interval(days => public.listing_validity_days())
           ELSE expires_at
         END
   WHERE id = p_listing_id;

  RETURN p_status;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2c. Renew: defaults to the setting, limited to approved / expired, and
--     brings an expired listing back
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.renew_listing(p_listing_id uuid, p_days integer DEFAULT NULL)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_owner  uuid;
  v_status text;
  v_new    timestamptz;
BEGIN
  SELECT publisher_user_id, status INTO v_owner, v_status
    FROM public.listings WHERE id = p_listing_id;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'listing not found' USING errcode = 'P0002';
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not authorized to renew this listing' USING errcode = '42501';
  END IF;
  -- Only a live or lapsed approval can be extended. Anything else (draft,
  -- pending, rejected, sold, paused, deleted) has its own path.
  IF v_status NOT IN ('approved', 'expired') THEN
    RAISE EXCEPTION 'invalid_transition' USING errcode = '22023';
  END IF;

  IF p_days IS NULL OR p_days <= 0 THEN
    p_days := public.listing_validity_days();
  END IF;
  p_days := LEAST(p_days, 365);

  v_new := greatest(
    now(),
    coalesce((SELECT expires_at FROM public.listings WHERE id = p_listing_id), now())
  ) + make_interval(days => p_days);

  IF v_status = 'expired' THEN
    -- A return, not an arrival: subscribers were alerted at first approval.
    PERFORM set_config('app.skip_saved_search_alert', '1', true);
    UPDATE public.listings SET expires_at = v_new, status = 'approved' WHERE id = p_listing_id;
  ELSE
    UPDATE public.listings SET expires_at = v_new WHERE id = p_listing_id;
  END IF;
  RETURN v_new;
END;
$function$;

-- The old signature had DEFAULT 30; same arity and types, so this is a true
-- replace and PostgREST sees exactly one `renew_listing`.
REVOKE ALL ON FUNCTION public.renew_listing(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_listing(uuid, integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3a. The second notification type this needs
-- ---------------------------------------------------------------------------
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY[
  'account_approved', 'account_rejected',
  'listing_approved', 'listing_rejected',
  'inquiry_received', 'agency_invitation',
  'saved_search_match',
  'message_received',
  'viewing_requested', 'viewing_confirmed', 'viewing_declined', 'viewing_cancelled',
  'listing_expiring', 'listing_expired'
]));

-- ---------------------------------------------------------------------------
-- 3b. The sweep
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sweep_listing_expiry(p_warn_before interval DEFAULT interval '3 days')
RETURNS TABLE(warned integer, expired integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_warned  integer := 0;
  v_expired integer := 0;
  r record;
BEGIN
  IF p_warn_before IS NULL OR p_warn_before < interval '1 hour' OR p_warn_before > interval '30 days' THEN
    RAISE EXCEPTION 'warn window must be between 1 hour and 30 days, got %', p_warn_before
      USING ERRCODE = '22023';
  END IF;

  -- The sweep is the system, not a person: no app.current_user_id, so the
  -- status-history and audit rows record a NULL actor, as they do for any
  -- server-side change. Nothing here ever moves a row TO approved, but the
  -- suppression costs nothing and keeps a future edit from alerting by accident.
  PERFORM set_config('app.skip_saved_search_alert', '1', true);

  -- Warn once per expiry date. A renewal changes the date, so it earns a fresh
  -- warning when its own three days come round.
  FOR r IN
    SELECT l.id, l.publisher_user_id, l.title, l.expires_at
      FROM public.listings l
     WHERE l.status = 'approved'
       AND l.expires_at IS NOT NULL
       AND l.expires_at >  now()
       AND l.expires_at <= now() + p_warn_before
       AND NOT EXISTS (
             SELECT 1 FROM public.notifications n
              WHERE n.type = 'listing_expiring'
                AND n.recipient_user_id = l.publisher_user_id
                AND n.params->>'listing_id' = l.id::text
                AND (n.params->>'expires_at')::timestamptz = l.expires_at)
  LOOP
    PERFORM public.enqueue_notification(
      r.publisher_user_id, 'listing_expiring',
      jsonb_build_object('listing_id', r.id, 'listing_title', r.title, 'expires_at', r.expires_at));
    v_warned := v_warned + 1;
  END LOOP;

  -- Retire what has lapsed. The read policies already hide these; this makes
  -- the state visible to the publisher (status chip + Renew) and tells them.
  FOR r IN
    SELECT l.id, l.publisher_user_id, l.title
      FROM public.listings l
     WHERE l.status = 'approved'
       AND l.expires_at IS NOT NULL
       AND l.expires_at <= now()
  LOOP
    UPDATE public.listings SET status = 'expired' WHERE public.listings.id = r.id;
    PERFORM public.enqueue_notification(
      r.publisher_user_id, 'listing_expired',
      jsonb_build_object('listing_id', r.id, 'listing_title', r.title));
    v_expired := v_expired + 1;
  END LOOP;

  warned  := v_warned;
  expired := v_expired;
  RETURN NEXT;
END;
$function$;

REVOKE ALL ON FUNCTION public.sweep_listing_expiry(interval) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.sweep_listing_expiry(interval) IS
  'Hourly housekeeping (plan A32): warns publishers 3 days before a listing lapses (listing_expiring, once per expiry date) and flips lapsed approved listings to expired (listing_expired). Not callable by clients.';

NOTIFY pgrst, 'reload schema';
