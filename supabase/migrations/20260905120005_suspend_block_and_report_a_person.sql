-- Suspend, block, and report a person.
--
-- Review 2026-09-05 §4 G2 + G3 (plan A29). The only thing the schema knew how
-- to moderate was a listing: `reports.listing_id` was NOT NULL,
-- `moderation_actions.target_type` allowed only `'listing'`, and the one
-- "suspend" that existed was for agencies. A buyer harassed over chat had no
-- lever, and once a person was past the approval queue the only remedy was a
-- hand-written UPDATE — which the `enforce_profile_status_admin_only` trigger
-- would then refuse for anyone but an `admin` / `super_admin` role holder,
-- `users.suspend` permission or not.
--
-- Three things, all server-side, all callable from the app:
--
--   BLOCK      `user_blocks` (RLS on, no policies, no grants — reached only
--              through the definer RPCs `block_user`, `unblock_user`,
--              `list_my_blocks`, `is_user_blocked_by_me`). A block in either
--              direction closes every door between the two people: the
--              `messages` insert policy, `get_or_create_conversation`,
--              `request_viewing` and `submit_inquiry` all check
--              `is_blocked_between()`, which only answers for a pair the caller
--              belongs to, so it is not an oracle about strangers.
--
--   REPORT     `reports` gains `target_user_id`, exactly one of listing / user
--              (CHECK), three person-shaped reasons (harassment, scam,
--              impersonation), one open report per reporter+person, and
--              `submit_user_report()`. `v_reports` LEFT JOINs the listing now
--              and appends `target_user_id`, `target_user_name`, so the admin
--              queue and My Reports render both kinds.
--
--   SUSPEND    `moderate_user(p_user, 'suspend' | 'reinstate', reason)`,
--              gated on `users.suspend` — the strongest account right there
--              is. Suspend sets both statuses to `suspended`, pauses the
--              person's approved listings (they relist themselves after a
--              reinstate), ends their sessions so the app signs them out at
--              the next refresh, writes one `moderation_actions` row, and
--              tells them (`account_suspended`). Reinstate sets both to
--              `approved` and tells them. The admin queue reaches it through
--              `resolve_report_internal(…, 'suspend_user')`, on a report about
--              a person OR about a listing (its publisher). The profile-status
--              trigger learns to let the moderation path through, the way it
--              already lets self-deletion through.
--
-- Nothing here deletes a row. Every change is a status, a block row, or a
-- report row, and every one is proven in a rolled-back transaction in the PR.

-- ---------------------------------------------------------------------------
-- 1. Blocks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  CONSTRAINT user_blocks_not_self CHECK (blocker_user_id <> blocked_user_id)
);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks (blocked_user_id);
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_blocks FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.user_blocks IS
  'A person the blocker does not want to hear from. No client grants and no policies on purpose: every read and write goes through the definer RPCs block_user / unblock_user / list_my_blocks / is_user_blocked_by_me (plan A29).';

