-- =============================================================================
-- Al Nujom — pre-launch data cleanup
-- =============================================================================
-- Purpose: remove the demo/test listings (and everything that hangs off them)
-- that accumulated during development, so the app launches with real content
-- only. Admin/staff accounts and all reference data are preserved.
--
-- STATUS: NOT YET RUN. The Supabase project was paused at the time this was
-- written, so nothing here has been executed or verified against live data.
--
-- HOW TO USE
--   1. Restore the Supabase project first (see docs/ops/HANDOVER.md).
--   2. Take a backup / point-in-time-restore checkpoint. This script deletes
--      rows permanently.
--   3. Run PART 1 alone and read the output. It changes nothing.
--   4. Choose the listing set in PART 2 and confirm the counts look right.
--   5. Run PART 3. It ends with ROLLBACK on purpose — you will see exactly what
--      would be deleted without deleting it. Only after the numbers look
--      correct, change the final ROLLBACK to COMMIT and run it again.
--
-- WHY THE ORDER MATTERS
--   listings has 14 dependants. Most cascade, but four are ON DELETE RESTRICT
--   and will block the delete until their rows are gone:
--     favorites, inquiries, reports, lead_events
--   reports is itself referenced by moderation_actions (ON DELETE SET NULL),
--   and crm_leads owns crm_notes / crm_reminders (both CASCADE).
--   PART 3 deletes in an order that satisfies all of that.
-- =============================================================================


-- =============================================================================
-- PART 1 — INVENTORY (read-only, safe to run any time)
-- =============================================================================

-- 1a. How much content exists, and how much of it is public?
select
  (select count(*) from public.listings)                              as listings_total,
  (select count(*) from public.listings where status = 'approved')    as listings_approved,
  (select count(*) from public.listings where status = 'draft')       as listings_draft,
  (select count(*) from public.profiles)                              as profiles_total,
  (select count(*) from public.inquiries)                             as inquiries_total,
  (select count(*) from public.conversations)                         as conversations_total,
  (select count(*) from public.reviews)                               as reviews_total,
  (select count(*) from public.crm_leads)                             as crm_leads_total,
  (select count(*) from public.listing_media)                         as media_total;

-- 1b. Every listing with its owner and how much data hangs off it.
--     Use this to decide what is demo and what (if anything) is real.
select
  l.id,
  l.status,
  l.created_at::date                                  as created,
  coalesce(p.full_name, p.username, '(no name)')      as owner,
  left(l.title, 60)                                   as title,
  (select count(*) from public.listing_media  m where m.listing_id = l.id) as media,
  (select count(*) from public.favorites      f where f.listing_id = l.id) as favs,
  (select count(*) from public.inquiries      i where i.listing_id = l.id) as inquiries,
  (select count(*) from public.conversations  c where c.listing_id = l.id) as chats
from public.listings l
left join public.profiles p on p.user_id = l.publisher_user_id
order by l.created_at;

-- 1c. Accounts, so you can confirm which ones are staff and must survive.
select
  p.user_id,
  coalesce(p.full_name, p.username, '(no name)') as name,
  p.account_status,
  p.publisher_status,
  coalesce(
    (select string_agg(r.name, ', ')
       from public.user_roles ur
       join public.roles r on r.id = ur.role_id
      where ur.user_id = p.user_id),
    '(no role)'
  )                                                  as roles,
  (select count(*) from public.listings l where l.publisher_user_id = p.user_id) as listings
from public.profiles p
order by listings desc, name;

-- 1d. Storage objects are NOT removed by this script (they live in the storage
--     buckets, not in these tables). After the delete, list what is orphaned:
select
  o.bucket_id,
  count(*) as objects,
  pg_size_pretty(sum((o.metadata ->> 'size')::bigint)) as total_size
from storage.objects o
group by o.bucket_id
order by o.bucket_id;


