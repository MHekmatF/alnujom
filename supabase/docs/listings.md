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

References: `specs/010-listing-creation/data-model.md`,
`contracts/phase10-tables.md`, `contracts/phase10-rls-policies.md`.
