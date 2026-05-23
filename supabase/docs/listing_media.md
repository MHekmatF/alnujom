# listing_media

## Purpose

`listing_media` is the Phase 11 child table storing 1:N media artifacts per
listing. Each row represents one image (JPEG, client-side watermarked), one
video (MP4, direct upload), or one external link (URL — reserved per Q2=D for
a future spec; no Phase 11 UI inserts this kind).

## Shape

Defined in `supabase/migrations/20260522120001_create_listing_media.sql`. Ten
columns:

| Column | Type | Nullability | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NOT NULL | `gen_random_uuid()` | PK. Preserved across resubmits per R-14 (Q3=A edit-in-place). |
| `listing_id` | `UUID` | NOT NULL | — | FK to `public.listings(id)` ON DELETE CASCADE. |
| `kind` | `TEXT` | NOT NULL | — | CHECK enum: `'image'`, `'video'`, `'external_link'`. Phase 11 UI inserts only `image` + `video` per Q2=D. |
| `storage_path` | `TEXT` | NULL | — | Required for `kind IN ('image','video')`; NULL for external_link. Path shape: `<listing_id>/<ordering>_<rand>.jpg` or `.mp4`. |
| `external_url` | `TEXT` | NULL | — | Required for `kind='external_link'`; NULL for image/video. Reserved; no Phase 11 inserts. |
| `ordering` | `INTEGER` | NOT NULL | 0 | Publisher-controlled drag-reorder index; re-sequenced as 1..N on each reorder. |
| `is_main` | `BOOLEAN` | NOT NULL | false | Exactly one row per listing has `true` for `kind='image'` (partial unique index enforces). Never `true` for video/external_link (CHECK constraint enforces). |
| `watermarked` | `BOOLEAN` | NOT NULL | false | `true` for every Phase 11 client-uploaded image (FR-016). Used by the Q1=A FR-022 media-minimum check in `submit_listing`. |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | `now()` | Append-only. |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | `now()` | Maintained by Phase 4's `set_updated_at` trigger. |

### CHECK Constraints

- `listing_media_path_xor_url_chk`: mutual exclusivity between `storage_path`
  and `external_url` per kind. Images and videos must have a `storage_path` and
  null `external_url`; external_link rows must have `external_url` and null
  `storage_path`.
- `listing_media_main_only_when_image_chk`: `is_main = false OR kind = 'image'`
  — prevents video and external_link rows from being set as the main image.

### Indexes

- `listing_media_listing_id_idx` on `(listing_id)` — covers FK join performance.
- `listing_media_listing_id_ordering_idx` on `(listing_id, ordering)` — covers
  ordered fetch for the picker (SELECT ... ORDER BY ordering ASC).
- `listing_media_one_main_idx` (partial unique) on `(listing_id) WHERE is_main =
  true AND kind = 'image'` — enforces exactly one main image per listing (FR-003).

## Cap Trigger (FR-004)

`listing_media_cap_trigger` is a BEFORE INSERT trigger running
`listing_media_cap_check()`. It enforces:

- At most **10 image** rows per listing (`kind = 'image'`).
- At most **2 video/external_link** rows per listing (`kind IN ('video',
  'external_link')` combined — defense-in-depth for the future external_link
  kind per Q2=D).

On cap violation the trigger raises SQLSTATE `P0001` with MESSAGE
`'listing_media.cap_exceeded'` and a DETAIL JSONB:

```json
{
  "code": "listing_media.cap_exceeded",
  "kind": "image" | "video",
  "current_count": <int>,
  "max": 10 | 2
}
```

The Flutter datasource catches `PostgrestException` and parses this payload to
surface the appropriate ARB key (`media.cap.images10` or `media.cap.videos2`).

## Audit Trigger Group (FR-005)

Phase 4's `log_audit()` function is reused verbatim — this is its **eighth**
reuse across Phases 4/5/6/7/8/9/10/11 (R-05 invariant preserved). Three
triggers emit one `audit_logs` row per row-level mutation:

| Trigger | Event | Action Key |
|---|---|---|
| `audit_listing_media_insert` | AFTER INSERT | `listing_media.created` |
| `audit_listing_media_update` | AFTER UPDATE | `listing_media.updated` |
| `audit_listing_media_delete` | AFTER DELETE | `listing_media.deleted` |

The set-as-main operation fires `listing_media.updated` twice per logical action
(one for the row gaining `is_main=true`, one for the row losing it) per FR-021.

