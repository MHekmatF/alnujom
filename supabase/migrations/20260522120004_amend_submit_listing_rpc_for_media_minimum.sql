-- Phase 11: Listing Media Upload, Client-Side Watermark & Storage Policies.
-- FR-022 (Q1=A media-minimum check in submit_listing).
-- R-31: step 5a placed BETWEEN the price-count check and the IF-RAISE block.
-- R-35: Phase 10 migration 20260519120007_create_submit_listing_rpc.sql is NOT
--        edited — it is immutable. This migration supersedes the function body
--        via CREATE OR REPLACE FUNCTION. The existing EXECUTE grant to authenticated
--        is preserved automatically by CREATE OR REPLACE.
-- SC-017: submitting a draft with zero watermarked images produces SQLSTATE 22023
--         with missing_fields[] containing 'listing_media.images_below_minimum'.

CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID)
RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_listing       public.listings;
  v_profile_ok    BOOLEAN;
  v_price_count   INT;
  v_image_count   INT;
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

  -- (5a) PHASE 11 ADDITION (FR-022 / Q1=A): media-minimum check.
  -- Requires at least one listing_media row with kind='image' AND watermarked=true
  -- before the listing can be submitted for review. Folded into v_missing[] so the
  -- existing Phase 10 submit_failure_dialog iterates the key without code changes.
  SELECT count(*) INTO v_image_count
    FROM public.listing_media
    WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true;
  IF v_image_count = 0 THEN
    v_missing := array_append(v_missing, 'listing_media.images_below_minimum');
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

COMMENT ON FUNCTION public.submit_listing(UUID) IS
  'Phase 10 RPC, amended in Phase 11 (migration 20260522120004) for the Q1=A '
  'media-minimum check (FR-022). Validates Phase 10 required fields PLUS >= 1 '
  'listing_media row with kind=''image'' AND watermarked=true. Errors emit '
  'missing_fields[] in SQLSTATE 22023 DETAIL payload. '
  'Phase 10 migration 20260519120007 is NOT edited per R-35.';

-- No REVOKE/GRANT needed: CREATE OR REPLACE preserves the existing EXECUTE grant
-- to authenticated that was set in migration 20260519120007_create_submit_listing_rpc.sql.
