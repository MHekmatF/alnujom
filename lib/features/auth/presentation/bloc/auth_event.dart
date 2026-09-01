import 'package:flutter/widgets.dart' show Locale;

import '../../../../shared/domain/entities/profile.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../domain/entities/session.dart';

/// Auth events (Phase 5 R-18 / data-model.md §2.9).
///
/// Constitution IX: no Supabase types.
sealed class AuthEvent {
  const AuthEvent();
}

final class RegisterRequested extends AuthEvent {
  const RegisterRequested({
    required this.phone,
    required this.password,
    this.fullName,
    this.optionalRealEmail,
    required this.deviceLocale,
  });

  final PhoneNumber phone;
  final String password;
  final String? fullName;
  final String? optionalRealEmail;
  final Locale deviceLocale;
}

final class LoginRequested extends AuthEvent {
  const LoginRequested({required this.phone, required this.password});

  final PhoneNumber phone;
  final String password;
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}


final class SessionRefreshed extends AuthEvent {
  const SessionRefreshed(this.session);

  final Session? session;
}

final class ProfileRefreshed extends AuthEvent {
  const ProfileRefreshed(this.profile);

  final Profile profile;
}

final class AppResumedRefresh extends AuthEvent {
  const AppResumedRefresh();
}

/// Phase 22 (T040): the signed-in user's `user_roles` changed (live grant/revoke
/// delivered via the Realtime channel). Triggers a permission-cache refresh AND a
/// state re-emit so permission-gated widgets rebuild — the cache update alone is
/// invisible to the UI because [PermissionChecker] is not [Listenable] and
/// [AuthState] carries no permission data (FR-017/SC-005).
final class PermissionsChanged extends AuthEvent {
  const PermissionsChanged();
}
