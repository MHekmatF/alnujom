# Table: `permissions`

Added in Phase 6 (`20260515120002_create_permissions.sql`).

## Purpose

Stores the catalog of fine-grained permission keys referenced by RLS policies and the Flutter `PermissionChecker`. Permission rows are **immutable in v1** — keys can only be added via future migrations, never renamed or deleted (renaming would invalidate every referencing policy).

## Schema

| Column       | Type        | Default             | Notes |
|--------------|-------------|---------------------|-------|
| `id`         | UUID        | `gen_random_uuid()` | Primary key |
| `key`        | TEXT        | —                   | Dot-namespaced identifier, e.g. `listings.approve`. `UNIQUE NOT NULL`. |
| `category`   | TEXT        | —                   | Prefix segment of `key` (e.g. `listings`). For Phase 7 super-admin UI grouping. `NOT NULL`. |
| `description`| TEXT        | NULL                | Optional freeform notes. |
| `created_at` | TIMESTAMPTZ | `now()`             | Set at insert. |

No `updated_at` — rows are immutable.

## RLS Posture

| Operation | Policy | Gating condition |
|-----------|--------|------------------|
| SELECT    | `permissions_read_all_authenticated` | Every authenticated user |
| INSERT/UPDATE/DELETE | — (none in Phase 6) | Immutable in v1; future specs add keys via new migrations |
| Anon      | Blocked by Phase 4 RLS-default-block | |

Phase 7 keeps `permissions` immutable in the in-app v1 surface. No client INSERT/UPDATE/DELETE policies are added, and the super-admin UI does not mutate permission catalog rows.

## Phase 7 Defensive Audit Coverage

Phase 7 adds defensive audit triggers for future catalog-maintenance migrations or privileged maintenance scripts:

- `trg_permissions_audit_created` — AFTER INSERT, emits `audit_logs.action = 'permission.created'`.
- `trg_permissions_audit_updated` — AFTER UPDATE, emits `audit_logs.action = 'permission.updated'`.
- `trg_permissions_audit_deleted` — AFTER DELETE, emits `audit_logs.action = 'permission.deleted'`.

These triggers do not change the v1 immutability rule; they ensure any future mutation is captured automatically.

## Seeded Catalog (24 rows)

| `key`                | `category`   |
|----------------------|--------------|
| `users.view`         | `users`      |
| `users.approve`      | `users`      |
| `users.reject`       | `users`      |
| `users.suspend`      | `users`      |
| `listings.view_all`  | `listings`   |
| `listings.approve`   | `listings`   |
| `listings.reject`    | `listings`   |
| `listings.edit_any`  | `listings`   |
| `listings.delete_any`| `listings`   |
| `roles.view`         | `roles`      |
| `roles.create`       | `roles`      |
| `roles.update`       | `roles`      |
| `roles.delete`       | `roles`      |
| `permissions.manage` | `roles`      |
| `locations.manage`   | `locations`  |
| `currencies.manage`  | `currencies` |
| `ads.manage`         | `ads`        |
| `reports.manage`     | `reports`    |
| `agencies.view`      | `agencies`   |
| `agencies.approve`   | `agencies`   |
| `agencies.suspend`   | `agencies`   |
| `settings.manage`    | `settings`   |
| `audit_logs.view`    | `audit`      |
| `inquiries.view_all` | `inquiries`  |

**Category counts**: users:4, listings:5, roles:5, locations:1, currencies:1, ads:1, reports:1, agencies:3, settings:1, audit:1, inquiries:1.

## Cross-References

- Contract: `contracts/permissions-table.md`
- Role mappings: `supabase/docs/role_permissions.md`
- Dart mirror: `lib/core/security/permission_keys.dart`
