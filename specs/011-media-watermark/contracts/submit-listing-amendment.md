# Contract: `submit_listing` RPC amendment for Q1=A media-minimum

**Source FRs**: FR-022 | **Migration**: `20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` | **Predecessor**: [Phase 10's submit-listing-rpc.md](../../010-listing-creation/contracts/submit-listing-rpc.md) | **Source-of-truth**: [data-model.md §7](../data-model.md#7-amended-submit_listing-rpc-fr-022-r-31-r-35-migration-4)

## Amendment scope

Phase 11 amends Phase 10's `public.submit_listing(p_listing_id UUID) RETURNS JSONB` via `CREATE OR REPLACE FUNCTION` in a NEW migration file. The Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` is **NOT edited** per R-35 (Supabase migration tracker immutability).

The amendment is **additive only** — the function signature, permission preconditions, status flip logic, and JSONB return shape are unchanged from Phase 10. The only delta is one INSERT into the `v_missing TEXT[]` accumulator in step (5a).

## Phase 10 body order — unchanged

1. Load listing (raise 42704 if not found).
2. Verify `auth.uid() = listing.publisher_user_id` (raise 42501).
3. Verify `publisher_status='approved' AND account_status='approved'` (raise 42501).
4. Verify `status IN ('draft', 'rejected')` (raise 22023).
5. Q1=B Full required-field validation populating `v_missing[]`.
6. If `array_length(v_missing) > 0` → RAISE 22023 with combined DETAIL.
7. UPDATE status to `pending_review`.
8. Return JSONB success payload.

## Phase 11 insertion — step (5a)

Between Phase 10 steps 5 and 6, insert:

```sql
SELECT count(*) INTO v_image_count
FROM public.listing_media
WHERE listing_id = p_listing_id
  AND kind = 'image'
  AND watermarked = true;
IF v_image_count = 0 THEN
  v_missing := array_append(v_missing, 'listing_media.images_below_minimum');
END IF;
```

## Combined `missing_fields[]` shape

The Phase 10 RAISE EXCEPTION (step 6) emits the combined list — no separate emission path for the media key. The structured DETAIL JSONB returns:

```json
{
  "code": "submit_listing.missing_fields",
  "missing_fields": ["listings.title", "listings.area_size", "listing_media.images_below_minimum"]
}
```

Where the array order is: Phase 10 required fields first (in declaration order), then `listing_media.images_below_minimum` last (because step 5a runs after Phase 10's step 5).

## Client-side handling

Phase 10's `lib/features/listing_form/presentation/widgets/submit_failure_dialog.dart` iterates the `missing_fields[]` array and renders each key via `AppLocalizations` lookup. Phase 11 adds one new ARB key:

| Key | English | Arabic (draft) |
|---|---|---|
| `submit.error.imagesBelowMinimum` | "At least one photo is required" | "لازم صورة واحدة على الأقل" |

No source-code changes are required in `submit_failure_dialog.dart` — the dialog's iteration handles the new key automatically once the ARB entries exist.

## Q3=A resubmit alignment

The amended RPC body runs the media-minimum check against the **post-edit** state of `listing_media`. A publisher who deletes all images during a resubmit (Q3=A edit-in-place path) is rejected with `listing_media.images_below_minimum` per FR-022 + spec US3 acceptance scenario 4.

## R-35 immutability invariant

Phase 10's migration file `20260519120007_create_submit_listing_rpc.sql` is committed to source unchanged. The Supabase migration tracker records Phase 10's migration as applied; Phase 11's migration 4 is a NEW row in the tracker. After Phase 11 apply, the function body in the DB reflects Phase 11's version. Phase 10's migration file remains in source for historical audit.

`project_supabase_mcp_apply_migration.md` is the binding reference for why we cannot edit Phase 10's file in place.

## Idempotency

`CREATE OR REPLACE FUNCTION` is inherently idempotent — re-apply is safe. The migration filename is unique to Phase 11.

## Verification

| Test | Expected |
|---|---|
| Submit a draft with all Phase 10 fields + zero images | HTTP 400; `missing_fields[]` contains `listing_media.images_below_minimum` |
| Submit a draft with all Phase 10 fields + 1 image | HTTP 200; status flips to `pending_review` |
| Submit a `rejected` listing with all fields + zero images (Q3=A path) | HTTP 400; same `images_below_minimum` rejection |
| Submit by a non-owner | HTTP 403 (SQLSTATE 42501, unchanged from Phase 10) |
| `git diff` Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` | 0 changes (immutability) |
