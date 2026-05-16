# Data Model: Super-Admin Role & Permission Management

**Owner**: Phase 7 (`specs/007-super-admin-roles/`).
**Status**: Locked at plan time (2026-05-15). Bindings for `/speckit-tasks` and `/speckit-implement`.

This document captures every DB-side and Flutter-side data structure that Phase 7 introduces or extends. It is the spec-side source of truth that the implementation MUST match exactly.

---

## 1. DB-side additions

### 1.1 No new tables

Phase 7 introduces **zero new tables**. The four Phase 6 catalog tables (`roles`, `permissions`, `role_permissions`, `user_roles`) are sufficient for the in-app mutation surface. The `audit_logs` table from Phase 4 is also unchanged.

### 1.2 No new columns

Phase 7 introduces **zero new columns** on existing tables. The `roles.updated_at` column from Phase 6 (maintained by the `set_updated_at` trigger) is the basis for the optimistic-lock check (R-07) without modification.

### 1.3 No new enums

Phase 7 introduces **zero new enum values**. The Phase 6 `is_system BOOLEAN`, the `roles.key TEXT UNIQUE`, the `permissions.category TEXT`, and the `user_roles` shape are all reused.

### 1.4 No new helper functions

Phase 7 introduces **zero new general-purpose helper functions** beyond the three RPCs (section 2). `current_user_has_permission(perm_key TEXT)` from Phase 6 FR-008 is the gate; `current_user_is_admin()` from Phase 6 FR-012 is unchanged.

### 1.5 No new indexes

Phase 7 introduces **zero new indexes**. The existing PRIMARY KEY indexes on the Phase 6 catalog tables plus the UNIQUE constraints (`roles.key`, `user_roles(user_id, role_id)`) are sufficient at MVP scale. The `AssignRolePage` user search runs against `profiles.phone` (already UNIQUE-indexed from Phase 4) and `profiles.username` (already UNIQUE-indexed from Phase 4) — the prefix/substring patterns at MVP scale do not need a trigram index.

---

## 2. New SECURITY DEFINER RPCs

### 2.1 `public.mutate_role(...)`

**Owner migration**: `20260516120003_create_mutate_role_rpc.sql`.

**Signature**:

```sql
CREATE OR REPLACE FUNCTION public.mutate_role(
  op                  TEXT,
  role_id             UUID,
  role_key            TEXT,
  display_name        JSONB,
  description         TEXT,
  permission_keys     TEXT[],
  expected_updated_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$ ... $$;
```

**Behavior by `op`**:

| `op` | Required args | Permission re-check | Pre-checks | Mutation | Returns |
|---|---|---|---|---|---|
| `'create'` | `role_key`, `display_name` (both `ar`+`en` keys), `permission_keys[]` | `current_user_has_permission('roles.create')` AND `current_user_has_permission('permissions.manage')` if `array_length(permission_keys,1) > 0` | `role_key` not in `roles` (UNIQUE constraint); `display_name->>'ar' IS NOT NULL OR display_name->>'en' IS NOT NULL`; `is_system` is hard-coded FALSE inside the function (NOT taken from any argument) | `INSERT INTO roles (key, display_name, description, is_system) VALUES (role_key, display_name, description, false) RETURNING id INTO new_role_id`; for each `pk` in `permission_keys`: `INSERT INTO role_permissions (role_id, permission_id) SELECT new_role_id, id FROM permissions WHERE key = pk` | JSONB `{role_id, key, display_name, description, permission_keys}` |
| `'update'` | `role_id`, `expected_updated_at`, optional `display_name`, optional `description`, optional `permission_keys[]` | `current_user_has_permission('roles.update')` AND, if `permission_keys IS NOT NULL`, `current_user_has_permission('permissions.manage')` | Optimistic-lock: `expected_updated_at` matches current `roles.updated_at` for `role_id` (else raise `40001`); super_admin permission-set immutability (R-08): if `(SELECT key FROM roles WHERE id = role_id) = 'super_admin'` AND `permission_keys IS NOT NULL` AND `permission_keys` set-differs from current set, raise `42501` with structured code `errorSuperAdminPermissionsImmutable` | `UPDATE roles SET display_name = COALESCE(display_name, roles.display_name), description = COALESCE(description, roles.description) WHERE id = role_id`; the `set_updated_at` trigger advances `updated_at`; if `permission_keys IS NOT NULL`, compute delta (R-16): `INSERT INTO role_permissions` for newly-included keys, `DELETE FROM role_permissions` for newly-excluded keys | JSONB `{role_id, key, display_name, description, permission_keys, updated_at}` |
| `'delete'` | `role_id`, `expected_updated_at` | `current_user_has_permission('roles.delete')` | Optimistic-lock as above; system-role-immutability trigger fires automatically if the row is `is_system=true` (raise `42501`); FK RESTRICT on `user_roles.role_id` fires if any user holds the role (raise `23503`) | `DELETE FROM roles WHERE id = role_id`; cascade fires on `role_permissions.role_id ON DELETE CASCADE` — each cascaded delete emits a `role_permission.revoked` audit row | JSONB `{role_id}` |

