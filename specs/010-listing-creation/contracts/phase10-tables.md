# Contract: Phase 10 Tables

**Owner**: Phase 10, migrations `20260519120002` through `20260519120006`.
**Consumers**: every Phase 10 contract below; Phase 11 (listing_media adds 1:N child); Phase 12 (approve/reject path UPDATEs listings); Phase 13/14/15 (public read paths).

## Obligations

The five new tables MUST be created with the exact column shapes, constraints, indexes, and RLS-enabled state captured in [data-model.md § Tables](../data-model.md). The full CREATE TABLE bodies are normative.

In particular:

1. **`public.listings`** — 25 columns; PK `id UUID`; FKs to `auth.users`, `governorates`, `cities`, `areas`. `agency_id` has NO FK in Phase 10 (R-17). `status` defaults to `'draft'` with the 9-value CHECK. `location_visibility` defaults `'approximate'` with the 4-value CHECK. `contact_name_visibility` defaults `'public'` with the 2-value CHECK. `area_size NUMERIC(10,2) CHECK (>0 OR NULL)`. RLS enabled. `set_updated_at` trigger attached.
2. **`public.listing_details`** — 8 columns; PK `listing_id` is also the FK to `listings(id) ON DELETE CASCADE`. `amenities JSONB` defaults to `'[]'::jsonb` with `jsonb_typeof = 'array'` CHECK. `year_built` 1850 ≤ value ≤ current_year + 2. RLS enabled.
3. **`public.listing_prices`** — 7 columns; PK `id UUID`; FK to `listings(id) ON DELETE CASCADE` AND FK to `currencies(code) ON DELETE RESTRICT`. `amount NUMERIC(14, 2) CHECK (>0)` (R-10). `UNIQUE (listing_id, currency_code)` (Phase 9 Q4). Partial unique index `(listing_id) WHERE is_primary=true` (R-12). RLS enabled.
4. **`public.listing_visibility`** — 6 columns; PK `listing_id` is also the FK to `listings(id) ON DELETE CASCADE`. `last_updated_by` FK to `auth.users(id) ON DELETE SET NULL`. RLS enabled. `set_updated_at` trigger attached.
5. **`public.listing_status_history`** — 7 columns; PK `id UUID`; FK to `listings(id) ON DELETE CASCADE`. `changed_by` FK to `auth.users(id) ON DELETE SET NULL`. RLS enabled. Index `(listing_id, changed_at DESC)`.

## Verification

```sql
-- All 5 tables exist with RLS enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='public' AND tablename IN
  ('listings','listing_details','listing_prices','listing_visibility','listing_status_history');
-- Expected: 5 rows, all rowsecurity=t

-- listings columns
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='listings' ORDER BY ordinal_position;
-- Expected: 25 columns matching data-model.md

-- listing_prices constraints
SELECT constraint_name FROM information_schema.table_constraints
WHERE table_name='listing_prices' AND constraint_type IN ('UNIQUE','CHECK');
-- Expected: includes UNIQUE(listing_id, currency_code) AND CHECK on amount>0

-- listing_prices partial primary index
SELECT indexname, indexdef FROM pg_indexes WHERE indexname='listing_prices_one_primary_idx';
-- Expected: 1 row with (listing_id) WHERE is_primary = true
```

## Forbidden

- Renaming `status` to anything else (audit trigger + RLS policies + status-transition trigger all read this name).
- Changing `NUMERIC(14, 2)` precision on `listing_prices.amount` (R-10 lock-in).
- Adding an FK on `listings.agency_id` in Phase 10 (R-17; Phase 19 owns it).
- Adding an UPDATE or DELETE policy to `listing_status_history` (R-09 append-only invariant; FR-007).
