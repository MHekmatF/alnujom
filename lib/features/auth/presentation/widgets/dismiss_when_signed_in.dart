import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../bloc/auth_state.dart';

/// True once a real session exists, whatever the account's standing.
///
/// [PendingApproval], [Rejected] and [Suspended] are all *signed in* — the
/// account gate screens are what the router shows next. Only [Unauthenticated],
/// [Authenticating] and [AuthError] mean there is still no session.
bool hasSession(AuthState state) =>
    state is Authenticated ||
    state is PendingApproval ||
    state is Rejected ||
    state is Suspended;

/// Closes an auth page that was **pushed** on top of the app, once the sign-in
/// behind it has succeeded.
///
/// WHY THIS EXISTS — device walk, 2026-09-02, reported by the owner:
/// *"first time I pressed Login it stayed on the same screen, so I pressed Back
/// to open the app."* The sign-in had actually worked. What he was looking at
/// was a login page that had nothing left to do and would not leave.
///
/// The cause is the interaction between two correct things. `authRedirect`
/// sends an authenticated caller away from `/login`, but it works on the
/// router's *location*, and since #107 the guest sheet, the drawer, the
/// favourite heart and the listing contact block all reach the login screen
/// with `context.push`. A pushed route is an imperative entry on top of the
/// match list, and moving the location underneath it does not remove it. So the
/// stack below was already correct — that is why Back revealed a signed-in app
/// — while the form sat on top of it looking like a failure.
///
/// `push` itself is right and must stay: it is what stopped Back from quitting
/// the app outright when a guest tapped one of the account tabs (#107). The
/// page simply has to dismiss itself.
///
/// [context.canPop] is the entire guard. When `/login` **is** the stack root —
/// splash, the maintenance screen, register → login — there is nothing to pop,
/// this does nothing, and the global redirect moves the user on exactly as
/// before.
///
/// Deferred to the end of the frame because the same [AuthState] emission also
/// drives `GoRouter.refreshListenable`; popping after the router has settled
/// keeps the two out of each other's way.
void dismissWhenSignedIn(BuildContext context, AuthState state) {
  if (!hasSession(state)) return;
  if (!context.canPop()) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (!context.canPop()) return;
    context.pop();
  });
}