**Body skeleton** (for `data-model.md` reference — the actual SQL is in the migration):

```sql
BEGIN
  -- 1. Permission re-check by op
  IF op = 'create' AND NOT public.current_user_has_permission('roles.create') THEN
    RAISE EXCEPTION 'permission denied: roles.create' USING ERRCODE = '42501';
  END IF;
  IF op = 'update' AND NOT public.current_user_has_permission('roles.update') THEN
    RAISE EXCEPTION 'permission denied: roles.update' USING ERRCODE = '42501';
  END IF;
  IF op = 'delete' AND NOT public.current_user_has_permission('roles.delete') THEN
    RAISE EXCEPTION 'permission denied: roles.delete' USING ERRCODE = '42501';
  END IF;
  IF (op IN ('create','update')) AND permission_keys IS NOT NULL AND array_length(permission_keys, 1) IS NOT NULL
     AND NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  -- 2. Optimistic-lock check for update/delete
  IF op IN ('update','delete') THEN
    PERFORM 1 FROM public.roles WHERE id = role_id AND updated_at = expected_updated_at FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'role concurrent edit' USING ERRCODE = '40001';
    END IF;
  END IF;

  -- 3. super_admin permission-set immutability check (R-08)
  IF op = 'update' AND permission_keys IS NOT NULL THEN
    IF (SELECT key FROM public.roles WHERE id = role_id) = 'super_admin' THEN
      IF NOT (
        SELECT array(SELECT unnest(permission_keys) ORDER BY 1) =
               array(SELECT p.key FROM public.role_permissions rp
                     JOIN public.permissions p ON p.id = rp.permission_id
                     WHERE rp.role_id = role_id ORDER BY 1)
      ) THEN
        RAISE EXCEPTION 'super_admin permission set is immutable' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  -- 4. Op-specific execution
  IF op = 'create' THEN
    -- INSERT roles; for each pk INSERT role_permissions
  ELSIF op = 'update' THEN
    -- UPDATE roles; compute and apply role_permissions delta
  ELSIF op = 'delete' THEN
    -- DELETE roles (cascade fires on role_permissions)
  ELSE
    RAISE EXCEPTION 'unknown op: %', op USING ERRCODE = '22023';
  END IF;

  -- 5. Build and return JSONB result
  RETURN jsonb_build_object(...);
END;
```

**Audit-trail behavior**: FR-001 / FR-002 trigger groups fire automatically for each affected row in the transaction. A `create` with N permissions produces 1 `role.created` + N `role_permission.granted` audit rows. An `update` with K added and L removed permissions produces 1 `role.updated` + K `role_permission.granted` + L `role_permission.revoked` audit rows. A `delete` with M permissions produces 1 `role.deleted` + M `role_permission.revoked` audit rows.

**Error code catalog**: See research R-14 for the full SQLSTATE → structured code → ARB key mapping.

### 2.2 `public.assign_role_to_user(...)`

**Owner migration**: `20260516120004_create_user_role_assignment_rpcs.sql`.

**Signature**:

```sql
CREATE OR REPLACE FUNCTION public.assign_role_to_user(
  target_user_id     UUID,
  target_role_id     UUID,
  confirmation_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$ ... $$;
```

**Behavior**:

| Step | Check | On failure |
|---|---|---|
| 1 | `current_user_has_permission('permissions.manage')` returns TRUE | RAISE `42501` `errorAssignPermissionDenied` |
| 2 | If `target_role_id = (SELECT id FROM roles WHERE key='super_admin')`: read `(phone, username)` from `profiles WHERE user_id = target_user_id`; `confirmation_token` matches `phone` OR `username` exactly | RAISE `42501` `errorSuperAdminGrantConfirmationFailed` |
| 3 | `INSERT INTO user_roles (user_id, role_id, granted_by, granted_at) VALUES (target_user_id, target_role_id, auth.uid(), now())` | UNIQUE conflict raises `23505` `errorUserAlreadyHoldsRole` |
| 4 | Return JSONB `{user_id, role_id, granted_by, granted_at}` | n/a |

