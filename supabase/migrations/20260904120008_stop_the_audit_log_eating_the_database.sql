-- 20260904120008_stop_the_audit_log_eating_the_database.sql
--
-- Plan A22 / review §4 C3 — the audit log grows faster than the data it audits.
--
-- Measured on 2026-09-04, 1,410 rows / 1,576 kB:
--
--   listing.updated        247 rows   1,861 bytes each   460 kB
--   listing_media.updated  130 rows     939 bytes each   122 kB
--   listing_media.created   95 rows     538 bytes each    51 kB
--   listing.created         73 rows     957 bytes each    70 kB
--   listing_media.deleted   44 rows     528 bytes each    23 kB
--   listing.approved/…      44 rows   ~1,850 bytes each   81 kB
--
-- Three separate reasons for that, fixed here.
--
-- 1. EVERY listing UPDATE stored the WHOLE ROW TWICE — `to_jsonb(OLD)` and
--    `to_jsonb(NEW)` — so changing one price cost 1.9 KB. It now stores only the
--    keys that actually differ. Same information, a fraction of the bytes, and
--    it is genuinely easier to read: the admin viewer shows what changed instead
--    of two near-identical blobs to diff by eye.
--
-- 2. A STATUS CHANGE WROTE THE SAME THING TWICE. `listing.updated` fired, and
--    then `listing.approved` (or …rejected/…paused/…) fired carrying an
--    identical pair of snapshots. One row now, under the status verb when there
--    is one — the generic verb is the fallback, not an extra.
--
-- 3. THE THREE ROW-LEVEL `listing_media` TRIGGERS ARE DROPPED, per the plan. One
--    audit row per photo insert / update / delete, whole row each way, for
--    machine noise: A18's thumbnail backfill alone wrote 51 `listing_media.updated`
--    rows for a column no human set. Media changes stay auditable through the
--    listing itself and through `listing_revisions`, which is what an admin
--    actually reviews.
--
-- Plus `purge_audit_logs()` for the tail. It is NOT scheduled — see the note on
-- the function.

-- ---------------------------------------------------------------------------
-- 1 + 2. One row per listing change, carrying only what changed.
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER and `search_path = public, auth` are preserved from the
-- original: the function reads auth.uid().
CREATE OR REPLACE FUNCTION public.listings_audit_trigger_fn()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_actor       uuid := coalesce(
                          nullif(current_setting('app.current_user_id', true), '')::uuid,
                          auth.uid());
  v_status_verb text;
  v_old         jsonb;
  v_new         jsonb;
  v_before      jsonb := '{}'::jsonb;
  v_after       jsonb := '{}'::jsonb;
  v_key         text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- A row's birth: the whole thing, once. There is nothing to diff against.
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id,
                                   before_state, after_state)
    VALUES (v_actor, 'listing.created', 'listings', NEW.id::text,
            NULL, to_jsonb(NEW));
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id,
                                   before_state, after_state)
    VALUES (v_actor, 'listing.deleted', 'listings', OLD.id::text,
            to_jsonb(OLD), NULL);
    RETURN OLD;

  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);

    -- Only the keys that differ. Both tables have the same shape, so iterating
    -- NEW's keys covers every column.
    FOR v_key IN SELECT jsonb_object_keys(v_new) LOOP
      IF (v_old -> v_key) IS DISTINCT FROM (v_new -> v_key) THEN
        v_before := v_before || jsonb_build_object(v_key, v_old -> v_key);
        v_after  := v_after  || jsonb_build_object(v_key, v_new -> v_key);
      END IF;
    END LOOP;

    -- A no-op UPDATE (a re-save that changed nothing) is not an audit event.
    -- `updated_at` is touched by a BEFORE trigger, so a true no-op is rare —
    -- but a row rewritten to its own values should not cost 1.9 KB.
    IF v_after = '{}'::jsonb THEN
      RETURN NEW;
    END IF;

    IF OLD.status IS DISTINCT FROM NEW.status THEN
      v_status_verb := CASE NEW.status
        WHEN 'pending_review' THEN 'listing.submitted'
        WHEN 'approved'       THEN 'listing.approved'
        WHEN 'rejected'       THEN 'listing.rejected'
        WHEN 'paused'         THEN 'listing.paused'
        WHEN 'expired'        THEN 'listing.expired'
        WHEN 'sold'           THEN 'listing.sold'
        WHEN 'rented'         THEN 'listing.rented'
        WHEN 'deleted'        THEN 'listing.deleted'
        ELSE NULL
      END;
    END IF;

    -- ONE row. The status verb when the status moved, the generic verb
    -- otherwise — never both, which is what doubled the cost of every
    -- moderation decision.
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id,
                                   before_state, after_state)
    VALUES (v_actor, coalesce(v_status_verb, 'listing.updated'),
            'listings', NEW.id::text, v_before, v_after);

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. The per-photo triggers.
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS audit_listing_media_insert ON public.listing_media;
DROP TRIGGER IF EXISTS audit_listing_media_update ON public.listing_media;
DROP TRIGGER IF EXISTS audit_listing_media_delete ON public.listing_media;

-- ---------------------------------------------------------------------------
-- 4. Retention.
-- ---------------------------------------------------------------------------
-- NOT SCHEDULED, deliberately. `pg_cron` is available on this project (1.6.4)
-- but not installed, and the plan defers that decision to the owner along with
-- A7's. Nothing is deleted by applying this migration: today the oldest audit
-- row is 2026-05-09, so at 180 days retention the count that qualifies is ZERO
-- and stays zero until 2026-11-05.
--
-- To run it by hand (as the service role or in the SQL editor):
--     select public.purge_audit_logs();                 -- 180 days
--     select public.purge_audit_logs(interval '1 year');
--
-- To schedule it later, once the owner has decided:
--     create extension if not exists pg_cron;
--     select cron.schedule('purge-audit-logs', '0 3 1 * *',
--                          $$select public.purge_audit_logs()$$);
CREATE OR REPLACE FUNCTION public.purge_audit_logs(
  p_retain interval DEFAULT interval '180 days'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_deleted bigint;
BEGIN
  -- Guard against a fat-fingered `purge_audit_logs(interval '0')` wiping the
  -- whole table: nothing younger than a month is ever eligible.
  IF p_retain < interval '30 days' THEN
    RAISE EXCEPTION 'retention must be at least 30 days, got %', p_retain
      USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.audit_logs
  WHERE created_at < now() - p_retain;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$function$;

-- Nobody reaches this from the app. A new function gets a default PUBLIC
-- EXECUTE, so revoke it; the service role and postgres keep it through their
-- own membership, not through a grant here.
REVOKE ALL ON FUNCTION public.purge_audit_logs(interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_audit_logs(interval) FROM anon, authenticated;

COMMENT ON FUNCTION public.purge_audit_logs(interval) IS
  'Deletes audit_logs rows older than p_retain (default 180 days) and returns '
  'the count. Not scheduled — see 20260904120008 for the pg_cron recipe. '
  'Refuses a retention under 30 days.';
