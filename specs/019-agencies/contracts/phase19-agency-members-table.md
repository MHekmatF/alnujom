# Contract — `public.agency_members` table + membership predicates

**File**: `supabase/migrations/20260531120002_create_agency_members_table.sql` (Sub-Phase B). Full SQL in `data-model.md §1.2`.

## Columns / key

| Column | Type | Notes |
|--------|------|-------|
| `agency_id` | UUID NOT NULL | FK `agencies(id)` `ON DELETE CASCADE` |
| `user_id` | UUID NOT NULL | FK `auth.users(id)` `ON DELETE CASCADE` |
| `member_role` | TEXT NOT NULL | `CHECK IN ('admin','agent')` |
| `status` | TEXT NOT NULL | DEFAULT `'pending'`; `CHECK IN ('pending','active','removed')` |
| `invited_by` | UUID NULL | FK `auth.users(id)` `ON DELETE SET NULL` |
| `joined_at` | TIMESTAMPTZ NULL | set on accept |
| PK | `(agency_id, user_id)` | one row per (agency, user) — idempotent invites |

Index `idx_agency_members_user (user_id, status)` (my-agencies + my-invitations). RLS enabled.

## Predicates (SECURITY DEFINER — bypass RLS, used by policies + RPCs)

- `public.is_agency_member(p_agency_id uuid) RETURNS boolean` — `auth.uid()` is an `active` member.
- `public.is_agency_admin(p_agency_id uuid) RETURNS boolean` — `auth.uid()` is an `active` member with `member_role='admin'`.

Both `GRANT EXECUTE … TO authenticated`. They are the per-agency authorization gate (R-140) — NOT the global `agency_admin` role. Using a definer predicate avoids the self-referential-RLS recursion an inline `EXISTS` on `agency_members` would trigger.

## Lifecycle

`pending` (invited) → `active` (accepted) | `removed` (declined / kicked). The owner is seeded `admin`/`active` by `create_agency` and is protected from role-change/removal (`cannot_modify_owner` / `cannot_remove_owner`).

## Smoke tests

1. `create_agency` seeds the owner row `admin`/`active`.
2. Direct client `INSERT/UPDATE/DELETE` → denied (REVOKE; RPC-only).
3. `is_agency_admin(agency)` is true for the owner, false for an `agent`, false for a non-member.