**Audit-trail behavior**: Phase 6's `trg_user_roles_audit_granted` fires automatically — one `user_role.granted` audit row per call, with `actor_user_id = auth.uid()` (the super_admin) and `target_id = target_user_id`.

### 2.3 `public.revoke_role_from_user(...)`

**Owner migration**: `20260516120004_create_user_role_assignment_rpcs.sql`.

**Signature**:

```sql
CREATE OR REPLACE FUNCTION public.revoke_role_from_user(
  target_user_id UUID,
  target_role_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$ ... $$;
```

**Behavior**:

| Step | Check | On failure |
|---|---|---|
| 1 | `current_user_has_permission('permissions.manage')` returns TRUE | RAISE `42501` `errorRevokePermissionDenied` |
| 2 | NOT (`target_role_id = (SELECT id FROM roles WHERE key='super_admin')` AND `auth.uid() = target_user_id`) — i.e., unconditional self-revoke block on `super_admin` (R-05) | RAISE `42501` `errorSuperAdminSelfRevokeForbidden` |
| 3 | `DELETE FROM user_roles WHERE user_id = target_user_id AND role_id = target_role_id` | If 0 rows affected, RAISE `02000` `errorUserDoesNotHoldRole` (a no-op-but-explicit response; client can treat as success) |
| 4 | Return JSONB `{user_id, role_id, revoked_by, revoked_at: now()}` | n/a |

**Audit-trail behavior**: Phase 6's `trg_user_roles_audit_revoked` fires automatically — one `user_role.revoked` audit row per call.

---

## 3. New audit-trigger groups

### 3.1 Triggers on `public.roles`

**Owner migration**: `20260516120001_create_phase7_audit_triggers.sql`.

```sql
DROP TRIGGER IF EXISTS trg_roles_audit_created ON public.roles;
CREATE TRIGGER trg_roles_audit_created
  AFTER INSERT ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_updated ON public.roles;
CREATE TRIGGER trg_roles_audit_updated
  AFTER UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_deleted ON public.roles;
CREATE TRIGGER trg_roles_audit_deleted
  AFTER DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.deleted', '*', 'id');
```

**Notes**:
- `log_audit()` is Phase 4's reusable function (unchanged). Per Phase 5 / Phase 6 convention, the action key is passed verbatim as `TG_ARGV[0]`; no TG_OP-derived verb is appended.
- The Phase 6 `set_updated_at` trigger fires BEFORE UPDATE; the audit trigger fires AFTER UPDATE; both fire on every UPDATE.
- The Phase 6 `enforce_role_system_immutability` trigger fires BEFORE UPDATE OR DELETE; if it raises, the audit triggers do NOT fire (the transaction rolls back before AFTER triggers).

### 3.2 Triggers on `public.role_permissions`

```sql
DROP TRIGGER IF EXISTS trg_role_permissions_audit_granted ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_granted
  AFTER INSERT ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.granted', '*', 'role_id');

DROP TRIGGER IF EXISTS trg_role_permissions_audit_revoked ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_revoked
  AFTER DELETE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.revoked', '*', 'role_id');
```

**Notes**:
- No UPDATE trigger — `role_permissions` rows are immutable post-insert (Phase 6 R-15 / Phase 7 R-12 invariant).
- `target_id` is the role's id (not the permission's id) per R-12 — the operationally-meaningful target of a permission-grant is "the role gained this permission".
- The cascade from `roles ON DELETE CASCADE → role_permissions` fires N `role_permission.revoked` audit rows when a role is deleted; this is the intended behavior per US4 acceptance scenario 3.

### 3.3 Triggers on `public.permissions`

```sql
DROP TRIGGER IF EXISTS trg_permissions_audit_created ON public.permissions;
CREATE TRIGGER trg_permissions_audit_created
  AFTER INSERT ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_updated ON public.permissions;
CREATE TRIGGER trg_permissions_audit_updated
  AFTER UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_deleted ON public.permissions;
CREATE TRIGGER trg_permissions_audit_deleted
  AFTER DELETE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.deleted', '*', 'id');
```

**Notes**:
- These triggers are **defensive coverage** (Phase 7 R-03 / spec FR-003). The v1 catalog is closed; Phase 7's super-admin UI does NOT mutate `permissions` rows. The triggers exist so that any future migration or post-v1 spec that mutates the catalog is automatically audit-covered.

---

## 4. New write-side RLS policies

### 4.1 `roles_phase7_write.sql`

