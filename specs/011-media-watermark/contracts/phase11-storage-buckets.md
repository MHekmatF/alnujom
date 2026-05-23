# Contract: Supabase Storage buckets — `listing-images` and `listing-videos`

**Source FRs**: FR-008, Q4=A, Q8=A | **Migration**: `20260522120002_create_listing_media_storage_buckets.sql` | **Source-of-truth**: [data-model.md §5](../data-model.md#5-supabase-storage-buckets-fr-008-q4a-q8a-migration-2)

## Bucket configuration matrix

| Bucket | `id` / `name` | `public` | `file_size_limit` (bytes) | `allowed_mime_types` |
|---|---|---|---|---|
| Images | `listing-images` | `true` | 10485760 (10 MB) | `['image/jpeg']` |
| Videos | `listing-videos` | `true` | 31457280 (30 MB) | `['video/mp4']` |

## Migration body (R-26 idempotent upsert)

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

## Rationale

- **`public: true`** per Q8=A: RLS on `storage.objects` is the authoritative access filter (see `phase11-storage-policies.md`). Public clients consume stable URLs from `getPublicUrl()` — no signed-URL minting per render (R-29). Phase 13 gallery + Phase 14 thumbnails cache freely via `cached_network_image`.
- **`allowed_mime_types: ['image/jpeg']`** per Q4=A: the client-side FR-014 pipeline normalizes every source format (JPEG/PNG/HEIC/WebP) to JPEG before upload; the bucket never sees other mime types. Admin direct Studio uploads would also need to be JPEG.
- **`allowed_mime_types: ['video/mp4']`**: MP4 is the only universally Android-supported codec; matches the FR-017 client-side validator AND the bucket's enforcement.
- **`file_size_limit`** defense-in-depth alongside FR-004's BEFORE INSERT trigger and FR-017's client-side validator.

## Verification

```sql
SELECT id, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('listing-images', 'listing-videos');
```

Expected: 2 rows, both `public=true`, sizes 10485760 / 31457280, mime arrays as above. SC-029 references this query.

## Path convention

All objects in both buckets live at `<listing_id>/<filename>`. The owner INSERT policy on `storage.objects` enforces this shape via regex (see `phase11-storage-policies.md`).
