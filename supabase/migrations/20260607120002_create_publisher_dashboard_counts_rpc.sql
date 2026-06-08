-- Phase 25 uplift v2 — publisher dashboard KPI counts for the signed-in user.
-- SECURITY DEFINER + explicit auth.uid() filter so a publisher only ever sees
-- their own rollups. (The "signed-in users can execute SECURITY DEFINER"
-- advisor WARN is expected/intentional — same pattern as admin_dashboard_counts.)
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
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'pending'),
    (select count(*) from listings l where l.publisher_user_id = auth.uid() and l.status = 'rejected'),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid()),
    (select count(*) from inquiries i join listings l on l.id = i.listing_id where l.publisher_user_id = auth.uid() and i.status = 'new'),
    (select count(*) from lead_events e join listings l on l.id = e.listing_id where l.publisher_user_id = auth.uid());
$$;

revoke all on function public.publisher_dashboard_counts() from public;
revoke all on function public.publisher_dashboard_counts() from anon;
grant execute on function public.publisher_dashboard_counts() to authenticated;