```sql
DROP POLICY IF EXISTS roles_phase7_insert ON public.roles;
CREATE POLICY roles_phase7_insert ON public.roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('roles.create'));

DROP POLICY IF EXISTS roles_phase7_update ON public.roles;
CREATE POLICY roles_phase7_update ON public.roles
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('roles.update'))
  WITH CHECK (public.current_user_has_permission('roles.update'));

DROP POLICY IF EXISTS roles_phase7_delete ON public.roles;
CREATE POLICY roles_phase7_delete ON public.roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('roles.delete'));
```

**Notes**:
- The Phase 6 authenticated-read policy on `roles` is preserved unchanged.
- The Phase 6 `enforce_role_system_immutability` trigger fires defense-in-depth even if a user holds `roles.delete` — system rows cannot be deleted.

### 4.2 `role_permissions_phase7_write.sql`

```sql
DROP POLICY IF EXISTS role_permissions_phase7_insert ON public.role_permissions;
CREATE POLICY role_permissions_phase7_insert ON public.role_permissions
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS role_permissions_phase7_delete ON public.role_permissions;
CREATE POLICY role_permissions_phase7_delete ON public.role_permissions
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
```

**Notes**:
- No UPDATE policy — rows are immutable post-insert.
- Phase 6 authenticated-read policy preserved.

### 4.3 `user_roles_phase7_write.sql`

```sql
DROP POLICY IF EXISTS user_roles_phase7_insert ON public.user_roles;
CREATE POLICY user_roles_phase7_insert ON public.user_roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS user_roles_phase7_delete ON public.user_roles;
CREATE POLICY user_roles_phase7_delete ON public.user_roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
```

**Notes**:
- No UPDATE policy — rows are immutable post-insert (Phase 6 R-15 invariant).
- Phase 6 self-read + admin-cross-read policies preserved.
- The `assign_role_to_user` and `revoke_role_from_user` RPCs run as `SECURITY DEFINER` and bypass these policies in their function body; the server-side permission re-check inside each RPC is the authoritative gate. The RLS policies cover the direct-SQL-write path (a super_admin with `permissions.manage` writing via Supabase MCP `execute_sql` simulating their JWT). The two-step super_admin confirmation (R-04) and the unconditional self-revoke block (R-05) are enforced inside the RPCs only; the bare RLS policy does NOT carry those checks.

---

## 5. Flutter-side additions

### 5.1 `lib/core/security/permission_keys.dart` delta

Phase 6 defines `PermissionKeys` with 24 named constants + `adminCategoryKeys`. Phase 7 adds one constant:

```dart
static const Set<String> superAdminCategoryKeys = <String>{
  rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage,
};
```

The other 24 keys are unchanged. The file remains hand-maintained (Phase 6 R-19); future spec MAY codegen.

### 5.2 New feature folder `lib/features/super_admin/`

Constitution IV three-layer split. Sub-trees:

#### 5.2.1 `domain/entities/`

```dart
// role_with_counts.dart — the RolesListPage row
class RoleWithCounts {
  final String roleId;          // UUID
  final String roleKey;         // immutable identifier
  final Map<String, String> displayName;  // {'ar': '...', 'en': '...'}
  final String? description;
  final bool isSystem;
  final int permissionCount;
  final int userCount;
  final DateTime updatedAt;
}

// role_detail.dart — the RoleEditorPage payload
class RoleDetail {
  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final List<String> permissionKeys;  // current set
  final DateTime updatedAt;            // captured at open for optimistic-lock
}

// permission_catalog_entry.dart — one row of the checklist
class PermissionCatalogEntry {
  final String key;        // e.g., 'currencies.manage'
  final String category;   // e.g., 'currencies'
  final String? description;
}

// user_search_result.dart — one row of the AssignRolePage search
class UserSearchResult {
  final String userId;
  final String phone;
  final String? username;
  final String? fullName;
  final List<RoleAssignmentSummary> currentRoles;
}

// role_assignment_summary.dart — one row inside UserSearchResult.currentRoles
class RoleAssignmentSummary {
  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final DateTime grantedAt;
}

// role_mutation_result.dart — the mutate_role RPC response
class RoleMutationResult {
  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final List<String> permissionKeys;
  final DateTime updatedAt;
}

// role_assignment_result.dart — the assign/revoke RPC response
class RoleAssignmentResult {
  final String userId;
  final String roleId;
  final String? grantedBy;
  final DateTime at;
}
```

All entities are Supabase-free per Constitution IX. `equatable` is used for value-equality.

#### 5.2.2 `domain/repositories/`