## RLS Posture

RLS is enabled. Seven policies are bundled inline in
`supabase/migrations/20260522120001_create_listing_media.sql` and mirrored to
`supabase/policies/listing_media_policies.sql` (R-02 dual-storage invariant):

| Policy | Role | Operation | Condition |
|---|---|---|---|
| `listing_media_anon_select_when_approved` | anon, authenticated | SELECT | Parent listing `status='approved'` + publish window open |
| `listing_media_owner_select` | authenticated | SELECT | Auth user is parent listing's `publisher_user_id` |
| `listing_media_admin_select` | authenticated | SELECT | `current_user_has_permission('listings.view_all')` |
| `listing_media_owner_insert` | authenticated | INSERT | Owner + `status IN ('draft','rejected')` + `publisher_status='approved'` + `account_status='approved'` |
| `listing_media_owner_update` | authenticated | UPDATE | Same composite gate as owner INSERT |
| `listing_media_owner_delete` | authenticated | DELETE | Same composite gate as owner INSERT |
| `listing_media_admin_write` | authenticated | ALL | `current_user_has_permission('listings.edit_any')` |

No fourth anonymous carve-out is added (Phase 10 R-04 invariant preserved —
Phase 11 inherits the Phase 10 listings public-read gate via the parent join).

## Storage Integration

Two new Supabase Storage buckets created in migration
`20260522120002_create_listing_media_storage_buckets.sql`:

| Bucket | `public` | `file_size_limit` | `allowed_mime_types` | Notes |
|---|---|---|---|---|
| `listing-images` | `true` | 10 MB (10485760) | `['image/jpeg']` | Q4=A: pipeline normalizes source to JPEG. Q8=A: public+RLS. |
| `listing-videos` | `true` | 30 MB (31457280) | `['video/mp4']` | Direct MP4 upload only per Q2=D. |

Fourteen RLS policies on `storage.objects` (7 per bucket × 2 buckets) are
defined in migration `20260522120003_create_listing_media_storage_policies.sql`
and mirrored to `supabase/policies/listing_media_storage_policies.sql`.

### Two-Step Storage-Cleanup Ordering (R-28, R-38)

When a publisher deletes a media row, the client MUST perform operations in this
order:

1. `storage.from(bucket).remove([storage_path])` — remove bucket object first.
2. `from('listing_media').delete().eq('id', mediaId)` — then delete the row.

On storage failure: retry once. On second failure: abort without the SQL DELETE
(the row stays, preserving the publisher's ability to retry the delete).
On SQL failure after storage succeeded: surface a localized "cleanup partial"
message; the picker reloads from server and the orphaned row reappears. A future
Phase 23 reconciliation job will clean up orphaned bucket objects.

## Q1-Q8 Surface Alignment

| Question | Phase 11 Answer | Backend enforcement |
|---|---|---|
| Q1=A | >=1 watermarked image required at submit | `submit_listing` step 5a in migration 4 |
| Q2=D | `external_link` kind reserved, no Phase 11 UI | Kind CHECK retains the enum value |
| Q3=A | Edit-in-place on resubmit, row UUIDs preserved | No cascade delete on resubmit; publisher edits existing rows |
| Q4=A | Bucket accepts only `image/jpeg` | `allowed_mime_types` enforced by Supabase Storage |
| Q5=A | n/a -- permission declarations in AndroidManifest | No backend surface |
| Q6=B | n/a -- 8000x8000 cap checked client-side before decode | No server-side dimension check (bucket validates mime + size only) |
| Q7=B | n/a -- 60s timeout enforced at BLoC layer | No server-side timeout |
| Q8=A | Buckets `public=true` + RLS on storage.objects | 14 policies in migration 3 |

## References

- Table design: `specs/011-media-watermark/data-model.md §§ 1-4`
- Contract: `specs/011-media-watermark/contracts/phase11-listing-media-table.md`
- RLS contract: `specs/011-media-watermark/contracts/phase11-rls-policies.md`
- Cap trigger contract: `specs/011-media-watermark/contracts/phase11-cap-trigger.md`
- Audit trigger contract: `specs/011-media-watermark/contracts/phase11-audit-triggers.md`
- Storage bucket contract: `specs/011-media-watermark/contracts/phase11-storage-buckets.md`
- Storage policy contract: `specs/011-media-watermark/contracts/phase11-storage-policies.md`
