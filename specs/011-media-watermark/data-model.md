# Phase 11 — Data Model

**Branch**: `011-media-watermark` | **Date**: 2026-05-22
**Source**: [spec.md](spec.md) + [research.md](research.md) + [plan.md](plan.md)

This file is the complete data-layer reference for Phase 11. Every CREATE TABLE body, trigger body, RLS policy SQL, bucket configuration, amended RPC body, and Flutter entity / DTO / use-case shape that the contracts and quickstart reference. All names, types, and policy SQL are consumed verbatim by the implementation phase.

---

## 1. New table — `public.listing_media`

### 1.1 CREATE TABLE body (in migration `20260522120001_create_listing_media.sql`)

```sql
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

COMMENT ON TABLE public.listing_media IS 'Phase 11 — 1:N media artifacts per listing. Kinds: image (JPEG in listing-images bucket, client-side watermarked), video (MP4 in listing-videos bucket, not watermarked), external_link (URL — schema slot reserved per Q2=D for future-spec extension, no Phase 11 UI inserts). At most 10 image rows and 2 video/external_link rows per listing per listing_media_cap_trigger.';

CREATE INDEX IF NOT EXISTS listing_media_listing_id_idx ON public.listing_media (listing_id);
CREATE INDEX IF NOT EXISTS listing_media_listing_id_ordering_idx ON public.listing_media (listing_id, ordering);

CREATE UNIQUE INDEX IF NOT EXISTS listing_media_one_main_idx
  ON public.listing_media (listing_id)
  WHERE is_main = true AND kind = 'image';

ALTER TABLE public.listing_media ENABLE ROW LEVEL SECURITY;
```

### 1.2 `set_updated_at` trigger attachment (Phase 4 helper reused unchanged)

```sql
DROP TRIGGER IF EXISTS set_updated_at_on_listing_media ON public.listing_media;
CREATE TRIGGER set_updated_at_on_listing_media
  BEFORE UPDATE ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

### 1.3 Column-by-column inventory

| Column | Type | Nullability | Default | Notes |
|---|---|---|---|---|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Primary key. Preserved across resubmits per R-14 (Q3=A edit-in-place). |
| `listing_id` | UUID | NOT NULL | — | FK to `public.listings(id)` with `ON DELETE CASCADE`. |
| `kind` | TEXT | NOT NULL | — | CHECK enum: `'image'`, `'video'`, `'external_link'`. Phase 11 UI inserts only `image` + `video` per Q2=D. |
| `storage_path` | TEXT | NULL | — | Required for `kind IN ('image','video')`; NULL for `kind='external_link'`. Path shape: `<listing_id>/<ordering>_<rand>.jpg` (images) or `<listing_id>/<ordering>_<rand>.mp4` (videos). |
| `external_url` | TEXT | NULL | — | Required for `kind='external_link'`; NULL for `kind IN ('image','video')`. Reserved per Q2=D; no Phase 11 UI inserts. |
| `ordering` | INTEGER | NOT NULL | 0 | Publisher-controlled drag-reorder index; re-sequenced as 1..N on each reorder transaction. |
| `is_main` | BOOLEAN | NOT NULL | false | Exactly one row per listing has `true` for `kind='image'` (partial unique index enforces). Never `true` for video / external_link (CHECK constraint enforces). |
| `watermarked` | BOOLEAN | NOT NULL | false | `true` for every Phase 11 client-uploaded image (FR-016 sets it at INSERT). Used by Q1=A FR-022 media-minimum check. |
| `created_at` | TIMESTAMPTZ | NOT NULL | `now()` | Append-only. |
| `updated_at` | TIMESTAMPTZ | NOT NULL | `now()` | Maintained by Phase 4's `set_updated_at` trigger. |

---

## 2. Cap trigger — `listing_media_cap_trigger` (FR-004)

### 2.1 Trigger function body

```sql
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

COMMENT ON FUNCTION public.listing_media_cap_check() IS 'Phase 11 FR-004 — enforces 10-image / 2-video caps server-side. Combined predicate for video/external_link per Q2=D defense-in-depth.';

DROP TRIGGER IF EXISTS listing_media_cap_trigger ON public.listing_media;
CREATE TRIGGER listing_media_cap_trigger
  BEFORE INSERT ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.listing_media_cap_check();