```dart
// role_catalog_repository.dart
abstract class RoleCatalogRepository {
  Future<List<RoleWithCounts>> listRoles();
  Future<RoleDetail> loadRoleDetail(String roleId);
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog();
  Future<RoleMutationResult> createRole({
    required String roleKey,
    required Map<String, String> displayName,
    String? description,
    required List<String> permissionKeys,
  });
  Future<RoleMutationResult> updateRole({
    required String roleId,
    Map<String, String>? displayName,
    String? description,
    List<String>? permissionKeys,
    required DateTime expectedUpdatedAt,
  });
  Future<void> deleteRole({
    required String roleId,
    required DateTime expectedUpdatedAt,
  });
}

// user_search_repository.dart
abstract class UserSearchRepository {
  Future<List<UserSearchResult>> searchUsers(String query);
  Future<List<RoleAssignmentSummary>> loadUserAssignments(String userId);
  Future<RoleAssignmentResult> assign({
    required String targetUserId,
    required String targetRoleId,
    String? confirmationToken,  // required when targetRoleId references super_admin
  });
  Future<RoleAssignmentResult> revoke({
    required String targetUserId,
    required String targetRoleId,
  });
}
```

#### 5.2.3 `domain/usecases/`

One use case per primary action, each a callable class with a single `call()` method. Use cases hold no state; they delegate to the repository. List:

- `list_roles.dart` — `Future<List<RoleWithCounts>> call()` → `RoleCatalogRepository.listRoles()`.
- `load_role_detail.dart` — `Future<RoleDetail> call(String roleId)` → `RoleCatalogRepository.loadRoleDetail()`.
- `mutate_role.dart` — `Future<RoleMutationResult> call(MutateRoleParams params)` where `MutateRoleParams` is a sealed class with `Create`, `Update` variants.
- `delete_role.dart` — `Future<void> call({required String roleId, required DateTime expectedUpdatedAt})`.
- `search_users.dart` — `Future<List<UserSearchResult>> call(String query)`.
- `load_user_assignments.dart` — `Future<List<RoleAssignmentSummary>> call(String userId)`.
- `assign_role_to_user.dart` — `Future<RoleAssignmentResult> call({...})`.
- `revoke_role_from_user.dart` — `Future<RoleAssignmentResult> call({...})`.

#### 5.2.4 `data/`

DTOs mirror the RPC return JSON shape (`role_mutation_response_dto.dart`, `role_assignment_response_dto.dart`) and the SELECT shape (`role_dto.dart`, `permission_dto.dart`, `user_search_result_dto.dart`). Datasources:

- `supabase_role_catalog_datasource.dart` — wraps the Supabase client; one method per RPC; one method per SELECT. Translates `PostgrestException.code` (the SQLSTATE) to typed domain failures (`RoleEditConflict`, `SuperAdminPermissionsImmutable`, `SystemRoleImmutable`, `RoleHasUsers`, `RoleKeyDuplicate`, `RolePermissionDenied`, generic `BackendFailure`).
- `supabase_user_search_datasource.dart` — fulltext search via `supabase.from('profiles').select(...).or('phone.like.<q>%,username.ilike.%<q>%').limit(50).order('username')`; cross-user reads admitted by Phase 6's `users.view` policy.

Repository impls (`role_catalog_repository_impl.dart`, `user_search_repository_impl.dart`) compose the datasources, map DTOs to entities, and return domain failures wrapped in `Result<T>`.

#### 5.2.5 `presentation/bloc/`

**`RolesListBloc`** — events: `LoadRoles`, `RefreshRoles`. States: `Initial`, `Loading`, `Loaded(List<RoleWithCounts>)`, `Failure(Failure)`. Implements pull-to-refresh.

**`RoleEditorBloc`** — events: `OpenRole(roleId)`, `UpdateDisplayName(locale, value)`, `UpdateDescription(value)`, `TogglePermission(permKey)`, `Save`, `Cancel`. States: `Initial`, `Loading`, `Editing(RoleDetail, dirty: bool, ...)`, `Saving`, `SaveSucceeded`, `SaveConflict(reason: 'concurrent_edit' | 'super_admin_immutable' | 'system_role_protected')`. The `Editing` state carries the captured `expectedUpdatedAt`; the Save event constructs `MutateRoleParams.Update` and dispatches to the use case.

**`AssignRoleBloc`** — events: `UpdateQuery(query)` (debounced), `SelectUser(userId)`, `LoadAssignments(userId)`, `GrantRole(targetUserId, targetRoleId)`, `GrantSuperAdminRole(targetUserId, targetRoleId, confirmationToken)`, `RevokeRole(targetUserId, targetRoleId)`. States: `Initial`, `Searching`, `Results(List<UserSearchResult>)`, `UserDrawerOpen(userId, List<RoleAssignmentSummary>)`, `GrantInProgress`, `GrantSucceeded`, `GrantFailed(reason)`, `RevokeInProgress`, `RevokeSucceeded`, `RevokeFailed(reason)`. The two-step super_admin grant is mediated by the bloc — when the UI dispatches `GrantRole(targetUserId, superAdminRoleId)`, the bloc returns a `GrantNeedsSuperAdminConfirmation(targetUser)` state; the UI opens the confirmation dialog, gathers the typed match, and re-dispatches `GrantSuperAdminRole(...)` with the typed `confirmationToken`. Self-row super_admin-revoke affordance is suppressed at the widget level — when the active user is the signed-in super_admin and the `RoleAssignmentSummary` row references the super_admin role, the remove button is not rendered.

