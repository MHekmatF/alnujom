-- Tell people when a message arrives or a viewing moves.
--
-- Until now the notifications table carried six types, all of them about
-- moderation: account and listing decisions, a new inquiry, an agency
-- invitation. Nothing fired for the two things that actually need a person to
-- come back to the app.
--
--   * `bump_conversation_last_message` only updated a timestamp, so a buyer's
--     message reached the publisher only if the publisher happened to open the
--     Messages tab.
--   * `request_viewing` and `update_viewing_status` enqueued nothing at all: a
--     viewing request was invisible until someone opened the Viewings screen,
--     and the requester was never told it had been confirmed or declined.
--
-- (Review 2026-09-04, M4.) The types themselves were added to the CHECK in
-- `20260904120001`; `viewing_cancelled` is added here because a cancellation
-- leaves the other party with a dead appointment in their calendar, which is
-- the same gap pointing the other way.

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type = ANY (ARRAY[
      'account_approved'::text,
      'account_rejected'::text,
      'listing_approved'::text,
      'listing_rejected'::text,
      'inquiry_received'::text,
      'agency_invitation'::text,
      'saved_search_match'::text,
      'message_received'::text,
      'viewing_requested'::text,
      'viewing_confirmed'::text,
      'viewing_declined'::text,
      'viewing_cancelled'::text,
      'listing_expiring'::text
    ])
  );

-- ---------------------------------------------------------------------------
-- 1. A new chat message
-- ---------------------------------------------------------------------------
-- Debounced on purpose. A conversation is a burst of short messages, and one
-- push per message would be unusable — the phone would buzz five times while
-- someone types five lines. So: notify once, then stay quiet until the
-- recipient has actually read it, or ten minutes pass. That is the same shape
-- every chat app uses, and it means the row count tracks *conversations needing
-- attention* rather than message volume.
--
-- The recipient is derived from the conversation, never from the payload, so a
-- hand-crafted insert cannot address someone else's notification.
CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_buyer       uuid;
  v_publisher   uuid;
  v_listing     uuid;
  v_recipient   uuid;
BEGIN
  SELECT c.buyer_user_id, c.publisher_user_id, c.listing_id
    INTO v_buyer, v_publisher, v_listing
    FROM public.conversations c
    WHERE c.id = NEW.conversation_id;

  IF v_buyer IS NULL THEN
    RETURN NEW;  -- conversation vanished mid-insert; nothing to address
  END IF;

  v_recipient := CASE WHEN NEW.sender_user_id = v_buyer THEN v_publisher
                      ELSE v_buyer END;

  IF v_recipient IS NULL OR v_recipient = NEW.sender_user_id THEN
    RETURN NEW;
  END IF;

  -- Already told, and they have not looked yet.
  IF EXISTS (
    SELECT 1 FROM public.notifications n
    WHERE n.recipient_user_id = v_recipient
      AND n.type = 'message_received'
      AND n.read_at IS NULL
      AND n.params->>'conversation_id' = NEW.conversation_id::text
      AND n.created_at > now() - interval '10 minutes'
  ) THEN
    RETURN NEW;
  END IF;

  -- UUIDs only — the message body never leaves the table (FR-004: no free text
  -- in a notification payload, because it ends up in the OS tray).
  PERFORM public.enqueue_notification(
    v_recipient,
    'message_received',
    jsonb_build_object(
      'conversation_id', NEW.conversation_id,
      'listing_id', v_listing
    )
  );
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_messages_notify_recipient ON public.messages;
CREATE TRIGGER trg_messages_notify_recipient
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

-- ---------------------------------------------------------------------------
-- 2. A viewing was requested
-- ---------------------------------------------------------------------------
-- Unchanged except the final PERFORM.
CREATE OR REPLACE FUNCTION public.request_viewing(p_listing_id uuid, p_scheduled_at timestamp with time zone, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_publisher uuid; v_buyer uuid := auth.uid(); v_id uuid;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'authentication required' USING errcode = '42501'; END IF;
  SELECT publisher_user_id INTO v_publisher FROM public.listings WHERE id = p_listing_id;
  IF v_publisher IS NULL THEN RAISE EXCEPTION 'listing not found' USING errcode = 'P0002'; END IF;
  IF v_publisher = v_buyer THEN RAISE EXCEPTION 'cannot request a viewing on your own listing' USING errcode = '22023'; END IF;
  INSERT INTO public.viewings (listing_id, requester_user_id, publisher_user_id, scheduled_at, note)
  VALUES (p_listing_id, v_buyer, v_publisher, p_scheduled_at, p_note)
  RETURNING id INTO v_id;

  PERFORM public.enqueue_notification(
    v_publisher, 'viewing_requested',
    jsonb_build_object('viewing_id', v_id, 'listing_id', p_listing_id));

  RETURN v_id;
END; $function$;

-- ---------------------------------------------------------------------------
-- 3. A viewing was confirmed, declined or cancelled
-- ---------------------------------------------------------------------------
-- The recipient is always "the other one": confirm and decline are the
-- publisher's to make, so they reach the requester; cancel can come from either
-- side, so it reaches whoever did not press it.
CREATE OR REPLACE FUNCTION public.update_viewing_status(p_viewing_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v public.viewings%ROWTYPE;
  v_uid uuid := auth.uid();
  v_recipient uuid;
BEGIN
  SELECT * INTO v FROM public.viewings WHERE id = p_viewing_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'viewing not found' USING errcode = 'P0002'; END IF;
  IF v_uid NOT IN (v.requester_user_id, v.publisher_user_id) THEN
    RAISE EXCEPTION 'not authorized' USING errcode = '42501'; END IF;
  IF p_status NOT IN ('confirmed','declined','cancelled') THEN
    RAISE EXCEPTION 'invalid status' USING errcode = '22023'; END IF;
  IF p_status IN ('confirmed','declined') AND v_uid <> v.publisher_user_id THEN
    RAISE EXCEPTION 'only the publisher can confirm or decline' USING errcode = '42501'; END IF;

  UPDATE public.viewings SET status = p_status WHERE id = p_viewing_id;

  v_recipient := CASE WHEN v_uid = v.requester_user_id THEN v.publisher_user_id
                      ELSE v.requester_user_id END;

  PERFORM public.enqueue_notification(
    v_recipient,
    'viewing_' || p_status,
    jsonb_build_object('viewing_id', p_viewing_id, 'listing_id', v.listing_id));
END; $function$;
