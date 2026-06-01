-- Phase 22 (spec/022-notifications-realtime) — Migration 12/11 (post-apply security hardening).
-- WHY: 20260602120003 revoked EXECUTE on enqueue_notification / notify_push_dispatch FROM
-- anon, authenticated — but Postgres grants EXECUTE to PUBLIC by DEFAULT on every new
-- function, and a per-role REVOKE does NOT remove the PUBLIC grant. Live verification
-- (has_function_privilege) showed anon/authenticated could STILL execute the internal
-- fan-out writer via PUBLIC — a notification-forge hole (FR-019/FR-020, R-182). The Phase 12
-- atomic wrappers avoided this by REVOKE ALL ... FROM PUBLIC; mirror that here.
-- (Gotcha: memory project_supabase_view_rls_gotchas — "new public funcs get default anon
-- EXECUTE; REVOKE explicitly".)
-- Idempotent: REVOKE/GRANT are unconditional and safely re-runnable.

-- Internal only — never reachable from any client (called only by the SECURITY DEFINER
-- transition fns and the AFTER-INSERT trigger). Remove the residual PUBLIC default grant.
revoke execute on function public.enqueue_notification(uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function public.notify_push_dispatch()                  from public, anon, authenticated;

-- Client RPCs — authenticated-only (each self-scopes on auth.uid()). Strip the PUBLIC + anon
-- default grants, re-assert the authenticated grant (defense-in-depth — R-182).
revoke execute on function public.register_notification_token(text, text) from public, anon;
revoke execute on function public.deregister_notification_token(text)      from public, anon;
revoke execute on function public.mark_notification_read(uuid)             from public, anon;
revoke execute on function public.mark_all_notifications_read()            from public, anon;
revoke execute on function public.unread_notification_count()              from public, anon;

grant execute on function public.register_notification_token(text, text)   to authenticated;
grant execute on function public.deregister_notification_token(text)       to authenticated;
grant execute on function public.mark_notification_read(uuid)              to authenticated;
grant execute on function public.mark_all_notifications_read()             to authenticated;
grant execute on function public.unread_notification_count()              to authenticated;
