-- Phase 10: Listing Creation - status history and listings audit triggers.
-- FR-004/004a/007; R-05 log_audit() remains unchanged; R-09 separates operational history from compliance audit.

CREATE TABLE IF NOT EXISTS public.listing_status_history (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      UUID         NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  previous_status TEXT,
  new_status      TEXT         NOT NULL,
  changed_by      UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  reason          TEXT
);

CREATE INDEX IF NOT EXISTS idx_listing_status_history_listing
  ON public.listing_status_history (listing_id, changed_at DESC);

ALTER TABLE public.listing_status_history ENABLE ROW LEVEL SECURITY;

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

CREATE OR REPLACE FUNCTION public.listing_status_transition_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (NEW.id, NULL, NEW.status, auth.uid(), NULL);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid(), NULL);
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS listing_status_transition_trigger ON public.listings;
CREATE TRIGGER listing_status_transition_trigger
  AFTER INSERT OR UPDATE OF status ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listing_status_transition_trigger_fn();

CREATE OR REPLACE FUNCTION public.listings_audit_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  status_verb TEXT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (auth.uid(), 'listing.created', 'listings', NEW.id::text, NULL, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (auth.uid(), 'listing.updated', 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      status_verb := CASE NEW.status
        WHEN 'pending_review' THEN 'listing.submitted'
        WHEN 'approved'       THEN 'listing.approved'
        WHEN 'rejected'       THEN 'listing.rejected'
        WHEN 'paused'         THEN 'listing.paused'
        WHEN 'expired'        THEN 'listing.expired'
        WHEN 'sold'           THEN 'listing.sold'
        WHEN 'rented'         THEN 'listing.rented'
        WHEN 'deleted'        THEN 'listing.deleted'
        ELSE NULL
      END;
      IF status_verb IS NOT NULL THEN
        INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
        VALUES (auth.uid(), status_verb, 'listings', NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (auth.uid(), 'listing.deleted', 'listings', OLD.id::text, to_jsonb(OLD), NULL);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS listings_audit_trigger ON public.listings;
CREATE TRIGGER listings_audit_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listings_audit_trigger_fn();
