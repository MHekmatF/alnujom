# Contract — `public.agencies` table + `agency_status` enum

**File**: `supabase/migrations/20260531120001_create_agencies_table.sql` (Sub-Phase B). Full SQL in `data-model.md §1.1`.

## Enum

`CREATE TYPE agency_status AS ENUM ('pending','approved','rejected','suspended')` — new; NOT in `init_enums.sql`; distinct from `account_approval_status` (which lacks `suspended`).

## Columns

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | `gen_random_uuid()` |
| `owner_user_id` | UUID NOT NULL **UNIQUE** | FK `auth.users(id)` `ON DELETE CASCADE` — one agency per owner (Q3=A / R-138) |
| `name` | TEXT NOT NULL | `CHECK length(trim(name)) > 0`; unique among `approved` only (see policies contract) |
| `description`,`phone`,`whatsapp`,`address`,`logo_path`,`cover_path` | TEXT NULL | public profile fields |
| `status` | `agency_status` NOT NULL | DEFAULT `'pending'` |
| `created_at`,`updated_at` | TIMESTAMPTZ NOT NULL | `now()`; `updated_at` via the Phase 4 `set_updated_at()` BEFORE-UPDATE trigger |

## Indices

- `idx_agencies_status (status)` — public directory + admin queue.
- `ux_agencies_name_approved (lower(name)) WHERE status='approved'` — created in the policies migration (`…005`).

## State

RLS enabled (policies in `…005`). Lifecycle `pending → approved | rejected`; `approved ↔ suspended` (R-149). Transitions ONLY via `moderate_agency_internal` (service-role).

## Smoke tests

1. `create_agency` inserts a `pending` row with `owner_user_id = auth.uid()`; a 2nd attempt by the same owner → `already_owns_agency` (the UNIQUE is the backstop).
2. `INSERT … status='approved'` directly from a client → denied (REVOKE; RPC-only writes).
3. Deleting the owner (`auth.users`) cascades the agency row away (R-144); a listing that referenced it has `agency_id` SET NULL.
