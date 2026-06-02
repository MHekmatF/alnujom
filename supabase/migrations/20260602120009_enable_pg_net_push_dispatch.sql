-- Phase 22 (spec/022-notifications-realtime) — Migration 9/11.
-- Enables pg_net (the one justified new extension — R-185) and wires async, best-effort
-- push dispatch: an AFTER-INSERT trigger on public.notifications net.http_post's the new row
-- to the dispatch_push Edge Function. The trigger reads push_dispatch_url + push_dispatch_token
-- from Vault via app_vault_secret and RETURNS WITHOUT POSTING when EITHER secret is NULL —
-- degraded mode: the in-app history row is already written, push is simply skipped (FR-013).
-- Dispatch is async + best-effort: AFTER INSERT + net.http_post never blocks or fails the
-- actor's transaction (FR-017). search_path='' + SECURITY DEFINER; EXECUTE REVOKEd from clients.
-- Idempotent: extension if-not-exists, create-or-replace fn, drop-then-create trigger.

create extension if not exists pg_net;   -- justified new extension (plan Complexity Tracking)

create or replace function public.notify_push_dispatch()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_url text; v_token text;
begin
  v_url   := public.app_vault_secret('push_dispatch_url');
  v_token := public.app_vault_secret('push_dispatch_token');
  if v_url is null or v_token is null then
    return new;  -- push not configured → degraded mode, in-app history already written (FR-013)
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type','application/json',
                                  'Authorization','Bearer '||v_token),
    body := jsonb_build_object('notification_id', new.id,
                               'recipient_user_id', new.recipient_user_id,
                               'type', new.type, 'params', new.params));
  return new;
end $$;
revoke execute on function public.notify_push_dispatch() from anon, authenticated;

drop trigger if exists trg_notifications_push_dispatch on public.notifications;
create trigger trg_notifications_push_dispatch
  after insert on public.notifications
  for each row execute function public.notify_push_dispatch();
