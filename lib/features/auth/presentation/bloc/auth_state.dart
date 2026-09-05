import '../../../../shared/domain/entities/profile.dart';
import '../../domain/entities/auth_failure.dart';

/// Auth states (Phase 5 R-18 / data-model.md §2.9).
sealed class AuthState {
  const AuthState();
}

/// Why the app is showing the sign-in screen (plan A30). `none` is the
/// ordinary case: a fresh install, or a sign-out the user asked for.
enum SignedOutReason { none, sessionExpired }

/// No authenticated session.
final class Unauthenticated extends AuthState {
  const Unauthenticated({this.reason = SignedOutReason.none});

  final SignedOutReason reason;
}

/// Sign-in / register / logout in progress.
final class Authenticating extends AuthState {
  const Authenticating();
}

/// Session active + profile.accountStatus == approved.
final class Authenticated extends AuthState {
  const Authenticated(this.profile);

  final Profile profile;
}

/// Session active + profile.accountStatus == pending.
final class PendingApproval extends AuthState {
  const PendingApproval(this.profile);

  final Profile profile;
}

/// Session active + profile.accountStatus == rejected.
final class Rejected extends AuthState {
  const Rejected(this.profile, {this.reason = ''});

  final Profile profile;
  final String reason;
}

/// Session active + profile.accountStatus == suspended.
final class Suspended extends AuthState {
  const Suspended(this.profile);

  final Profile profile;
}

/// Transport-level auth error. UI shows the error + retry.
final class AuthError extends AuthState {
  const AuthError(this.failure);

  final AuthFailure failure;
}
