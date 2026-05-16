# Contract: `AssignRolePage` + `AssignRoleBloc`

**Owner**: Phase 7 (`lib/features/super_admin/presentation/pages/assign_role_page.dart`, `lib/features/super_admin/presentation/bloc/assign_role_bloc.dart`).
**Consumers**: super_admin sessions managing user role assignments.
**Stability**: Event/state surface is stable for v1.

---

## Purpose

The in-app surface for searching users by phone or username and managing their role assignments. Enforces the two-step `super_admin` grant confirmation client-side (UI half of R-04); suppresses the self-row super_admin-revoke affordance client-side (UI half of R-05). The server-side enforcement is in `assign_role_to_user` / `revoke_role_from_user` RPCs.

## Page structure

```dart
class AssignRolePage extends StatelessWidget {
  // BlocProvider<AssignRoleBloc>
  // Scaffold with:
  //   - AppBar(title: AppLocalizations.superAdminAssignRoleTitle)
  //   - Body:
  //       1. UserSearchField (debounced TextField, dispatches UpdateQuery)
  //       2. ListView of UserSearchResult cards (tap → SelectUser event)
  //       3. ModalBottomSheet (or full-screen drawer): user drawer
  //           - User info (full_name, phone, username)
  //           - ListView of currentRoles, each with a remove (revoke) affordance
  //             - Self-row super_admin: remove affordance NOT rendered
  //           - "Grant role" button (gated by PermissionChecker.has(PermissionKeys.permissionsManage))
}
```

## User search (R-13)

The search field debounces 300ms after the last keystroke and dispatches `UpdateQuery(query)`. The bloc calls `searchUsersUseCase(query)`; the datasource runs `SELECT user_id, phone, username, full_name FROM profiles WHERE phone LIKE query || '%' OR username ILIKE '%' || query || '%' ORDER BY username LIMIT 50`. Results are admitted by the Phase 6 cross-user `users.view`-gated policy because super_admin holds it.

## User drawer

When a user is selected, the bloc loads `currentRoles` via `loadUserAssignmentsUseCase(userId)` which queries `SELECT r.id, r.key, r.display_name, ur.granted_at FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? ORDER BY r.key`. The drawer renders one `AssignedRoleRow` per role; each row has a remove button EXCEPT in the case described in the next section.

## Self-row super_admin-revoke affordance (R-05 UI half)

```dart
bool _shouldShowRemoveAffordance(BuildContext context, RoleAssignmentSummary row, String selectedUserId) {
  final isSelfRow = getIt<AuthBloc>().state.userId == selectedUserId;
  final isSuperAdminRole = row.roleKey == 'super_admin';
  return !(isSelfRow && isSuperAdminRole);  // hide for self super_admin
}
```

The remove button is not rendered when the active session's `auth.uid()` equals the selected `userId` AND the row's `roleKey` is `super_admin`. The server-side check in `revoke_role_from_user` is the defense-in-depth — a crafted client bypassing the UI would still hit the 42501.

## Two-step super_admin grant (R-04 UI half)

When the super_admin taps "Grant role" and selects the `super_admin` row from the role picker:

1. The bloc transitions to `GrantNeedsSuperAdminConfirmation(targetUser)` state.
2. The UI opens `SuperAdminGrantConfirmationDialog` widget which:
   - Shows the consequences ("this user will gain every permission in the catalog, including the ability to manage roles and permissions").
   - Requires the super_admin to type the target user's phone OR username into a confirmation field.
   - Enables the "Confirm grant" button only when the typed value exactly matches `targetUser.phone` OR `targetUser.username`.
3. On confirm, the bloc dispatches `GrantSuperAdminRole(targetUserId, superAdminRoleId, typedValue)`; the bloc passes the `typedValue` as the `confirmation_token` argument to `assign_role_to_user`.
4. The server re-validates (R-04 server half); on mismatch (e.g., a crafted client), raises 42501 `errorSuperAdminGrantConfirmationFailed`.
5. On success, the bloc emits `GrantSucceeded`; the drawer refreshes.

For all other role grants (non-super_admin), the bloc takes the simpler path:

1. Dispatch `GrantRole(targetUserId, roleId)`.
2. The bloc shows a standard single-step confirmation dialog (the `ConfirmationDialog` widget per R-19).
3. On confirm, calls `assign_role_to_user(targetUserId, roleId, NULL)` — server ignores the `confirmation_token` because `target_role_id` is not `super_admin`.

## AssignRoleBloc

### Events

```dart
sealed class AssignRoleEvent {}
class UpdateQuery extends AssignRoleEvent { final String query; }
class SelectUser extends AssignRoleEvent { final String userId; }
class LoadAssignments extends AssignRoleEvent { final String userId; }
class GrantRole extends AssignRoleEvent { final String targetUserId; final String targetRoleId; }
class GrantSuperAdminRole extends AssignRoleEvent { final String targetUserId; final String targetRoleId; final String confirmationToken; }
class RevokeRole extends AssignRoleEvent { final String targetUserId; final String targetRoleId; }
class CloseDrawer extends AssignRoleEvent {}
```

### States

