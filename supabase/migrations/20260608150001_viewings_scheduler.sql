-- Wave G3 (growth) — viewing/appointment scheduler.
CREATE TABLE IF NOT EXISTS public.viewings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  requester_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  publisher_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','confirmed','declined','cancelled')),
  note text CHECK (note IS NULL OR char_length(note) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT viewings_no_self CHECK (requester_user_id <> publisher_user_id)
);
CREATE INDEX IF NOT EXISTS idx_viewings_requester ON public.viewings (requester_user_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_viewings_publisher ON public.viewings (publisher_user_id, scheduled_at DESC);

ALTER TABLE public.viewings ENABLE ROW LEVEL SECURITY;
CREATE POLICY viewings_select_member ON public.viewings FOR SELECT TO authenticated
  USING (auth.uid() IN (requester_user_id, publisher_user_id));
CREATE POLICY viewings_insert_requester ON public.viewings FOR INSERT TO authenticated
  WITH CHECK (requester_user_id = auth.uid() AND requester_user_id <> publisher_user_id);
CREATE POLICY viewings_update_member ON public.viewings FOR UPDATE TO authenticated
  USING (auth.uid() IN (requester_user_id, publisher_user_id));

GRANT SELECT, INSERT, UPDATE ON public.viewings TO authenticated;
CREATE TRIGGER trg_viewings_set_updated_at BEFORE UPDATE ON public.viewings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.request_viewing(
  p_listing_id uuid, p_scheduled_at timestamptz, p_note text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_publisher uuid; v_buyer uuid := auth.uid(); v_id uuid;
BEGIN
  IF v_buyer IS NULL THEN RAISE EXCEPTION 'authentication required' USING errcode = '42501'; END IF;
  SELECT publisher_user_id INTO v_publisher FROM public.listings WHERE id = p_listing_id;
  IF v_publisher IS NULL THEN RAISE EXCEPTION 'listing not found' USING errcode = 'P0002'; END IF;
  IF v_publisher = v_buyer THEN RAISE EXCEPTION 'cannot request a viewing on your own listing' USING errcode = '22023'; END IF;
  INSERT INTO public.viewings (listing_id, requester_user_id, publisher_user_id, scheduled_at, note)
  VALUES (p_listing_id, v_buyer, v_publisher, p_scheduled_at, p_note)
  RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.update_viewing_status(p_viewing_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v public.viewings%ROWTYPE; v_uid uuid := auth.uid();
BEGIN
  SELECT * INTO v FROM public.viewings WHERE id = p_viewing_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'viewing not found' USING errcode = 'P0002'; END IF;
  IF v_uid NOT IN (v.requester_user_id, v.publisher_user_id) THEN
    RAISE EXCEPTION 'not authorized' USING errcode = '42501'; END IF;
  IF p_status NOT IN ('confirmed','declined','cancelled') THEN
    RAISE EXCEPTION 'invalid status' USING errcode = '22023'; END IF;
  IF p_status IN ('confirmed','declined') AND v_uid <> v.publisher_user_id THEN
    RAISE EXCEPTION 'only the publisher can confirm or decline' USING errcode = '42501'; END IF;
  UPDATE public.viewings SET status = p_status WHERE id = p_viewing_id;
END; $$;

REVOKE ALL ON FUNCTION public.request_viewing(uuid, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_viewing(uuid, timestamptz, text) TO authenticated;
REVOKE ALL ON FUNCTION public.update_viewing_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_viewing_status(uuid, text) TO authenticated;
