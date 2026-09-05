-- Put the housekeeping on a clock.
--
-- Review 2026-09-05 §4 G9 (plan A32). Four recurring jobs existed as functions
-- and nothing ran them: the audit-log purge (A22), the account purge (A7), the
-- expiry sweep (A26) and the storage sweep (A25). Every one of them depended on
-- somebody remembering. `pg_cron` 1.6.4 was available and never installed
-- because ADR-0001 kept the service-role key out of any scheduler — but the
-- two edge functions run inside Supabase's own runtime, and the only secret a
-- job has to present is a bearer that `housekeeping_token_matches()` compares
-- against Vault inside the database. The key never moves.
--
-- The schedule (UTC; Syria is UTC+3, so 03:30 UTC is 06:30 in Damascus):
--
--   housekeeping_listing_expiry   hourly at :10   sweep_listing_expiry()
--   housekeeping_audit_purge      Sun 04:00       purge_audit_logs()  (180-day retention)
--   housekeeping_account_purge    daily 03:30     POST purge_deleted_accounts   (30-day grace)
--   housekeeping_storage_sweep    Sun 04:30       POST sweep_storage            (7 / 30-day graces)
--
-- Deliberately NOT scheduled: a push-token sweep. `notification_tokens` has
-- only `created_at`, and the app re-registers on launch without touching it,
-- so an age cut would delete live tokens. FCM tells the dispatcher which ones
-- are dead, and it prunes those on send; that is enough.
--
-- `cron.schedule(name, …)` replaces a job with the same name, so re-running
-- this file is a no-op. Jobs run as the role that scheduled them (postgres)
-- and log to `cron.job_run_details`, which pg_cron trims itself.
--
-- The first storage sweep removes the 31 orphaned files found on 2026-09-05
-- and the media of any listing deleted more than 30 days earlier. The owner
-- can stop it before Sunday with `SELECT cron.unschedule('housekeeping_storage_sweep');`.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---------------------------------------------------------------------------
-- The bearer the scheduler presents to the two edge functions
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'housekeeping_token') THEN
    PERFORM vault.create_secret(
      encode(gen_random_bytes(32), 'hex'),
      'housekeeping_token',
      'Bearer pg_cron presents to purge_deleted_accounts and sweep_storage; verified by public.housekeeping_token_matches(). Rotate by updating this secret — nothing else holds it.');
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- The jobs
-- ---------------------------------------------------------------------------
SELECT cron.schedule(
  'housekeeping_listing_expiry',
  '10 * * * *',
  $job$ SELECT public.sweep_listing_expiry(); $job$);

SELECT cron.schedule(
  'housekeeping_audit_purge',
  '0 4 * * 0',
  $job$ SELECT public.purge_audit_logs(); $job$);

SELECT cron.schedule(
  'housekeeping_account_purge',
  '30 3 * * *',
  $job$ SELECT net.http_post(
          url     := 'https://hczsgceagommznjaohyk.supabase.co/functions/v1/purge_deleted_accounts',
          headers := jsonb_build_object('Content-Type', 'application/json',
                                        'Authorization', 'Bearer ' || public.app_vault_secret('housekeeping_token')),
          body    := '{}'::jsonb,
          timeout_milliseconds := 120000); $job$);

SELECT cron.schedule(
  'housekeeping_storage_sweep',
  '30 4 * * 0',
  $job$ SELECT net.http_post(
          url     := 'https://hczsgceagommznjaohyk.supabase.co/functions/v1/sweep_storage',
          headers := jsonb_build_object('Content-Type', 'application/json',
                                        'Authorization', 'Bearer ' || public.app_vault_secret('housekeeping_token')),
          body    := '{}'::jsonb,
          timeout_milliseconds := 120000); $job$);

COMMENT ON EXTENSION pg_cron IS
  'Installed 2026-09-05 (plan A32) for the four housekeeping jobs; see supabase/migrations/20260905120003_put_the_housekeeping_on_a_clock.sql for the schedule and how to stop one.';
