-- Phase 029 (F5) — amend listing_media cap trigger for 360° panorama rows.
--
-- Adds a third branch to public.listing_media_cap_check() capping the number of
-- 'panorama' rows per listing at 2 (mirrors the 2-video cap UX). A panorama is
-- an equirectangular image stored in the listing-images bucket with kind set to
-- the free-text token 'panorama'. The image / video / external_link branches are
-- copied VERBATIM from 20260522120001_create_listing_media.sql — only the new
-- ELSIF panorama branch is added.
--
-- NOTE: kind is a free-text column with a CHECK constraint
--   CHECK (kind IN ('image', 'video', 'external_link')).
-- The 'panorama' token is written via UPDATE (MediaSetPanorama / uploadPanorama),
-- and the CHECK was widened to include 'panorama' in spec 026. This migration is
-- INSERT-trigger-only; it does not touch the CHECK constraint.

CREATE OR REPLACE FUNCTION public.listing_media_cap_check()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_image_count INTEGER;
  v_video_count INTEGER;
  v_panorama_count INTEGER;
BEGIN
  IF NEW.kind = 'image' THEN
    SELECT count(*) INTO v_image_count
    FROM public.listing_media
    WHERE listing_id = NEW.listing_id AND kind = 'image';

    IF v_image_count >= 10 THEN
      RAISE EXCEPTION 'listing_media.cap_exceeded'
        USING
          ERRCODE = 'P0001',
          DETAIL = jsonb_build_object(
            'code', 'listing_media.cap_exceeded',
            'kind', 'image',
            'current_count', v_image_count,
            'max', 10
          )::TEXT;
    END IF;
  ELSIF NEW.kind IN ('video', 'external_link') THEN
    SELECT count(*) INTO v_video_count
    FROM public.listing_media
    WHERE listing_id = NEW.listing_id AND kind IN ('video', 'external_link');

    IF v_video_count >= 2 THEN
      RAISE EXCEPTION 'listing_media.cap_exceeded'
        USING
          ERRCODE = 'P0001',
          DETAIL = jsonb_build_object(
            'code', 'listing_media.cap_exceeded',
            'kind', 'video',
            'current_count', v_video_count,
            'max', 2
          )::TEXT;
    END IF;
  ELSIF NEW.kind = 'panorama' THEN
    SELECT count(*) INTO v_panorama_count
    FROM public.listing_media
    WHERE listing_id = NEW.listing_id AND kind = 'panorama';

    IF v_panorama_count >= 2 THEN
      RAISE EXCEPTION 'listing_media.cap_exceeded'
        USING
          ERRCODE = 'P0001',
          DETAIL = jsonb_build_object(
            'code', 'listing_media.cap_exceeded',
            'kind', 'panorama',
            'current_count', v_panorama_count,
            'max', 2
          )::TEXT;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.listing_media_cap_check() IS
  'Phase 11 FR-004 + Phase 029 F5 — enforces 10-image / 2-video / 2-panorama caps '
  'server-side. Combined predicate for video/external_link per Q2=D; panorama rows '
  '(equirectangular images uploaded via the 360° CTA) are capped at 2 per listing.';

-- The BEFORE INSERT trigger binding from 20260522120001 is unchanged; replacing
-- the function body re-uses the existing listing_media_cap_trigger.
