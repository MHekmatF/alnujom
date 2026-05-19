-- Phase 10: Listing Creation - publisher listings view.
-- FR-015, SC-015; contracts/phase10-v-publisher-listings.md.
-- Query helper only: underlying table RLS remains the security boundary.

CREATE OR REPLACE VIEW public.v_publisher_listings AS
SELECT
  l.id                       AS listing_id,
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
  l.latitude,
  l.longitude,
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
  h.id                       AS latest_history_id,
  h.previous_status          AS latest_history_previous_status,
  h.new_status               AS latest_history_new_status,
  h.changed_by               AS latest_history_changed_by,
  h.changed_at               AS latest_history_changed_at,
  h.reason                   AS latest_history_reason,
  p.id                       AS primary_price_id,
  p.currency_code            AS primary_price_currency_code,
  p.amount                   AS primary_price_amount
FROM public.listings l
LEFT JOIN LATERAL (
  SELECT * FROM public.listing_status_history
  WHERE listing_id = l.id
  ORDER BY changed_at DESC
  LIMIT 1
) h ON true
LEFT JOIN public.listing_prices p
  ON p.listing_id = l.id AND p.is_primary = true
WHERE l.status <> 'deleted';

GRANT SELECT ON public.v_publisher_listings TO authenticated;
