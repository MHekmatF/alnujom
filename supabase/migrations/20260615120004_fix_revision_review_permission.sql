-- Phase 031 follow-up — fix the stay-live revision admin gate.
--
-- BUG: apply_listing_revision + reject_listing_revision gated on
--   current_user_has_permission('listings.review'), but 'listings.review' is
--   NOT a permission in this project's scheme (the listing-moderation perms are
--   'listings.approve' and 'listings.reject'). The check therefore ALWAYS
--   returned false, so no admin could ever apply or reject a revision (42501).
--   Found in on-device QA: publisher could stage+submit a revision, but the
--   admin Approve/Reject buttons were silent no-ops.
--
-- FIX: re-create both RPCs with the real permission keys — apply gates on
--   'listings.approve', reject gates on 'listings.reject'. Bodies are otherwise
--   identical to migration 20260615120001. CREATE OR REPLACE is idempotent and
--   preserves grants.

CREATE OR REPLACE FUNCTION public.apply_listing_revision(p_revision_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_rev public.listing_revisions%ROWTYPE; v_listing_id UUID; v_proposed JSONB; v_manifest JSONB;
  v_currency TEXT; v_amount NUMERIC; v_item JSONB; v_keep_paths TEXT[];
BEGIN
  IF NOT public.current_user_has_permission('listings.approve') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'permission denied'; END IF;
  SELECT lr.* INTO v_rev FROM public.listing_revisions AS lr WHERE lr.id = p_revision_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found'; END IF;
  IF v_rev.status <> 'pending_review' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'revision is not pending review'; END IF;
  v_listing_id := v_rev.listing_id; v_proposed := v_rev.proposed; v_manifest := COALESCE(v_rev.media_manifest, '[]'::jsonb);
  UPDATE public.listings AS l
     SET title = COALESCE(v_proposed->>'title', l.title),
         purpose = COALESCE(v_proposed->>'purpose', l.purpose),
         property_type = COALESCE(v_proposed->>'property_type', l.property_type),
         governorate_id = NULLIF(v_proposed->>'governorate_id', '')::uuid,
         city_id = NULLIF(v_proposed->>'city_id', '')::uuid,
         area_id = NULLIF(v_proposed->>'area_id', '')::uuid,
         address_text = v_proposed->>'address_text',
         latitude = NULLIF(v_proposed->>'latitude', '')::numeric,
         longitude = NULLIF(v_proposed->>'longitude', '')::numeric,
         location_visibility = COALESCE(v_proposed->>'location_visibility', l.location_visibility),
         contact_name_visibility = COALESCE(v_proposed->>'contact_name_visibility', l.contact_name_visibility),
         phone = v_proposed->>'phone', whatsapp = v_proposed->>'whatsapp',
         area_size = NULLIF(v_proposed->>'area_size', '')::numeric,
         rooms = NULLIF(v_proposed->>'rooms', '')::smallint,
         bathrooms = NULLIF(v_proposed->>'bathrooms', '')::smallint,
         floor = NULLIF(v_proposed->>'floor', '')::smallint
   WHERE l.id = v_listing_id;
  INSERT INTO public.listing_details AS ld (listing_id, description, amenities, year_built, furnished, parking)
  VALUES (v_listing_id, v_proposed->>'description', COALESCE(v_proposed->'amenities', '[]'::jsonb),
    NULLIF(v_proposed->>'year_built', '')::smallint, (v_proposed->>'furnished')::boolean, (v_proposed->>'parking')::boolean)
  ON CONFLICT (listing_id) DO UPDATE SET description = EXCLUDED.description, amenities = EXCLUDED.amenities,
    year_built = EXCLUDED.year_built, furnished = EXCLUDED.furnished, parking = EXCLUDED.parking;
  v_currency := NULLIF(v_proposed->>'price_currency_code', ''); v_amount := NULLIF(v_proposed->>'price_amount', '')::numeric;
  IF v_currency IS NOT NULL AND v_amount IS NOT NULL AND v_amount > 0 THEN
    DELETE FROM public.listing_prices AS lp WHERE lp.listing_id = v_listing_id AND lp.is_primary = true AND lp.currency_code <> v_currency;
    INSERT INTO public.listing_prices AS lp (listing_id, currency_code, amount, is_primary)
    VALUES (v_listing_id, v_currency, v_amount, true)
    ON CONFLICT (listing_id, currency_code) DO UPDATE SET amount = EXCLUDED.amount, is_primary = true;
  END IF;
  SELECT COALESCE(array_agg(elem->>'storage_path'), ARRAY[]::text[]) INTO v_keep_paths
  FROM jsonb_array_elements(v_manifest) AS elem WHERE elem->>'storage_path' IS NOT NULL;
  DELETE FROM public.listing_media AS lm WHERE lm.listing_id = v_listing_id
    AND (lm.storage_path IS NULL OR NOT (lm.storage_path = ANY (v_keep_paths)));
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_manifest) LOOP
    CONTINUE WHEN (v_item->>'storage_path') IS NULL;
    UPDATE public.listing_media AS lm
       SET kind = COALESCE(v_item->>'kind', lm.kind), is_main = COALESCE((v_item->>'is_main')::boolean, false),
           ordering = COALESCE((v_item->>'ordering')::int, lm.ordering), thumbnail_path = v_item->>'thumbnail_path'
     WHERE lm.listing_id = v_listing_id AND lm.storage_path = (v_item->>'storage_path');
    IF NOT FOUND THEN
      INSERT INTO public.listing_media (listing_id, kind, storage_path, external_url, ordering, is_main, watermarked, thumbnail_path)
      VALUES (v_listing_id, COALESCE(v_item->>'kind', 'image'), v_item->>'storage_path', NULL,
        COALESCE((v_item->>'ordering')::int, 0), COALESCE((v_item->>'is_main')::boolean, false), true, v_item->>'thumbnail_path');
    END IF;
  END LOOP;
  UPDATE public.listing_revisions AS lr SET status = 'approved' WHERE lr.id = p_revision_id;
  INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
  VALUES (auth.uid(), 'listing_revision.applied', 'listing_revisions', p_revision_id::text,
    to_jsonb(v_rev), jsonb_build_object('listing_id', v_listing_id, 'status', 'approved'));
END; $function$;

CREATE OR REPLACE FUNCTION public.reject_listing_revision(p_revision_id uuid, p_reason jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_rev public.listing_revisions%ROWTYPE;
BEGIN
  IF NOT public.current_user_has_permission('listings.reject') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'permission denied'; END IF;
  SELECT lr.* INTO v_rev FROM public.listing_revisions AS lr WHERE lr.id = p_revision_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found'; END IF;
  IF v_rev.status <> 'pending_review' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'revision is not pending review'; END IF;
  UPDATE public.listing_revisions AS lr SET status = 'rejected', reject_reason = p_reason WHERE lr.id = p_revision_id;
  INSERT INTO public.audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
  VALUES (auth.uid(), 'listing_revision.rejected', 'listing_revisions', p_revision_id::text,
    to_jsonb(v_rev), jsonb_build_object('status', 'rejected', 'reject_reason', p_reason));
END; $function$;
