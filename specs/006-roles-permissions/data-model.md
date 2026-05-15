# Phase 6 — Roles & Permissions: Data Model

The full set of database artifacts, Flutter domain entities, and seeded content introduced or modified by Phase 6. Companion to `spec.md`'s functional requirements and `research.md`'s locked decisions.

---

## SQL: New tables

### `roles`

```sql
CREATE TABLE IF NOT EXISTS public.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL UNIQUE,
  display_name JSONB NOT NULL,
  description TEXT,
  is_system   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `key`: stable identifier used by joins and code. Immutable for `is_system=true` rows (enforced by trigger — see "System-role immutability trigger" below).
- `display_name`: JSONB keyed by locale. Required keys: `ar`, `en`. Future locales may be added without a schema change. Example: `{"ar": "مدير", "en": "Admin"}`.
- `is_system`: marks the seven seeded rows. `is_system=true` rows cannot be deleted or have their `key` renamed.
- `set_updated_at()` (Phase 4 helper) is attached as BEFORE UPDATE trigger.

**RLS posture**:
- ENABLE RLS.
- SELECT policy `roles_read_all_authenticated`: `FOR SELECT TO authenticated USING (TRUE)` — every signed-in user can read the role catalog (the profile page reads `display_name`; the PermissionChecker doesn't directly read this table but Phase 7's UI will).
- No INSERT / UPDATE / DELETE policy in Phase 6 — the seed is the only inserter; Phase 7's super-admin UI brings mutation policies.
- Anon: no access (Phase 4's RLS-default-block covers it).

**Seed (7 rows)** — see "Seeded role catalog" below.

---

### `permissions`

```sql
CREATE TABLE IF NOT EXISTS public.permissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key         TEXT NOT NULL UNIQUE,
  category    TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `key`: the dot-namespaced permission identifier referenced by every RLS policy and the Flutter `PermissionChecker` (e.g., `listings.approve`).
- `category`: the prefix segment of `key` (`listings`). Stored separately for the future Phase 7 super-admin UI's grouping; not used at runtime.
- No `updated_at` — permission rows are immutable in v1; renaming a key would invalidate every referencing policy.

**RLS posture**:
- ENABLE RLS.
- SELECT policy `permissions_read_all_authenticated`: `FOR SELECT TO authenticated USING (TRUE)`.
- No INSERT / UPDATE / DELETE policy in Phase 6 — permissions are immutable in v1; future specs that add keys do so via their own migrations (no in-app surface).
- Anon: no access.

**Seed (24 rows)** — see "Seeded permission catalog" below.

---

### `role_permissions`

```sql
CREATE TABLE IF NOT EXISTS public.role_permissions (
  role_id       UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE RESTRICT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);
```

- Composite PK (`role_id`, `permission_id`) — UNIQUE by construction.
- `ON DELETE CASCADE` on `role_id`: if a (non-system) role is deleted in Phase 7+, its mapping rows go with it.
- `ON DELETE RESTRICT` on `permission_id`: prevents accidental orphaning of policy gates by a permission delete. Phase 6 ships no DELETE policy on `permissions` anyway, but the FK is the belt-and-suspenders guard.

**RLS posture**:
- ENABLE RLS.
- SELECT policy `role_permissions_read_all_authenticated`: `FOR SELECT TO authenticated USING (TRUE)` — the frontend `PermissionChecker` joins through this table.
- No INSERT / UPDATE / DELETE policy in Phase 6 — Phase 7's super-admin UI brings them.
- Anon: no access.

**Seed** — see "Seeded role-permission mappings" below.

---

### `user_roles`

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

- `granted_by`: NULL for system grants (the FR-011 backfill, the FR-013 auto-`user`-role trigger). Populated with `auth.uid()` for in-app grants from Phase 7 onward.
- `UNIQUE (user_id, role_id)`: a user holds each role at most once.
- `ON DELETE CASCADE` on `user_id`: deleting the auth user removes their assignments.
- `ON DELETE RESTRICT` on `role_id`: defense-in-depth against deleting a still-assigned role.
- `ON DELETE SET NULL` on `granted_by`: preserves the assignment if the granter's account is deleted.

