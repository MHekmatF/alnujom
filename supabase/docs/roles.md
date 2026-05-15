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
| INSERT    | — (none in Phase 6) | Seed is the only inserter; Phase 7 adds mutation policies |
| UPDATE    | — (none in Phase 6) | `display_name` / `description` editable via Phase 7 super-admin UI |
| DELETE    | — (none in Phase 6) | |
| Anon      | Blocked by Phase 4 RLS-default-block | |

## Triggers

- `trg_roles_set_updated_at` — BEFORE UPDATE, calls `set_updated_at()` (Phase 4 helper).
- `trg_roles_enforce_system_immutability` — BEFORE UPDATE OR DELETE, calls `enforce_role_system_immutability()`. Raises `42501` if:
  - `TG_OP = 'DELETE'` and `OLD.is_system = TRUE`
  - `TG_OP = 'UPDATE'` and `OLD.is_system = TRUE` and `NEW.key IS DISTINCT FROM OLD.key`
  - Updates to `display_name` or `description` on system rows are **allowed**.

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
