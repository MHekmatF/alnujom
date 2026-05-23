# Contract: `public.listing_media` table

**Source FRs**: FR-001, FR-002, FR-003 | **Migration**: `20260522120001_create_listing_media.sql` | **Source-of-truth**: [data-model.md §1](../data-model.md#1-new-table--publiclisting_media)

## Column shape

| Column | Type | Nullability | Default | Notes |
|---|---|---|---|---|
| `id` | UUID | NOT NULL | `gen_random_uuid()` | Primary key. Preserved across Q3=A resubmits (R-14). |
| `listing_id` | UUID | NOT NULL | — | FK → `public.listings(id) ON DELETE CASCADE`. |
| `kind` | TEXT | NOT NULL | — | CHECK ∈ `{image, video, external_link}`. Phase 11 UI inserts only `image` + `video` (Q2=D). |
| `storage_path` | TEXT | NULL | — | Required for `image`/`video`; NULL for `external_link`. |
| `external_url` | TEXT | NULL | — | Required for `external_link`; NULL for `image`/`video`. No Phase 11 UI inserts. |
| `ordering` | INTEGER | NOT NULL | 0 | Publisher drag-reorder index. |
| `is_main` | BOOLEAN | NOT NULL | false | Exactly one `true` per listing for `kind=image` (partial index). Never `true` for video/external_link (CHECK). |
| `watermarked` | BOOLEAN | NOT NULL | false | Set true by FR-016 at upload. Q1=A FR-022 counts only `kind='image' AND watermarked=true`. |
| `created_at` | TIMESTAMPTZ | NOT NULL | `now()` | Append-only. |
| `updated_at` | TIMESTAMPTZ | NOT NULL | `now()` | Maintained by Phase 4's `set_updated_at`. |

## Constraints

- `listing_media_path_xor_url_chk` — mutual exclusivity between `storage_path` and `external_url`.
- `listing_media_main_only_when_image_chk` — `is_main=true` permitted only when `kind='image'`.
- Partial unique index `listing_media_one_main_idx ON (listing_id) WHERE is_main=true AND kind='image'`.
- Index `listing_media_listing_id_idx` and `listing_media_listing_id_ordering_idx` on (`listing_id`) and (`listing_id`, `ordering`).
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.

## Triggers attached on this table

| Trigger | Timing | Function | FR |
|---|---|---|---|
| `set_updated_at_on_listing_media` | BEFORE UPDATE | Phase 4 `set_updated_at()` | (utility) |
| `listing_media_cap_trigger` | BEFORE INSERT | `listing_media_cap_check()` | FR-004 |
| `audit_listing_media_insert` | AFTER INSERT | `log_audit('listing_media.created')` | FR-005 |
| `audit_listing_media_update` | AFTER UPDATE | `log_audit('listing_media.updated')` | FR-005 |
| `audit_listing_media_delete` | AFTER DELETE | `log_audit('listing_media.deleted')` | FR-005 |

## Lifecycle

- INSERT during owner draft/rejected window OR by admin with `listings.edit_any` — FR-006.
- Cascade-DELETE with parent `public.listings` row.
- UPDATE permitted on `ordering`, `is_main` (subject to partial index), and metadata; NOT on `id`, `listing_id`, `kind`, `storage_path`, `external_url`, `watermarked` (no enforced lock — convention only).

## Idempotency

The migration uses `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`. Re-apply is safe (matches Phase 4–10 pattern).