**RLS posture**:
- ENABLE RLS.
- SELECT policy `user_roles_self_read`: `FOR SELECT TO authenticated USING (auth.uid() = user_id)` — the profile page reads.
- SELECT policy `user_roles_admin_cross_read`: `FOR SELECT TO authenticated USING (current_user_has_permission('users.view'))` — moderators, admins, super_admins can cross-read.
- No INSERT / UPDATE / DELETE policy in Phase 6 — Phase 7 brings them. The FR-011 backfill runs as `postgres` and bypasses RLS for its own INSERTs.
- Anon: no access.

**Triggers attached**:
- `trg_user_roles_audit_granted` AFTER INSERT — `log_audit('user_role.granted', '*', 'user_id')` per FR-010 / R-15.
- `trg_user_roles_audit_revoked` AFTER DELETE — `log_audit('user_role.revoked', '*', 'user_id')` per FR-010 / R-15.
- No UPDATE trigger in v1 — `user_roles` rows are immutable post-insert.

---

## SQL: New helper functions

### `current_user_has_permission(perm_key TEXT) RETURNS BOOLEAN`

```sql
CREATE OR REPLACE FUNCTION public.current_user_has_permission(perm_key TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE((
    EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.role_permissions rp ON rp.role_id = ur.role_id
      JOIN public.permissions p ON p.id = rp.permission_id
      WHERE ur.user_id = auth.uid()
        AND p.key = perm_key
    )
  ), FALSE);
$$;

REVOKE EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) TO authenticated;
```

- Returns `FALSE` (not raise) for callers without `auth.uid()` (via the COALESCE wrapper) and for unknown permission keys.
- The two GRANT/REVOKE statements live in `20260515120008_phase6_advisor_hardening.sql` (R-12 advisor-hardening pattern).

---

### `current_user_is_admin() RETURNS BOOLEAN` (body swap)

Phase 5's `current_user_is_admin()` body is replaced in `20260515120006_swap_admin_predicate_to_role_check.sql`:

```sql
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE((
    EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid()
        AND r.key IN ('admin', 'super_admin')
    )
  ), FALSE);
$$;
```

- The function name, signature, return type, and qualifiers are unchanged from Phase 5.
- The body now resolves to "user holds `admin` OR `super_admin` role" — strictly equivalent to Phase 5's behavior at deploy time (because Phase 6 backfills only `admin`; super_admin is unassigned until post-Phase-6 privileged SQL per R-16).
- No Phase 4 or Phase 5 policy file is edited; every policy that referenced this helper by name picks up the new body automatically.

---

## SQL: New trigger functions and trigger attachments

### System-role immutability trigger (`enforce_role_system_immutability()`)

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

- Fires uniformly for privileged (`postgres`) and unprivileged callers — RLS bypass does not bypass triggers.
- `display_name` / `description` updates are still allowed on `is_system=true` rows (the trigger only rejects key rename + delete).
- Lives in `20260515120001_create_roles.sql`.

---

### Auto-`user`-role trigger (`auto_create_user_role_for_user()`)

```sql
CREATE OR REPLACE FUNCTION public.auto_create_user_role_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (NEW.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now())
  ON CONFLICT (user_id, role_id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auto_create_user_role_for_user() FROM PUBLIC, anon;
-- No explicit GRANT — only the trigger invokes this function.

DROP TRIGGER IF EXISTS trg_profiles_auto_user_role ON public.profiles;
CREATE TRIGGER trg_profiles_auto_user_role
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_user_role_for_user();
```

- Fires after Phase 4's auto-provision trigger creates the `profiles` row.
- `SECURITY DEFINER` because `auth.uid()` (the new user) has no permission to insert into `user_roles` themselves.
- Idempotent via `ON CONFLICT DO NOTHING`.
- Lives in `20260515120004_create_user_roles.sql` (after the table exists).

