# Contract: Phase 10 RLS Policies

**Owner**: Phase 10, migrations `20260519120002` through `20260519120006`; mirror files under `supabase/policies/`.
**Consumers**: every Phase 10 read/write path; Phase 12 (admin approval path); Phase 13 (public listing detail); Phase 14 (search); Phase 15 (map).

## Obligations

The five new tables ship with the policy bundle captured in [data-model.md § RLS Policies](../data-model.md). Highlights:

### `public.listings`

- `listings_select_public` — SELECT to `anon, authenticated` USING `status='approved' AND publish-window-open`.
- `listings_select_owner` — SELECT to `authenticated` USING `auth.uid()=publisher_user_id`.
- `listings_select_admin` — SELECT to `authenticated` USING `current_user_has_permission('listings.view_all')`.
- `listings_insert_owner` — INSERT to `authenticated` WITH CHECK `auth.uid()=publisher_user_id AND <approved-pair gate>` (R-19).
- `listings_update_owner` — UPDATE to `authenticated` USING (own + status IN draft/rejected + approved-pair) WITH CHECK (own + status IN draft/pending_review).
- `listings_update_admin` — UPDATE to `authenticated` USING `listings.edit_any`.
- `listings_delete_admin` — DELETE to `authenticated` USING `listings.delete_any`.

### Child tables (`listing_details`, `listing_prices`, `listing_visibility`)

Each carries three policies that derive ownership through the parent via `EXISTS (SELECT 1 FROM public.listings l WHERE l.id = <child>.listing_id AND ...)`:

- `<table>_select_inherited` — to `anon, authenticated`, mirrors the parent's three SELECT branches.
- `<table>_write_owner` — to `authenticated`, FOR ALL, USING + WITH CHECK on `own + status IN ('draft','rejected')`.
- `<table>_admin` — to `authenticated`, FOR ALL, USING + WITH CHECK on `listings.edit_any`.

### `public.listing_status_history`

- `listing_status_history_insert_trigger_only` — INSERT WITH CHECK `pg_trigger_depth() > 0` (per R-09).
- `listing_status_history_select_owner` — SELECT to `authenticated` USING `(own parent listing) OR listings.view_all`.
- NO UPDATE policy. NO DELETE policy. (Per FR-007 append-only invariant.)

### Constitution III posture

- No table opts out of RLS.
- No broad anon SELECT carve-out (R-04 deviation from Phase 8/9 pattern, intentional).
- Public reads admit anonymous ONLY for `status='approved'` rows within the publish window.

## Verification

```sql
-- All 5 tables have RLS enabled and at least one policy:
SELECT c.relname,
       c.relrowsecurity,
       (SELECT count(*) FROM pg_policy p WHERE p.polrelid = c.oid) as policy_count
FROM pg_class c
WHERE c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname='public')
  AND c.relname IN ('listings','listing_details','listing_prices','listing_visibility','listing_status_history');
-- Expected: 5 rows; all relrowsecurity=t; all policy_count > 0

-- Append-only on listing_status_history
SELECT polcmd, count(*) FROM pg_policy p
JOIN pg_class c ON p.polrelid = c.oid
WHERE c.relname='listing_status_history' GROUP BY polcmd;
-- Expected: at least 'a' (ALL) or 'r' (SELECT) + 'i' (INSERT); NO 'w' (UPDATE) or 'd' (DELETE)

-- Anon SELECT on a draft listing returns 0 rows
SELECT count(*) FROM public.listings WHERE id=<draft_id>;
-- Run as anonymous; Expected: 0
```

## Forbidden

- Adding an UPDATE or DELETE policy to `public.listing_status_history`.
- Granting broad anonymous SELECT on `public.listings` regardless of status.
- Granting `auth.uid()=publisher_user_id` UPDATE on `approved`/`paused`/`sold`/`rented`/`expired` listings (only `draft` and `rejected` are owner-editable in Phase 10).
- Allowing publisher self-DELETE of own listings (DELETE is admin-only via `listings.delete_any`).
