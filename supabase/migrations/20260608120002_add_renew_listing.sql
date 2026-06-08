-- Wave C (Phase 25 uplift v3) — listing renewal.
-- Expired listings are already hidden publicly by the listings_select_public
-- RLS policy (expires_at > now()); owners still see them via listings_select_owner.
-- listings_update_owner only permits owner UPDATE for draft/rejected, so renewal
-- must be a SECURITY DEFINER RPC. It only extends expires_at (never touches
-- status, so the status-transition trigger does not fire).
CREATE OR REPLACE FUNCTION public.renew_listing(
  p_listing_id uuid,
  p_days integer DEFAULT 30
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
  v_new timestamptz;
BEGIN
  SELECT publisher_user_id INTO v_owner FROM public.listings WHERE id = p_listing_id;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'listing not found' USING errcode = 'P0002';
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not authorized to renew this listing' USING errcode = '42501';
  END IF;
  IF p_days IS NULL OR p_days <= 0 THEN
    p_days := 30;
  END IF;
  v_new := greatest(
    now(),
    coalesce((SELECT expires_at FROM public.listings WHERE id = p_listing_id), now())
  ) + make_interval(days => p_days);
  UPDATE public.listings SET expires_at = v_new WHERE id = p_listing_id;
  RETURN v_new;
END;
$$;

REVOKE ALL ON FUNCTION public.renew_listing(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_listing(uuid, integer) TO authenticated;