---

### Audit triggers on `user_roles` (reuses `log_audit()` — two triggers per Phase 5 convention)

Phase 4's `log_audit()` function takes the action string verbatim from `TG_ARGV[0]` — it does NOT append a TG_OP-derived verb (see `supabase/migrations/20260506120004_create_audit_logs.sql` line 24: `v_action TEXT := TG_ARGV[0];`). So Phase 5's pattern is to pass the full action key as the first argument (e.g., `'profile.status_changed'`, `'account_approval.status_changed'`). Phase 6 mirrors this by attaching **two separate triggers** to `user_roles` — one per legal mutation event — each with a distinct action key:

```sql
-- (a) Audit on INSERT: a role assignment is granted to a user.
DROP TRIGGER IF EXISTS trg_user_roles_audit_granted ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_granted
  AFTER INSERT ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.granted', '*', 'user_id');

-- (b) Audit on DELETE: a role assignment is revoked from a user.
DROP TRIGGER IF EXISTS trg_user_roles_audit_revoked ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_revoked
  AFTER DELETE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.revoked', '*', 'user_id');
```

- `log_audit` is Phase 4's reusable trigger function — unchanged in Phase 6 (R-15 invariant preserved).
- Action keys emitted: `user_role.granted` (per INSERT row), `user_role.revoked` (per DELETE row). **No UPDATE trigger** in v1 — `user_roles` rows are immutable after insert (`granted_by` and `granted_at` are set at insert time and not updated). If a future spec introduces UPDATEs (e.g., to refresh `granted_at` on a re-assignment), add `trg_user_roles_audit_changed AFTER UPDATE … EXECUTE FUNCTION log_audit('user_role.changed', '*', 'user_id')` in that spec.
- Audit row column = `audit_logs.action`. Target row column = `audit_logs.target_id` (the `user_id` of the affected user; the `'user_id'` argument tells `log_audit` which column of `NEW`/`OLD` to extract).
- Both triggers live in `20260515120004_create_user_roles.sql`.

---

### Updated `enforce_profile_status_admin_only()` (column-drop side-effect)

The Phase 5 trigger function previously also rejected non-privileged client mutations of `profiles.is_admin`. With the column dropped in `20260515120007_backfill_is_admin_and_drop.sql`, the function body is rewritten in the same migration to remove the `is_admin` reference. The remaining responsibility — blocking non-privileged client mutations of `account_status` and `publisher_status` — is preserved.

```sql
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (
    (NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status)
    AND NOT public.current_user_is_admin()
    AND auth.role() <> 'service_role'
  ) THEN
    RAISE EXCEPTION 'only admins may change account_status or publisher_status'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
```

- The trigger attachment on `profiles` (BEFORE UPDATE) is unchanged.
- `current_user_is_admin()` in the predicate now resolves to the role-membership check after migration 6.

---

## SQL: New policy on existing `profiles` table

### `profiles_phase6_users_view` (stacked SELECT)

Lives in `supabase/policies/profiles_phase6_users_view.sql`:

```sql
DROP POLICY IF EXISTS profiles_phase6_users_view ON public.profiles;
CREATE POLICY profiles_phase6_users_view
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
```

- Stacked on top of the Phase 4 self-only SELECT policy. PostgreSQL ORs the USING clauses of multiple SELECT policies on the same table for the same role → effective grant is "self OR users.view".
- Phase 4's `supabase/policies/profiles_policies.sql` is NOT edited.

---

## Seeded role catalog (7 rows)

| `key`         | `display_name`                                  | `is_system` |
|---------------|-------------------------------------------------|-------------|
| `user`        | `{"ar": "مستخدم", "en": "User"}`                | `true`      |
| `owner`       | `{"ar": "مالك", "en": "Owner"}`                 | `true`      |
| `agent`       | `{"ar": "وكيل", "en": "Agent"}`                 | `true`      |
| `agency_admin`| `{"ar": "مدير وكالة", "en": "Agency Admin"}`    | `true`      |
| `moderator`   | `{"ar": "مشرف", "en": "Moderator"}`             | `true`      |
| `admin`       | `{"ar": "مدير", "en": "Admin"}`                 | `true`      |
| `super_admin` | `{"ar": "مدير عام", "en": "Super Admin"}`       | `true`      |