```

### 2.2 Error contract (R-30)

| Attribute | Value |
|---|---|
| SQLSTATE | `P0001` (PL/pgSQL `raise_exception`) |
| MESSAGE | `'listing_media.cap_exceeded'` (stable identifier; consumed by the Flutter datasource as `error.message`) |
| DETAIL JSONB shape | `{ "code": "listing_media.cap_exceeded", "kind": "image"|"video", "current_count": <int>, "max": 10|2 }` |
| Client-side handling | `lib/features/listing_form/data/datasources/supabase_listing_media_datasource.dart` catches `PostgrestException`, reads `error.details`, parses JSON, surfaces via the FR-019 ARB key `media.cap.images10` or `media.cap.videos2`. |

---

## 3. Audit trigger group on `public.listing_media` (FR-005, R-05 EIGHTH time)

Phase 4's `log_audit()` function is reused verbatim — zero edits to its body. Phase 11 attaches the trigger group below:

```sql
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
```

The `log_audit()` function (Phase 4) emits one `audit_logs` row per fire carrying `actor_user_id=auth.uid()`, `action=<arg>`, `target_type='listing_media'`, `target_id=NEW.id`/`OLD.id`, `before_state=row_to_json(OLD)::jsonb`, `after_state=row_to_json(NEW)::jsonb`. Set-as-main fires `audit_listing_media_update` twice per logical action (one for the row whose `is_main` flipped to true, one for the row that previously held `true`) per FR-021.

---

## 4. RLS policies on `public.listing_media` (FR-006, FR-009 — no new permission keys)

### 4.1 Inline-bundled in migration 1 (and mirrored to `supabase/policies/listing_media_policies.sql`)

```sql
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

-- Owner INSERT — composite gate per FR-005
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
```

---

## 5. Supabase Storage buckets (FR-008, Q4=A, Q8=A; migration 2)

### 5.1 `storage.buckets` INSERT (R-26 idempotent upsert)

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('listing-images', 'listing-images', true, 10485760, ARRAY['image/jpeg']),
  ('listing-videos', 'listing-videos', true, 31457280, ARRAY['video/mp4'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;
```

### 5.2 Bucket configuration matrix

| Bucket | `public` | `file_size_limit` | `allowed_mime_types` | Rationale |
|---|---|---|---|---|
| `listing-images` | `true` | 10485760 (10 MB) | `['image/jpeg']` | Per Q4=A every stored object is JPEG (client-side pipeline normalizes broader source formats). Per Q8=A `public: true` + RLS = access boundary; SC-029 verifies the flag. Per FR-008 the 10 MB cap is well above any post-downscale 1920×1920 JPEG quality-85 output (typically < 1 MB) so the limit is defense-in-depth. |
| `listing-videos` | `true` | 31457280 (30 MB) | `['video/mp4']` | Per Q2=D no external-link inserts in Phase 11; direct MP4 upload only. Per IMPLEMENTATION_PLAN §Phase 11 the 30 MB cap is the v1 video size limit. Per FR-008 + R-26 idempotent upsert. |

---

## 6. RLS policies on `storage.objects` (FR-007, R-27; migration 3)

### 6.1 Policy inventory — six policies per bucket × two buckets = twelve total

For each of `listing-images` and `listing-videos`, the following six policies ship inline in migration 3 AND mirrored to `supabase/policies/listing_media_storage_policies.sql`:

```sql
-- 1. Anon SELECT when parent listing approved + publish window open
DROP POLICY IF EXISTS "listing_images_anon_select_when_approved" ON storage.objects;
CREATE POLICY "listing_images_anon_select_when_approved"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);

-- 2. Owner SELECT — any status of own listing
DROP POLICY IF EXISTS "listing_images_owner_select" ON storage.objects;
CREATE POLICY "listing_images_owner_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
  )
);

-- 3. Admin SELECT via listings.view_all
DROP POLICY IF EXISTS "listing_images_admin_select" ON storage.objects;
CREATE POLICY "listing_images_admin_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.view_all')
);

-- 4. Owner INSERT — composite gate + path-shape WITH CHECK
DROP POLICY IF EXISTS "listing_images_owner_insert" ON storage.objects;
CREATE POLICY "listing_images_owner_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listing-images'
  AND storage.objects.name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 5. Owner UPDATE — same composite gate (covers metadata renames; the project does not rename objects but defense-in-depth)
DROP POLICY IF EXISTS "listing_images_owner_update" ON storage.objects;
CREATE POLICY "listing_images_owner_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 6. Owner DELETE — same composite gate; admin write also through this policy
DROP POLICY IF EXISTS "listing_images_owner_delete" ON storage.objects;
CREATE POLICY "listing_images_owner_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Admin INSERT/UPDATE/DELETE — single FOR ALL policy
DROP POLICY IF EXISTS "listing_images_admin_write" ON storage.objects;
CREATE POLICY "listing_images_admin_write"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.edit_any')
)
WITH CHECK (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.edit_any')
);
```

The same six policies repeat for `bucket_id = 'listing-videos'` (just substitute the bucket id in the literal). Total: **12 policies on `storage.objects`**.

### 6.2 Path-shape regex (R-27)

The owner INSERT policy enforces the path shape `<listing_id>/<filename>` via:
```
^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$
```
which matches a standard UUID v4 prefix + slash + non-empty filename. Uploads with malformed paths are rejected at INSERT time.

### 6.3 SQL naming convention note (L2)

Inside policies on `storage.objects`, the column reference for the path is the bare identifier `name` (not `storage.objects.name`). PostgreSQL resolves `name` to the local table within the policy's USING / WITH CHECK context. Use `split_part(name, '/', 1)::uuid` consistently across all 14 policies and the migration body to avoid ambiguity.

