-- Phase 22 (spec/022-notifications-realtime) — Migration 3/11.
-- Creates: the internal enqueue_notification writer (definer, EXECUTE REVOKEd from clients)
--          + 5 client RPCs (register/deregister token, mark read, mark all, unread count).
-- Contract: contracts/phase22-notification-rpcs-and-enqueue.md · data-model.md §…003.
-- Posture (R-182): every fn SECURITY DEFINER + search_path=''; clients self-scoped on auth.uid().
-- Idempotent: create-or-replace bodies + re-asserted grants/revokes; safely re-runnable.

-- ─── Internal writer (R-183) ──────────────────────────────────────────────
-- Always writes history (FR-021 / R-189), regardless of notifications_enabled.
-- Called ONLY by the SECURITY DEFINER transition functions (the 4 fan-out amendments).
create or replace function public.enqueue_notification(
  p_recipient uuid, p_type text, p_params jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_recipient is null then return null; end if;          -- defensive: skip if no recipient
  insert into public.notifications(recipient_user_id, type, params)
    values (p_recipient, p_type, coalesce(p_params, '{}'::jsonb))
    returning id into v_id;
  return v_id;
end $$;
-- Internal only — never reachable via /rest/v1/rpc (R-182).
revoke execute on function public.enqueue_notification(uuid, text, jsonb) from anon, authenticated;

-- ─── Client RPC: register / refresh this device's token (R-191) ────────────
create or replace function public.register_notification_token(p_token text, p_platform text default 'android')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  insert into public.notification_tokens(user_id, token, platform, is_active, last_seen_at)
    values (auth.uid(), p_token, coalesce(p_platform, 'android'), true, now())
  on conflict (user_id, token)
    do update set is_active = true, last_seen_at = now();
end $$;
grant execute on function public.register_notification_token(text, text) to authenticated;

-- ─── Client RPC: deregister THIS device only (R-191) ───────────────────────
create or replace function public.deregister_notification_token(p_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.notification_tokens where user_id = auth.uid() and token = p_token;
end $$;
grant execute on function public.deregister_notification_token(text) to authenticated;

-- ─── Client RPC: mark one own notification read (FR-008) ───────────────────
create or replace function public.mark_notification_read(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at = coalesce(read_at, now())
   where id = p_id and recipient_user_id = auth.uid();
end $$;
grant execute on function public.mark_notification_read(uuid) to authenticated;

-- ─── Client RPC: mark all own notifications read (FR-008) ──────────────────
create or replace function public.mark_all_notifications_read()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at = now()
   where recipient_user_id = auth.uid() and read_at is null;
end $$;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- ─── Client RPC: unread count for the badge (R-193) — bounded, self-only ───
create or replace function public.unread_notification_count()
returns integer language sql security definer set search_path = '' stable as $$
  select count(*)::int from public.notifications
   where recipient_user_id = auth.uid() and read_at is null;
$$;
grant execute on function public.unread_notification_count() to authenticated;
