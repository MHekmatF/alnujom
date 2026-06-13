-- Phase 29 (029-crm-reels-growth) — W2: fix publisher_dashboard_counts() pending
-- bucket. The original (20260607120002) counted pending listings with
-- l.status = 'pending', but the listings status enum uses 'pending_review'
-- (20260519120002_create_listings.sql:11) — so the pending KPI always read 0.
-- This is a VERBATIM copy of the original RPC with ONLY that one predicate
-- changed to 'pending_review'. CREATE OR REPLACE preserves the existing grants.
create or replace function public.publisher_dashboard_counts()
returns table (
  total_listings bigint,
  active_listings bigint,
  pending_listings bigint,
  rejected_listings bigint,
  total_inquiries bigint,
  new_inquiries bigint,
  lead_events_total bigint
)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*) from listings l where l.publisher_user_id = auth.uid()),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'approved'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'pending_review'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'rejected'),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid()),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid() and i.status = 'new'),
    (select count(*) from lead_events e join listings l on l.id = e.listing_id where l.publisher_user_id = auth.uid());
$$;

revoke all on function public.publisher_dashboard_counts() from public;
revoke all on function public.publisher_dashboard_counts() from anon;
grant execute on function public.publisher_dashboard_counts() to authenticated;
