-- Phase 22 (spec/022-notifications-realtime) — Migration 1/11.
-- Creates: public.notification_tokens (device push tokens), RLS self-read only,
--          client writes REVOKEd (registration is RPC-only — R-182), partial index.
-- Contract: contracts/phase22-notification-tokens-table.md · data-model.md §…001.
-- Idempotent: create-if-not-exists table/index/policy guards; safely re-runnable
--             (Supabase MCP apply_migration does NOT dedupe by name — re-runs the SQL).

create table if not exists public.notification_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  token        text not null,
  platform     text not null default 'android' check (platform in ('android')),  -- Android-only (Principle XI)
  is_active    boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (user_id, token)                                                          -- one row per device-token per user
);

alter table public.notification_tokens enable row level security;

-- Self-only read (R-182/R-188). No admin cross-read.
drop policy if exists notification_tokens_select_self on public.notification_tokens;
create policy notification_tokens_select_self on public.notification_tokens
  for select to authenticated using (user_id = auth.uid());

-- No client writes — registration is via register/deregister_notification_token RPC only (R-182).
revoke insert, update, delete on public.notification_tokens from authenticated, anon;

create index if not exists ix_notification_tokens_user
  on public.notification_tokens(user_id) where is_active;
