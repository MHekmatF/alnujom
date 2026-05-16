# Contract: `RoleEditorPage` + `RoleEditorBloc`

**Owner**: Phase 7 (`lib/features/super_admin/presentation/pages/role_editor_page.dart`, `lib/features/super_admin/presentation/bloc/role_editor_bloc.dart`).
**Consumers**: super_admin sessions opening a specific role for edit.
**Stability**: Event/state surface is stable for v1.

---

## Purpose

The in-app surface for editing a role's `display_name`, `description`, and permission set. Captures the Phase 6 `roles.updated_at` token at page-open time and dispatches the atomic `mutate_role` RPC on save with the captured `expected_updated_at` for optimistic locking (R-07). Renders the permission checklist as read-only when the active role is `super_admin` (R-08).

## Page structure

```dart
class RoleEditorPage extends StatelessWidget {
  final String roleId;

  // BlocProvider<RoleEditorBloc> seeded by OpenRole(roleId)
  // Scaffold with:
  //   - AppBar(title: role.displayName[currentLocale])
  //   - Body:
  //       1. TextField for display_name.ar
  //       2. TextField for display_name.en
  //       3. TextField (multiline) for description
  //       4. PermissionChecklist widget (read-only if roleKey == 'super_admin')
  //   - FloatingActionButton: Save, disabled when state.dirty == false OR state.saving == true
}
```

## RoleEditorBloc

### Events

```dart
sealed class RoleEditorEvent {}
class OpenRole extends RoleEditorEvent { final String roleId; }
class UpdateDisplayName extends RoleEditorEvent { final String locale; final String value; }
class UpdateDescription extends RoleEditorEvent { final String value; }
class TogglePermission extends RoleEditorEvent { final String permKey; }
class Save extends RoleEditorEvent {}
class ReloadAfterConflict extends RoleEditorEvent {}
class Cancel extends RoleEditorEvent {}
```

### States

```dart
sealed class RoleEditorState {}
class Initial extends RoleEditorState {}
class Loading extends RoleEditorState {}

class Editing extends RoleEditorState {
  final RoleDetail original;             // immutable snapshot at open
  final RoleDetail current;              // mutable working copy
  final DateTime expectedUpdatedAt;      // captured at open; passed to mutate_role
  final bool dirty;                       // current != original ?
  final bool isSuperAdminRow;             // current.roleKey == 'super_admin'
  final bool saving;
}

class SaveSucceeded extends RoleEditorState {}
class SaveConflict extends RoleEditorState {
  final ConflictReason reason;  // concurrent_edit | super_admin_immutable | system_role_protected
  final String localizedMessage;
}
class LoadFailure extends RoleEditorState {
  final Failure failure;
}
```

### Behavior

1. **OnOpenRole**:
   - Emit `Loading`.
   - `await loadRoleDetailUseCase(roleId)`.
   - On success: emit `Editing(original, original, original.updatedAt, dirty: false, isSuperAdminRow: original.roleKey == 'super_admin', saving: false)`.
   - On failure: emit `LoadFailure(failure)`.

