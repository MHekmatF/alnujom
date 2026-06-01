-- Phase 22 (spec/022-notifications-realtime) — Migration 10/11.
-- Adds public.listings + public.reports (admin counters — FR-015/FR-016) and
-- public.user_roles (live permission refresh — FR-017) to the supabase_realtime
-- publication (R-190). Row visibility stays governed by each table's existing RLS
-- (admins see listings/reports; a user sees own user_roles) — NO policy change.
-- REPLICA IDENTITY DEFAULT (the PK) suffices for the change events the clients consume.
-- Idempotent: guarded per-table add (alter publication … add table errors if the table is
-- already a member, so skip those already in pg_publication_tables); safely re-runnable.

do $$
declare
  v_tbl text;
  v_tables constant text[] := array['listings','reports','user_roles'];
begin
  -- The publication is created by Supabase platform init; guard in case it is absent.
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  foreach v_tbl in array v_tables loop
    if not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = v_tbl
    ) then
      execute format('alter publication supabase_realtime add table public.%I', v_tbl);
    end if;
  end loop;
end $$;
