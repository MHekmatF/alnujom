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
| INSERT/UPDATE/DELETE | — (none in Phase 6) | Phase 7 super-admin UI adds mutation policies |
| Anon      | Blocked by Phase 4 RLS-default-block | |

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