---

## 7. Amended `submit_listing` RPC (FR-022, R-31, R-35; migration 4)

The Phase 10 `submit_listing` body is reproduced in full below with the Phase 11 amendment marked. The amendment is between Phase 10's existing `v_missing` accumulator and the IF-RAISE block. Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` is NOT edited.

### 7.1 Full amended body (Phase 11 migration 4)

```sql
CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_listing public.listings;
  v_profile public.profiles;
  v_primary_price_count INTEGER;
  v_image_count INTEGER;
  v_missing TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- (1) Load listing
  SELECT * INTO v_listing FROM public.listings WHERE id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'listing not found'
      USING ERRCODE = '42704';
  END IF;

  -- (2) Verify owner
  IF v_listing.publisher_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'not authorized to submit this listing'
      USING ERRCODE = '42501';
  END IF;

  -- (3) Verify approved-publisher precondition
  SELECT * INTO v_profile FROM public.profiles WHERE user_id = auth.uid();
  IF v_profile.publisher_status <> 'approved' OR v_profile.account_status <> 'approved' THEN
    RAISE EXCEPTION 'publisher not approved'
      USING ERRCODE = '42501';
  END IF;

  -- (4) Verify current status
  IF v_listing.status NOT IN ('draft', 'rejected') THEN
    RAISE EXCEPTION 'listing not in editable status'
      USING ERRCODE = '22023',
            DETAIL = jsonb_build_object(
              'code', 'submit_listing.wrong_status',
              'current_status', v_listing.status
            )::TEXT;
  END IF;

  -- (5) Phase 10 Q1=B Full required-field validation
  IF v_listing.title IS NULL OR length(btrim(v_listing.title)) = 0 THEN v_missing := array_append(v_missing, 'listings.title'); END IF;
  IF v_listing.purpose IS NULL THEN v_missing := array_append(v_missing, 'listings.purpose'); END IF;
  IF v_listing.property_type IS NULL THEN v_missing := array_append(v_missing, 'listings.property_type'); END IF;
  IF v_listing.governorate_id IS NULL THEN v_missing := array_append(v_missing, 'listings.governorate_id'); END IF;
  IF v_listing.city_id IS NULL THEN v_missing := array_append(v_missing, 'listings.city_id'); END IF;
  IF v_listing.area_id IS NULL THEN v_missing := array_append(v_missing, 'listings.area_id'); END IF;
  IF v_listing.address_text IS NULL OR length(btrim(v_listing.address_text)) = 0 THEN v_missing := array_append(v_missing, 'listings.address_text'); END IF;
  IF v_listing.area_size IS NULL OR v_listing.area_size <= 0 THEN v_missing := array_append(v_missing, 'listings.area_size'); END IF;

  IF v_listing.property_type IN ('apartment', 'villa') THEN
    IF v_listing.rooms IS NULL THEN v_missing := array_append(v_missing, 'listings.rooms'); END IF;
    IF v_listing.bathrooms IS NULL THEN v_missing := array_append(v_missing, 'listings.bathrooms'); END IF;
  END IF;

  IF v_listing.phone IS NULL AND v_listing.whatsapp IS NULL THEN
    v_missing := array_append(v_missing, 'listings.contact_channel');
  END IF;

  SELECT count(*) INTO v_primary_price_count
  FROM public.listing_prices
  WHERE listing_id = p_listing_id AND is_primary = true AND amount > 0;
  IF v_primary_price_count = 0 THEN
    v_missing := array_append(v_missing, 'listing_prices.primary_amount');
  END IF;

  -- (5a) PHASE 11 ADDITION (FR-022 / Q1=A): media-minimum check
  SELECT count(*) INTO v_image_count
  FROM public.listing_media
  WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true;
  IF v_image_count = 0 THEN
    v_missing := array_append(v_missing, 'listing_media.images_below_minimum');
  END IF;

  -- (6) If any missing fields, RAISE with combined list
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'missing required fields'
      USING ERRCODE = '22023',
            DETAIL = jsonb_build_object(
              'code', 'submit_listing.missing_fields',
              'missing_fields', v_missing
            )::TEXT;
  END IF;

  -- (7) Status flip (status-transition trigger captures history row; audit trigger emits listing.submitted)
  UPDATE public.listings
  SET status = 'pending_review'
  WHERE id = p_listing_id;

  -- (8) Return success
  RETURN jsonb_build_object(
    'listing_id', p_listing_id,
    'status', 'pending_review',
    'submitted_at', now()
  );
END;
$$;

COMMENT ON FUNCTION public.submit_listing(UUID) IS 'Phase 10 RPC, amended in Phase 11 (migration 20260522120004) for the Q1=A media-minimum check (FR-022). Validates Phase 10 Q1=B required fields PLUS ≥1 listing_media row with kind=''image'' AND watermarked=true. Errors emit missing_fields[] in the SQLSTATE 22023 DETAIL payload.';
```

