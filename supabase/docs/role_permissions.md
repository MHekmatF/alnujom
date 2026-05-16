# Table: `role_permissions`

Added in Phase 6 (`20260515120003_create_role_permissions.sql`).

## Purpose

Junction table mapping roles to their permitted actions. The Flutter `PermissionChecker` joins through this table (`user_roles → role_permissions → permissions`) to build each user's effective permission set in one Postgrest round-trip.

## Schema

| Column          | Type        | Default | Notes |
|-----------------|-------------|---------|-------|
| `role_id`       | UUID        | —       | FK → `public.roles(id)` **ON DELETE CASCADE**. Part of composite PK. |
| `permission_id` | UUID        | —       | FK → `public.permissions(id)` **ON DELETE RESTRICT**. Part of composite PK. |
| `created_at`    | TIMESTAMPTZ | `now()` | Set at insert. |

**Primary Key**: `(role_id, permission_id)` — a role holds each permission at most once.

**FK rationale**:
- CASCADE on `role_id`: if a custom role is deleted in Phase 7+, its mapping rows are cleaned up automatically.
- RESTRICT on `permission_id`: prevents accidental orphaning of RLS policy gates by a permission delete. Phase 6 ships no DELETE policy on `permissions` anyway.

## RLS Posture

| Operation | Policy | Gating condition |
|-----------|--------|------------------|
| SELECT    | `role_permissions_read_all_authenticated` | Every authenticated user (needed by PermissionChecker join) |
| INSERT   | `role_permissions_phase7_insert` | `current_user_has_permission('permissions.manage')` |
| UPDATE   | — | Rows are immutable post-insert |
| DELETE   | `role_permissions_phase7_delete` | `current_user_has_permission('permissions.manage')` |
| Anon      | Blocked by Phase 4 RLS-default-block | |

Phase 7 write policies are documented in [`supabase/policies/role_permissions_phase7_write.sql`](../policies/role_permissions_phase7_write.sql) and are applied inline by `20260516120002_create_phase7_write_policies.sql`.

## Phase 7 Mutation Surface

Role-permission changes are computed server-side by `public.mutate_role(...)`. Clients pass the full target permission-key set; the RPC compares it with the current mapping, inserts newly-added permissions, and deletes removed permissions. This avoids client-side TOCTOU delta bugs and keeps audit rows at row-level granularity.

## Phase 7 Audit Coverage

- `trg_role_permissions_audit_granted` — AFTER INSERT, emits `audit_logs.action = 'role_permission.granted'` with `target_id = role_id`.
- `trg_role_permissions_audit_revoked` — AFTER DELETE, emits `audit_logs.action = 'role_permission.revoked'` with `target_id = role_id`.

Deleting a custom role cascades to this table and emits one `role_permission.revoked` row for each removed mapping.

## Seeded Default Mappings

| Role            | Permission count | Keys |
|-----------------|-----------------|------|
| `user`          | 0 | — (own-data access flows from `owner_id = auth.uid()` RLS, not permission keys) |
| `owner`         | 0 | — |
| `agent`         | 0 | — |
| `agency_admin`  | 0 | — (agency-member keys added in Phase 19) |
| `moderator`     | 5 | `users.view`, `listings.view_all`, `listings.approve`, `listings.reject`, `reports.manage` |
| `admin`         | 17 | moderator's 5 + `users.approve`, `users.reject`, `users.suspend`, `listings.edit_any`, `locations.manage`, `currencies.manage`, `ads.manage`, `agencies.approve`, `agencies.suspend`, `audit_logs.view`, `agencies.view`, `inquiries.view_all` |
| `super_admin`   | 24 | All keys |

Seed total = **46 rows** (0+0+0+0+5+17+24). Admin = 5 moderator keys + 10 admin-only §9.1 keys (incl. `audit_logs.view`) + 2 R-04 additions (`agencies.view`, `inquiries.view_all`).

## Cross-References

- Contract: `contracts/role-permissions-table.md`
- Roles: `supabase/docs/roles.md`
- Permissions: `supabase/docs/permissions.md`
