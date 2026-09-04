-- Close the three write holes proven on 2026-09-04, and let the saved-search
-- alert insert the row it was written to insert.
--
-- Evidence and the exact proofs: docs/ops/REVIEW_2026-09-04.md sections 2 and 5.
-- Each was executed as the `authenticated` role with a forged JWT claim inside
-- BEGIN … ROLLBACK, so none of them is theoretical.
--
-- Nothing here changes what the app can do. Every write the client performs
-- already goes through an RPC or through the one column this migration leaves
-- writable; the grants being removed are Supabase's blanket
-- `GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated`, which no
-- part of the app was relying on.

-- ---------------------------------------------------------------------------
-- 1. notifications.type — the constraint rejects the type the trigger inserts
-- ---------------------------------------------------------------------------
-- `trg_listings_saved_search_alert` is AFTER UPDATE FOR EACH ROW on listings and
-- calls notify_saved_search_matches(), which inserts type 'saved_search_match'.
-- That trigger fires inside approve_listing_internal()'s UPDATE. The CHECK added
-- in 20260602120002 lists six types and was never widened when the alert shipped
-- in 20260608130001, so:
--
--     first user saves a search
--       -> admin approves a listing that matches it
--         -> trigger raises 23514
--           -> the whole approval transaction rolls back
--
-- Proven: a bare INSERT of that type fails with
-- `violates check constraint "notifications_type_check"`. It has never fired
-- only because public.saved_searches has zero rows.
--
-- The five types after it belong to the message/viewing alerts (plan item A16)
-- and the expiry reminder. Adding them now means A16 is a trigger and a client
-- string table, not another migration on this constraint.
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
      'listing_expiring'::text
    ])
  );

-- ---------------------------------------------------------------------------
-- 2. messages — a member could rewrite the counterpart's words
-- ---------------------------------------------------------------------------
-- `messages_update_member` had USING (caller is a member of the conversation)
-- and **no WITH CHECK**, while `authenticated` held UPDATE on every column. So,
-- proven as the buyer against the publisher's message:
--
--     update public.messages
--        set body = 'TAMPERED by the buyer', sender_user_id = <buyer>
--      where id = <the publisher's message>;
--     -> body changed, sender_user_id now the buyer
--
-- The only UPDATE the app performs on this table is the read receipt
-- (supabase_chat_datasource.markRead: read_at = now() on the counterpart's
-- unread rows), so `read_at` is the only column that needs to be writable.
--
-- The column grant is the real fix — it makes every other column unwritable
-- whatever any policy says. The policy is tightened to match anyway, so the
-- intent is legible at the policy level too and a future column grant cannot
-- silently widen it.
REVOKE UPDATE, DELETE ON public.messages FROM authenticated;
REVOKE ALL ON public.messages FROM anon;
GRANT UPDATE (read_at) ON public.messages TO authenticated;

DROP POLICY IF EXISTS messages_update_member ON public.messages;

CREATE POLICY messages_update_member ON public.messages
  FOR UPDATE TO authenticated
  USING (
    -- Only the COUNTERPART's rows: you never mark your own message read.
    sender_user_id IS DISTINCT FROM (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND ((SELECT auth.uid()) = c.buyer_user_id
          OR (SELECT auth.uid()) = c.publisher_user_id)
    )
  )
  WITH CHECK (
    sender_user_id IS DISTINCT FROM (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND ((SELECT auth.uid()) = c.buyer_user_id
          OR (SELECT auth.uid()) = c.publisher_user_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 3. viewings — a requester could confirm their own viewing
-- ---------------------------------------------------------------------------
-- update_viewing_status() correctly restricts 'confirmed'/'declined' to the
-- publisher. `viewings_update_member` let either party UPDATE any column
-- directly and walk straight past it. Proven as the requester:
--
--     update public.viewings set status = 'confirmed' where id = <own request>;
--     -> status = 'confirmed'
--
-- `viewings_insert_requester` had the same shape of gap in the other direction:
-- it checked WHO was inserting but not WHAT, so a hand-crafted INSERT could
-- create a viewing already in status 'confirmed'.
--
-- supabase_viewings_datasource only ever SELECTs this table; the two writes are
-- request_viewing() and update_viewing_status(), both SECURITY DEFINER, so both
-- keep working with the grants gone.
DROP POLICY IF EXISTS viewings_update_member ON public.viewings;
DROP POLICY IF EXISTS viewings_insert_requester ON public.viewings;
REVOKE INSERT, UPDATE, DELETE ON public.viewings FROM authenticated;
REVOKE ALL ON public.viewings FROM anon;

-- ---------------------------------------------------------------------------
-- 4. conversations — nothing outside the RPC should write here
-- ---------------------------------------------------------------------------
-- `conversations_insert_buyer` checked that the inserting user was the buyer,
-- but not that `publisher_user_id` was really the listing's publisher. A
-- hand-crafted INSERT could therefore open a conversation against any user id
-- and message a stranger who never published anything — the same class of gap
-- as 2 and 3, found by reading rather than by running, so recorded here rather
-- than claimed as proven.
--
-- get_or_create_conversation() derives the publisher from the listing and is
-- SECURITY DEFINER; bump_conversation_last_message() (the last_message_at
-- trigger) is too. The client only SELECTs. So no grant is needed at all.
DROP POLICY IF EXISTS conversations_insert_buyer ON public.conversations;
REVOKE INSERT, UPDATE, DELETE ON public.conversations FROM authenticated;
REVOKE ALL ON public.conversations FROM anon;

-- ---------------------------------------------------------------------------
-- Verification (run after applying)
-- ---------------------------------------------------------------------------
--   -- 1. the alert type now inserts
--   begin;
--     insert into public.notifications (recipient_user_id, type, params)
--       values ((select user_id from public.profiles limit 1),
--               'saved_search_match', '{}'::jsonb);
--   rollback;
--
--   -- 2/3. the two proofs from the review must now FAIL
--   -- (see docs/ops/REVIEW_2026-09-04.md section 6 for the full harness)
--
--   -- 4. the read receipt must still WORK
--   begin;
--     set local role authenticated;
--     select set_config('request.jwt.claims', …buyer…, true);
--     update public.messages set read_at = now()
--      where conversation_id = … and sender_user_id <> … and read_at is null;
--   rollback;
