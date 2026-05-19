# listing_visibility

## Purpose

`listing_visibility` is a narrow one-to-one projection used by later map and
public-read phases. Phase 10 keeps `listings.location_visibility` authoritative
and syncs this child table by trigger.

## Shape

Defined in `supabase/migrations/20260519120005_create_listing_visibility.sql`.
`listing_id` is both the primary key and an FK to `public.listings(id) ON DELETE
CASCADE`.

## R-11 Sync Pattern

`listing_visibility_sync_trigger` fires on parent listing inserts and visibility
updates. It upserts the child row with `location_visibility`,
`contact_name_visibility`, `last_updated_by`, and `updated_at`.

## RLS Posture

RLS is enabled. Policies derive read/write authorization through the parent
`listings` row and are mirrored in
`supabase/policies/listing_visibility_policies.sql`.