Seed SQL pattern (one row per system role, idempotent):

```sql
INSERT INTO public.roles (key, display_name, is_system)
VALUES
  ('user',         '{"ar": "مستخدم", "en": "User"}'::jsonb,          TRUE),
  ('owner',        '{"ar": "مالك", "en": "Owner"}'::jsonb,           TRUE),
  ('agent',        '{"ar": "وكيل", "en": "Agent"}'::jsonb,           TRUE),
  ('agency_admin', '{"ar": "مدير وكالة", "en": "Agency Admin"}'::jsonb, TRUE),
  ('moderator',    '{"ar": "مشرف", "en": "Moderator"}'::jsonb,        TRUE),
  ('admin',        '{"ar": "مدير", "en": "Admin"}'::jsonb,            TRUE),
  ('super_admin',  '{"ar": "مدير عام", "en": "Super Admin"}'::jsonb, TRUE)
ON CONFLICT (key) DO NOTHING;
```

Lives in `20260515120001_create_roles.sql`.

---

## Seeded permission catalog (24 rows)

| `key`                | `category`   | Notes |
|----------------------|--------------|-------|
| `users.view`         | `users`      | Cross-user `profiles` read (the moderator-and-up gate) |
| `users.approve`      | `users`      | Approve a pending account-approval request |
| `users.reject`       | `users`      | Reject a pending account-approval request |
| `users.suspend`      | `users`      | Suspend an approved user (Phase 7 surface) |
| `listings.view_all`  | `listings`   | Cross-publisher listings read (moderator-and-up) |
| `listings.approve`   | `listings`   | Approve a submitted listing |
| `listings.reject`    | `listings`   | Reject a submitted listing |
| `listings.edit_any`  | `listings`   | Edit a listing owned by another publisher (admin tier) |
| `listings.delete_any`| `listings`   | Delete a listing owned by another publisher (super-admin tier) |
| `roles.view`         | `roles`      | Read the role catalog (Phase 7 super-admin UI gate) |
| `roles.create`       | `roles`      | Create a custom role (super-admin tier) |
| `roles.update`       | `roles`      | Edit a role's display_name / permissions / user assignments |
| `roles.delete`       | `roles`      | Delete a non-system role (super-admin tier) |
| `permissions.manage` | `roles`      | Mutate the permissions table (post-v1 if ever) |
| `locations.manage`   | `locations`  | Admin Syrian governorates / cities / areas (Phase 8) |
| `currencies.manage`  | `currencies` | Admin exchange rates (Phase 9) |
| `ads.manage`         | `ads`        | Admin ads / banners (Phase 21) |
| `reports.manage`     | `reports`    | Moderate reports (Phase 18) |
| `agencies.view`      | `agencies`   | View agency directory (admin tier) |
| `agencies.approve`   | `agencies`   | Approve agency applications (Phase 19) |
| `agencies.suspend`   | `agencies`   | Suspend an approved agency (Phase 19) |
| `settings.manage`    | `settings`   | Mutate app-wide settings (Phase 23) |
| `audit_logs.view`    | `audit`      | Read the audit_logs table (admin tier) |
| `inquiries.view_all` | `inquiries`  | Cross-publisher inquiry read (Phase 16) |

Seed SQL pattern (one row per key, idempotent):

