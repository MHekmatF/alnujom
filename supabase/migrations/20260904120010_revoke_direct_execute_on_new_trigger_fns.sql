-- 20260904120010_revoke_direct_execute_on_new_trigger_fns.sql
--
-- Follow-up to A16 and A23 — I added two trigger functions this week and left
-- them with the PUBLIC EXECUTE grant every new function is created with.
-- `20260717120010_revoke_direct_execute_internal_fns.sql` established the rule
-- for exactly this and these two slipped past it; the security advisor's
-- `anon_security_definer_function_executable` count went 15 → 17.
--
--   notify_new_message()          — A16, AFTER INSERT on public.messages
--   inquiries_set_publisher_fn()  — A23, BEFORE INSERT/UPDATE on public.inquiries
--
-- Neither is exploitable: a `trigger`-returning plpgsql function called directly
-- raises 0A000 before a line of its body runs. But the standing rule is that an
-- internal function is not part of the RPC surface, and an advisor finding
-- nobody can explain is how a real one gets ignored.
--
-- Revoking cannot break the triggers: PostgreSQL does not check EXECUTE on a
-- trigger function against the session role — it runs as the table owner when
-- the trigger fires. Same reasoning as the July migration.

REVOKE EXECUTE ON FUNCTION public.notify_new_message()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.inquiries_set_publisher_fn()
  FROM PUBLIC, anon, authenticated;
