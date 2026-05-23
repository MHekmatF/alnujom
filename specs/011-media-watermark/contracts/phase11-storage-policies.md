# Contract: `storage.objects` RLS policies for `listing-images` + `listing-videos`

**Source FRs**: FR-007, R-27 | **Migration**: `20260522120003_create_listing_media_storage_policies.sql` + parallel `supabase/policies/listing_media_storage_policies.sql` | **Source-of-truth**: [data-model.md §6](../data-model.md#6-rls-policies-on-storageobjects-fr-007-r-27-migration-3)

## Policy inventory — 12 policies total

For EACH of `listing-images` and `listing-videos` (substitute the bucket id in policy names + USING clauses), six policies ship:

| # | Policy name | Role | Operation | Predicate summary |
|---|---|---|---|---|
| 1 | `<bucket>_anon_select_when_approved` | anon, authenticated | SELECT | Parent listing `status='approved'` + publish window open |
| 2 | `<bucket>_owner_select` | authenticated | SELECT | Parent listing `publisher_user_id = auth.uid()` (any status of own) |
| 3 | `<bucket>_admin_select` | authenticated | SELECT | `current_user_has_permission('listings.view_all')` |
| 4 | `<bucket>_owner_insert` | authenticated | INSERT | Composite write-gate + path-shape WITH CHECK |
| 5 | `<bucket>_owner_update` | authenticated | UPDATE | Composite write-gate (USING + WITH CHECK) |
| 6 | `<bucket>_owner_delete` | authenticated | DELETE | Composite write-gate |
| 7 | `<bucket>_admin_write` | authenticated | ALL | `current_user_has_permission('listings.edit_any')` (single FOR ALL policy covering admin INSERT/UPDATE/DELETE) |

Total: 7 × 2 buckets = **14 policies** (six owner+anon policies + one admin FOR ALL policy per bucket).

## Path-shape enforcement (R-27)

The owner INSERT policy's `WITH CHECK` requires:
```sql
storage.objects.name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
```
Uploads to paths not matching `<UUID>/<filename>` are rejected at INSERT.

## Composite write-gate predicate (owner policies 4–6)

```sql
bucket_id = '<bucket>'
AND EXISTS (
  SELECT 1 FROM public.listings l
  JOIN public.profiles p ON p.user_id = l.publisher_user_id
  WHERE l.id = split_part(storage.objects.name, '/', 1)::uuid
    AND l.publisher_user_id = auth.uid()
    AND l.status IN ('draft', 'rejected')
    AND p.publisher_status = 'approved'
    AND p.account_status = 'approved'
)
```

Identical predicate across INSERT (in `WITH CHECK`), UPDATE (in `USING` + `WITH CHECK`), and DELETE (in `USING`). Mirrors `phase11-rls-policies.md`'s composite for `public.listing_media`.

## Verification

```sql
SELECT count(*) FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (policyname LIKE 'listing_images_%' OR policyname LIKE 'listing_videos_%');
```
Expected: ≥ 14 rows after Phase 11 apply. SC-029 references this count.

> **Naming note**: bucket IDs are hyphenated (`listing-images`, `listing-videos`) but the policy names use underscores (`listing_images_*`, `listing_videos_*`). Unquoted SQL identifiers cannot contain hyphens; the LIKE pattern must match the underscored policy name, not the bucket id.

## Manual smoke tests (carried in quickstart.md)

| Scenario | Expected |
|---|---|
| Anonymous GET against a `draft` listing's object URL | 403 |
| Anonymous GET against an `approved`+in-publish-window listing's object URL | 200 + bytes |
| Owner (the listing's publisher) GET against own `draft` listing's object | 200 + bytes |
| Different non-admin publisher GET against another publisher's `draft` object | 403 |
| Admin with `listings.view_all` GET against any status | 200 + bytes |
| Owner POST with malformed path (no UUID prefix) | 403 (path-shape WITH CHECK rejects) |
| Owner POST during own `pending_review` listing | 403 (status NOT IN draft/rejected) |
