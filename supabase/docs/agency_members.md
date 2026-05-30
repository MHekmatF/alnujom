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

## Live RLS reader/writer matrix (Sub-Phase C, Migration …005)

Attached by `supabase/migrations/20260531120005_create_agency_policies.sql`
(load-bearing — Principle III, data-model §1.14):

| Actor | `agencies` SELECT | `agency_members` SELECT | `agency_verification_requests` SELECT | any table INSERT/UPDATE/DELETE | Vault id/registration |
|-------|-------------------|--------------------------|----------------------------------------|--------------------------------|------------------------|
| Anonymous | ✅ only `status='approved'` | ❌ | ❌ | ❌ | ❌ |
| Authenticated non-member | ✅ approved only | ✅ own invitation row only | ❌ | ❌ (RPC only) | ❌ |
| Owner / active member | ✅ own agency (any status) | ✅ own agency roster | agency-admins ✅ / agents ❌ | ❌ (RPC only) | ❌ (admin-decrypt only) |
| `agencies.view`/`approve`/`suspend` holder | ✅ ALL | ✅ ALL | ✅ ALL | ❌ (moderate_agency → service-role RPC only) | ✅ via `app_vault_secret_for_agency` |
| `service_role` (Edge Fn) | n/a (bypasses RLS) | n/a | n/a | via `moderate_agency_internal` only | n/a |

`agency_members` policy (Migration …005):

- `agency_members_select` — `TO authenticated USING (user_id=auth.uid() OR
  public.is_agency_member(agency_id) OR
  public.current_user_has_permission('agencies.view'))` — an invitee sees their own
  pending row, an active member sees the same-agency roster, an `agencies.view`
  holder sees all.
- `REVOKE INSERT, UPDATE, DELETE ON public.agency_members FROM authenticated, anon`
  — no client write; all member writes flow through the privileged RPCs (FR-017).
- No `anon` policy.

## Roster reads via `v_agencies` scoping

App reads of agency profiles go through the SECURITY DEFINER `public.v_agencies`
view (Migration …006), whose explicit owner/member/admin WHERE reproduces rows 1–4
of the matrix above (so a member's own `pending` agency stays visible). The
`agency_members` base policy here governs roster reads + defense-in-depth.

## Audit triggers (Migration …011)

`supabase/migrations/20260531120011_create_agency_audit_triggers.sql` attaches TWO
triggers (the INSERT/DELETE and the UPDATE-OF cases are intentionally **split** —
combining an `OF column-list` with INSERT/DELETE in one `CREATE TRIGGER` is
ambiguous), both reusing the Phase 4 `log_audit()` emitter (FR-012/FR-041):

- `trg_agency_members_audit_ins_del` — `AFTER INSERT OR DELETE … EXECUTE FUNCTION
  log_audit('agency_member.changed', 'agency_id,user_id,member_role,status',
  'user_id')`.
- `trg_agency_members_audit_upd` — `AFTER UPDATE OF member_role, status … WHEN
  (OLD.member_role IS DISTINCT FROM NEW.member_role OR OLD.status IS DISTINCT FROM
  NEW.status) EXECUTE FUNCTION log_audit('agency_member.changed',
  'agency_id,user_id,member_role,status', 'user_id')`.

`pk_col = 'user_id'` (the affected member); the column list carries `agency_id +
user_id` so the composite identity survives in the before/after snapshot. The actor
is `auth.uid()` (the member-change RPC path).
