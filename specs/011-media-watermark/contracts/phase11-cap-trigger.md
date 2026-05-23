# Contract: `listing_media_cap_trigger` (FR-004)

**Source FRs**: FR-004 | **Migration**: `20260522120001_create_listing_media.sql` (bundled with table create) | **Source-of-truth**: [data-model.md §2](../data-model.md#2-cap-trigger--listing_media_cap_trigger-fr-004)

## Function signature

```sql
CREATE OR REPLACE FUNCTION public.listing_media_cap_check() RETURNS TRIGGER
```

## Trigger attachment

```sql
CREATE TRIGGER listing_media_cap_trigger
  BEFORE INSERT ON public.listing_media
  FOR EACH ROW EXECUTE FUNCTION public.listing_media_cap_check();
```

## Behavior matrix

| `NEW.kind` | Predicate | Cap | Action if cap exceeded |
|---|---|---|---|
| `'image'` | `count(*) FROM listing_media WHERE listing_id = NEW.listing_id AND kind = 'image'` ≥ 10 | 10 | `RAISE EXCEPTION` (P0001) with structured DETAIL |
| `'video'` | `count(*) FROM listing_media WHERE listing_id = NEW.listing_id AND kind IN ('video','external_link')` ≥ 2 | 2 | `RAISE EXCEPTION` (P0001) with structured DETAIL |
| `'external_link'` | (same combined predicate as video) | 2 | Same — but Phase 11 UI never inserts; only direct admin SQL could trigger this branch |

## Error payload (R-30)

| Field | Value |
|---|---|
| SQLSTATE | `P0001` |
| MESSAGE | `'listing_media.cap_exceeded'` |
| DETAIL (JSONB-as-TEXT) | `{ "code": "listing_media.cap_exceeded", "kind": "image"|"video", "current_count": <int>, "max": 10|2 }` |

## Client handling

`SupabaseListingMediaDatasource.uploadImage()` and `.uploadVideo()` catch `PostgrestException`:
- Read `error.message` — if equals `'listing_media.cap_exceeded'`, parse `error.details` as JSON.
- Surface the localized ARB string `media.cap.images10` (for `kind=image`) or `media.cap.videos2` (for `kind=video`) per FR-019.

## Defense-in-depth

This trigger fires for **all callers** including admins with `listings.edit_any` — admins cannot bypass the cap. SC-018 verifies the admin path.

## Idempotency

`CREATE OR REPLACE FUNCTION` + `DROP TRIGGER IF EXISTS ... CREATE TRIGGER` makes re-apply safe.
