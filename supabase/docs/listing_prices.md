# listing_prices

## Purpose

`listing_prices` stores listing price rows. Phase 10 presents a single-currency
UX, but the table keeps the Phase 9 forward-compatible row-per-currency shape.

## Shape

Defined in `supabase/migrations/20260519120004_create_listing_prices.sql`.

- `listing_id` references `public.listings(id) ON DELETE CASCADE`.
- `currency_code` references `public.currencies(code) ON DELETE RESTRICT`.
- `amount` is `NUMERIC(14,2)` and must be positive.
- `UNIQUE(listing_id, currency_code)` preserves the Phase 9 forward statement.
- `listing_prices_one_primary_idx` enforces at most one primary price per listing.

## Phase 10 Invariant

Per Q3, every Phase 10 surface allows exactly one price row per listing. The
schema remains ready for a future multi-currency spec.

## RLS Posture

RLS is enabled. Policies derive read/write authorization through the parent
`listings` row and are mirrored in `supabase/policies/listing_prices_policies.sql`.
