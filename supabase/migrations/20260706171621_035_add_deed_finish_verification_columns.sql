-- 20260706171621_035_add_deed_finish_verification_columns
--
-- RECONSTRUCTED 2026-07-17 from the live database (commit-only — already applied
-- via Supabase MCP on 2026-07-06 as tracker version 20260706171621 / name
-- `035_add_deed_finish_verification_columns`). DO NOT re-apply through MCP; this
-- file exists so the repo is the source of truth for the live schema (DB-1 fix).
-- All statements are idempotent so a from-scratch replay is safe.
--
-- Phase 035 Stage 3 — Syria-native deed/finish attributes + a verification lifecycle
-- on listings. deed_type / finish_level are optional; verification_status drives the
-- "field-verified" badge and defaults to 'none'.
alter table public.listings
  add column if not exists deed_type           text,
  add column if not exists finish_level        text,
  add column if not exists verification_status text not null default 'none',
  add column if not exists verified_at         timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'listings_deed_type_check'
  ) then
    alter table public.listings
      add constraint listings_deed_type_check
      check (deed_type is null or deed_type = any (array[
        'green','red','temporary','agricultural','court_ruling'
      ]));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'listings_finish_level_check'
  ) then
    alter table public.listings
      add constraint listings_finish_level_check
      check (finish_level is null or finish_level = any (array[
        'on_bone','normal','deluxe','super_deluxe'
      ]));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'listings_verification_status_check'
  ) then
    alter table public.listings
      add constraint listings_verification_status_check
      check (verification_status = any (array['none','under_review','verified']));
  end if;
end $$;

create index if not exists listings_verification_status_idx
  on public.listings using btree (verification_status);
