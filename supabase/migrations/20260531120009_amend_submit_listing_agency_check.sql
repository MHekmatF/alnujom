-- Phase 19 (spec/019-agencies) — Migration 9/13.
-- R-143 integration check: amend submit_listing for the agency-membership soft gate (FR-020).
--
-- This CREATE OR REPLACE re-bases the LATEST submit_listing body
-- (20260522120004_amend_submit_listing_rpc_for_media_minimum.sql) VERBATIM —
-- profile approval, editable-status guard, all required-field checks, the residential
-- rules, the >=1 primary-price check, the Phase 11 media-minimum check, and the JSONB
-- return shape are ALL preserved unchanged.
--
-- The ONLY addition is the agency-membership branch, inserted immediately BEFORE the
-- `UPDATE public.listings SET status='pending_review'` line: when a listing carries an
-- agency_id, the submitter must be an active member of that agency AND the agency must be
-- in {pending,approved} (a rejected/suspended agency blocks NEW publishing — R-149).
-- The per-user publish RLS (listings_insert_owner / listings_update_owner, 20260519120002)
-- is UNTOUCHED — this is a soft gate, not a second publish authority (Q1=A / R-143).
--
-- R-35: the Phase 10/11 migrations 20260519120007 + 20260522120004 are NOT edited in
--       place — this migration supersedes the body via CREATE OR REPLACE. The existing
--       EXECUTE grant to authenticated is preserved automatically by CREATE OR REPLACE.

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

  -- (5b) PHASE 19 ADDITION (FR-020 / R-143): agency-membership soft gate.
  -- When the listing carries an agency_id, the submitter must be an ACTIVE member of
  -- that agency AND the agency must be in {pending,approved} (not rejected/suspended,
  -- R-149). This validates membership at publish time WITHOUT touching the per-user
  -- publish RLS — agency approval is NOT a second publish authority (Q1=A soft gate).
  IF v_listing.agency_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.agency_members m
      JOIN public.agencies a ON a.id = m.agency_id
      WHERE m.agency_id = v_listing.agency_id
        AND m.user_id   = auth.uid()
        AND m.status    = 'active'
        AND a.status IN ('pending','approved')         -- not rejected/suspended (R-149)
    ) THEN
      RAISE EXCEPTION 'not_an_agency_member' USING ERRCODE = '42501';
    END IF;
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
  'Phase 10 RPC, amended in Phase 11 (20260522120004) for the Q1=A media-minimum '
  'check (FR-022), amended in Phase 19 (20260531120009) for the FR-020/R-143 '
  'agency-membership soft gate. Validates Phase 10 required fields PLUS >= 1 '
  'listing_media row with kind=''image'' AND watermarked=true PLUS — when '
  'agency_id is set — active membership of an agency in {pending,approved} '
  '(not_an_agency_member otherwise). The per-user publish RLS is untouched. '
  'Errors emit missing_fields[] in SQLSTATE 22023 DETAIL payload. '
  'Phase 10/11 migrations 20260519120007 + 20260522120004 are NOT edited per R-35.';

-- No REVOKE/GRANT needed: CREATE OR REPLACE preserves the existing EXECUTE grant
-- to authenticated set in migration 20260519120007_create_submit_listing_rpc.sql.
