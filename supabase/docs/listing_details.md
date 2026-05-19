# listing_details

## Purpose

`listing_details` is a one-to-one Phase 10 child table for optional descriptive
listing attributes: description, amenities, year built, furnished, and parking.

## Shape

Defined in `supabase/migrations/20260519120003_create_listing_details.sql`.
`listing_id` is both the primary key and an FK to `public.listings(id) ON DELETE
CASCADE`. The `amenities` column is JSONB and constrained to an array.

## RLS Posture

RLS is enabled. Policies derive read/write authorization through the parent
`listings` row:

- Public read follows the parent approved-and-published gate.
- Owner read/write follows parent ownership and editable statuses.
- Admin access uses `current_user_has_permission('listings.edit_any')`.

Policies are mirrored in `supabase/policies/listing_details_policies.sql`.

## Triggers

Only `trg_listing_details_set_updated_at` is attached; no status or audit logic
lives on this child table.