### 7.2 Error contract — extended `missing_fields[]` array

| Missing-field key | Source FR | Phase | Notes |
|---|---|---|---|
| `listings.title` | Phase 10 FR-010a | 10 | Phase 10 Q1=B carry-forward. |
| `listings.purpose` | Phase 10 FR-010a | 10 | |
| `listings.property_type` | Phase 10 FR-010a | 10 | |
| `listings.governorate_id` | Phase 10 FR-010a | 10 | |
| `listings.city_id` | Phase 10 FR-010a | 10 | |
| `listings.area_id` | Phase 10 FR-010a | 10 | |
| `listings.address_text` | Phase 10 FR-010a | 10 | |
| `listings.area_size` | Phase 10 FR-010a | 10 | |
| `listings.rooms` | Phase 10 FR-010a | 10 | Residential property types only. |
| `listings.bathrooms` | Phase 10 FR-010a | 10 | Residential property types only. |
| `listings.contact_channel` | Phase 10 FR-010a | 10 | At least one of phone / whatsapp. |
| `listing_prices.primary_amount` | Phase 10 FR-010a | 10 | At least one is_primary=true row with amount>0. |
| `listing_media.images_below_minimum` | **Phase 11 FR-022** | **11** | At least one `kind='image' AND watermarked=true` row. |

The Phase 10 client-side `submit_failure_dialog.dart` iterates `missing_fields[]` and renders each key via ARB lookup; Phase 11 adds the ARB key `submit.error.imagesBelowMinimum` to both `app_ar.arb` and `app_en.arb`.

---

## 8. Flutter entity / DTO / use-case / BLoC event shapes

### 8.1 Entity — `lib/features/listing_form/domain/entities/listing_media.dart`

```dart
import 'package:equatable/equatable.dart';

enum ListingMediaKind {
  image,
  video,
  // 'external_link' is intentionally omitted per Q2=D — schema retains the enum value
  // for future-spec forward-compat, but the Dart entity surface narrows to what Phase 11 inserts.
}

class ListingMedia extends Equatable {
  final String id;                  // UUID
  final String listingId;           // UUID
  final ListingMediaKind kind;
  final String? storagePath;        // Required for image/video
  final String? externalUrl;        // Always NULL in Phase 11 entity surface
  final int ordering;
  final bool isMain;
  final bool watermarked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListingMedia({
    required this.id,
    required this.listingId,
    required this.kind,
    this.storagePath,
    this.externalUrl,
    required this.ordering,
    required this.isMain,
    required this.watermarked,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id, listingId, kind, storagePath, externalUrl,
        ordering, isMain, watermarked, createdAt, updatedAt,
      ];
}
```

### 8.2 DTO — `lib/features/listing_form/data/dtos/listing_media_dto.dart`

```dart
class ListingMediaDto {
  final String id;
  final String listingId;
  final String kind; // 'image' | 'video' | 'external_link'
  final String? storagePath;
  final String? externalUrl;
  final int ordering;
  final bool isMain;
  final bool watermarked;
  final DateTime createdAt;
  final DateTime updatedAt;

  ListingMediaDto({
    required this.id,
    required this.listingId,
    required this.kind,
    this.storagePath,
    this.externalUrl,
    required this.ordering,
    required this.isMain,
    required this.watermarked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ListingMediaDto.fromJson(Map<String, dynamic> json) => ListingMediaDto(
        id: json['id'] as String,
        listingId: json['listing_id'] as String,
        kind: json['kind'] as String,
        storagePath: json['storage_path'] as String?,
        externalUrl: json['external_url'] as String?,
        ordering: json['ordering'] as int,
        isMain: json['is_main'] as bool,
        watermarked: json['watermarked'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  ListingMedia toEntity() => ListingMedia(
        id: id,
        listingId: listingId,
        kind: switch (kind) {
          'image' => ListingMediaKind.image,
          'video' => ListingMediaKind.video,
          // external_link rows from admin direct-SQL inserts: surfaced as broken-image placeholder per spec edge case;
          // entity layer treats unknown values defensively by mapping to image (will fail to render — picker shows error state)
          _ => ListingMediaKind.image,
        },
        storagePath: storagePath,
        externalUrl: externalUrl,
        ordering: ordering,
        isMain: isMain,
        watermarked: watermarked,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
```

### 8.3 Datasource — `lib/features/listing_form/data/datasources/supabase_listing_media_datasource.dart`

Method signatures (full implementation deferred to /speckit-implement):

```dart
abstract class SupabaseListingMediaDatasource {
  Future<List<ListingMediaDto>> loadForListing(String listingId);
  Future<ListingMediaDto> uploadImage({
    required String listingId,
    required Uint8List watermarkedJpegBytes,
    required int ordering,
    required bool isMain,
  });
  Future<ListingMediaDto> uploadVideo({
    required String listingId,
    required String filePath,
    required int ordering,
  });
  Future<void> reorder(String listingId, List<String> newOrderIds);
  Future<void> setMain(String listingId, String mediaId);
  Future<void> deleteMedia(String mediaId);
}
```