#### 5.2.6 `presentation/pages/`

- `roles_list_page.dart` — `Scaffold` + `BlocBuilder<RolesListBloc>`; renders a `ListView` of `RoleCard` widgets; floating action button "Create" gated by `PermissionChecker.has(PermissionKeys.rolesCreate)`; tile tap navigates to `/admin/super-admin/roles/:roleId`.
- `role_editor_page.dart` — opens with a `BlocProvider<RoleEditorBloc>` seeded by `OpenRole(roleId)`; renders `display_name` per-locale `TextField` widgets (ar + en), a `description` `TextField`, and the `PermissionChecklist` widget grouped by category. Save button gated by appropriate permission; disabled when `dirty=false`. The save flow handles the `SaveConflict` states with localized error toasts/banners and a "Reload" affordance for the optimistic-lock case.
- `create_role_page.dart` — variant of editor for `op='create'`; required field is `roleKey`; client-side validation rejects empty `roleKey`, empty `displayName.ar` AND empty `displayName.en` simultaneously, and `roleKey = 'super_admin'` (the row would conflict with the seeded system role).
- `assign_role_page.dart` — `Scaffold` with the search field at the top; debounced `UpdateQuery` events; results in a `ListView`; tapping a result opens a `showModalBottomSheet` (or full-screen drawer) with the user's `currentRoles` list and a "Grant role" button gated by `PermissionChecker.has(PermissionKeys.permissionsManage)`.

#### 5.2.7 `presentation/widgets/`

- `role_card.dart` — Phase 2 `Card` primitive; shows display_name, isSystem badge, permission count, user count.
- `permission_checklist.dart` — `ListView` grouped by category. Each group's header uses `permission_category_header.dart`.
- `permission_category_header.dart` — reads `AppLocalizations.of(context).permissionCategoryUsers` (or the right ARB key for the category) via a switch-on-category-string helper. Fallback: the raw category value if the ARB key is missing.
- `confirmation_dialog.dart` — reusable widget per R-19.
- `super_admin_grant_confirmation_dialog.dart` — the two-step gate; wraps the consequences ack + typed match.
- `assigned_role_row.dart` — one row inside the user drawer; remove button suppressed for self-row super_admin per R-05.
- `user_search_field.dart` — debounced `TextField` wrapper; dispatches `UpdateQuery`.

---

## 6. ARB key delta

### 6.1 `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` — 12 permission-category keys

Per R-09:

| ARB key | `ar` | `en` |
|---|---|---|
| `permissionCategoryUsers` | المستخدمون | Users |
| `permissionCategoryListings` | العقارات | Listings |
| `permissionCategoryRoles` | الأدوار | Roles |
| `permissionCategoryLocations` | المواقع | Locations |
| `permissionCategoryCurrencies` | العملات | Currencies |
| `permissionCategoryAds` | الإعلانات | Ads |
| `permissionCategoryReports` | البلاغات | Reports |
| `permissionCategoryAgencies` | الوكالات | Agencies |
| `permissionCategorySettings` | الإعدادات | Settings |
| `permissionCategoryAudit` | سجل التدقيق | Audit log |
| `permissionCategoryInquiries` | الاستفسارات | Inquiries |
| `permissionCategoryPermissions` | الصلاحيات | Permissions |

### 6.2 Page / button / dialog / validation strings

Approximately 25–30 additional keys covering:

