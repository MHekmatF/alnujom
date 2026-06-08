-- Wave G2 (growth) — saved-search alerts. When a listing becomes publicly
-- visible, insert a 'saved_search_match' notification for every saved_search
-- (other than the publisher's own) whose jsonb filters match the listing.
-- SECURITY DEFINER so it can insert notifications for other recipients.
CREATE OR REPLACE FUNCTION public.notify_saved_search_matches()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec record;
BEGIN
  -- Only fire when the listing is (newly) publicly visible.
  IF NOT (NEW.status = 'approved'
          AND (NEW.published_at IS NULL OR NEW.published_at <= now())
          AND (NEW.expires_at IS NULL OR NEW.expires_at > now())) THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM 'approved' THEN
    RETURN NEW;  -- already approved before; not a new appearance
  END IF;

  FOR rec IN
    SELECT s.id, s.user_id, s.label, s.filters
    FROM public.saved_searches s
    WHERE s.user_id <> NEW.publisher_user_id
      AND (s.filters->>'purpose' IS NULL OR s.filters->>'purpose' = NEW.purpose)
      AND (s.filters->>'property_type' IS NULL OR s.filters->>'property_type' = NEW.property_type)
      AND (s.filters->>'governorate_id' IS NULL OR s.filters->>'governorate_id' = NEW.governorate_id::text)
      AND (s.filters->>'city_id' IS NULL OR s.filters->>'city_id' = NEW.city_id::text)
      AND (s.filters->>'area_id' IS NULL OR s.filters->>'area_id' = NEW.area_id::text)
      AND (s.filters->>'rooms' IS NULL OR (NEW.rooms IS NOT NULL AND
           CASE WHEN s.filters->>'rooms_mode' = 'atLeast'
                THEN NEW.rooms >= (s.filters->>'rooms')::int
                ELSE NEW.rooms = (s.filters->>'rooms')::int END))
      AND (s.filters->>'bathrooms' IS NULL OR (NEW.bathrooms IS NOT NULL AND
           CASE WHEN s.filters->>'bathrooms_mode' = 'atLeast'
                THEN NEW.bathrooms >= (s.filters->>'bathrooms')::int
                ELSE NEW.bathrooms = (s.filters->>'bathrooms')::int END))
      AND (s.filters->>'area_size_min' IS NULL OR (NEW.area_size IS NOT NULL AND NEW.area_size >= (s.filters->>'area_size_min')::numeric))
      AND (s.filters->>'area_size_max' IS NULL OR (NEW.area_size IS NOT NULL AND NEW.area_size <= (s.filters->>'area_size_max')::numeric))
  LOOP
    INSERT INTO public.notifications (recipient_user_id, type, params)
    VALUES (rec.user_id, 'saved_search_match', jsonb_build_object(
      'listing_id', NEW.id,
      'listing_title', NEW.title,
      'saved_search_id', rec.id,
      'saved_search_label', rec.label
    ));
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_listings_saved_search_alert ON public.listings;
CREATE TRIGGER trg_listings_saved_search_alert
AFTER INSERT OR UPDATE OF status ON public.listings
FOR EACH ROW EXECUTE FUNCTION public.notify_saved_search_matches();