Implementation notes:
- `uploadImage` calls `supabase.storage.from('listing-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: 'image/jpeg'))` then `supabase.from('listing_media').insert({...}).select().single()` per FR-015 atomic-from-publisher-perspective.
- `uploadVideo` similarly but `.upload(path, File(filePath))` with `contentType: 'video/mp4'`.
- `deleteMedia` per R-38: load row → `storage.from(bucket).remove([storage_path])` → `from('listing_media').delete().eq('id', mediaId)`. On storage failure, retry once; on second failure, abort without the SQL DELETE.
- `setMain` issues a single transactional UPDATE via PostgREST that flips `is_main=true` on the target row and `is_main=false` on the prior main; the partial unique index serializes server-side.

### 8.4 Use cases — `lib/features/listing_form/domain/usecases/`

| File | Signature | Notes |
|---|---|---|
| `upload_image.dart` | `Future<ListingMedia> call({required String listingId, required XFile file})` | Runs the FR-014 pipeline (header read R-24 → decode → EXIF strip → downscale → watermark composite → JPEG re-encode) then delegates upload+insert to the datasource. Q7=B 60-second timeout enforced at BLoC layer per R-39. |
| `upload_video.dart` | `Future<ListingMedia> call({required String listingId, required XFile file})` | Runs `video_file_validator` then delegates upload+insert. No watermark composite for videos per FR-014 image-only scope. |
| `reorder_media.dart` | `Future<void> call({required String listingId, required List<String> newOrder})` | Single transactional UPDATE. |
| `set_main_image.dart` | `Future<void> call({required String listingId, required String mediaId})` | Single transactional UPDATE flipping two rows. |
| `delete_media.dart` | `Future<void> call({required String mediaId})` | R-38 ordering. |
| `load_media_for_listing.dart` | `Future<List<ListingMedia>> call({required String listingId})` | Reads ordered by `ordering ASC`. |

### 8.5 BLoC event surface — `ListingFormBloc` extension per R-40

New event types added to Phase 10's `listing_form_event.dart`:

```dart
class MediaPicked extends ListingFormEvent {
  final List<XFile> files;
  const MediaPicked(this.files);
}

class VideoPicked extends ListingFormEvent {
  final XFile file;
  const VideoPicked(this.file);
}

class MediaReordered extends ListingFormEvent {
  final List<String> newOrder; // listing_media.id values in new sequence
  const MediaReordered(this.newOrder);
}

class MediaSetMain extends ListingFormEvent {
  final String mediaId;
  const MediaSetMain(this.mediaId);
}

class MediaDeleted extends ListingFormEvent {
  final String mediaId;
  const MediaDeleted(this.mediaId);
}
```

State extension:
```dart
class ListingFormState {
  // ... (existing Phase 10 fields)
  final List<ListingMedia> media;           // NEW per R-40
  final Map<String, _MediaUploadProgress> uploadInFlight; // NEW — per-thumbnail processing/upload state
}
```

The `MediaPicked` handler iterates the picked files, enqueues each onto the R-25 isolate worker, updates `uploadInFlight` per file, and emits state transitions as each pipeline completes. The Q7=B timeout per R-39 wraps each `Future` in `.timeout(Duration(seconds: 60))`.

### 8.6 MediaPicker widget tree

```
step_media.dart (StatelessWidget)
└── BlocBuilder<ListingFormBloc, ListingFormState>
    ├── upload-affordances row
    │   ├── ElevatedButton "Add images" (disabled when count_image >= 10)
    │   └── ElevatedButton "Add video"  (disabled when count_video >= 2)
    └── MediaPicker (StatefulWidget — for drag-reorder gesture state)
        └── ReorderableGridView.builder
            └── per-thumbnail MediaThumbnail (StatelessWidget)
                ├── Image.memory(localBytes) OR Image.network(publicUrl) per R-29
                ├── "main" badge (top-end-corner FloatingActionButton-style chip)
                ├── ordering badge (top-start-corner Container with index)
                ├── progress overlay (CircularProgressIndicator when uploadInFlight)
                ├── error overlay (Icon + localized message + Retry button)
                └── GestureDetector onLongPress → action sheet
```

### 8.7 Watermark pipeline — `lib/features/listing_form/presentation/util/watermark_pipeline.dart`

The pipeline is a top-level pure function callable from the R-25 isolate worker:

