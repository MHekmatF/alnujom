# Table: `user_roles`

Added in Phase 6 (`20260515120004_create_user_roles.sql`).

## Purpose

Records which roles each user holds. A user may hold multiple roles (e.g. `user` + `admin`). The `PermissionChecker` singleton fetches this table at sign-in to build the session-scoped permission cache.

## Schema

| Column       | Type        | Default             | Notes |
|--------------|-------------|---------------------|-------|
| `id`         | UUID        | `gen_random_uuid()` | Primary key |
| `user_id`    | UUID        | —                   | FK → `auth.users(id)` **ON DELETE CASCADE**. `NOT NULL`. |
| `role_id`    | UUID        | —                   | FK → `public.roles(id)` **ON DELETE RESTRICT**. `NOT NULL`. |
| `granted_by` | UUID        | NULL                | FK → `auth.users(id)` **ON DELETE SET NULL**. NULL for system grants (backfill, auto-trigger). |
| `granted_at` | TIMESTAMPTZ | `now()`             | When the role was granted. |
| `created_at` | TIMESTAMPTZ | `now()`             | Row insertion timestamp. |

**UNIQUE constraint**: `(user_id, role_id)` — a user holds each role at most once.

**FK rationale**:
- CASCADE on `user_id`: deleting the auth user removes all their role assignments.
- RESTRICT on `role_id`: defense-in-depth — blocks deletion of a role that is still assigned to users.
- SET NULL on `granted_by`: preserves the assignment if the granting user's account is deleted.

## RLS Posture

| Operation | Policy | Gating condition |
|-----------|--------|------------------|
| SELECT (self) | `user_roles_self_read` | `auth.uid() = user_id` |
| SELECT (cross) | `user_roles_admin_cross_read` | `current_user_has_permission('users.view')` — moderators, admins, super_admins |
| INSERT/UPDATE/DELETE | — (none in Phase 6) | Phase 7 adds mutation policies. The FR-011 backfill runs as `postgres` and bypasses RLS. |
| Anon | Blocked by Phase 4 RLS-default-block | |

## Triggers

- `trg_profiles_auto_user_role` — AFTER INSERT ON `profiles`, calls `auto_create_user_role_for_user()`. Assigns the `user` role to every new profile automatically. SECURITY DEFINER (new user has no INSERT permission on `user_roles`). Idempotent via `ON CONFLICT (user_id, role_id) DO NOTHING`.
- `trg_user_roles_audit_granted` — AFTER INSERT, calls `log_audit('user_role.granted', '*', 'user_id')`. Emits an audit row for each role grant.
- `trg_user_roles_audit_revoked` — AFTER DELETE, calls `log_audit('user_role.revoked', '*', 'user_id')`. Emits an audit row for each role revocation.

No UPDATE trigger in v1 — rows are immutable post-insert.

## Audit Notes

- Backfill INSERTs (from `20260515120007`) fire `trg_user_roles_audit_granted` and emit `user_role.granted` rows with `actor_user_id = NULL` (migration runs as `postgres`, no `auth.uid()`).
- Phase 7+ in-app grants will have `actor_user_id = <super_admin uuid>`.

## Relationship to `profiles.account_status`

A user's `account_status` (pending/approved/rejected/suspended) is independent of their role assignments. A user can hold the `user` role from day one (via the auto-trigger) and still be `pending` approval. The `admin` role is assigned on top by privileged action.

## Cross-References

- Contract: `contracts/user-roles-table.md`
- Auto-user-role trigger: `contracts/auto-user-role-trigger.md`
- Audit trigger: `contracts/user-roles-audit-trigger.md`
- Audit log: `supabase/docs/audit_logs.md`
