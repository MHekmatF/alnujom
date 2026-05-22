-- Mirror of the inline RLS policies in supabase/migrations/20260519120006_create_listing_status_history.sql.
-- R-02 dual-storage invariant: both files MUST be kept in sync at PR review.
-- NO UPDATE POLICY. NO DELETE POLICY. Table is append-only per FR-007.

DROP POLICY IF EXISTS listing_status_history_insert_trigger_only ON public.listing_status_history;
CREATE POLICY listing_status_history_insert_trigger_only ON public.listing_status_history
  FOR INSERT
  WITH CHECK (pg_trigger_depth() > 0);

DROP POLICY IF EXISTS listing_status_history_select_owner ON public.listing_status_history;
CREATE POLICY listing_status_history_select_owner ON public.listing_status_history
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.listings l WHERE l.id = listing_status_history.listing_id AND l.publisher_user_id = auth.uid())
    OR public.current_user_has_permission('listings.view_all')
  );