```dart
Future<Uint8List> processImageForUpload({
  required Uint8List sourceBytes,
  required Uint8List watermarkAssetBytes,
}) async {
  // (a) format-detect: read first N bytes; throw _UnsupportedFormatException if outside Q4 accept set
  final format = detectFormat(sourceBytes);

  // (a-pre) Q6 header-only dimension cap; throw _ImageTooLargeException if width|height > 8000
  final dims = readImageDimensions(sourceBytes, format);
  if (dims.width > 8000 || dims.height > 8000) {
    throw _ImageTooLargeException();
  }

  // (b) decode to raw RGBA pixels; HEIC uses flutter_image_compress fallback
  final image = await decodeImage(sourceBytes, format);

  // (c) apply EXIF rotation + strip EXIF
  final oriented = applyExifOrientation(image);

  // (d) downscale to ≤ 1920 px long edge
  final scaled = downscale(oriented, maxLongEdge: 1920);

  // (e) composite watermark per R-23 (bottom-end, 15% opacity, 18% of long edge, 24px padding)
  final watermarked = compositeWatermark(scaled, watermarkAssetBytes);

  // (f) re-encode as JPEG quality 85
  final jpegBytes = encodeJpeg(watermarked, quality: 85);

  return jpegBytes;
}
```

The R-23 watermark composite parameters are codified inside `compositeWatermark` (not exposed as configurable parameters in Phase 11 — codified per R-23).

### 8.8 Header reader — `lib/features/listing_form/presentation/util/image_header_reader.dart` (R-24)

```dart
class ImageDimensions {
  final int width;
  final int height;
  ImageDimensions(this.width, this.height);
}

enum ImageFormat { jpeg, png, heic, webp, unsupported }

ImageFormat detectFormat(Uint8List bytes) {
  if (bytes.length < 12) return ImageFormat.unsupported;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return ImageFormat.jpeg;
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return ImageFormat.png;
  // HEIC/HEIF: ftyp box at offset 4-7 followed by heic/heif/mif1/heix brand
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (['heic', 'heif', 'mif1', 'heix', 'msf1'].contains(brand)) return ImageFormat.heic;
  }
  // WebP: RIFF....WEBP
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46
      && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return ImageFormat.webp;
  }
  return ImageFormat.unsupported;
}

Future<ImageDimensions?> readImageDimensions(Uint8List bytes, ImageFormat format) async {
  // Implementation details: see research R-24. JPEG: walk SOF0 marker. PNG: read IHDR chunk. HEIC: parse ispe box
  // via flutter_image_compress metadata API. WebP: read VP8X chunk dimensions.
  // Returns null if dimensions cannot be extracted (corrupt header).
}
```

---

## 9. ARB key inventory (FR-019)

~20 new keys to add to both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`:

| Key | English | Arabic (Syrian-friendly draft — finalized at /speckit-implement) |
|---|---|---|
| `media.addImages` | "Add images" | "أضف صور" |
| `media.addVideo` | "Add video" | "أضف فيديو" |
| `media.action.setMain` | "Set as main" | "اجعلها الصورة الرئيسية" |
| `media.action.delete` | "Delete" | "حذف" |
| `media.action.reorderHint` | "Press and hold to reorder" | "اضغط مطولاً لإعادة الترتيب" |
| `media.cap.images10` | "10-image limit reached" | "الحد الأقصى 10 صور" |
| `media.cap.videos2` | "2-video limit reached" | "الحد الأقصى فيديوهين" |
| `media.error.formatNotSupported` | "Please pick a JPEG, PNG, HEIC, or WebP" | "الصيغ المدعومة: JPEG, PNG, HEIC, WebP" |
| `media.error.imageTooLarge` | "This image is too large — max 8000×8000 pixels" | "هاي الصورة كبيرة كتير — الحد الأقصى 8000×8000 بكسل" |
| `media.error.timeout` | "This upload took too long — please try again" | "ما تم رفع الصورة — جرّب مرة ثانية" |
| `media.error.uploadFailed` | "Upload failed — please try again" | "فشل الرفع — جرّب مرة ثانية" |
| `media.error.videoSizeExceeded` | "Video must be ≤ 30 MB" | "الفيديو لازم يكون أصغر من 30 ميغا" |
| `media.error.videoFormatMustBeMp4` | "Video must be MP4 format" | "صيغة الفيديو لازم MP4" |
| `media.error.galleryPermissionDenied` | "Gallery access is required to upload photos" | "بدون الوصول للمعرض ما رح نقدر نرفع الصور" |
| `media.action.openSettings` | "Open settings" | "افتح الإعدادات" |
| `media.error.watermarkAssetMissing` | "Watermark could not be applied — please update the app" | "ما قدرنا نضيف العلامة المائية — حدّث التطبيق" |
| `media.readOnly.pendingOrApproved` | "Media cannot be changed after submitting for review" | "ما فيك تعدّل الصور بعد إرسال الإعلان للمراجعة" |
| `media.thumbnail.mainBadge` | "Main" | "الرئيسية" |
| `submit.error.imagesBelowMinimum` | "At least one photo is required" | "لازم صورة واحدة على الأقل" |
| `media.review.carouselLabel` | "Listing media" | "صور الإعلان" |

The Arabic translations above are drafts; final copy is reviewed at `/speckit-implement` time by the project's Arabic-copy reviewer (per Constitution V Syrian-friendly preference — colloquial Levantine where natural; no stiff Modern Standard Arabic).

---

## 10. Pubspec delta (R-22, R-37)

Three new top-level deps added under `dependencies:`:

```yaml
dependencies:
  # ... (existing deps unchanged)
  image_picker: ^1.1.2
  image: ^4.5.4
  flutter_image_compress: ^2.4.0