-- =============================================================================
-- PART 2 — CHOOSE WHAT TO DELETE
-- =============================================================================
-- Pick ONE strategy below and use the matching definition of doomed_listings in
-- PART 3. Option A is the default: it deletes every listing, which is the right
-- call when 100% of current content is development data.

--   Option A — delete ALL listings (the default in PART 3)
--       select id from public.listings
--
--   Option B — delete everything EXCEPT an explicit keep-list
--       select id from public.listings
--        where id not in ('00000000-0000-0000-0000-000000000000'::uuid /*, ... */)
--
--   Option C — delete only listings owned by specific test accounts
--       select id from public.listings
--        where publisher_user_id in ('<user-uuid>'::uuid /*, ... */)

-- Sanity check before committing to it — how many rows does your choice hit?
select count(*) as listings_to_delete from public.listings;   -- Option A


-- =============================================================================
-- PART 3 — DELETE (ends in ROLLBACK; change to COMMIT when the counts are right)
-- =============================================================================

begin;

create temporary table doomed_listings on commit drop as
  -- >>> Replace this line if you chose Option B or C in PART 2. <<<
  select id from public.listings;

create temporary table doomed_leads on commit drop as
  select id from public.crm_leads
   where listing_id in (select id from doomed_listings);

-- --- RESTRICT dependants first (these block the listing delete) --------------

-- lead_events references BOTH listings (RESTRICT) and crm_leads, so it goes
-- before either of them.
delete from public.lead_events
 where listing_id in (select id from doomed_listings)
    or lead_id    in (select id from doomed_leads);

-- moderation_actions references reports (SET NULL). Clearing the actions first
-- keeps the moderation audit trail from pointing at reports that no longer
-- exist. If you would rather KEEP the moderation history, delete this statement
-- — the SET NULL will let reports go anyway.
delete from public.moderation_actions
 where report_id in (
   select id from public.reports
    where listing_id in (select id from doomed_listings)
 );

delete from public.reports   where listing_id in (select id from doomed_listings);
delete from public.inquiries where listing_id in (select id from doomed_listings);
delete from public.favorites where listing_id in (select id from doomed_listings);

-- --- CRM (crm_notes / crm_reminders cascade off crm_leads) -------------------

delete from public.crm_leads where id in (select id from doomed_leads);

-- --- The listings themselves ------------------------------------------------
-- These cascade automatically and need no explicit delete:
--   listing_details, listing_media, listing_prices, listing_status_history,
--   listing_visibility, listing_revisions, conversations (-> messages), viewings
-- These null out automatically: reviews.listing_id, crm_leads.listing_id

delete from public.listings where id in (select id from doomed_listings);

-- --- Verify -----------------------------------------------------------------

select
  (select count(*) from public.listings)      as listings_left,
  (select count(*) from public.listing_media) as media_left,
  (select count(*) from public.inquiries)     as inquiries_left,
  (select count(*) from public.favorites)     as favorites_left,
  (select count(*) from public.conversations) as conversations_left,
  (select count(*) from public.reports)       as reports_left,
  (select count(*) from public.crm_leads)     as crm_leads_left,
  (select count(*) from public.reviews)       as reviews_left,
  (select count(*) from public.profiles)      as profiles_left;

-- Change to COMMIT once the numbers above are what you expect.
rollback;


-- =============================================================================
-- PART 4 — AFTERWARDS
-- =============================================================================
-- 1. Storage is not touched above. Photos and videos of deleted listings are
--    still in the `listing-media` bucket. Remove them from the Supabase
--    dashboard (Storage -> bucket -> select -> delete) or via the storage API.
--    Re-run query 1d to see the sizes.
--
-- 2. Demo ACCOUNTS are deliberately not deleted here. Removing an auth user is
--    a separate operation (auth.users, via the dashboard or the admin API) and
--    the app now ships a self-serve deletion RPC — prefer that path so the same
--    anonymisation rules apply. Delete staff accounts only if you are certain.
--
-- 3. Re-run PART 1 afterwards and confirm the app's home feed is empty and does
--    not error, then publish the first real listings.
