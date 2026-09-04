-- 20260904120009_filter_the_publisher_dashboard.sql
--
-- Plan A23 / review §4 — the publisher dashboard subscribed to ALL changes on
-- `listings` and `inquiries`, so every write in the system fanned out to every
-- open dashboard: a Realtime message each, and an RLS check per subscriber per
-- event.
--
-- Reading it turned up that the `inquiries` half was not merely unfiltered, it
-- WAS NEVER DELIVERING ANYTHING. Two independent reasons:
--
--   1. `public.inquiries` is not in the `supabase_realtime` publication, so no
--      change on it is ever published. (`listings`, `reports`, `messages`,
--      `user_roles` and `conversations` are; `inquiries` and `notifications`
--      are not.)
--   2. There is no per-user column to filter on. The table carries
--      `listing_id` and nothing else that identifies the publisher, so the
--      client could not have narrowed the subscription even if events arrived.
--
-- So a publisher's counter has never moved when an inquiry landed — it moved on
-- the next manual refresh, or on the channel's own resubscribe reconcile. This
-- fixes the plumbing and the fan-out together.
--
-- WHY REPLICA IDENTITY FULL
-- -------------------------
-- A Realtime filter on a non-primary-key column needs the old row to decide
-- whether a subscriber could see the record BEFORE the change. With the default
-- replica identity the old record carries the primary key alone, so
-- `publisher_user_id` is absent and filtered UPDATE/DELETE events are silently
-- dropped — INSERT keeps working, which is exactly how this hides. Same lesson
-- as `user_roles` and `messages`, both of which already carry FULL.
--
-- The cost is that every UPDATE writes the whole old row to the WAL. Both these
-- tables are low-write (a listing is edited a handful of times in its life), so
-- it is the right trade here and would not be on a hot table.

-- ---------------------------------------------------------------------------
-- 1. A per-publisher column on inquiries, derived — never client-supplied.
-- ---------------------------------------------------------------------------
ALTER TABLE public.inquiries
  ADD COLUMN IF NOT EXISTS publisher_user_id uuid REFERENCES auth.users(id);

COMMENT ON COLUMN public.inquiries.publisher_user_id IS
  'The listing owner at the time of the inquiry. Denormalised from '
  'listings.publisher_user_id so a Realtime subscription and the RLS policy can '
  'both narrow on one column instead of a per-row EXISTS join (Plan A23). '
  'Maintained by inquiries_set_publisher_trigger — a client value is ignored.';

-- Recompute from the listing on every write. Because it OVERWRITES whatever
-- arrived, the column cannot be forged, which is what makes it safe to hang an
-- RLS policy on below.
CREATE OR REPLACE FUNCTION public.inquiries_set_publisher_fn()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  SELECT l.publisher_user_id
    INTO NEW.publisher_user_id
  FROM public.listings l
  WHERE l.id = NEW.listing_id;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS inquiries_set_publisher_trigger ON public.inquiries;
CREATE TRIGGER inquiries_set_publisher_trigger
  BEFORE INSERT OR UPDATE OF listing_id ON public.inquiries
  FOR EACH ROW EXECUTE FUNCTION public.inquiries_set_publisher_fn();

UPDATE public.inquiries i
   SET publisher_user_id = l.publisher_user_id
  FROM public.listings l
 WHERE l.id = i.listing_id
   AND i.publisher_user_id IS DISTINCT FROM l.publisher_user_id;

ALTER TABLE public.inquiries ALTER COLUMN publisher_user_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_inquiries_publisher
  ON public.inquiries (publisher_user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 2. The publisher's own policies stop joining.
-- ---------------------------------------------------------------------------
-- Same rows, decided by one column comparison instead of an EXISTS against
-- `listings` per row — which is the cost Realtime pays on EVERY event for EVERY
-- subscriber, not just on a page load.
DROP POLICY IF EXISTS inquiries_select_publisher ON public.inquiries;
CREATE POLICY inquiries_select_publisher ON public.inquiries
  FOR SELECT
  USING (publisher_user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS inquiries_update_publisher ON public.inquiries;
CREATE POLICY inquiries_update_publisher ON public.inquiries
  FOR UPDATE
  USING (publisher_user_id = (SELECT auth.uid()))
  WITH CHECK (publisher_user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- 3. Publish inquiries, and give both tables an old row to filter on.
-- ---------------------------------------------------------------------------
ALTER TABLE public.listings  REPLICA IDENTITY FULL;
ALTER TABLE public.inquiries REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'inquiries'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.inquiries;
  END IF;
END $$;
