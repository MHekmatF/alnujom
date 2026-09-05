-- Throttle chat and posting.
--
-- Review 2026-09-05 §4 G4 (plan A28). `20260904120002` capped the three
-- endpoints a stranger can call; the two a *signed-in* user can flood were
-- left open: `messages` (a plain INSERT under an RLS membership check, and
-- every row fires a push to the other party) and `submit_listing` / draft
-- creation (rows, moderation-queue noise, and an approval fan-out per
-- listing). Supabase rate-limits Auth, not PostgREST.
--
-- Same shape as before: runaway-script guards keyed on things that are real
-- (`auth.uid()`, the conversation, the listing owner), never on the loopback
-- address PostgREST presents. The numbers are set well above anything a
-- person does and well below what a script needs:
--
--   messages          60 per conversation per hour, 120 per sender per hour
--   listing drafts    20 created per publisher per hour
--   submissions       10 per publisher per hour, 30 per publisher per day
--
-- All four raise `rate_limited` / 23514, the code the app already maps to a
-- generic "try again later". Each count runs against an existing index
-- (messages(conversation_id, created_at); listings(publisher_user_id, …);
-- listing_status_history(listing_id)), so the cost is a handful of index
-- probes per write.

-- ---------------------------------------------------------------------------
-- messages — BEFORE INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.messages_rate_guard_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_recent integer;
BEGIN
  -- The sender is whoever the row says, and RLS has already tied that to the
  -- caller; a definer function may still count across the table.
  SELECT count(*) INTO v_recent
    FROM public.messages m
   WHERE m.conversation_id = NEW.conversation_id
     AND m.created_at > now() - interval '1 hour';
  IF v_recent >= 60 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  SELECT count(*) INTO v_recent
    FROM public.messages m
   WHERE m.sender_user_id = NEW.sender_user_id
     AND m.created_at > now() - interval '1 hour';
  IF v_recent >= 120 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.messages_rate_guard_fn() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_messages_rate_guard ON public.messages;
CREATE TRIGGER trg_messages_rate_guard
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_rate_guard_fn();

-- The per-sender count needs an index the table did not have: only
-- (conversation_id, …) existed. sender_user_id is also an unindexed FK on the
-- performance advisor's list.
CREATE INDEX IF NOT EXISTS idx_messages_sender_created
  ON public.messages (sender_user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- listings — BEFORE INSERT (drafts are created by direct INSERT under RLS)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.listings_rate_guard_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_recent integer;
BEGIN
  SELECT count(*) INTO v_recent
    FROM public.listings l
   WHERE l.publisher_user_id = NEW.publisher_user_id
     AND l.created_at > now() - interval '1 hour';
  IF v_recent >= 20 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.listings_rate_guard_fn() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_listings_rate_guard ON public.listings;
CREATE TRIGGER trg_listings_rate_guard
  BEFORE INSERT ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listings_rate_guard_fn();

-- ---------------------------------------------------------------------------
-- submit_listing — a guard at the top; the body is unchanged from
-- 20260531120009 (agency check) as read live on 2026-09-05
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_listing       public.listings;
  v_profile_ok    BOOLEAN;
  v_price_count   INT;
  v_image_count   INT;
  v_missing       TEXT[] := ARRAY[]::TEXT[];
  v_residential   BOOLEAN;
  v_recent        INT;
BEGIN
  SELECT * INTO v_listing FROM public.listings WHERE id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'listing not found';
  END IF;

  IF v_listing.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  SELECT (publisher_status = 'approved' AND account_status = 'approved') INTO v_profile_ok
    FROM public.profiles WHERE user_id = auth.uid();
  IF NOT COALESCE(v_profile_ok, false) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'publisher not approved';
  END IF;

  IF v_listing.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'listing not in editable status';
  END IF;

  -- A28: submissions per publisher, counted from the status history (every
  -- submit writes a pending_review row there).
  SELECT count(*) INTO v_recent
    FROM public.listing_status_history h
    JOIN public.listings l ON l.id = h.listing_id
   WHERE l.publisher_user_id = auth.uid()
     AND h.new_status = 'pending_review'
     AND h.changed_at > now() - interval '1 hour';
  IF v_recent >= 10 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;
  SELECT count(*) INTO v_recent
    FROM public.listing_status_history h
    JOIN public.listings l ON l.id = h.listing_id
   WHERE l.publisher_user_id = auth.uid()
     AND h.new_status = 'pending_review'
     AND h.changed_at > now() - interval '1 day';
  IF v_recent >= 30 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  IF length(trim(coalesce(v_listing.title, ''))) = 0          THEN v_missing := array_append(v_missing, 'listings.title');             END IF;
  IF v_listing.purpose IS NULL                                THEN v_missing := array_append(v_missing, 'listings.purpose');           END IF;
  IF v_listing.property_type IS NULL                          THEN v_missing := array_append(v_missing, 'listings.property_type');     END IF;
  IF v_listing.governorate_id IS NULL                         THEN v_missing := array_append(v_missing, 'listings.governorate_id');    END IF;
  IF v_listing.city_id IS NULL                                THEN v_missing := array_append(v_missing, 'listings.city_id');           END IF;
  IF v_listing.area_id IS NULL                                THEN v_missing := array_append(v_missing, 'listings.area_id');           END IF;
  IF length(trim(coalesce(v_listing.address_text, ''))) = 0   THEN v_missing := array_append(v_missing, 'listings.address_text');      END IF;
  IF v_listing.area_size IS NULL OR v_listing.area_size <= 0  THEN v_missing := array_append(v_missing, 'listings.area_size');         END IF;
  IF length(trim(coalesce(v_listing.phone, ''))) = 0
     AND length(trim(coalesce(v_listing.whatsapp, ''))) = 0   THEN v_missing := array_append(v_missing, 'listings.phone_or_whatsapp'); END IF;

  v_residential := v_listing.property_type IN ('apartment', 'villa');
  IF v_residential THEN
    IF v_listing.rooms IS NULL OR v_listing.rooms < 0          THEN v_missing := array_append(v_missing, 'listings.rooms');             END IF;
    IF v_listing.bathrooms IS NULL OR v_listing.bathrooms < 0  THEN v_missing := array_append(v_missing, 'listings.bathrooms');         END IF;
  END IF;

  SELECT count(*) INTO v_price_count
    FROM public.listing_prices WHERE listing_id = p_listing_id AND is_primary = true AND amount > 0;
  IF v_price_count <> 1 THEN
    v_missing := array_append(v_missing, 'listing_prices.primary');
  END IF;

  SELECT count(*) INTO v_image_count
    FROM public.listing_media
    WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true;
  IF v_image_count = 0 THEN
    v_missing := array_append(v_missing, 'listing_media.images_below_minimum');
  END IF;

  IF array_length(v_missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'missing required fields',
      DETAIL  = jsonb_build_object('missing_fields', to_jsonb(v_missing))::text;
  END IF;

  -- PHASE 19 (FR-020 / R-143): agency-membership soft gate.
  IF v_listing.agency_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.agency_members m
      JOIN public.agencies a ON a.id = m.agency_id
      WHERE m.agency_id = v_listing.agency_id
        AND m.user_id   = auth.uid()
        AND m.status    = 'active'
        AND a.status IN ('pending','approved')
    ) THEN
      RAISE EXCEPTION 'not_an_agency_member' USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.listings SET status = 'pending_review' WHERE id = p_listing_id;

  RETURN jsonb_build_object(
    'listing_id',  p_listing_id,
    'status',      'pending_review',
    'submitted_at', now()
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
