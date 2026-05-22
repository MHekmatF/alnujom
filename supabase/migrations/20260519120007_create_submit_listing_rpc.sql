-- Phase 10: Listing Creation - submit_listing RPC.
-- FR-010/010a; R-06 RPC not Edge Function, matching Phase 7/9 precedent.

CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_listing       public.listings;
  v_profile_ok    BOOLEAN;
  v_price_count   INT;
  v_missing       TEXT[] := ARRAY[]::TEXT[];
  v_residential   BOOLEAN;
BEGIN
  SELECT * INTO v_listing FROM public.listings WHERE id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'listing not found';
  END IF;

  IF v_listing.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  SELECT (publisher_status = 'approved' AND account_status = 'approved') INTO v_profile_ok
    FROM public.profiles WHERE user_id = auth.uid();
  IF NOT COALESCE(v_profile_ok, false) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'publisher not approved';
  END IF;

  IF v_listing.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'listing not in editable status';
  END IF;

  -- array_append used instead of `v_missing || 'literal'` — Postgres parses
  -- TEXT[] || TEXT as appending a text-array literal, which fails for bare
  -- strings ("Array value must start with '{'"). array_append is unambiguous.
  IF length(trim(coalesce(v_listing.title, ''))) = 0          THEN v_missing := array_append(v_missing, 'listings.title');             END IF;
  IF v_listing.purpose IS NULL                                THEN v_missing := array_append(v_missing, 'listings.purpose');           END IF;
  IF v_listing.property_type IS NULL                          THEN v_missing := array_append(v_missing, 'listings.property_type');     END IF;
  IF v_listing.governorate_id IS NULL                         THEN v_missing := array_append(v_missing, 'listings.governorate_id');    END IF;
  IF v_listing.city_id IS NULL                                THEN v_missing := array_append(v_missing, 'listings.city_id');           END IF;
  IF v_listing.area_id IS NULL                                THEN v_missing := array_append(v_missing, 'listings.area_id');           END IF;
  IF length(trim(coalesce(v_listing.address_text, ''))) = 0   THEN v_missing := array_append(v_missing, 'listings.address_text');      END IF;
  IF v_listing.area_size IS NULL OR v_listing.area_size <= 0  THEN v_missing := array_append(v_missing, 'listings.area_size');         END IF;
  IF length(trim(coalesce(v_listing.phone, ''))) = 0
     AND length(trim(coalesce(v_listing.whatsapp, ''))) = 0   THEN v_missing := array_append(v_missing, 'listings.phone_or_whatsapp'); END IF;

  v_residential := v_listing.property_type IN ('apartment', 'villa');
  IF v_residential THEN
    IF v_listing.rooms IS NULL OR v_listing.rooms < 0          THEN v_missing := array_append(v_missing, 'listings.rooms');             END IF;
    IF v_listing.bathrooms IS NULL OR v_listing.bathrooms < 0  THEN v_missing := array_append(v_missing, 'listings.bathrooms');         END IF;
  END IF;

  SELECT count(*) INTO v_price_count
    FROM public.listing_prices WHERE listing_id = p_listing_id AND is_primary = true AND amount > 0;
  IF v_price_count <> 1 THEN
    v_missing := array_append(v_missing, 'listing_prices.primary');
  END IF;

  IF array_length(v_missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'missing required fields',
      DETAIL  = jsonb_build_object('missing_fields', to_jsonb(v_missing))::text;
  END IF;

  UPDATE public.listings SET status = 'pending_review' WHERE id = p_listing_id;

  RETURN jsonb_build_object(
    'listing_id',  p_listing_id,
    'status',      'pending_review',
    'submitted_at', now()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_listing(UUID) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_listing(UUID) TO authenticated;
