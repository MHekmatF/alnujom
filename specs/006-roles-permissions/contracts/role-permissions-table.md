# Contract: `role_permissions` Table

**Owner**: Phase 6 (`supabase/migrations/20260515120003_create_role_permissions.sql`).
**Consumers**: `current_user_has_permission()` (the central join), the Flutter `PermissionChecker` data layer (joins through this table to compute the effective permission set), Phase 7's super-admin UI (the only mutation surface — grant/revoke a permission on a role).
**Stability**: Schema stable for v1. Mappings are mutable in Phase 7+ for non-system roles; system roles' permission mappings ARE editable (per Phase 6 spec assumption — "system roles immutability is partial"; only the role identity, not its permissions, is immutable).

---

## Purpose

The many-to-many join expressing "role R grants capability P". Phase 6 seeds the §9.1 defaults; Phase 7's super-admin UI mutates them through SECURITY DEFINER RPCs.

## Schema

```sql
CREATE TABLE IF NOT EXISTS public.role_permissions (
  role_id       UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE RESTRICT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);
```

- Composite PK — UNIQUE by construction.
- `ON DELETE CASCADE` on `role_id`: deleting a (non-system) role cascades to its mappings.
- `ON DELETE RESTRICT` on `permission_id`: prevents accidental orphaning of policy gates. (Phase 6 ships no DELETE policy on `permissions` anyway, but the FK is the belt-and-suspenders guard.)

## RLS

- `role_permissions_read_all_authenticated`: every authenticated session reads (the frontend `PermissionChecker` joins through this table).
- No write policies in Phase 6.
- Anon: blocked.

## Seed (per role)

| Role            | Mapped permissions | Row count |
|-----------------|--------------------|-----------|
| `user`          | (none)             | 0 |
| `owner`         | (none)             | 0 |
| `agent`         | (none)             | 0 |
| `agency_admin`  | (none — Phase 19 adds agency-member keys) | 0 |
| `moderator`     | `users.view`, `listings.view_all`, `listings.approve`, `listings.reject`, `reports.manage` | 5 |
| `admin`         | (the 5 moderator keys) + `users.approve`, `users.reject`, `users.suspend`, `listings.edit_any`, `locations.manage`, `currencies.manage`, `ads.manage`, `agencies.approve`, `agencies.suspend`, `audit_logs.view`, `agencies.view`, `inquiries.view_all` | 16 |
| `super_admin`   | every row in `permissions` | 24 |

**Phase 6 R-04 documents the admin = 16 (not 15) decision and the addition of `agencies.view` + `inquiries.view_all` beyond §9.1's literal list.**

See `data-model.md` → "Seeded role-permission mappings" for the full INSERT blocks.

## Invariants

- **Seed total = 45 rows**: 0+0+0+0+5+16+24.
- **No orphan**: every `role_id` ⇒ exists in `roles`; every `permission_id` ⇒ exists in `permissions` (FK-enforced).
- **No duplicate**: composite PK prevents.

## Verification (Supabase MCP `execute_sql`)

```sql
SELECT r.key AS role, count(*) AS perm_count
FROM public.role_permissions rp JOIN public.roles r ON r.id = rp.role_id
GROUP BY r.key ORDER BY r.key;
-- Expected:
-- admin: 16, moderator: 5, super_admin: 24
-- (user, owner, agent, agency_admin do not appear because they have 0 rows.)

SELECT p.key FROM public.role_permissions rp
JOIN public.roles r ON r.id = rp.role_id
JOIN public.permissions p ON p.id = rp.permission_id
WHERE r.key = 'moderator' ORDER BY p.key;
-- Expected: listings.approve, listings.reject, listings.view_all, reports.manage, users.view
```

## Forward references

- Phase 7's super-admin UI brings `roles.update` mutation paths that INSERT and DELETE rows from this table. Audit triggers on this table land in Phase 7 alongside the mutation UI (per spec assumption: audit triggers on `roles`, `permissions`, `role_permissions` are out of scope for Phase 6).
- Future specs (Phase 19, Phase 21) MAY INSERT rows here when they seed new permission keys for existing roles.