```dart
sealed class AssignRoleState {}
class Initial extends AssignRoleState {}
class Searching extends AssignRoleState { final String query; }
class Results extends AssignRoleState { final String query; final List<UserSearchResult> results; }
class UserDrawerLoading extends AssignRoleState { ... }
class UserDrawerOpen extends AssignRoleState {
  final UserSearchResult user;
  final List<RoleAssignmentSummary> currentRoles;
}
class GrantNeedsSuperAdminConfirmation extends AssignRoleState { final UserSearchResult targetUser; final String targetRoleId; }
class GrantInProgress extends AssignRoleState { final UserSearchResult targetUser; final String targetRoleId; }
class GrantSucceeded extends AssignRoleState { ... }
class GrantFailed extends AssignRoleState { final Failure failure; final String localizedMessage; }
class RevokeInProgress extends AssignRoleState { final UserSearchResult targetUser; final String targetRoleId; }
class RevokeSucceeded extends AssignRoleState { ... }
class RevokeFailed extends AssignRoleState { final Failure failure; final String localizedMessage; }
```

### Behavior outline

- **UpdateQuery**: debounced via a `Debouncer` or `Bloc.transformEvents(...)` — 300ms. On fire, emit `Searching` then call `searchUsersUseCase`.
- **SelectUser**: emit `UserDrawerLoading`; call `loadUserAssignmentsUseCase`; emit `UserDrawerOpen`.
- **GrantRole**: read the target role's `key`; if `key == 'super_admin'`, emit `GrantNeedsSuperAdminConfirmation` and let the UI open the confirmation dialog; else proceed with a standard `ConfirmationDialog` and on confirm call `assignRoleToUserUseCase(targetUserId, targetRoleId, null)`.
- **GrantSuperAdminRole**: emit `GrantInProgress`; call `assignRoleToUserUseCase(targetUserId, targetRoleId, confirmationToken)`; on success emit `GrantSucceeded` and refresh the drawer; on failure (42501 `errorSuperAdminGrantConfirmationFailed`, 42501 `errorAssignPermissionDenied`, 23505 `errorUserAlreadyHoldsRole`), emit `GrantFailed`.
- **RevokeRole**: emit standard `ConfirmationDialog`; on confirm emit `RevokeInProgress`; call `revokeRoleFromUserUseCase(targetUserId, targetRoleId)`; on success emit `RevokeSucceeded` and refresh; on failure (42501 `errorSuperAdminSelfRevokeForbidden`, 42501 `errorRevokePermissionDenied`, 02000 `errorUserDoesNotHoldRole`), emit `RevokeFailed`.

## Permission gating

| Affordance | Gate |
|---|---|
| Page reachable | Route guard `_requireSuperAdmin` |
| Search affordance enabled | `PermissionChecker.any(PermissionKeys.superAdminCategoryKeys)` AND `PermissionChecker.has(PermissionKeys.usersView)` (super_admin holds both via the full-catalog mapping) |
| "Grant role" button enabled | `PermissionChecker.has(PermissionKeys.permissionsManage)` |
| Per-row remove (revoke) button | `PermissionChecker.has(PermissionKeys.permissionsManage)` AND `!_isSelfSuperAdminRow` |

## Mid-session propagation (R-17)

After a grant or revoke completes, the AFFECTED user's `PermissionChecker` cache will refresh on their next observation point (auth-state token-refresh OR foreground resume). The Phase 7 page does NOT push a notification to the affected user (Realtime is Phase 22). The spec SC-011 verifies the eventual-consistency behavior.

The super_admin's OWN `PermissionChecker` cache is not affected by grants/revokes of OTHER users; it refreshes only when their own role assignments change.

## Verification (Manual UI walk on Infinix Note 8)

1. Sign in as the bootstrapped super_admin. Open `/admin/super-admin/assign`.
2. Type a known user's phone prefix → confirm results appear within ~1 second.
3. Tap a result → confirm the drawer opens with the user's `currentRoles` listed.
4. Tap "Grant role" → pick `moderator` from the picker → confirm a standard `ConfirmationDialog` opens → confirm → confirm the drawer refreshes to include `moderator`.
5. Tap "Grant role" → pick `super_admin` → confirm `SuperAdminGrantConfirmationDialog` opens (NOT the standard dialog) → acknowledge consequences → type a wrong value → confirm "Confirm grant" button is disabled → type the user's phone → confirm button enables → tap → confirm 42501 paths show their localized messages if a typo simulates server mismatch; on correct match, grant succeeds.
6. Self-revoke test: open self's drawer (find self via the search field) → confirm the `super_admin` row has NO remove button.
7. Revoke a non-super_admin role: tap remove on `moderator` → confirm a standard `ConfirmationDialog` opens → confirm → confirm the row disappears from the drawer.
8. On a second device, sign in as the user just granted `moderator` → background → foreground → confirm the admin tile appears within seconds (SC-011 path).

## Forward references

- Phase 22 (Push + Realtime) MAY add a push notification to the affected user on grant/revoke. The Phase 7 bloc emits the same events; the Phase 22 layer would subscribe to the audit log or to a notification fan-out function and dispatch the push.
- A future spec MAY add bulk operations (multi-select users, multi-grant). R-20 explicitly defers this from v1.