```sql
INSERT INTO public.permissions (key, category, description) VALUES
  ('users.view',          'users',      'Read other users'' profiles (cross-user).'),
  ('users.approve',       'users',      'Approve a pending account-approval request.'),
  ('users.reject',        'users',      'Reject a pending account-approval request.'),
  ('users.suspend',       'users',      'Suspend an approved user.'),
  ('listings.view_all',   'listings',   'Read all listings across publishers.'),
  ('listings.approve',    'listings',   'Approve a submitted listing.'),
  ('listings.reject',     'listings',   'Reject a submitted listing.'),
  ('listings.edit_any',   'listings',   'Edit any listing regardless of publisher.'),
  ('listings.delete_any', 'listings',   'Delete any listing regardless of publisher.'),
  ('roles.view',          'roles',      'Read the role catalog.'),
  ('roles.create',        'roles',      'Create custom roles.'),
  ('roles.update',        'roles',      'Edit roles and their permissions / assignments.'),
  ('roles.delete',        'roles',      'Delete non-system roles.'),
  ('permissions.manage',  'roles',      'Mutate the permissions table (post-v1 if ever).'),
  ('locations.manage',    'locations',  'Admin Syrian governorates, cities, areas.'),
  ('currencies.manage',   'currencies', 'Admin exchange rates and supported currencies.'),
  ('ads.manage',          'ads',        'Admin ads and banners.'),
  ('reports.manage',      'reports',    'Moderate reports.'),
  ('agencies.view',       'agencies',   'View agency directory.'),
  ('agencies.approve',    'agencies',   'Approve agency applications.'),
  ('agencies.suspend',    'agencies',   'Suspend an approved agency.'),
  ('settings.manage',     'settings',   'Mutate app-wide settings.'),
  ('audit_logs.view',     'audit',      'Read the audit_logs table.'),
  ('inquiries.view_all',  'inquiries',  'Cross-publisher inquiry read.')
ON CONFLICT (key) DO NOTHING;
```

Lives in `20260515120002_create_permissions.sql`.

---

## Seeded role-permission mappings

Per R-04 (admin = 16 rows, the §9.1 literal 15 + `agencies.view` + `inquiries.view_all`):