CREATE OR REPLACE FUNCTION public.is_blocked_between(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  -- Answers only for a pair the caller belongs to; a stranger asking about two
  -- other people always gets false.
  SELECT auth.uid() IS NOT NULL
     AND auth.uid() IN (p_a, p_b)
     AND EXISTS (
       SELECT 1 FROM public.user_blocks b
        WHERE (b.blocker_user_id = p_a AND b.blocked_user_id = p_b)
           OR (b.blocker_user_id = p_b AND b.blocked_user_id = p_a));
$$;
REVOKE ALL ON FUNCTION public.is_blocked_between(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_blocked_between(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.block_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot_block_self' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = p_user_id) THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '23503';
  END IF;
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  VALUES (auth.uid(), p_user_id)
  ON CONFLICT DO NOTHING;
  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.user_blocks
   WHERE blocker_user_id = auth.uid() AND blocked_user_id = p_user_id;
  RETURN FOUND;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_user_blocked_by_me(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks b
     WHERE b.blocker_user_id = auth.uid() AND b.blocked_user_id = p_user_id);
$$;

CREATE OR REPLACE FUNCTION public.list_my_blocks()
RETURNS TABLE(user_id uuid, full_name text, blocked_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT b.blocked_user_id, p.full_name, b.created_at
    FROM public.user_blocks b
    LEFT JOIN public.profiles p ON p.user_id = b.blocked_user_id
   WHERE b.blocker_user_id = auth.uid()
   ORDER BY b.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_user_blocked_by_me(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_my_blocks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_blocked_by_me(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_blocks() TO authenticated;

-- Every door between two people checks the block.
DROP POLICY IF EXISTS messages_insert_member ON public.messages;
CREATE POLICY messages_insert_member ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversations c
       WHERE c.id = messages.conversation_id
         AND ((SELECT auth.uid()) = c.buyer_user_id OR (SELECT auth.uid()) = c.publisher_user_id)
         AND NOT public.is_blocked_between(c.buyer_user_id, c.publisher_user_id)));

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_listing_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_publisher uuid;
  v_buyer uuid := auth.uid();
  v_conv uuid;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'authentication required' USING errcode = '42501'; END IF;
  SELECT publisher_user_id INTO v_publisher FROM public.listings WHERE id = p_listing_id;
  IF v_publisher IS NULL THEN RAISE EXCEPTION 'listing not found' USING errcode = 'P0002'; END IF;
  IF v_publisher = v_buyer THEN RAISE EXCEPTION 'cannot message your own listing' USING errcode = '22023'; END IF;
  -- A29: a block in either direction closes this door.
  IF public.is_blocked_between(v_buyer, v_publisher) THEN
    RAISE EXCEPTION 'user_blocked' USING errcode = '42501';
  END IF;
  INSERT INTO public.conversations (listing_id, buyer_user_id, publisher_user_id)
  VALUES (p_listing_id, v_buyer, v_publisher)
  ON CONFLICT (listing_id, buyer_user_id) DO UPDATE SET listing_id = EXCLUDED.listing_id
  RETURNING id INTO v_conv;
  RETURN v_conv;
END; $function$;

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
  -- A29: a block in either direction closes this door.
  IF public.is_blocked_between(v_buyer, v_publisher) THEN
    RAISE EXCEPTION 'user_blocked' USING errcode = '42501';
  END IF;
  INSERT INTO public.viewings (listing_id, requester_user_id, publisher_user_id, scheduled_at, note)
  VALUES (p_listing_id, v_buyer, v_publisher, p_scheduled_at, p_note)
  RETURNING id INTO v_id;

  PERFORM public.enqueue_notification(
    v_publisher, 'viewing_requested',
    jsonb_build_object('viewing_id', v_id, 'listing_id', p_listing_id));

  RETURN v_id;
END; $function$;

-- submit_inquiry: the 2026-09-04 body (throttle + fingerprint) plus the block check.
CREATE OR REPLACE FUNCTION public.submit_inquiry(p_listing_id uuid, p_sender_name text, p_inquirer_phone text, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'vault'
AS $function$
DECLARE
  v_listing_status       TEXT;
  v_publisher_user_id    UUID;
  v_inquiry_id           UUID;
  v_phone_normalized     TEXT;
  v_key_id               UUID;
  v_encrypted            BYTEA;
  v_ip                   INET;
  v_user_agent           TEXT;
  v_client               TEXT;
  v_recent               INT;
BEGIN
  IF p_sender_name IS NULL OR length(trim(p_sender_name)) < 1 OR length(trim(p_sender_name)) > 100 THEN
    RAISE EXCEPTION 'invalid_sender_name' USING ERRCODE = '23514';
  END IF;

  IF p_inquirer_phone IS NULL OR p_inquirer_phone !~ '^\+[1-9]\d{6,14}$' THEN
    RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '23514';
  END IF;
  v_phone_normalized := p_inquirer_phone;

  IF p_message IS NULL OR length(trim(p_message)) < 1 OR length(trim(p_message)) > 2000 THEN
    RAISE EXCEPTION 'invalid_message_length' USING ERRCODE = '23514';
  END IF;

  SELECT l.status, l.publisher_user_id
    INTO v_listing_status, v_publisher_user_id
    FROM public.listings l
    WHERE l.id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_listing_status <> 'approved' THEN
    RAISE EXCEPTION 'listing_not_approved' USING ERRCODE = '23514';
  END IF;
  IF auth.uid() IS NOT NULL AND v_publisher_user_id = auth.uid() THEN
    RAISE EXCEPTION 'self_contact_blocked' USING ERRCODE = '23514';
  END IF;
  -- A29: a signed-in sender who is blocked by (or has blocked) the publisher.
  IF auth.uid() IS NOT NULL AND public.is_blocked_between(auth.uid(), v_publisher_user_id) THEN
    RAISE EXCEPTION 'user_blocked' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_recent
    FROM public.inquiries i
    WHERE i.listing_id = p_listing_id
      AND i.created_at > now() - interval '1 hour';
  IF v_recent >= 20 THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT count(*) INTO v_recent
      FROM public.inquiries i
      WHERE i.sender_user_id = auth.uid()
        AND i.created_at > now() - interval '1 hour';
    IF v_recent >= 10 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = '23514';
    END IF;
  END IF;

  SELECT decrypted_secret::uuid INTO v_key_id
    FROM vault.decrypted_secrets
    WHERE name = 'app-inquirer-phone-key';

  IF v_key_id IS NULL THEN
    RAISE EXCEPTION 'vault_key_missing' USING ERRCODE = 'P0001';
  END IF;

  v_inquiry_id := gen_random_uuid();
  v_encrypted := pgsodium.crypto_aead_det_encrypt(
    convert_to(v_phone_normalized, 'utf8'),
    convert_to(v_inquiry_id::text, 'utf8'),
    v_key_id,
    pg_catalog.uuid_send(v_inquiry_id)
  );

  v_ip := inet_client_addr();
  BEGIN
    v_user_agent := current_setting('request.headers', true)::jsonb->>'user-agent';
  EXCEPTION WHEN OTHERS THEN
    v_user_agent := NULL;
  END;
  v_client := public.app_client_fingerprint();

  INSERT INTO public.inquiries (
    id, listing_id, sender_user_id, sender_name,
    inquirer_phone_encrypted, inquirer_phone_key_name,
    message, status, created_at, updated_at
  ) VALUES (
    v_inquiry_id, p_listing_id, auth.uid(), trim(p_sender_name),
    v_encrypted, 'app-inquirer-phone-key',
    trim(p_message), 'new', now(), now()
  );

  INSERT INTO public.lead_events (
    listing_id, user_id, event_type, metadata, created_at
  ) VALUES (
    p_listing_id, auth.uid(), 'inquiry_sent',
    jsonb_build_object('ip', v_ip::text, 'user_agent', v_user_agent, 'client', v_client),
    now()
  );

  PERFORM public.enqueue_notification(
    v_publisher_user_id, 'inquiry_received',
    jsonb_build_object('listing_id', p_listing_id, 'inquiry_id', v_inquiry_id));

  RETURN v_inquiry_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Reports about a person
-- ---------------------------------------------------------------------------
ALTER TABLE public.reports ALTER COLUMN listing_id DROP NOT NULL;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS target_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_xor;
ALTER TABLE public.reports ADD CONSTRAINT reports_target_xor
  CHECK ((listing_id IS NOT NULL) <> (target_user_id IS NOT NULL));
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reason_check;
ALTER TABLE public.reports ADD CONSTRAINT reports_reason_check CHECK (reason = ANY (ARRAY[
  'fake_listing', 'wrong_price', 'already_sold_or_rented', 'duplicate', 'spam',
  'wrong_location', 'inappropriate_content', 'other',
  'harassment', 'scam', 'impersonation'
]));
CREATE INDEX IF NOT EXISTS idx_reports_target_user
  ON public.reports (target_user_id) WHERE target_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_reports_open_per_reporter_user
  ON public.reports (reporter_user_id, target_user_id)
  WHERE status IN ('new', 'reviewing') AND target_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.submit_user_report(p_user_id uuid, p_reason text, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_id  UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000';
  END IF;
  IF p_user_id = v_uid THEN
    RAISE EXCEPTION 'cannot_report_self' USING ERRCODE = '22023';
  END IF;
  IF p_reason NOT IN ('harassment', 'scam', 'spam', 'impersonation', 'inappropriate_content', 'other') THEN
    RAISE EXCEPTION 'invalid_reason' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
     WHERE p.user_id = p_user_id AND p.account_status <> 'deleted') THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '23503';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.reports
     WHERE reporter_user_id = v_uid
       AND target_user_id = p_user_id
       AND status IN ('new', 'reviewing')) THEN
    RAISE EXCEPTION 'already_reported' USING ERRCODE = '23505';
  END IF;
  IF p_note IS NOT NULL AND char_length(p_note) > 1000 THEN
    RAISE EXCEPTION 'note_too_long' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.reports (target_user_id, reporter_user_id, reason, note, status, metadata)
  VALUES (
    p_user_id, v_uid, p_reason, NULLIF(p_note, ''), 'new',
    jsonb_build_object(
      'ip', inet_client_addr()::text,
      'user_agent', current_setting('request.headers', true)::jsonb->>'user-agent',
      'client', public.app_client_fingerprint()))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text) TO authenticated;

-- The view now carries both kinds. Same columns in the same order, two more
-- at the end; the listing join becomes LEFT so a person report is not dropped.
CREATE OR REPLACE VIEW public.v_reports AS
 SELECT r.id,
    r.listing_id,
    r.reporter_user_id,
    r.reason,
    r.note,
    r.status,
    r.reviewing_by,
    r.resolved_by,
    r.resolution,
    r.created_at,
    r.resolved_at,
    l.title AS listing_title,
    l.status AS listing_status,
    lm.card_path AS main_image_path,
    g.display_name ->> 'ar'::text AS governorate_name_ar,
    g.display_name ->> 'en'::text AS governorate_name_en,
    c.display_name ->> 'ar'::text AS city_name_ar,
    c.display_name ->> 'en'::text AS city_name_en,
    r.target_user_id,
    tp.full_name AS target_user_name
   FROM public.reports r
     LEFT JOIN public.listings l ON l.id = r.listing_id
     LEFT JOIN public.governorates g ON g.id = l.governorate_id
     LEFT JOIN public.cities c ON c.id = l.city_id
     LEFT JOIN LATERAL ( SELECT COALESCE(m.thumbnail_path, m.storage_path) AS card_path
           FROM public.listing_media m
          WHERE m.listing_id = l.id AND m.is_main = true
          ORDER BY m.ordering
         LIMIT 1) lm ON true
     LEFT JOIN public.profiles tp ON tp.user_id = r.target_user_id
  WHERE r.reporter_user_id = auth.uid() OR public.current_user_has_permission('reports.manage'::text);

-- ---------------------------------------------------------------------------
-- 3. Suspend and reinstate a person
-- ---------------------------------------------------------------------------
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY[
  'account_approved', 'account_rejected', 'account_suspended', 'account_reinstated',
  'listing_approved', 'listing_rejected',
  'inquiry_received', 'agency_invitation',
  'saved_search_match',
  'message_received',
  'viewing_requested', 'viewing_confirmed', 'viewing_declined', 'viewing_cancelled',
  'listing_expiring', 'listing_expired'
]));

ALTER TABLE public.moderation_actions DROP CONSTRAINT IF EXISTS moderation_actions_action_check;
ALTER TABLE public.moderation_actions ADD CONSTRAINT moderation_actions_action_check
  CHECK (action = ANY (ARRAY['dismiss', 'hide', 'mark_duplicate', 'delete', 'suspend_user', 'reinstate_user']));
ALTER TABLE public.moderation_actions DROP CONSTRAINT IF EXISTS moderation_actions_target_type_check;
ALTER TABLE public.moderation_actions ADD CONSTRAINT moderation_actions_target_type_check
  CHECK (target_type = ANY (ARRAY['listing', 'user']));

-- The trigger lets the moderation path through, exactly as it already lets
-- self-deletion through: a GUC naming the person, set only by
-- moderate_user_internal after its caller was checked.
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  IF NEW.account_status = 'deleted'
     AND NEW.publisher_status = 'deleted'
     AND nullif(current_setting('app.account_self_deletion', true), '') = NEW.user_id::text
  THEN
    RETURN NEW;
  END IF;

  -- A29: moderate_user_internal names its target here after checking the caller.
  IF nullif(current_setting('app.user_moderation', true), '') = NEW.user_id::text THEN
    RETURN NEW;
  END IF;

  IF (
    (NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status)
    AND NOT public.current_user_is_admin()
    AND auth.role() <> 'service_role'
  ) THEN
    RAISE EXCEPTION 'only admins may change account_status or publisher_status'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.moderate_user_internal(p_user_id uuid, p_actor_user_id uuid, p_action text, p_reason text DEFAULT NULL::text, p_report_id uuid DEFAULT NULL::uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acc    text;
  v_pub    text;
  v_before jsonb;
  v_after  jsonb;
  v_paused integer := 0;
BEGIN
  IF p_action NOT IN ('suspend', 'reinstate') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;
  IF p_user_id = p_actor_user_id THEN
    RAISE EXCEPTION 'cannot_moderate_self' USING ERRCODE = '22023';
  END IF;

  SELECT account_status::text, publisher_status::text INTO v_acc, v_pub
    FROM public.profiles WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_acc = 'deleted' THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '22023';
  END IF;
  IF p_action = 'suspend' AND v_acc = 'suspended' THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '22023';
  END IF;
  IF p_action = 'reinstate' AND v_acc <> 'suspended' THEN
    RAISE EXCEPTION 'invalid_transition' USING ERRCODE = '22023';
  END IF;

  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);
  PERFORM set_config('app.user_moderation', p_user_id::text, true);
  v_before := jsonb_build_object('account_status', v_acc, 'publisher_status', v_pub);

  IF p_action = 'suspend' THEN
    UPDATE public.profiles
       SET account_status = 'suspended', publisher_status = 'suspended'
     WHERE user_id = p_user_id;

    -- Their live listings leave the feed. Not a re-approval later: after a
    -- reinstate the person relists from My Listings, which is already allowed
    -- for paused rows and does not re-alert saved searches.
    PERFORM set_config('app.skip_saved_search_alert', '1', true);
    UPDATE public.listings SET status = 'paused'
     WHERE publisher_user_id = p_user_id AND status = 'approved';
    GET DIAGNOSTICS v_paused = ROW_COUNT;

    -- End their sessions: the app signs them out at the next token refresh
    -- and the next sign-in lands on the suspended screen.
    BEGIN
      DELETE FROM auth.sessions WHERE user_id = p_user_id;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;

    PERFORM public.enqueue_notification(p_user_id, 'account_suspended', '{}'::jsonb);
  ELSE
    UPDATE public.profiles
       SET account_status = 'approved', publisher_status = 'approved'
     WHERE user_id = p_user_id;
    PERFORM public.enqueue_notification(p_user_id, 'account_reinstated', '{}'::jsonb);
  END IF;

  SELECT jsonb_build_object('account_status', account_status, 'publisher_status', publisher_status)
         || jsonb_build_object('listings_paused', v_paused)
    INTO v_after
    FROM public.profiles WHERE user_id = p_user_id;

  INSERT INTO public.moderation_actions
    (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
  VALUES ('user', p_user_id, p_report_id,
          CASE p_action WHEN 'suspend' THEN 'suspend_user' ELSE 'reinstate_user' END,
          p_actor_user_id, p_reason, v_before, v_after);

  PERFORM set_config('app.user_moderation', '', true);
  RETURN p_action;
END;
$function$;
REVOKE ALL ON FUNCTION public.moderate_user_internal(uuid, uuid, text, text, uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.moderate_user(p_user_id uuid, p_action text, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.current_user_has_permission('users.suspend') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  RETURN public.moderate_user_internal(p_user_id, auth.uid(), p_action, p_reason, NULL);
END;
$function$;
REVOKE ALL ON FUNCTION public.moderate_user(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.moderate_user(uuid, text, text) TO authenticated;
COMMENT ON FUNCTION public.moderate_user(uuid, text, text) IS
  'Suspend or reinstate a person. Caller must hold users.suspend. Suspend pauses their approved listings, ends their sessions and notifies them; reinstate restores both statuses (plan A29).';

-- The report queue reaches the same path. A report about a person accepts
-- dismiss / suspend_user; a report about a listing keeps its four actions and
-- gains suspend_user (the publisher).
CREATE OR REPLACE FUNCTION public.resolve_report_internal(p_report_id uuid, p_actor_user_id uuid, p_action text, p_note text DEFAULT NULL::text)
 RETURNS TABLE(report_id uuid, report_status text, listing_id uuid, listing_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_listing_id   UUID;
  v_target_user  UUID;
  v_open_status  TEXT;
  v_before       JSONB;
  v_after        JSONB;
  v_new_report   TEXT;
  v_person       UUID;
  v_sib          RECORD;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  IF p_action NOT IN ('dismiss', 'hide', 'mark_duplicate', 'delete', 'suspend_user') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT r.listing_id, r.target_user_id, r.status
    INTO v_listing_id, v_target_user, v_open_status
    FROM public.reports r WHERE r.id = p_report_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'report_not_found' USING ERRCODE = '23503';
  END IF;
  IF v_open_status NOT IN ('new', 'reviewing') THEN
    RAISE EXCEPTION 'already_resolved' USING ERRCODE = '23514';
  END IF;
  IF v_target_user IS NOT NULL AND p_action NOT IN ('dismiss', 'suspend_user') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  IF p_action = 'suspend_user' THEN
    v_person := coalesce(v_target_user,
                         (SELECT l.publisher_user_id FROM public.listings l WHERE l.id = v_listing_id));
    IF v_person IS NULL THEN
      RAISE EXCEPTION 'user_not_found' USING ERRCODE = '23503';
    END IF;
  END IF;

  IF v_listing_id IS NOT NULL THEN
    SELECT jsonb_build_object('status', l.status, 'title', l.title)
      INTO v_before FROM public.listings l WHERE l.id = v_listing_id;
  END IF;

  v_new_report := CASE WHEN p_action = 'dismiss' THEN 'dismissed' ELSE 'resolved' END;

  UPDATE public.reports
     SET status = v_new_report, resolved_by = p_actor_user_id,
         resolved_at = now(), resolution = p_action,
         reviewing_by = NULL, reviewing_started_at = NULL
   WHERE id = p_report_id;

  IF p_action = 'hide' THEN
    UPDATE public.listings SET status = 'paused'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'mark_duplicate' THEN
    PERFORM set_config('app.current_rejection_reason', 'duplicate', true);
    UPDATE public.listings SET status = 'rejected'
      WHERE id = v_listing_id AND status = 'approved';
  ELSIF p_action = 'delete' THEN
    UPDATE public.listings SET status = 'deleted'
      WHERE id = v_listing_id AND status IN ('approved', 'paused', 'rejected');
  ELSIF p_action = 'suspend_user' THEN
    -- Writes its own moderation_actions row (target 'user', this report id).
    PERFORM public.moderate_user_internal(v_person, p_actor_user_id, 'suspend',
              coalesce(p_note, 'report ' || p_report_id::text), p_report_id);
  END IF;

  IF v_listing_id IS NOT NULL THEN
    SELECT jsonb_build_object('status', l.status, 'title', l.title)
      INTO v_after FROM public.listings l WHERE l.id = v_listing_id;
  END IF;

  IF p_action <> 'suspend_user' THEN
    INSERT INTO public.moderation_actions
      (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
    VALUES (CASE WHEN v_target_user IS NOT NULL THEN 'user' ELSE 'listing' END,
            coalesce(v_target_user, v_listing_id),
            p_report_id, p_action, p_actor_user_id, p_note, v_before, v_after);
  END IF;

  -- Sibling reports about the same listing / person close with the same
  -- outcome, as before.
  IF p_action <> 'dismiss' THEN
    FOR v_sib IN
      SELECT sib.id AS sib_id
      FROM public.reports sib
      WHERE sib.id <> p_report_id
        AND sib.status IN ('new', 'reviewing')
        AND ((v_listing_id IS NOT NULL AND sib.listing_id = v_listing_id)
          OR (v_target_user IS NOT NULL AND sib.target_user_id = v_target_user))
    LOOP
      UPDATE public.reports
         SET status = 'resolved', resolved_by = p_actor_user_id,
             resolved_at = now(), resolution = p_action,
             reviewing_by = NULL, reviewing_started_at = NULL
       WHERE id = v_sib.sib_id;
      INSERT INTO public.moderation_actions
        (target_type, target_id, report_id, action, performed_by, reason, before_state, after_state)
      VALUES (CASE WHEN v_target_user IS NOT NULL THEN 'user' ELSE 'listing' END,
              coalesce(v_target_user, v_listing_id),
              v_sib.sib_id, p_action, p_actor_user_id,
              'auto-resolved: actioned via report ' || p_report_id::text,
              v_before, v_after);
    END LOOP;
  END IF;

  RETURN QUERY
    SELECT p_report_id, v_new_report, v_listing_id,
           (SELECT l.status FROM public.listings l WHERE l.id = v_listing_id);
END;
$function$;

NOTIFY pgrst, 'reload schema';
