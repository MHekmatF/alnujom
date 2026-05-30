# agency_members

## Purpose

`public.agency_members` is the Phase 19 agency roster. Each row is one
(agency, user) membership. `member_role` is `admin` or `agent`; `status` moves
`pending` (invited) → `active` (accepted) | `removed` (declined / kicked). The
per-agency authorization gate throughout Phase 19 is **membership** (an `active`
`admin` row), NOT a global `agency_admin` role (R-140) — this is what the two
SECURITY DEFINER predicates below answer.

Authoritative interface contract:
[`specs/019-agencies/contracts/phase19-agency-members-table.md`](../../specs/019-agencies/contracts/phase19-agency-members-table.md).

## Shape

Defined in `supabase/migrations/20260531120002_create_agency_members_table.sql`.
Direct client writes are blocked at the table level (Migration …005 revokes
INSERT/UPDATE/DELETE) so every row originates from the privileged member RPCs
(`invite_agency_member`, `respond_agency_invitation`, `set_agency_member_role`,
`remove_agency_member`) and the `create_agency` owner-seed (Migration …008).

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `agency_id` | `uuid` | NOT NULL, FK -> `public.agencies(id)` ON DELETE CASCADE | The agency. |
| `user_id` | `uuid` | NOT NULL, FK -> `auth.users(id)` ON DELETE CASCADE | The member. |
| `member_role` | `text` | NOT NULL, CHECK in {`admin`,`agent`} | Per-agency role. |
| `status` | `text` | NOT NULL, DEFAULT `'pending'`, CHECK in {`pending`,`active`,`removed`} | Membership lifecycle. |
| `invited_by` | `uuid` | NULL, FK -> `auth.users(id)` ON DELETE SET NULL | The inviting admin (attribution survives that admin's deletion). |
| `joined_at` | `timestamptz` | NULL | Set when the invite is accepted. |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Server-generated. |
| `updated_at` | `timestamptz` | NOT NULL, DEFAULT `now()` | Maintained by the Phase 4 `set_updated_at` trigger. |
| — | — | **PRIMARY KEY `(agency_id, user_id)`** | One row per (agency, user) — makes invites idempotent (`ON CONFLICT (agency_id, user_id) DO NOTHING`). |

## Lifecycle

`pending` (invited) → `active` (accepted) | `removed` (declined / kicked). The
owner is seeded `admin`/`active` by `create_agency` and is protected from
role-change and removal (`cannot_modify_owner` / `cannot_remove_owner` in the
member RPCs).

## Indices

| Index | Definition | Purpose |
|-------|-----------|---------|
| `idx_agency_members_user` | `(user_id, status)` | "My agencies" + "my pending invitations" lookup. |

## Membership predicates (SECURITY DEFINER)

Defined in this migration; both `LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public`, `GRANT EXECUTE … TO authenticated`:

- `public.is_agency_member(p_agency_id uuid) RETURNS boolean` — true when
  `auth.uid()` is an `active` member of the agency.
- `public.is_agency_admin(p_agency_id uuid) RETURNS boolean` — true when
  `auth.uid()` is an `active` member with `member_role = 'admin'`.

They are SECURITY DEFINER so they bypass RLS — using a definer predicate inside
the `agency_members` RLS policy avoids the self-referential-RLS recursion an
inline `EXISTS` on `agency_members` would trigger. They are the per-agency
authorization gate used by the RLS policies (Migration …005), the write RPCs
(Migration …008), the storage policies (Migration …013), and the `submit_listing`
agency-membership branch (Migration …009).

## FK delete behaviors (R-144)

| FK column | References | ON DELETE behavior | Rationale |
|-----------|-----------|-------------------|-----------|
| `agency_id` | `public.agencies(id)` | **CASCADE** | Deleting an agency removes its roster with no orphans. |
| `user_id` | `auth.users(id)` | **CASCADE** | Deleting an account removes its memberships with no orphans. |
| `invited_by` | `auth.users(id)` | **SET NULL** | The membership survives the inviting admin's account deletion (attribution goes null, row stays). |

## RLS posture (forward-stated)

- **Migration 2 (this file)**: `ALTER TABLE public.agency_members ENABLE ROW
  LEVEL SECURITY` is set. NO policies are attached. Default-deny means direct
  reads return zero rows until Migration …005 attaches the reader policy.
- **Migration …005 (`20260531120005_create_agency_policies.sql`)** will add:
  - `agency_members_select` — SELECT for `authenticated` where
    `user_id = auth.uid() OR public.is_agency_member(agency_id) OR
    public.current_user_has_permission('agencies.view')` (so a member sees the
    same-agency roster, an invitee sees their own pending row, an admin sees all).
  - `REVOKE INSERT, UPDATE, DELETE ON public.agency_members FROM authenticated,
    anon` — no client write path; all member writes flow through the privileged
    RPCs (FR-017).
  - No `anon` policy.

The full live reader/writer matrix (data-model §1.14) is appended to this doc in
Sub-Phase C (T022).
