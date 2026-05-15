# Contract: `roles` Table

**Owner**: Phase 6 (`supabase/migrations/20260515120001_create_roles.sql`).
**Consumers**: `current_user_is_admin()` (joins through `roles`), `current_user_has_permission()` (joins through `user_roles → roles`), the Flutter profile page (reads `display_name` for the user's `user_roles`), Phase 7's super-admin UI (the only mutation surface).
**Stability**: Schema is stable for v1. New columns may be added in later phases without breaking changes. The seven seeded `is_system=true` rows have stable `key` values forever.

---

## Purpose

Carries the role identity — the named bundle of permissions every user assignment points at. The seven seeded system roles are the canonical role set for v1; super_admin can ADD custom non-system roles in Phase 7+ via `roles.create`.

## Schema

```sql
CREATE TABLE IF NOT EXISTS public.roles (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key          TEXT NOT NULL UNIQUE,
  display_name JSONB NOT NULL,
  description  TEXT,
  is_system    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `key`: stable string identifier (e.g., `admin`). Immutable for `is_system=true` rows (system-role-immutability trigger raises 42501 on rename).
- `display_name`: JSONB `{ar: …, en: …}`. Both keys required at insert time.
- `is_system`: marks the seven seeded rows; cannot be deleted; `key` cannot be renamed.

## RLS

- `roles_read_all_authenticated`: every authenticated session reads.
- No write policies in Phase 6.
- Anon: blocked (Phase 4 RLS-default).

## Triggers attached

- `set_updated_at` (Phase 4 helper) — BEFORE UPDATE.
- `enforce_role_system_immutability` (this phase) — BEFORE UPDATE OR DELETE. See `system-role-immutability-trigger.md`.

## Seed (7 rows, idempotent)

See `data-model.md` → "Seeded role catalog" for the full INSERT block.

## Invariants

- **Seven `is_system=true` rows exist after Phase 6**: `user`, `owner`, `agent`, `agency_admin`, `moderator`, `admin`, `super_admin`.
- **System rows cannot be deleted**: enforced by trigger; raises 42501.
- **System rows' `key` cannot be renamed**: enforced by trigger; raises 42501. `display_name` and `description` ARE editable on system rows (Phase 7 surface).
- **Non-system rows MAY be created and managed**: Phase 7's super-admin UI exposes this; Phase 6 does not.

## Verification (Supabase MCP `execute_sql`)

```sql
SELECT count(*) FROM public.roles WHERE is_system = TRUE;
-- Expected: 7

SELECT key FROM public.roles ORDER BY key;
-- Expected: admin, agency_admin, agent, moderator, owner, super_admin, user

SELECT display_name->>'ar' AS ar_label, display_name->>'en' AS en_label
FROM public.roles WHERE key = 'admin';
-- Expected: ar_label='مدير', en_label='Admin'
```

System-row immutability:

```sql
-- Renaming a system row's key MUST fail
UPDATE public.roles SET key = 'admin_new' WHERE key = 'admin';
-- Expected: ERROR 42501 'cannot rename system role: admin'

-- Deleting a system row MUST fail
DELETE FROM public.roles WHERE key = 'user';
-- Expected: ERROR 42501 'cannot delete system role: user'

-- Editing display_name on a system row MUST succeed
UPDATE public.roles SET display_name = display_name || '{"fr":"Administrateur"}' WHERE key = 'admin';
-- Expected: 1 row affected (no error)
```

## Forward references

- Phase 7's super-admin UI MAY add columns (e.g., `archived_at` for soft-deleting non-system roles). The signature stays stable; new columns are additive.
