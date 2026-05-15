# Contract: `user_roles` Table

**Owner**: Phase 6 (`supabase/migrations/20260515120004_create_user_roles.sql`).
**Consumers**: `current_user_has_permission()` (the starting join), `current_user_is_admin()` (joins to `roles` for membership check), the Flutter profile page (reads the signed-in user's assignments), Phase 7's super-admin UI (the in-app mutation surface — grant/revoke a role on a user).
**Stability**: Schema stable for v1. Mutations are restricted to Phase 6's backfill migration (admin and user role grants) and the auto-`user`-role trigger; Phase 7+ brings in-app mutations.

---

## Purpose

The (user, role) assignment table — the source of truth for "user U holds role R". Every effective-permission computation starts here. Audit-logged on every mutation (FR-010).

## Schema

```sql
CREATE TABLE IF NOT EXISTS public.user_roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id     UUID NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  granted_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role_id)
);
```

- `granted_by`: NULL for system grants (backfill migration, auto-user-role trigger). Populated with `auth.uid()` for in-app grants from Phase 7 onward.
- `UNIQUE (user_id, role_id)`: a user holds each role at most once.

## RLS

- `user_roles_self_read`: `auth.uid() = user_id` — the profile page reads.
- `user_roles_admin_cross_read`: `current_user_has_permission('users.view')` — moderators / admins / super_admins read across users.
- No write policies in Phase 6. The FR-011 backfill migration runs as `postgres` and bypasses RLS for its own INSERTs.
- Anon: blocked.

## Triggers attached

- `trg_user_roles_audit_granted` AFTER INSERT — `log_audit('user_role.granted', '*', 'user_id')`.
- `trg_user_roles_audit_revoked` AFTER DELETE — `log_audit('user_role.revoked', '*', 'user_id')`.
- No UPDATE trigger in v1 — `user_roles` rows are immutable after insert (no Phase 6/7 mutation path UPDATEs an existing row).
- See `user-roles-audit-trigger.md` for the full contract.

## Companion trigger on `profiles` (FR-013)

`trg_profiles_auto_user_role` (AFTER INSERT on `profiles`) auto-inserts a `user`-role assignment for every new profile via `auto_create_user_role_for_user()`. See `auto-user-role-trigger.md`.

## Invariants

- **Every signed-in user holds at least one `user_roles` row**: established by FR-011 backfill (every existing profile) + the FR-013 auto-`user`-role trigger (every future profile). Verified by SC-005.
- **Backfill is idempotent**: re-running the backfill migration produces no duplicate rows (ON CONFLICT (user_id, role_id) DO NOTHING).
- **Every prior `is_admin=true` user holds the `admin` role after Phase 6**: established by FR-011 step 2. Verified by SC-002 / SC-004.
- **Audit trail is complete**: every INSERT (via `trg_user_roles_audit_granted`) and every DELETE (via `trg_user_roles_audit_revoked`) emits one `audit_logs` row. The actor column is `actor_user_id` (NOT `actor`): it carries `auth.uid()` for in-app mutations from Phase 7 onward, and NULL for system grants (the FR-011 backfill, which runs as `postgres` with no JWT). No UPDATE trigger in v1 — `user_roles` rows are immutable post-insert (R-15).

## Verification (Supabase MCP `execute_sql`)

Pre-migration:
```sql
SELECT count(*) FROM public.profiles WHERE is_admin = TRUE;
-- Capture this as N_pre.
```

Post-migration:
```sql
SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'admin';
-- Expected: ≥ N_pre

SELECT count(*) FROM public.profiles p WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = p.user_id AND r.key = 'user'
);
-- Expected: 0
```

Audit trail:
```sql
SELECT action, actor_user_id, target_id FROM public.audit_logs
WHERE action LIKE 'user_role.%' ORDER BY created_at DESC LIMIT 10;
-- Expected: rows with action 'user_role.granted' (from the backfill) — actor_user_id IS NULL because the migration runs as postgres.
-- Phase 7+ mutations from the in-app super-admin UI produce actor_user_id = <super_admin uuid>.
```

## Forward references

- Phase 7's super-admin UI brings in-app INSERT/UPDATE/DELETE policies and SECURITY DEFINER RPCs (e.g., `assign_role_to_user`, `revoke_role_from_user`).
- Phase 22's Realtime spec may add a Realtime subscription on this table for the Flutter `PermissionChecker` (see project memory `project_phase22_perm_cache_revisit.md`).