- Admin home tile: `adminTileSuperAdmin` ("الإدارة الفائقة" / "Super-admin").
- Pages: `superAdminRolesListTitle`, `superAdminRoleEditorTitle`, `superAdminCreateRoleTitle`, `superAdminAssignRoleTitle`.
- Form labels: `roleKeyLabel`, `roleDisplayNameLabelAr`, `roleDisplayNameLabelEn`, `roleDescriptionLabel`, `rolePermissionsLabel`.
- Buttons: `actionSave`, `actionCancel`, `actionDelete`, `actionCreate`, `actionGrant`, `actionRevoke`.
- Confirmation dialogs: `confirmDeleteRoleTitle`, `confirmDeleteRoleBody`, `confirmRevokeRoleTitle`, `confirmRevokeRoleBody`, `confirmSuperAdminGrantTitle`, `confirmSuperAdminGrantBody`, `confirmSuperAdminGrantTypedMatchLabel`.
- Search affordances: `userSearchPlaceholder`, `userSearchEmptyResults`.
- Validation: `errorRequired`, `errorRoleKeyDuplicate` (mapped from `23505`), `errorRoleEditConflict` (mapped from `40001`), `errorSuperAdminPermissionsImmutable` (mapped from `42501` super_admin guard), `errorSystemRoleImmutable` (mapped from `42501` system-role trigger), `errorRoleHasUsers` (mapped from `23503`), `errorRolePermissionDenied`, `errorAssignPermissionDenied`, `errorSuperAdminGrantConfirmationFailed`, `errorUserAlreadyHoldsRole`, `errorRevokePermissionDenied`, `errorSuperAdminSelfRevokeForbidden`, `errorUserDoesNotHoldRole`.
- Empty / loading states: `superAdminRolesLoading`, `superAdminRolesEmpty`, `superAdminEditorLoading`, `superAdminSearchLoading`.

All ARB keys ship to both files in the same commit per Phase 3's localization gate. The final exact list is generated during `/speckit-implement`; this section is the spec-level inventory.

---

## 7. Routing

### 7.1 New go_router routes

```dart
GoRoute(
  path: '/admin/super-admin/roles',
  redirect: (context, state) => _requireSuperAdmin(context),
  builder: (context, state) => const RolesListPage(),
  routes: [
    GoRoute(
      path: ':roleId',
      redirect: (context, state) => _requireSuperAdmin(context),
      builder: (context, state) => RoleEditorPage(roleId: state.pathParameters['roleId']!),
    ),
    GoRoute(
      path: 'create',
      redirect: (context, state) => _requireSuperAdmin(context),
      builder: (context, state) => const CreateRolePage(),
    ),
  ],
),
GoRoute(
  path: '/admin/super-admin/assign',
  redirect: (context, state) => _requireSuperAdmin(context),
  builder: (context, state) => const AssignRolePage(),
),
```

The `_requireSuperAdmin` helper reads `getIt<PermissionChecker>().any(PermissionKeys.superAdminCategoryKeys)`; returns `/admin` (the Phase 6 admin home) if false, `null` (proceed) if true.

---

## 8. Data flow summary

### 8.1 Role-edit flow

1. Super_admin opens `RoleEditorPage` for role X.
2. `RoleEditorBloc.OpenRole(X)` dispatches `LoadRoleDetail(X)` use case.
3. Use case calls `RoleCatalogRepository.loadRoleDetail(X)`.
4. Repository → datasource → Supabase `SELECT ... FROM roles + role_permissions WHERE role_id = X`.
5. Datasource returns DTO; repository maps to `RoleDetail` entity; bloc emits `Editing(roleDetail, dirty: false, expectedUpdatedAt: roleDetail.updatedAt)`.
6. Super_admin toggles permissions; `RoleEditorBloc.TogglePermission(k)` updates the in-state permission set; emits `Editing(updated, dirty: true, expectedUpdatedAt: ...)`.
7. Super_admin taps Save; `RoleEditorBloc.Save` dispatches `MutateRole(Update(roleId: X, displayName: ..., description: ..., permissionKeys: [...], expectedUpdatedAt: ...))`.
8. Use case calls `RoleCatalogRepository.updateRole(...)`.
9. Repository → datasource → Supabase `supabase.rpc('mutate_role', params: {...})`.
10. RPC fires; on success, returns JSONB; Phase 7 audit triggers fire automatically (1 `role.updated` + delta `role_permission.*` rows).
11. Datasource maps response DTO to `RoleMutationResult`; bloc emits `SaveSucceeded`; UI pops to `RolesListPage` which refreshes.
12. On `40001` SQLSTATE: bloc emits `SaveConflict('concurrent_edit')`; UI shows toast + "Reload" action that re-dispatches `OpenRole(X)` and discards the local edits.
13. On `42501` super_admin guard: bloc emits `SaveConflict('super_admin_immutable')`; UI shows toast.

### 8.2 User-role grant flow (non-super_admin)