```

One updated `flutter.assets` declaration (additive):

```yaml
flutter:
  assets:
    # ... (existing entries unchanged)
    - assets/images/watermark/
```

`pubspec.lock` regenerated via `flutter pub get`; ~12 new transitive entries committed in the same PR.

---

## 11. AndroidManifest delta (FR-023, R-32)

`android/app/src/main/AndroidManifest.xml` gains three `<uses-permission>` declarations before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

No other manifest changes.

---

## 12. Per-FR / per-SC verification map

| FR / SC | Verification |
|---|---|
| FR-001 (table exists) | `SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='listing_media'` → 1. |
| FR-002 (CHECK constraints) | `SELECT conname FROM pg_constraint WHERE conrelid='public.listing_media'::regclass AND contype='c'` → returns `listing_media_path_xor_url_chk` AND `listing_media_main_only_when_image_chk`. |
| FR-003 (partial unique index) | `SELECT indexname FROM pg_indexes WHERE tablename='listing_media' AND indexdef LIKE '%WHERE%is_main%'` → 1. |
| FR-004 (cap trigger) | Insert 10 image rows successfully, then attempt 11th — expect SQLSTATE P0001 with `error.message='listing_media.cap_exceeded'`. |
| FR-005 (audit triggers) | Insert one row, then check `SELECT count(*) FROM audit_logs WHERE action='listing_media.created' AND target_id=<that row's id>` → 1. |
| FR-006 (RLS on listing_media) | Anon SELECT against a draft listing's media row → 0 rows. After parent.status='approved', anon SELECT → 1 row. |
| FR-007 (storage.objects RLS) | Anonymous Supabase Storage download of a draft listing's bucket object → 403. After parent.status='approved' → 200 + bytes. |
| FR-008 (bucket config) | `SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id IN ('listing-images','listing-videos')` → 2 rows with public=true + correct limits + correct mime arrays. |
| FR-009 (no new permission key) | `git diff` against Phase 6 permissions seed migration → 0 new rows. |
| FR-010, FR-011, FR-012, FR-013 | Manual UI walk on Infinix Note 8 + Pixel 8 Pro emulator. |
| FR-014 (pipeline) | Upload 1 source image; download from bucket; visually confirm watermark + long-edge=1920px + JPEG mime. |
| FR-015 (atomic upload) | Force upload failure (e.g., disconnect network mid-upload via emulator); confirm no `listing_media` row was inserted. |
| FR-016 (`watermarked=true`) | After upload, `SELECT watermarked FROM listing_media WHERE id=<...>` → true. |
| FR-017 (video validator) | Manual UI: pick MP4 > 30 MB → rejected client-side. Pick .mov → rejected. Pick MP4 ≤ 30 MB → accepted. |
| FR-018 (no other validators) | Code review: no new files under `lib/core/validators/` beyond `video_file_validator.dart`. |
| FR-019 (ARB keys) | Grep `lib/l10n/app_ar.arb` for the 20 new keys; same for `app_en.arb`; both should match. |
| FR-020 (design tokens) | `grep -E "Color\\(0xFF\|EdgeInsets\\.only\\(left:\|SizedBox\\(height: [0-9]+" lib/features/listing_form/presentation/widgets/media_picker.dart` → 0 hits. |
| FR-021 (audit on every mutation) | After picker session: `SELECT count(*) FROM audit_logs WHERE action LIKE 'listing_media.%'` ≥ count of mutations. |
| FR-022 (Q1=A media check in submit_listing) | Submit a draft with zero images → HTTP 400; `missing_fields[]` contains `listing_media.images_below_minimum`. |
| FR-023 (Android manifest) | Grep `android/app/src/main/AndroidManifest.xml` for the three new permission lines. |
| SC-001 (≤ 5 min end-to-end) | Stopwatch on Infinix Note 8 quickstart walk. |
| SC-002 (JPEG long edge ≤ 1920) | Download bucket object; `exiftool` shows JPEG + dimensions ≤ 1920 long edge. |
| SC-003 (watermark visible at default position) | Download bucket object; visually inspect 5 random samples. |
| SC-004, SC-005 (caps both layers) | 11th-image direct INSERT → trigger error; picker UI disabled at 10. |
| SC-006 (audit count parity) | Verify `audit_logs` count = manual-session mutation count. |
| SC-007 (RLS enabled) | `SELECT relrowsecurity FROM pg_class WHERE relname='listing_media'` → true. |
| SC-008 (storage RLS deny anon on non-approved) | Anonymous download of draft bucket object → 403. |
| SC-009 (path under listing_id prefix) | Verify `SELECT name FROM storage.objects WHERE bucket_id='listing-images' AND name NOT LIKE '<listing_id>/%'` → 0 rows for that listing. |
| SC-010 (one main per listing) | `SELECT listing_id, count(*) FROM listing_media WHERE is_main=true GROUP BY listing_id HAVING count(*) > 1` → 0 rows. |
| SC-011 (fps during processing) | Visual scroll-smoothness check during 8-image batch on Infinix Note 8. |
| SC-012 (per-thumbnail actions work) | Manual walk through set-main, delete, drag-reorder on Infinix Note 8. |
| SC-013 (`log_audit` unchanged) | `git diff specs/004-supabase-foundation/data-model.md` → 0 edits to the `log_audit()` function body. |
| SC-014 (Constitution IX) | Grep `package:supabase_flutter` in `lib/features/listing_form/presentation/widgets/*.dart` → 0 hits. |
| SC-015 (Constitution V) | Phase 3 lint guard reports 0 hardcoded user-facing strings. |
| SC-016 (Constitution VI) | Grep for inline hex / EdgeInsets.only / raw pixel SizedBox in `lib/features/listing_form/presentation/widgets/` → 0 hits. |
| SC-017 (Q1=A submit_listing media check) | Submit zero-image draft → HTTP 400; payload contains `listing_media.images_below_minimum`. |
| SC-018 (caps enforce for admins too) | As admin with `listings.edit_any`, direct INSERT of 11th image → cap trigger fires. |
| SC-019 (no external_link UI in Phase 11) | Code review: no `Add external link` CTA; no `external_video_url_validator.dart` file. |
| SC-020 (Q3=A row UUIDs preserved on resubmit) | Query `listing_media` before + after resubmit; row UUIDs identical. |
| SC-021 (trigger-before-seed ordering) | Read migration 1 file: triggers attached BEFORE any seed INSERT (Phase 11 seeds zero rows; defensive). |
| SC-022 (no new permission key) | Same as FR-009. |
| SC-023 (set-main hidden on video) | Manual UI: long-press video thumbnail → action sheet does not show "Set as main". |
| SC-024 (EXIF stripped) | Download bucket object; `exiftool` reports 0 GPS / camera-make / camera-model fields. |
| SC-025 (status-flip immediately affects anon read) | Approve listing → anonymous download succeeds. Re-flip to rejected → anonymous download returns 403. |
| SC-026 (manifest permissions on both Android codepaths) | Grep AndroidManifest.xml; walk picker on Infinix Note 8 (Android 10/11) + Pixel 8 Pro emulator (Android 14). |
| SC-027 (Q6=B pre-decode reject 8000+) | Pick a 9000×9000 test image; picker surfaces FR-019 image-too-large error; debug log confirms decode not invoked. |
| SC-028 (Q7=B 60s timeout) | Throttle network to ~50 kbps; pick 5 MB JPEG; confirm timeout-error state after ~60s; no `listing_media` row inserted. |
| SC-029 (Q8=A public bucket + RLS) | `SELECT id, public FROM storage.buckets WHERE id IN ('listing-images','listing-videos')` → both public=true; `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE '%listing%'` → 12. |

