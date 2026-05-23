# listings

## Purpose

`listings` is the Phase 10 parent table for publisher-created real-estate listings.
It stores the canonical listing row, including ownership, classification,
location, contact fields, status, and publication window.

## Shape

Defined in `supabase/migrations/20260519120002_create_listings.sql` with 25
columns. Notable constraints:

- `publisher_user_id` references `auth.users(id)` with cascade delete.
- `governorate_id`, `city_id`, and `area_id` reference the Phase 8 location tables.
- `agency_id` is intentionally FK-less in Phase 10; Phase 19 adds the agency FK.
- `status` is constrained to the Phase 10 listing lifecycle values.
- `location_visibility` and `contact_name_visibility` are constrained text enums.

## RLS Posture

RLS is enabled. Policies are bundled inline in the migration and mirrored in
`supabase/policies/listings_policies.sql`.

- Anonymous and authenticated users can read only approved listings inside the
  publication window.
- Owners can read their own listings in any status.
- Admin reads use `current_user_has_permission('listings.view_all')`.
- Owner inserts require `auth.uid() = publisher_user_id` and an approved
  `profiles.publisher_status` + `profiles.account_status` pair.
- Owner updates are limited to `draft` and `rejected` listings.
- Admin updates/deletes use `listings.edit_any` and `listings.delete_any`.

## Triggers

- `trg_listings_set_updated_at` maintains `updated_at`.
- `listing_visibility_sync_trigger` syncs parent visibility fields to
  `listing_visibility`.
- `listing_status_transition_trigger` appends operational status history rows.
- `listings_audit_trigger` emits listing audit action keys.

## Phase 11 Amendment — Media-Minimum Check in `submit_listing`

**Migration**: `20260522120004_amend_submit_listing_rpc_for_media_minimum.sql`
**FR**: FR-022 | **Q-resolution**: Q1=A

Phase 11 amends `public.submit_listing(p_listing_id UUID)` via `CREATE OR REPLACE
FUNCTION` to add a media-minimum check as step 5a between the price-count check
and the `IF-RAISE` block. The check:

```sql
SELECT count(*) INTO v_image_count
  FROM public.listing_media
  WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true;
IF v_image_count = 0 THEN
  v_missing := array_append(v_missing, 'listing_media.images_below_minimum');
END IF;
```

If no watermarked image rows exist for the listing, `'listing_media.images_below_minimum'`
is appended to `v_missing[]`. The structured error payload (`SQLSTATE 22023`,
`missing_fields[]` array) is unchanged — the Phase 10
`submit_failure_dialog.dart` already iterates this array without source-code
changes required. Phase 11 adds the ARB key `submit.error.imagesBelowMinimum`
to both `app_ar.arb` and `app_en.arb`.

**Immutability**: The Phase 10 migration
`20260519120007_create_submit_listing_rpc.sql` is NOT edited (R-35). Migration 4
supersedes the function body via `CREATE OR REPLACE`. SECURITY DEFINER,
`search_path=public,auth`, and the EXECUTE grant to `authenticated` are all
preserved by `CREATE OR REPLACE`.

**Cross-reference**: `specs/011-media-watermark/contracts/submit-listing-amendment.md`

The `public.listings` table itself is **unchanged** in Phase 11 — no new columns,
no new constraints, no new indexes.

References: `specs/010-listing-creation/data-model.md`,
`contracts/phase10-tables.md`, `contracts/phase10-rls-policies.md`.

## Phase 12 amendments

**Spec**: `specs/012-listing-approval` (Phase 12 — Listing Approval Workflow)

The `public.listings` table itself is **unchanged** in Phase 12 — no new columns,
no new constraints, no new indexes. Phase 12 ships:

- **`approve_listing` Edge Function** is the ONLY writer that flips `status` to
  `approved`. The Edge Function sets `published_at = now()` in the same UPDATE
  and leaves `expires_at` at the column default `NULL` per clarification Q2=A
  (no auto-expiry; future Phase 23 settings may introduce a default expiry).
- **`reject_listing` Edge Function** flips `status` to `rejected` and the
  amended `listing_status_transition_trigger_fn` writes the JSON-encoded
  rejection reason (Q4=A) into `listing_status_history.reason`.
- Both Edge Functions guard the UPDATE with `.eq('status', 'pending_review')`
  so concurrent admin races produce HTTP 409 `already_acted_on` for the loser.

Phase 12 amends three pre-existing functions via a single new migration
(`20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`) so the
Edge Function service-role caller's admin UID flows to:

- `listing_status_history.changed_by` via the amended
  `listing_status_transition_trigger_fn` (sources from session variable
  `app.current_user_id` set immediately before the UPDATE).
- `audit_logs.actor_user_id` via the amended `listings_audit_trigger_fn` and
  `log_audit()` (same session variable, COALESCE fallback to `auth.uid()`).

The Phase 10 migration file `20260519120006_create_listing_status_history.sql`
remains UNEDITED (R-35 immutability).