1. Super_admin opens `AssignRolePage`, searches, selects user U.
2. `AssignRoleBloc.LoadAssignments(U)` → `UserSearchRepository.loadUserAssignments(U)`.
3. UI shows the user's current roles + a "Grant role" button.
4. Super_admin picks role R from the role picker (sourced from `RoleCatalogRepository.listRoles()`).
5. Single-step confirmation dialog appears.
6. On confirm: `AssignRoleBloc.GrantRole(U, R)` → `AssignRoleToUser({targetUserId: U, targetRoleId: R, confirmationToken: null})`.
7. RPC fires; on success, returns JSONB; Phase 6's `trg_user_roles_audit_granted` fires.
8. Bloc emits `GrantSucceeded`; UI refreshes the drawer.

### 8.3 User-role grant flow (super_admin)

Steps 1–4 as above, super_admin picks role = `super_admin`.

5. UI opens `SuperAdminGrantConfirmationDialog` instead of the standard dialog.
6. Super_admin acknowledges consequences (button A), types the target user's phone OR username (input field B). Button "Confirm grant" enables only when B matches.
7. On confirm: `AssignRoleBloc.GrantSuperAdminRole(U, R, typedValue)` → `AssignRoleToUser({targetUserId: U, targetRoleId: R, confirmationToken: typedValue})`.
8. RPC fires; server re-checks the confirmation_token matches `profiles.phone` OR `profiles.username` for U; on mismatch, raises `42501 errorSuperAdminGrantConfirmationFailed`.
9. On success: Phase 6 audit trigger fires; bloc emits `GrantSucceeded`; UI refreshes.

### 8.4 User-role revoke flow

1. Super_admin opens user drawer for U; sees role R in the list.
2. If U == auth.uid() AND R == super_admin: the remove button is not rendered (R-05 UI half).
3. Else: super_admin taps the remove button; confirmation dialog appears.
4. On confirm: `AssignRoleBloc.RevokeRole(U, R)` → `RevokeRoleFromUser({targetUserId: U, targetRoleId: R})`.
5. RPC fires; if U == auth.uid() AND R == super_admin (e.g., crafted client bypassing the UI), raises `42501 errorSuperAdminSelfRevokeForbidden` (R-05 server half).
6. On success: Phase 6 audit trigger fires; bloc emits `RevokeSucceeded`; UI refreshes.

### 8.5 Role-create flow

1. Super_admin taps "Create" on `RolesListPage`; `CreateRolePage` opens.
2. Super_admin fills form; client-side validation rejects empty fields and `roleKey = 'super_admin'`.
3. On Save: `mutate_role(op: 'create', role_key: ..., display_name: ..., description: ..., permission_keys: ..., expected_updated_at: null)`.
4. RPC fires; on success: Phase 7 `role.created` audit row + N `role_permission.granted` audit rows.
5. UI pops to `RolesListPage`; the list refreshes to include the new row.

### 8.6 Role-delete flow

1. Super_admin long-presses a non-system row on `RolesListPage`; contextual menu offers "Delete".
2. UI calls a read-only RPC or direct SELECT to count `SELECT count(*) FROM user_roles WHERE role_id = X`; result populates the confirmation dialog.
3. If `userCount > 0`: dialog offers "Revoke and delete" path (US4 acceptance scenario 4); the path first batch-revokes via N `RevokeRoleFromUser` calls (no special RPC; client orchestrates), then calls `mutate_role(op: 'delete', role_id: X, expected_updated_at: ...)`. Each revoke produces one `user_role.revoked` audit row; the delete produces one `role.deleted` row + M cascaded `role_permission.revoked` rows.
4. If `userCount == 0`: dialog offers "Delete" directly; `mutate_role(op: 'delete', role_id: X, expected_updated_at: ...)` fires; same audit rows minus the user_role.revoked ones.
5. On `23503 FK violation` (someone granted the role between the count and the delete): dialog re-prompts with the new count.
6. On `42501` system-role-immutability: should not happen (UI suppresses delete on system rows); if it does (crafted client), the dialog shows the localized error.

---

## 9. Validation summary

Every entity and contract surface in this document has at least one Success Criterion in `spec.md` § Measurable Outcomes. The mapping:

| Section | SC reference |
|---|---|
| 2.1 mutate_role | SC-004, SC-005, SC-006, SC-007, SC-024, SC-025, SC-026 |
| 2.2 assign_role_to_user | SC-008, SC-009, SC-012 |
| 2.3 revoke_role_from_user | SC-010, SC-012 |
| 3.x audit triggers | SC-015, SC-016, SC-017 |
| 4.x write policies | SC-013, SC-014 |
| 5.x Flutter feature folder | SC-001, SC-002, SC-003, SC-011, SC-019, SC-020, SC-022, SC-023 |
| 6.x ARB delta | SC-021, SC-027 |
| 7.x routing | SC-002 |

No entity in this document lacks a corresponding SC; no SC lacks a corresponding data-model entity. The data model is complete for `/speckit-tasks`.
