# Contract: `permissions` Table

**Owner**: Phase 6 (`supabase/migrations/20260515120002_create_permissions.sql`).
**Consumers**: `current_user_has_permission()` (joins through `role_permissions → permissions`), the Flutter `PermissionChecker` data layer (reads the joined `permissions.key` values), Phase 7's super-admin UI (reads the catalog grouped by category to drive its UI).
**Stability**: The 24 v1 keys from §9.1 are stable identifiers forever. New keys may be added in later phases via migration (never removed in v1).

---

## Purpose

The canonical catalog of fine-grained capabilities. Every RLS policy in the project that gates "this action requires capability X" references a key from this table. The frontend `PermissionChecker` mirrors the catalog as Dart constants (see `permission-keys-dart.md`).

## Schema

```sql
CREATE TABLE IF NOT EXISTS public.permissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL UNIQUE,
  category    TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `key`: the dot-namespaced identifier (e.g., `listings.approve`). Immutable in v1 — renaming would invalidate every policy that references it.
- `category`: the prefix segment of `key`. Used by Phase 7's super-admin UI for grouping; not used at runtime.
- No `updated_at` — rows are immutable in v1.

## RLS

- `permissions_read_all_authenticated`: every authenticated session reads.
- No write policies in Phase 6. No write policies in any v1 spec — new keys ship via additive migrations only.
- Anon: blocked.

## Seed (24 rows, idempotent)

See `data-model.md` → "Seeded permission catalog" for the full INSERT block and category breakdown.

## Invariants

- **Exactly the 24 keys from §9.1 exist after Phase 6**: see `data-model.md` for the list.
- **Categories**: `users`, `listings`, `roles`, `locations`, `currencies`, `ads`, `reports`, `agencies`, `settings`, `audit`, `inquiries`. (11 distinct categories.)
- **No DELETE in v1**: a permission key, once seeded, lives forever in the catalog.
- **No UPDATE in v1**: descriptions ARE technically editable (no Phase 6 trigger blocks them), but no Phase 6 surface mutates them; Phase 7's super-admin UI MAY allow `description` edits (TBD that spec).

## Verification (Supabase MCP `execute_sql`)

```sql
SELECT count(*) FROM public.permissions;
-- Expected: ≥ 24

SELECT category, count(*) AS n FROM public.permissions GROUP BY category ORDER BY category;
-- Expected:
-- ads: 1, agencies: 3, audit: 1, currencies: 1, inquiries: 1, listings: 5,
-- locations: 1, reports: 1, roles: 5, settings: 1, users: 4
-- (Note: roles category has 5 keys because permissions.manage is filed under roles.)

SELECT key FROM public.permissions WHERE category = 'users' ORDER BY key;
-- Expected: users.approve, users.reject, users.suspend, users.view
```

## Forward references

- Future specs that introduce new admin-tier features (Phase 19 agencies, Phase 21 ads) MAY add granular permission keys via their own migrations. Each such migration MUST also INSERT into `role_permissions` for the appropriate roles. The Dart `permission_keys.dart` is updated in the same PR.
