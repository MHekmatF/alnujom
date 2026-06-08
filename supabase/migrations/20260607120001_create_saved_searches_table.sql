-- Phase 25 uplift v2 — saved searches (user-owned filter snapshots).
create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text,
  filters jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists saved_searches_user_created_idx
  on public.saved_searches (user_id, created_at desc);

alter table public.saved_searches enable row level security;

-- Owner-only access on every verb (no anon).
drop policy if exists saved_searches_select_own on public.saved_searches;
create policy saved_searches_select_own on public.saved_searches
  for select to authenticated using (user_id = auth.uid());

drop policy if exists saved_searches_insert_own on public.saved_searches;
create policy saved_searches_insert_own on public.saved_searches
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists saved_searches_update_own on public.saved_searches;
create policy saved_searches_update_own on public.saved_searches
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists saved_searches_delete_own on public.saved_searches;
create policy saved_searches_delete_own on public.saved_searches
  for delete to authenticated using (user_id = auth.uid());
