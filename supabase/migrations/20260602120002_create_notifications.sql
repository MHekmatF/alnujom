-- Phase 22 (spec/022-notifications-realtime) — Migration 2/11.
-- Creates: public.notifications (durable in-app history store backing the center — R-181),
--          RLS self-read only, client writes REVOKEd (rows written ONLY by enqueue_notification),
--          read-state via RPC. Two indexes (center list + partial unread).
-- Contract: contracts/phase22-notifications-table.md · data-model.md §…002.
-- params carry UUIDs ONLY — no PII / moderator free-text (FR-004).
-- Idempotent: create-if-not-exists guards; safely re-runnable.

create table if not exists public.notifications (
  id                uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  type              text not null check (type in (
                      'account_approved','account_rejected',
                      'listing_approved','listing_rejected',
                      'inquiry_received','agency_invitation')),
  params            jsonb not null default '{}'::jsonb,  -- deep-link IDs + render params (UUIDs only — FR-004)
  read_at           timestamptz,                          -- null = unread
  created_at        timestamptz not null default now()
);

alter table public.notifications enable row level security;

-- Self-only read (R-188). No admin cross-read.
drop policy if exists notifications_select_self on public.notifications;
create policy notifications_select_self on public.notifications
  for select to authenticated using (recipient_user_id = auth.uid());

-- No client writes — rows written only by enqueue_notification (definer); read-state via RPC (R-182).
revoke insert, update, delete on public.notifications from authenticated, anon;

create index if not exists ix_notifications_recipient_created
  on public.notifications(recipient_user_id, created_at desc);
create index if not exists ix_notifications_unread
  on public.notifications(recipient_user_id) where read_at is null;
