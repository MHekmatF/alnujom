-- Wave B (Phase 25 uplift v3) — featured listings (admin-granted, no payment).
-- A listing is "featured" while featured_until > now(). Admins/moderators with
-- listings.edit_any grant featuring for N days; nothing here charges money.

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS featured_until timestamptz;

COMMENT ON COLUMN public.listings.featured_until IS
  'Phase 25 — when set and > now(), the listing is featured (promoted) on the home carousel. Admin-granted via set_listing_featured(); no payment involved.';

-- Partial index: only featured rows, for the home carousel sort/filter.
CREATE INDEX IF NOT EXISTS idx_listings_featured_until
  ON public.listings (featured_until DESC)
  WHERE featured_until IS NOT NULL;

-- Admin RPC: grant/extend featuring for N days (N<=0 clears it).
-- SECURITY DEFINER + explicit permission gate (listings.edit_any). Returns the
-- new featured_until (NULL when cleared). Bypasses RLS by design (moderation).
CREATE OR REPLACE FUNCTION public.set_listing_featured(
  p_listing_id uuid,
  p_days integer
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new timestamptz;
BEGIN
  IF NOT public.current_user_has_permission('listings.edit_any') THEN
    RAISE EXCEPTION 'not authorized to feature listings' USING errcode = '42501';
  END IF;

  IF p_days IS NULL OR p_days <= 0 THEN
    v_new := NULL;  -- clear featuring
  ELSE
    -- Extend from the later of now() or any existing featured_until.
    v_new := greatest(
      now(),
      coalesce((SELECT featured_until FROM public.listings WHERE id = p_listing_id), now())
    ) + make_interval(days => p_days);
  END IF;

  UPDATE public.listings
     SET featured_until = v_new
   WHERE id = p_listing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing not found' USING errcode = 'P0002';
  END IF;

  RETURN v_new;
END;
$$;

-- New functions get default anon EXECUTE — revoke and scope to authenticated.
REVOKE ALL ON FUNCTION public.set_listing_featured(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_listing_featured(uuid, integer) TO authenticated;
