# Contract: System-Role Immutability Trigger

**Owner**: Phase 6 (`supabase/migrations/20260515120001_create_roles.sql`).
**Consumers**: implicit — enforces an invariant for every caller (in-app, super-admin UI in Phase 7+, direct SQL via Supabase MCP `execute_sql`).
**Stability**: The trigger function name (`enforce_role_system_immutability`) and the trigger name (`trg_roles_enforce_system_immutability`) are stable for v1.

---

## Purpose

Prevents the seven seeded `is_system=true` roles from being deleted or renamed. The trigger fires uniformly across all callers — including privileged (`postgres`) and `SECURITY DEFINER` RPCs — because RLS bypass does not bypass triggers.

The `display_name` and `description` columns ARE editable on system rows (so super_admin can localize the labels via Phase 7's UI). Only `key` mutation and DELETE are blocked.

## Function

```sql
CREATE OR REPLACE FUNCTION public.enforce_role_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'DELETE' AND OLD.is_system) THEN
    RAISE EXCEPTION 'cannot delete system role: %', OLD.key
      USING ERRCODE = '42501';
  END IF;

  IF (TG_OP = 'UPDATE' AND OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key) THEN
    RAISE EXCEPTION 'cannot rename system role: % (attempted new key: %)', OLD.key, NEW.key
      USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_roles_enforce_system_immutability ON public.roles;
CREATE TRIGGER trg_roles_enforce_system_immutability
  BEFORE UPDATE OR DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_role_system_immutability();
```

## Semantics

| Operation | `is_system` value | Result |
|---|---|---|
| DELETE on a system row | `OLD.is_system = true` | RAISE 42501 |
| DELETE on a non-system row | `OLD.is_system = false` | Pass (Phase 7's super-admin UI may delete custom roles) |
| UPDATE `key` on a system row | `OLD.is_system = true`, `NEW.key ≠ OLD.key` | RAISE 42501 |
| UPDATE `key` on a non-system row | `OLD.is_system = false`, `NEW.key ≠ OLD.key` | Pass |
| UPDATE `display_name` or `description` on a system row | `OLD.is_system = true`, `NEW.key = OLD.key` | Pass |
| UPDATE other columns | various | Pass |

## Invariants

- **Fires uniformly across callers**: privileged (`postgres`), `SECURITY DEFINER` functions, RLS-gated authenticated sessions, anon (anon is already blocked by RLS, but the trigger would fire even if anon got past RLS).
- **Errors are surfaceable**: the `42501 insufficient_privilege` SQLSTATE is the standard PostgreSQL privilege-violation code; clients (including the Flutter app) can pattern-match against it to display a localized "system role cannot be modified" error.
- **`display_name` and `description` editable**: super_admin needs to localize role labels and refine documentation via Phase 7's UI.

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Renaming a system role MUST fail
UPDATE public.roles SET key = 'admin_new' WHERE key = 'admin';
-- Expected: ERROR 42501

-- 2. Deleting a system role MUST fail
DELETE FROM public.roles WHERE key = 'user';
-- Expected: ERROR 42501

-- 3. Editing display_name on a system role MUST succeed
UPDATE public.roles
SET display_name = display_name || jsonb_build_object('fr', 'Administrateur')
WHERE key = 'admin';
-- Expected: 1 row affected

-- 4. Renaming a non-system role MUST succeed
-- (Only possible after Phase 7 creates a non-system role; in Phase 6 there are no non-system rows.)
```

## Forward references

- Phase 7's super-admin UI consumes the `is_system` flag client-side to hide delete/rename UI for system rows. The trigger is the DB-side guard that catches any malformed client request or direct SQL.
- A future spec MAY relax this for specific roles (e.g., allow deleting `agency_admin` if no `user_roles` rows reference it). The trigger function would gain an additional check.
