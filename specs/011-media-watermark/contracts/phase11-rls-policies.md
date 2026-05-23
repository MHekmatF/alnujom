# Contract: RLS policies on `public.listing_media` (FR-006)

**Source FRs**: FR-006, FR-009 | **Migration**: `20260522120001_create_listing_media.sql` (bundled inline) + parallel `supabase/policies/listing_media_policies.sql` | **Source-of-truth**: [data-model.md §4](../data-model.md#4-rls-policies-on-publiclisting_media-fr-006-fr-009--no-new-permission-keys)

## Constitution III posture

`public.listing_media` ships with `ENABLE ROW LEVEL SECURITY`. **No anon SELECT carve-out** (Phase 10 R-04 invariant preserved — Phase 11 does not add the fourth project-wide carve-out). Anon SELECT is gated by the parent listing's `status='approved'` + publish-window predicate, mirroring Phase 10's `public.listings` policy.

## Policy inventory — 7 policies

| # | Policy name | Role | Op | Predicate summary |
|---|---|---|---|---|
| 1 | `listing_media_anon_select_when_approved` | anon, authenticated | SELECT | Parent `status='approved'` + publish window open |
| 2 | `listing_media_owner_select` | authenticated | SELECT | Parent `publisher_user_id = auth.uid()` |
| 3 | `listing_media_admin_select` | authenticated | SELECT | `current_user_has_permission('listings.view_all')` |
| 4 | `listing_media_owner_insert` | authenticated | INSERT | Composite write-gate (see below) |
| 5 | `listing_media_owner_update` | authenticated | UPDATE | Composite write-gate (USING + WITH CHECK) |
| 6 | `listing_media_owner_delete` | authenticated | DELETE | Composite write-gate |
| 7 | `listing_media_admin_write` | authenticated | ALL | `current_user_has_permission('listings.edit_any')` |

## Composite write-gate predicate (policies 4–6)

```sql
EXISTS (
  SELECT 1 FROM public.listings l
  JOIN public.profiles p ON p.user_id = l.publisher_user_id
  WHERE l.id = listing_media.listing_id
    AND l.publisher_user_id = auth.uid()
    AND l.status IN ('draft', 'rejected')
    AND p.publisher_status = 'approved'
    AND p.account_status = 'approved'
)
```

Identical predicate across INSERT (`WITH CHECK`), UPDATE (both `USING` + `WITH CHECK`), and DELETE (`USING`).

## No new permission keys (FR-009, R-15)

Phase 6 §9.1 already carries:
- `listings.view_all` → admin SELECT (policy 3).
- `listings.edit_any` → admin write (policy 7).

Phase 11 introduces no new permission rows in `public.permissions`. SC-022 verifies this via `git diff` against the Phase 6 seed.

## Defense-in-depth alignment with `storage.objects` policies

The same composite write-gate predicate appears (with `split_part(name, '/', 1)::uuid` join instead of `listing_id`) in the 14 storage policies — see `phase11-storage-policies.md`. Both layers reject the same access patterns.

## Append-only / immutability invariants — N/A in Phase 11

Unlike Phase 10's `listing_status_history` (which is INSERT-only via `pg_trigger_depth()`), Phase 11's `listing_media` table accepts UPDATE + DELETE from authorized callers. The Q3=A resubmit path requires UPDATE (reorder, set-main) and DELETE (per-thumbnail delete). The audit trail captures every mutation (FR-005).

## Manual smoke tests (carried in quickstart.md)

| Scenario | Expected SELECT result |
|---|---|
| Anon SELECT against draft listing's media | 0 rows |
| Anon SELECT against approved+in-publish-window listing's media | N rows |
| Owner SELECT against own draft media | N rows |
| Different non-admin SELECT against another publisher's draft media | 0 rows |
| Admin (`listings.view_all`) SELECT against any media | N rows |

| Scenario | Expected INSERT result |
|---|---|
| Approved publisher INSERT during own `draft` listing | Success |
| Approved publisher INSERT during own `pending_review` listing | RLS deny (0 rows affected) |
| Pending/rejected/suspended publisher INSERT during own `draft` listing | RLS deny |
| Admin (`listings.edit_any`) INSERT into any listing's media | Success (subject to FR-004 cap trigger) |
| Anonymous INSERT | RLS deny |

## Idempotency

`DROP POLICY IF EXISTS ... CREATE POLICY` pattern across all 7 policies. Re-apply safe.
