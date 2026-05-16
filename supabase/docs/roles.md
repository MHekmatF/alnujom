# Table: `roles`

Added in Phase 6 (`20260515120001_create_roles.sql`).

## Purpose

Stores the catalog of roles that can be assigned to users. Roles are named sets of permissions. Phase 6 ships seven system roles (marked `is_system = TRUE`); custom roles can be added via Phase 7's super-admin UI.

## Schema

| Column       | Type        | Default              | Notes |
|--------------|-------------|----------------------|-------|
| `id`         | UUID        | `gen_random_uuid()`  | Primary key |
| `key`        | TEXT        | —                    | Stable identifier used by joins and Dart code. `UNIQUE NOT NULL`. Immutable for `is_system = TRUE` rows (trigger-enforced). |
| `display_name` | JSONB     | —                    | `NOT NULL`. Bilingual: `{"ar": "...", "en": "..."}`. Future locales may be added without a schema change. |
| `description`  | TEXT      | NULL                 | Optional freeform notes. |
| `is_system`  | BOOLEAN     | `FALSE`              | Marks seeded system rows. Blocks DELETE and key rename via trigger. |
| `created_at` | TIMESTAMPTZ | `now()`              | Set at insert. |
| `updated_at` | TIMESTAMPTZ | `now()`              | Maintained by `set_updated_at` BEFORE UPDATE trigger. |

## RLS Posture

| Operation | Policy | Gating condition |
|-----------|--------|------------------|
| SELECT    | `roles_read_all_authenticated` | Every authenticated user |
| INSERT    | `roles_phase7_insert` | `current_user_has_permission('roles.create')` |
| UPDATE    | `roles_phase7_update` | `current_user_has_permission('roles.update')` |
| DELETE    | `roles_phase7_delete` | `current_user_has_permission('roles.delete')` |
| Anon      | Blocked by Phase 4 RLS-default-block | |

Phase 7 write policies are documented in [`supabase/policies/roles_phase7_write.sql`](../policies/roles_phase7_write.sql) and are applied inline by `20260516120002_create_phase7_write_policies.sql`.

## Triggers

- `trg_roles_set_updated_at` — BEFORE UPDATE, calls `set_updated_at()` (Phase 4 helper).
- `trg_roles_enforce_system_immutability` — BEFORE UPDATE OR DELETE, calls `enforce_role_system_immutability()`. Raises `42501` if:
  - `TG_OP = 'DELETE'` and `OLD.is_system = TRUE`
  - `TG_OP = 'UPDATE'` and `OLD.is_system = TRUE` and `NEW.key IS DISTINCT FROM OLD.key`
  - Updates to `display_name` or `description` on system rows are **allowed**.
- `trg_roles_audit_created` — AFTER INSERT, emits `audit_logs.action = 'role.created'`.
- `trg_roles_audit_updated` — AFTER UPDATE, emits `audit_logs.action = 'role.updated'`.
- `trg_roles_audit_deleted` — AFTER DELETE, emits `audit_logs.action = 'role.deleted'`.

## Phase 7 Mutation Surface

In-app role mutations use `public.mutate_role(...)` as the canonical surface. The RPC wraps role row changes and role-permission deltas in one database transaction, re-checks the required permission keys server-side, uses `roles.updated_at` for optimistic locking, and enforces `super_admin` permission-set immutability. Direct table writes remain RLS-gated and trigger-audited as defense-in-depth.

## Seeded System Roles (7 rows)

| `key`         | `display_name.ar`  | `display_name.en` |
|---------------|--------------------|-------------------|
| `user`        | مستخدم             | User              |
| `owner`       | مالك               | Owner             |
| `agent`       | وكيل               | Agent             |
| `agency_admin`| مدير وكالة         | Agency Admin      |
| `moderator`   | مشرف               | Moderator         |
| `admin`       | مدير               | Admin             |
| `super_admin` | مدير عام           | Super Admin       |

## Lifecycle

- **Insert**: via seed block in `20260515120001_create_roles.sql` (idempotent, `ON CONFLICT (key) DO NOTHING`). Custom roles via Phase 7 super-admin UI.
- **Update**: `display_name` and `description` are mutable for all rows. `key` is immutable for `is_system = TRUE` rows.
- **Delete**: blocked for `is_system = TRUE` rows by trigger. Non-system custom roles can be deleted via Phase 7 UI.

## Cross-References

- Contract: `contracts/roles-table.md`
- Immutability trigger: `contracts/system-role-immutability-trigger.md`
- Role-permission mappings: `supabase/docs/role_permissions.md`
- User assignments: `supabase/docs/user_roles.md`
