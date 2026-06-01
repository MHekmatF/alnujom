-- Phase 21 — admin write RPCs. SECURITY DEFINER; each re-checks ads.manage (FR-019, R-165).
-- Placements passed as JSONB array: '[{"placement_key":"home_top_banner","priority":10}, ...]'.

CREATE OR REPLACE FUNCTION public.create_ad(
  p_title       TEXT,
  p_image_path  TEXT,
  p_caption_ar  TEXT,
  p_caption_en  TEXT,
  p_link_kind   TEXT,
  p_link_value  TEXT,
  p_start_at    TIMESTAMPTZ,
  p_end_at      TIMESTAMPTZ,
  p_is_active   BOOLEAN,
  p_placements  JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ad_id UUID;
  v_elem  JSONB;
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.ads (
    title, image_path, caption_ar, caption_en, link_kind, link_value,
    start_at, end_at, is_active, created_by
  ) VALUES (
    p_title, p_image_path, p_caption_ar, p_caption_en, p_link_kind, p_link_value,
    p_start_at, p_end_at, COALESCE(p_is_active, true), auth.uid()
  ) RETURNING id INTO v_ad_id;

  IF p_placements IS NOT NULL THEN
    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_placements) LOOP
      INSERT INTO public.ad_placements (ad_id, placement_key, priority)
      VALUES (v_ad_id, v_elem->>'placement_key', COALESCE((v_elem->>'priority')::int, 0));
    END LOOP;
  END IF;

  RETURN v_ad_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_ad(
  p_ad_id       UUID,
  p_title       TEXT,
  p_image_path  TEXT,
  p_caption_ar  TEXT,
  p_caption_en  TEXT,
  p_link_kind   TEXT,
  p_link_value  TEXT,
  p_start_at    TIMESTAMPTZ,
  p_end_at      TIMESTAMPTZ,
  p_is_active   BOOLEAN,
  p_placements  JSONB
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_elem JSONB;
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.ads SET
    title = p_title, image_path = p_image_path,
    caption_ar = p_caption_ar, caption_en = p_caption_en,
    link_kind = p_link_kind, link_value = p_link_value,
    start_at = p_start_at, end_at = p_end_at, is_active = p_is_active
  WHERE id = p_ad_id AND archived_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503';
  END IF;

  -- Replace placement set atomically.
  DELETE FROM public.ad_placements WHERE ad_id = p_ad_id;
  IF p_placements IS NOT NULL THEN
    FOR v_elem IN SELECT * FROM jsonb_array_elements(p_placements) LOOP
      INSERT INTO public.ad_placements (ad_id, placement_key, priority)
      VALUES (p_ad_id, v_elem->>'placement_key', COALESCE((v_elem->>'priority')::int, 0));
    END LOOP;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_ad_active(p_ad_id UUID, p_is_active BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.ads SET is_active = p_is_active WHERE id = p_ad_id AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_ad(p_ad_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.current_user_has_permission('ads.manage') THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;
  UPDATE public.ads SET archived_at = now() WHERE id = p_ad_id AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'ad_not_found' USING ERRCODE = '23503'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_ad_active(UUID,BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archive_ad(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_ad_active(UUID,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_ad(UUID) TO authenticated;
