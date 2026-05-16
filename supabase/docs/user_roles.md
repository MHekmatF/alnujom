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
| INSERT | `user_roles_phase7_insert` | `current_user_has_permission('permissions.manage')` |
| UPDATE | — | Rows are immutable post-insert |
| DELETE | `user_roles_phase7_delete` | `current_user_has_permission('permissions.manage')` |
| Anon | Blocked by Phase 4 RLS-default-block | |

Phase 7 write policies are documented in [`supabase/policies/user_roles_phase7_write.sql`](../policies/user_roles_phase7_write.sql) and are applied inline by `20260516120002_create_phase7_write_policies.sql`. Phase 6 read policies are preserved unchanged.

## Triggers

- `trg_profiles_auto_user_role` — AFTER INSERT ON `profiles`, calls `auto_create_user_role_for_user()`. Assigns the `user` role to every new profile automatically. SECURITY DEFINER (new user has no INSERT permission on `user_roles`). Idempotent via `ON CONFLICT (user_id, role_id) DO NOTHING`.
- `trg_user_roles_audit_granted` — AFTER INSERT, calls `log_audit('user_role.granted', '*', 'user_id')`. Emits an audit row for each role grant.
- `trg_user_roles_audit_revoked` — AFTER DELETE, calls `log_audit('user_role.revoked', '*', 'user_id')`. Emits an audit row for each role revocation.

No UPDATE trigger in v1 — rows are immutable post-insert.

## Audit Notes

- Backfill INSERTs (from `20260515120007`) fire `trg_user_roles_audit_granted` and emit `user_role.granted` rows with `actor_user_id = NULL` (migration runs as `postgres`, no `auth.uid()`).
- Phase 7+ in-app grants will have `actor_user_id = <super_admin uuid>`.

## Phase 7 Assignment Surface

In-app assignment changes use two SECURITY DEFINER RPCs as the canonical mutation surface:

- `public.assign_role_to_user(target_user_id, target_role_id, confirmation_token)` inserts a row after re-checking `permissions.manage`. When granting `super_admin`, the RPC requires `confirmation_token` to exactly match the target user's phone or username, mirroring the two-step UI confirmation.
- `public.revoke_role_from_user(target_user_id, target_role_id)` deletes a row after re-checking `permissions.manage`. It rejects attempts by a user to revoke their own `super_admin` role with `42501`.

The Phase 6 audit triggers on `user_roles` are unchanged and continue to emit `user_role.granted` / `user_role.revoked` for these RPC writes.

## Relationship to `profiles.account_status`

A user's `account_status` (pending/approved/rejected/suspended) is independent of their role assignments. A user can hold the `user` role from day one (via the auto-trigger) and still be `pending` approval. The `admin` role is assigned on top by privileged action.

## Cross-References

- Contract: `contracts/user-roles-table.md`
- Auto-user-role trigger: `contracts/auto-user-role-trigger.md`
- Audit trigger: `contracts/user-roles-audit-trigger.md`
- Audit log: `supabase/docs/audit_logs.md`