2. **OnUpdateDisplayName / OnUpdateDescription / OnTogglePermission**:
   - Compute `nextCurrent` from the previous `current` state.
   - If `isSuperAdminRow` AND the event is `TogglePermission`: ignore (the UI doesn't dispatch this in the first place, but the bloc rejects defensively).
   - Compute `dirty = nextCurrent != original`.
   - Emit `Editing(original, nextCurrent, expectedUpdatedAt, dirty, isSuperAdminRow, saving: false)`.

3. **OnSave**:
   - If `!dirty`: no-op.
   - Emit `Editing(..., saving: true)`.
   - Construct `MutateRoleParams.Update(roleId: original.roleId, displayName: current.displayName, description: current.description, permissionKeys: current.permissionKeys, expectedUpdatedAt: expectedUpdatedAt)`.
   - `await mutateRoleUseCase(params)`.
   - On success: emit `SaveSucceeded`; the page's listener pops to `RolesListPage` which refreshes.
   - On `RoleEditConflict` failure (SQLSTATE 40001): emit `SaveConflict(reason: concurrent_edit, localizedMessage: AppLocalizations.errorRoleEditConflict)`.
   - On `SuperAdminPermissionsImmutable` failure (SQLSTATE 42501 with structured code): emit `SaveConflict(reason: super_admin_immutable, ...)`.
   - On `SystemRoleImmutable` failure (Phase 6 trigger): emit `SaveConflict(reason: system_role_protected, ...)`.
   - On generic backend failure: emit `Editing(..., saving: false)` and surface the failure via a snackbar.

4. **OnReloadAfterConflict**:
   - Emit `Loading`.
   - Re-dispatch `OpenRole(currentRoleId)`.

5. **OnCancel**:
   - Discards working state; navigates back.

## Optimistic-lock token capture (R-07)

The `expectedUpdatedAt` field on `Editing` state is captured at page open time and held in state for the entire editing session. It is NOT refreshed on each event — that's the whole point of optimistic locking (the value represents "what I saw when I started editing"). The token is passed to `mutate_role` only when the user taps Save; on `40001` conflict, the user is offered a "Reload" affordance that re-captures the token.

## Super_admin checklist read-only (R-08)

The `PermissionChecklist` widget receives an `isReadOnly: bool` prop. The page passes `isReadOnly: state.isSuperAdminRow`. When `isReadOnly`, each `Checkbox` is rendered with `onChanged: null` (disabled gesture); the visual styling uses Phase 2's disabled-color token. The widget also surfaces a localized banner above the checklist when read-only: "The super_admin role's permission set cannot be changed." (`AppLocalizations.superAdminPermissionsLocked`).

The `display_name` and `description` `TextField`s remain editable when `isSuperAdminRow` — only the checklist is locked.

The `Save` button is enabled iff `dirty == true` regardless of `isSuperAdminRow`; saving an edit to display_name only is allowed (and the RPC accepts it because `permission_keys` is unchanged from the current set).

## Page-level permission gating

| Affordance | Gate |
|---|---|
| Page itself reachable | Route guard `_requireSuperAdmin` (super-admin-routing.md) |
| Save button enabled | `state.dirty && !state.saving && permissionChecker.has(PermissionKeys.rolesUpdate)` AND (if checklist changed: `permissionChecker.has(PermissionKeys.permissionsManage)`) |
| Per-permission toggle in the checklist | `permissionChecker.has(PermissionKeys.permissionsManage)` — if the user lacks it, the checklist is read-only regardless of `isSuperAdminRow` |

## Error-to-localized-message mapping

The bloc translates backend `Failure` types to localized message keys via this map:

| Failure | ARB key |
|---|---|
| `RoleEditConflict` (SQLSTATE 40001) | `errorRoleEditConflict` |
| `SuperAdminPermissionsImmutable` (42501 structured) | `errorSuperAdminPermissionsImmutable` |
| `SystemRoleImmutable` (42501 from Phase 6 trigger) | `errorSystemRoleImmutable` |
| `RoleHasUsers` (23503 — only triggers on delete; editor doesn't hit this directly) | `errorRoleHasUsers` |
| `RoleKeyDuplicate` (23505 — only triggers on create) | `errorRoleKeyDuplicate` |
| `RolePermissionDenied` (42501 — caller lacks the relevant permission) | `errorRolePermissionDenied` |
| `BackendFailure` (network, timeout, generic) | `errorGenericBackend` |

## Verification (Manual UI walk on Infinix Note 8)

1. Open `RoleEditorPage` for the `admin` role → confirm 17 checked permissions; toggle one off; toggle one on; tap Save → confirm save succeeds and the list reflects the change.
2. Open `RoleEditorPage` for the `super_admin` row → confirm checklist read-only (every checkbox disabled); confirm a banner reads "The super_admin role's permission set cannot be changed." in the active locale; edit `display_name.en` to "Super Administrator"; tap Save → save succeeds.
3. Force a 40001: open the same role in two simulated sessions (use Supabase MCP `execute_sql` to advance `updated_at` between the two opens); save in session 1 → succeeds; save in session 2 without reloading → confirm the localized "this role was changed by another super_admin — reload and re-apply your edits" message; tap "Reload" → editor refreshes with current state.
4. Force a 42501 via the RPC directly (Supabase MCP `execute_sql` running as super_admin): call `mutate_role(op:='update', role_id:=<super_admin_id>, permission_keys:=ARRAY['currencies.manage'], expected_updated_at:=<current>)` → confirm 42501 with `errorSuperAdminPermissionsImmutable` structured message.

## Forward references

- Phase 22 (Push + Realtime) MAY add a Realtime subscription on the role row so the editor receives "role was changed by another super_admin" pushes without the foreground-resume detour. If so, this contract gains an optional Realtime-subscription state.
- A future spec MAY add draft persistence (auto-save to local storage so the losing-conflict super_admin doesn't lose all their work). v1 discards pending edits on conflict per R-07.
