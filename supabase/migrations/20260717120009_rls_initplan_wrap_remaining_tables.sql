-- 20260717120009_rls_initplan_wrap_remaining_tables
--
-- QA E2E perf (PERF-M1, completion): wrap auth.uid() as (select auth.uid()) on the
-- remaining public tables so it evaluates once per query (an InitPlan) instead of once
-- per row. Semantically IDENTICAL — generated + reviewed from pg_policies; row-dependent
-- predicates (is_agency_member, current_user_has_permission, EXISTS subqueries) are left
-- untouched. Completes the wrap started for the hot feed/search/chat tables in
-- 20260717120008. Verified live: 0 unwrapped auth.uid() remain in any public policy.
--
-- Residual (documented follow-up, NOT done here — higher risk / lower value):
--   * wrap current_user_has_permission()/current_user_is_admin() calls,
--   * merge the 27 duplicate permissive policies (advisor multiple_permissive_policies).
alter policy agencies_select_authenticated on public.agencies using (((status = 'approved'::agency_status) OR (owner_user_id = (select auth.uid())) OR is_agency_member(id) OR current_user_has_permission('agencies.view'::text)));
alter policy agency_members_select on public.agency_members using (((user_id = (select auth.uid())) OR is_agency_member(agency_id) OR current_user_has_permission('agencies.view'::text)));
alter policy crm_leads_delete_owner on public.crm_leads using ((publisher_user_id = (select auth.uid())));
alter policy crm_leads_insert_owner on public.crm_leads with check (((publisher_user_id = (select auth.uid())) AND ((source_inquiry_id IS NULL) OR (EXISTS ( SELECT 1 FROM (inquiries i JOIN listings l ON ((l.id = i.listing_id))) WHERE ((i.id = crm_leads.source_inquiry_id) AND (l.publisher_user_id = (select auth.uid()))))))));
alter policy crm_leads_select_owner on public.crm_leads using ((publisher_user_id = (select auth.uid())));
alter policy crm_leads_update_owner on public.crm_leads using ((publisher_user_id = (select auth.uid())));
alter policy crm_notes_delete_owner on public.crm_notes using ((publisher_user_id = (select auth.uid())));
alter policy crm_notes_insert_owner on public.crm_notes with check (((publisher_user_id = (select auth.uid())) AND (EXISTS ( SELECT 1 FROM crm_leads cl WHERE ((cl.id = crm_notes.lead_id) AND (cl.publisher_user_id = (select auth.uid())))))));
alter policy crm_notes_select_owner on public.crm_notes using ((publisher_user_id = (select auth.uid())));
alter policy crm_notes_update_owner on public.crm_notes using ((publisher_user_id = (select auth.uid())));
alter policy crm_reminders_delete_owner on public.crm_reminders using ((publisher_user_id = (select auth.uid())));
alter policy crm_reminders_insert_owner on public.crm_reminders with check (((publisher_user_id = (select auth.uid())) AND (EXISTS ( SELECT 1 FROM crm_leads cl WHERE ((cl.id = crm_reminders.lead_id) AND (cl.publisher_user_id = (select auth.uid())))))));
alter policy crm_reminders_select_owner on public.crm_reminders using ((publisher_user_id = (select auth.uid())));
alter policy crm_reminders_update_owner on public.crm_reminders using ((publisher_user_id = (select auth.uid())));
alter policy inquiries_select_publisher on public.inquiries using ((EXISTS ( SELECT 1 FROM listings l WHERE ((l.id = inquiries.listing_id) AND (l.publisher_user_id = (select auth.uid()))))));
alter policy inquiries_select_sender on public.inquiries using (((sender_user_id = (select auth.uid())) AND (sender_user_id IS NOT NULL)));
alter policy inquiries_update_publisher on public.inquiries using ((EXISTS ( SELECT 1 FROM listings l WHERE ((l.id = inquiries.listing_id) AND (l.publisher_user_id = (select auth.uid())))))) with check ((EXISTS ( SELECT 1 FROM listings l WHERE ((l.id = inquiries.listing_id) AND (l.publisher_user_id = (select auth.uid()))))));
alter policy lead_events_select_publisher on public.lead_events using ((EXISTS ( SELECT 1 FROM listings l WHERE ((l.id = lead_events.listing_id) AND (l.publisher_user_id = (select auth.uid()))))));
alter policy listing_revisions_owner_delete on public.listing_revisions using ((publisher_user_id = (select auth.uid())));
alter policy listing_revisions_owner_insert on public.listing_revisions with check ((publisher_user_id = (select auth.uid())));
alter policy listing_revisions_owner_select on public.listing_revisions using ((publisher_user_id = (select auth.uid())));
alter policy listing_revisions_owner_update on public.listing_revisions using ((publisher_user_id = (select auth.uid()))) with check ((publisher_user_id = (select auth.uid())));
alter policy notification_tokens_select_self on public.notification_tokens using ((user_id = (select auth.uid())));
alter policy notifications_select_self on public.notifications using ((recipient_user_id = (select auth.uid())));
alter policy profiles_select_self on public.profiles using (((select auth.uid()) = user_id));
alter policy profiles_update_self on public.profiles using (((select auth.uid()) = user_id)) with check (((select auth.uid()) = user_id));
alter policy reports_select_self_or_admin on public.reports using (((reporter_user_id = (select auth.uid())) OR current_user_has_permission('reports.manage'::text)));
alter policy reviews_delete_own on public.reviews using ((reviewer_user_id = (select auth.uid())));
alter policy reviews_insert_own on public.reviews with check (((reviewer_user_id = (select auth.uid())) AND (reviewer_user_id <> target_user_id)));
alter policy reviews_update_own on public.reviews using ((reviewer_user_id = (select auth.uid()))) with check ((reviewer_user_id = (select auth.uid())));
alter policy saved_searches_delete_own on public.saved_searches using ((user_id = (select auth.uid())));
alter policy saved_searches_insert_own on public.saved_searches with check ((user_id = (select auth.uid())));
alter policy saved_searches_select_own on public.saved_searches using ((user_id = (select auth.uid())));
alter policy saved_searches_update_own on public.saved_searches using ((user_id = (select auth.uid()))) with check ((user_id = (select auth.uid())));
alter policy user_preferences_delete_self on public.user_preferences using (((select auth.uid()) = user_id));
alter policy user_preferences_insert_self on public.user_preferences with check (((select auth.uid()) = user_id));
alter policy user_preferences_select_self on public.user_preferences using (((select auth.uid()) = user_id));
alter policy user_preferences_update_self on public.user_preferences using (((select auth.uid()) = user_id)) with check (((select auth.uid()) = user_id));
alter policy user_roles_self_read on public.user_roles using (((select auth.uid()) = user_id));
alter policy viewings_insert_requester on public.viewings with check (((requester_user_id = (select auth.uid())) AND (requester_user_id <> publisher_user_id)));
alter policy viewings_select_member on public.viewings using ((((select auth.uid()) = requester_user_id) OR ((select auth.uid()) = publisher_user_id)));
alter policy viewings_update_member on public.viewings using ((((select auth.uid()) = requester_user_id) OR ((select auth.uid()) = publisher_user_id)));