| Role            | Permissions mapped | Row count |
|-----------------|--------------------|-----------|
| `user`          | (none)             | 0         |
| `owner`         | (none — own-listings gates flow from later phases' `owner_id = auth.uid()` RLS, not from a permission key) | 0 |
| `agent`         | (none — same)      | 0         |
| `agency_admin`  | (none — agency-member management keys are added in Phase 19) | 0 |
| `moderator`     | `users.view`, `listings.view_all`, `listings.approve`, `listings.reject`, `reports.manage` | 5 |
| `admin`         | (moderator's 5) + `users.approve`, `users.reject`, `users.suspend`, `listings.edit_any`, `locations.manage`, `currencies.manage`, `ads.manage`, `agencies.approve`, `agencies.suspend`, `audit_logs.view`, `agencies.view`, `inquiries.view_all` | 16 |
| `super_admin`   | every row in `permissions` | 24 |

Seed SQL pattern (idempotent, three blocks):

```sql
-- Moderator: 5 rows
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'moderator'),
  p.id
FROM public.permissions p
WHERE p.key IN ('users.view', 'listings.view_all', 'listings.approve', 'listings.reject', 'reports.manage')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Admin: 16 rows (moderator + admin-only writes + agencies.view + inquiries.view_all)
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'admin'),
  p.id
FROM public.permissions p
WHERE p.key IN (
  'users.view', 'listings.view_all', 'listings.approve', 'listings.reject', 'reports.manage',
  'users.approve', 'users.reject', 'users.suspend',
  'listings.edit_any',
  'locations.manage', 'currencies.manage', 'ads.manage',
  'agencies.approve', 'agencies.suspend',
  'audit_logs.view',
  'agencies.view', 'inquiries.view_all'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Super_admin: all 24 rows
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM public.roles WHERE key = 'super_admin'),
  p.id
FROM public.permissions p
ON CONFLICT (role_id, permission_id) DO NOTHING;
```

Lives in `20260515120003_create_role_permissions.sql`.

---

## FR-011 backfill data flow

The transactional migration `20260515120007_backfill_is_admin_and_drop.sql` performs five steps in order:

1. **Backfill `admin` role for prior `is_admin=true` users**:
   ```sql
   INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
   SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'admin'), NULL, now()
   FROM public.profiles p
   WHERE p.is_admin = TRUE
   ON CONFLICT (user_id, role_id) DO NOTHING;
   ```

2. **Backfill `user` role for every existing profile**:
   ```sql
   INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
   SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now()
   FROM public.profiles p
   ON CONFLICT (user_id, role_id) DO NOTHING;
   ```

3. **Drop the column**:
   ```sql
   ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin;
   ```

4. **Rewrite the column-mutation trigger function** (removes the dropped column's reference):
   ```sql
   CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only() …
   ```
   (Body shown above in "Updated `enforce_profile_status_admin_only()`".)

5. **(Implicit) Migration tracker entry** — Supabase's tracker captures the migration name.

The migration is auditable: each INSERT also fires the FR-010 audit trigger on `user_roles` (`trg_user_roles_audit_granted`), emitting `user_role.granted` rows with `actor_user_id = NULL` (the backfill is a system action — runs as `postgres` with no `auth.uid()`). Phase 7's super-admin UI can filter these out of the audit-history view via the `actor_user_id IS NULL AND action = 'user_role.granted'` predicate if desired.

---

## Flutter: Domain entities

### `AssignedRole` (new, in `lib/features/profile/domain/entities/assigned_role.dart`)

```dart
class AssignedRole {
  final String roleKey;          // e.g., 'admin'
  final String displayName;      // already resolved to the active locale at data-source boundary
  final bool isSystem;

  const AssignedRole({
    required this.roleKey,
    required this.displayName,
    required this.isSystem,
  });
}
```

- Pure Dart; no Supabase import.
- `displayName` is resolved at the data-source boundary against the active locale (the data source has access to the locale via `flutter_secure_storage` or `LocaleCubit`); the entity surfaces only the resolved string.

### `Profile` (Phase 5 entity — UPDATE: remove `isAdmin`)

```dart
class Profile extends Equatable {
  // ... existing Phase 5 fields ...
  // final bool isAdmin;  // REMOVED in Phase 6
  // ... rest of Phase 5 fields preserved ...
}
```

- `copyWith` and `props` drop the field.
- The data-layer mapper in `supabase_profile_datasource.dart` drops `is_admin` from its SELECT list.

---

## Flutter: `PermissionChecker` state shape (FR-014)

```dart
class PermissionChecker {
  final PermissionCatalogRepository _repo;
  Set<String> _cache = const <String>{};
  bool _loaded = false;

  PermissionChecker(this._repo);

  Future<void> load() async { … }     // populates _cache; sets _loaded = true
  Future<void> refresh() async { … }  // re-fetches; on failure keeps _cache; sets _loaded = true on first success
  bool has(String permKey) => _cache.contains(permKey);
  bool any(Iterable<String> permKeys) => permKeys.any(_cache.contains);
  bool all(Iterable<String> permKeys) => permKeys.every(_cache.contains);
  void clear() { _cache = const <String>{}; _loaded = false; }
}
```

- The cache is replaced atomically on `refresh()` success — the new `Set<String>` is built off the response, then assigned to `_cache` in a single statement.
- On `refresh()` failure (network error, transient Supabase error), the previous `_cache` is retained (per FR-014 + the edge-case "cache fetch failure falls back to last known value").
- `clear()` resets `_loaded` to false so a subsequent `load()` performs a fresh fetch (rather than treating the empty `_cache` as authoritative).

## Flutter: Postgrest response flatten (PermissionCatalogRepositoryImpl)

The `PermissionCatalogRepositoryImpl.loadEffectivePermissions()` method runs one Postgrest call with three-deep nested embedding and flattens the JSON response into a `Set<String>`. The query and flatten are:

```dart
@override
Future<Set<String>> loadEffectivePermissions() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const <String>{};

  final raw = await Supabase.instance.client
      .from('user_roles')
      .select('role:roles(role_permissions(permission:permissions(key)))')
      .eq('user_id', userId);

  // Response shape (List<dynamic>, one row per user_roles row for this user):
  // [
  //   {
  //     'role': {
  //       'role_permissions': [
  //         { 'permission': { 'key': 'users.approve' } },
  //         { 'permission': { 'key': 'listings.approve' } },
  //         ...
  //       ]
  //     }
  //   },
  //   { 'role': { 'role_permissions': [ ... ] } },
  //   ...
  // ]

  final keys = <String>{};
  for (final row in (raw as List)) {
    final rolePermissions = ((row as Map)['role'] as Map?)?['role_permissions'] as List? ?? const [];
    for (final rp in rolePermissions) {
      final key = ((rp as Map)['permission'] as Map?)?['key'] as String?;
      if (key != null) keys.add(key);
    }
  }
  return keys;
}
```

The defensive `as Map?` / `as List?` casts handle the (unlikely) case where Postgrest returns a row with no joined role or no joined permissions — those rows contribute zero keys to the set without raising.

---

## Flutter: `PermissionKeys` constants layout (FR-018)

```dart
/// Mirror of the 24 seeded permissions.key values from §9.1.
/// Hand-maintained — when a future spec adds or removes a permission key
/// via migration, this file MUST be updated in the same PR.
abstract class PermissionKeys {
  PermissionKeys._();

  /// Users category
  static const String usersView    = 'users.view';
  static const String usersApprove = 'users.approve';
  static const String usersReject  = 'users.reject';
  static const String usersSuspend = 'users.suspend';

  /// Listings category
  static const String listingsViewAll   = 'listings.view_all';
  static const String listingsApprove   = 'listings.approve';
  static const String listingsReject    = 'listings.reject';
  static const String listingsEditAny   = 'listings.edit_any';
  static const String listingsDeleteAny = 'listings.delete_any';

  /// Roles category
  static const String rolesView         = 'roles.view';
  static const String rolesCreate       = 'roles.create';
  static const String rolesUpdate       = 'roles.update';
  static const String rolesDelete       = 'roles.delete';
  static const String permissionsManage = 'permissions.manage';

  /// Locations / Currencies / Ads / Reports
  static const String locationsManage  = 'locations.manage';
  static const String currenciesManage = 'currencies.manage';
  static const String adsManage        = 'ads.manage';
  static const String reportsManage    = 'reports.manage';

  /// Agencies category
  static const String agenciesView    = 'agencies.view';
  static const String agenciesApprove = 'agencies.approve';
  static const String agenciesSuspend = 'agencies.suspend';

  /// Settings / Audit / Inquiries
  static const String settingsManage  = 'settings.manage';
  static const String auditLogsView   = 'audit_logs.view';
  static const String inquiriesViewAll = 'inquiries.view_all';

  /// Derived: every admin-category permission key.
  /// Used by the main-navigation admin-tile visibility check
  /// (`PermissionChecker.any(PermissionKeys.adminCategoryKeys)`).
  static const Set<String> adminCategoryKeys = <String>{
    usersView, usersApprove, usersReject, usersSuspend,
    listingsViewAll, listingsApprove, listingsReject, listingsEditAny, listingsDeleteAny,
    rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage,
    locationsManage, currenciesManage, adsManage, reportsManage,
    agenciesView, agenciesApprove, agenciesSuspend,
    settingsManage, auditLogsView, inquiriesViewAll,
  };
}
```

---

## Cross-references

- **Spec**: see `spec.md` for FR-001 through FR-022, user stories, success criteria, edge cases.
- **Research**: see `research.md` R-01 through R-22 for the rationale behind every shape above.
- **Contracts**: see `contracts/` for the externally-facing contract of each table, function, trigger, policy, and Flutter file listed here.
- **Quickstart**: see `quickstart.md` for the manual verification recipe that exercises the seeded catalog, the backfill, the helpers, and the Flutter surface.
