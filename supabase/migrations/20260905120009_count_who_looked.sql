-- Count who looked.
--
-- Review 2026-09-05 §4 G12 (plan A35; July FINDINGS UX-4). Opening a listing
-- recorded nothing, so publishers had no idea whether anyone saw their
-- property; only contact actions were counted. This records one row per
-- viewer per listing per day and shows the total on the publisher's card.
--
-- Design notes, each the answer to a wrong first draft:
--   * The count lives in `listing_views`, not in a column on `listings`. A
--     counter column would fire the audit trigger and bump `updated_at` on
--     every view — the audit-log flood A22 just fixed, plus the feed order
--     drifting under readers' feet.
--   * The viewer key is `auth.uid()` for a signed-in person, else a random
--     install id the app keeps in secure storage. It is never an IP (PostgREST
--     shows loopback for everyone) and never anything a person typed.
--   * The publisher opening their own listing does not count, and one listing
--     cannot collect more than 5,000 distinct views in a day — a runaway-
--     script ceiling, not a business limit.
--   * `v_publisher_listings` is security_invoker, so the correlated count runs
--     as the publisher: a SELECT policy scoped to their own listings is what
--     makes it non-zero.

CREATE TABLE IF NOT EXISTS public.listing_views (
  listing_id uuid NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  viewer_key text NOT NULL,
  viewed_on  date NOT NULL DEFAULT current_date,
  PRIMARY KEY (listing_id, viewer_key, viewed_on)
);
ALTER TABLE public.listing_views ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.listing_views FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS listing_views_select_publisher ON public.listing_views;
CREATE POLICY listing_views_select_publisher ON public.listing_views
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
     WHERE l.id = listing_views.listing_id
       AND l.publisher_user_id = (SELECT auth.uid())));
GRANT SELECT ON public.listing_views TO authenticated;

CREATE OR REPLACE FUNCTION public.record_listing_view(p_listing_id uuid, p_viewer_key text DEFAULT NULL::text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_key       text;
  v_publisher uuid;
  v_status    text;
BEGIN
  v_key := coalesce(auth.uid()::text, nullif(btrim(p_viewer_key), ''));
  IF v_key IS NULL OR length(v_key) > 64 OR v_key !~ '^[A-Za-z0-9-]+$' THEN
    RETURN;  -- nothing to key on: not an error, just not counted
  END IF;
  SELECT status, publisher_user_id INTO v_status, v_publisher
    FROM public.listings WHERE id = p_listing_id;
  IF v_status IS DISTINCT FROM 'approved' THEN RETURN; END IF;
  IF auth.uid() IS NOT NULL AND v_publisher = auth.uid() THEN RETURN; END IF;
  IF (SELECT count(*) FROM public.listing_views v
       WHERE v.listing_id = p_listing_id AND v.viewed_on = current_date) >= 5000 THEN
    RETURN;
  END IF;
  INSERT INTO public.listing_views (listing_id, viewer_key)
  VALUES (p_listing_id, v_key)
  ON CONFLICT DO NOTHING;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_listing_view(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_listing_view(uuid, text) TO anon, authenticated;
COMMENT ON FUNCTION public.record_listing_view(uuid, text) IS
  'One row per viewer per listing per day (plan A35). Signed-in viewers key on their id, guests on an install id; the publisher never counts; 5,000 distinct views per listing per day is the ceiling.';

-- The publisher's own list carries the total. Same columns in the same order,
-- one more at the end; security_invoker stays on.
CREATE OR REPLACE VIEW public.v_publisher_listings AS
 SELECT l.id AS listing_id,
    l.publisher_user_id,
    l.agency_id,
    l.purpose,
    l.property_type,
    l.status,
    l.title,
    l.governorate_id,
    l.city_id,
    l.area_id,
    l.address_text,
    l.location_visibility,
    l.phone,
    l.whatsapp,
    l.contact_name_visibility,
    l.area_size,
    l.rooms,
    l.bathrooms,
    l.floor,
    l.created_at,
    l.updated_at,
    l.published_at,
    l.expires_at,
    h.id AS latest_history_id,
    h.previous_status AS latest_history_previous_status,
    h.new_status AS latest_history_new_status,
    h.changed_by AS latest_history_changed_by,
    h.changed_at AS latest_history_changed_at,
    h.reason AS latest_history_reason,
    p.id AS primary_price_id,
    p.currency_code AS primary_price_currency_code,
    p.amount AS primary_price_amount,
    (SELECT count(*) FROM public.listing_views v WHERE v.listing_id = l.id)::integer AS views_count
   FROM public.listings l
     LEFT JOIN LATERAL ( SELECT listing_status_history.id,
            listing_status_history.listing_id,
            listing_status_history.previous_status,
            listing_status_history.new_status,
            listing_status_history.changed_by,
            listing_status_history.changed_at,
            listing_status_history.reason
           FROM public.listing_status_history
          WHERE listing_status_history.listing_id = l.id
          ORDER BY listing_status_history.changed_at DESC
         LIMIT 1) h ON true
     LEFT JOIN public.listing_prices p ON p.listing_id = l.id AND p.is_primary = true
  WHERE l.status <> 'deleted'::text;
ALTER VIEW public.v_publisher_listings SET (security_invoker = true);

NOTIFY pgrst, 'reload schema';