---

## 13. Seed inventory

**Phase 11 seeds zero rows.** Per R-08 (carry-forward from Phase 10), the trigger-attach-before-seed invariant is defensively preserved for any future spec — the cap + audit triggers are attached at the end of migration 1, before any hypothetical seed INSERT would run. No fixture data ships in Phase 11.

The reference Phase 10 listing (created during the Phase 10 device walk per spec 010 DEFERRED.md) is the natural test subject for Phase 11's quickstart — the publisher uploads media against that existing draft / rejected listing on the Infinix Note 8.

---

## 14. Cross-phase footprint summary

| Phase | Phase 11 touch |
|---|---|
| Phase 4 | `log_audit()` reused unchanged (R-05 EIGHTH time). `set_updated_at` attached to `listing_media`. |
| Phase 5 | `profiles.publisher_status` + `account_status` consumed by FR-006 + storage policies. No edits. |
| Phase 6 | `current_user_has_permission()` reused. No new permission keys. No edits. |
| Phase 7 | RPC pattern (R-06) carried forward to the `submit_listing` amendment. No edits. |
| Phase 8 | No touch — Phase 8's `LocationPicker` is not consumed by the picker. |
| Phase 9 | No touch — Phase 9's `MoneyFormatter` is not consumed by the picker. |
| Phase 10 | `public.listings` is the FK parent. `submit_listing` RPC amended via `CREATE OR REPLACE` in migration 4 (Phase 10's migration 20260519120007 NOT edited per R-35). `ListingFormBloc` extended (not replaced) per R-40. `step_media_placeholder.dart` deleted; `step_media.dart` mounts in its place. `listings_repository_impl.dart` extended. The Phase 10 `submit_failure_dialog.dart` consumes the new `listing_media.images_below_minimum` missing-field key without source-code changes (it iterates the array). |
