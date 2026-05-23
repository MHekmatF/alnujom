-- Phase 11: Listing Media Upload, Client-Side Watermark & Storage Policies.
-- FR-001 (table), FR-002 (CHECK constraints), FR-003 (partial unique index),
-- FR-004 (cap trigger), FR-005 (audit triggers), FR-006 (RLS policies).
-- R-22: three pubspec packages (image_picker, image, flutter_image_compress).
-- Q1=A: media-minimum enforced at submit_listing (migration 20260522120004).
-- Q2=D: external_link kind retained in schema enum for forward-compat; Phase 11 UI
--        inserts only 'image' and 'video'.
-- R-35: Phase 10 migration 20260519120007 is NOT edited — immutable invariant.

-- ===========================================================================
-- 1. CREATE TABLE public.listing_media
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.listing_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('image', 'video', 'external_link')),
  storage_path TEXT NULL,
  external_url TEXT NULL,
  ordering INTEGER NOT NULL DEFAULT 0,
  is_main BOOLEAN NOT NULL DEFAULT false,
  watermarked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT listing_media_path_xor_url_chk CHECK (
    (kind = 'external_link' AND external_url IS NOT NULL AND storage_path IS NULL)
    OR (kind IN ('image', 'video') AND storage_path IS NOT NULL AND external_url IS NULL)
  ),

  CONSTRAINT listing_media_main_only_when_image_chk CHECK (
    is_main = false OR kind = 'image'
  )
);

COMMENT ON TABLE public.listing_media IS
  'Phase 11 — 1:N media artifacts per listing. Kinds: image (JPEG in listing-images bucket, '
  'client-side watermarked), video (MP4 in listing-videos bucket, not watermarked), '
  'external_link (URL — schema slot reserved per Q2=D for future-spec extension, no Phase 11 UI '
  'inserts). At most 10 image rows and 2 video/external_link rows per listing per '
  'listing_media_cap_trigger.';

-- ===========================================================================
-- 2. Indexes
-- ===========================================================================

CREATE INDEX IF NOT EXISTS listing_media_listing_id_idx
  ON public.listing_media (listing_id);

CREATE INDEX IF NOT EXISTS listing_media_listing_id_ordering_idx
  ON public.listing_media (listing_id, ordering);

CREATE UNIQUE INDEX IF NOT EXISTS listing_media_one_main_idx
  ON public.listing_media (listing_id)
  WHERE is_main = true AND kind = 'image';

-- ===========================================================================
-- 3. Enable Row Level Security
-- ===========================================================================

ALTER TABLE public.listing_media ENABLE ROW LEVEL SECURITY;

-- ===========================================================================
-- 4. set_updated_at trigger (Phase 4 helper reused unchanged — R-05 invariant)
-- ===========================================================================

DROP TRIGGER IF EXISTS set_updated_at_on_listing_media ON public.listing_media;
CREATE TRIGGER set_updated_at_on_listing_media
  BEFORE UPDATE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ===========================================================================
-- 5. Cap trigger function + trigger (FR-004, R-30)
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.listing_media_cap_check()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_image_count INTEGER;
  v_video_count INTEGER;
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
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.listing_media_cap_check() IS
  'Phase 11 FR-004 — enforces 10-image / 2-video caps server-side. Combined predicate '
  'for video/external_link per Q2=D defense-in-depth.';

DROP TRIGGER IF EXISTS listing_media_cap_trigger ON public.listing_media;
CREATE TRIGGER listing_media_cap_trigger
  BEFORE INSERT ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.listing_media_cap_check();

-- ===========================================================================
-- 6. Audit trigger group (FR-005, R-05 EIGHTH time across Phases 4/5/6/7/8/9/10/11)
-- log_audit() function body NOT modified — reused verbatim.
-- ===========================================================================

DROP TRIGGER IF EXISTS audit_listing_media_insert ON public.listing_media;
CREATE TRIGGER audit_listing_media_insert
  AFTER INSERT ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.created');

DROP TRIGGER IF EXISTS audit_listing_media_update ON public.listing_media;
CREATE TRIGGER audit_listing_media_update
  AFTER UPDATE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.updated');

DROP TRIGGER IF EXISTS audit_listing_media_delete ON public.listing_media;
CREATE TRIGGER audit_listing_media_delete
  AFTER DELETE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('listing_media.deleted');

-- ===========================================================================
-- 7. RLS policies on public.listing_media (FR-006)
-- 7 policies: anon SELECT, owner SELECT, admin SELECT,
--             owner INSERT, owner UPDATE, owner DELETE, admin FOR ALL.
-- Each CREATE POLICY preceded by DROP POLICY IF EXISTS for idempotency.
-- Mirrored to supabase/policies/listing_media_policies.sql (R-02 dual-storage).
-- ===========================================================================

-- Public SELECT when parent listing is approved + publish window open
DROP POLICY IF EXISTS "listing_media_anon_select_when_approved" ON public.listing_media;
CREATE POLICY "listing_media_anon_select_when_approved"
ON public.listing_media FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_media.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);

-- Owner SELECT — any status of own listing
DROP POLICY IF EXISTS "listing_media_owner_select" ON public.listing_media;
CREATE POLICY "listing_media_owner_select"
ON public.listing_media FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
  )
);

-- Admin SELECT via listings.view_all
DROP POLICY IF EXISTS "listing_media_admin_select" ON public.listing_media;
CREATE POLICY "listing_media_admin_select"
ON public.listing_media FOR SELECT
TO authenticated
USING (public.current_user_has_permission('listings.view_all'));

-- Owner INSERT — composite gate per FR-006
DROP POLICY IF EXISTS "listing_media_owner_insert" ON public.listing_media;
CREATE POLICY "listing_media_owner_insert"
ON public.listing_media FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Owner UPDATE — composite gate; same as INSERT
DROP POLICY IF EXISTS "listing_media_owner_update" ON public.listing_media;
CREATE POLICY "listing_media_owner_update"
ON public.listing_media FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Owner DELETE — composite gate; same as INSERT/UPDATE
DROP POLICY IF EXISTS "listing_media_owner_delete" ON public.listing_media;
CREATE POLICY "listing_media_owner_delete"
ON public.listing_media FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Admin INSERT/UPDATE/DELETE via listings.edit_any
DROP POLICY IF EXISTS "listing_media_admin_write" ON public.listing_media;
CREATE POLICY "listing_media_admin_write"
ON public.listing_media FOR ALL
TO authenticated
USING (public.current_user_has_permission('listings.edit_any'))
WITH CHECK (public.current_user_has_permission('listings.edit_any'));
