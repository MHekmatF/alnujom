import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/errors/result.dart';
import '../entities/password_reset_outcome.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../entities/session.dart';

/// Auth repository contract (Phase 5 FR-011, contracts/auth-repository.md).
///
/// Constitution IX: no Supabase types in this file. The data layer translates.
abstract class AuthRepository {
  /// Domain-shaped session stream. Emits null when signed out.
  Stream<Session?> get sessionStream;

  /// Snapshot read of the current session (null if signed out).
  Session? get currentSession;

  /// Register: signUp + post-signup profile fill + locale handoff (R-11).
  Future<Result<Session>> register({
    required PhoneNumber phone,
    required String password,
    required String? fullName,
    required String? optionalRealEmail,
    required Locale deviceLocale,
  });

  /// Login with phone + password.
  Future<Result<Session>> login({
    required PhoneNumber phone,
    required String password,
  });

  /// Sign out. Clears the local session token.
  Future<void> logout();

  /// Requests a password reset and reports what the server could do about it:
  /// mail sent, phone-only account, or no such account. Only transport failures
  /// surface as [FailureResult].
  Future<Result<PasswordResetOutcome>> requestPasswordReset({
    required PhoneNumber phone,
  });

  /// Spec 005 D-01 — fires once each time an incoming password-recovery deep
  /// link (`alnujom://auth/reset-password`) has been exchanged for a recovery
  /// session, i.e. the user may now choose a new password.
  ///
  /// A recovery that lands during app start (before any widget is mounted) is
  /// held and replayed to the first subscriber, so the listener never misses a
  /// cold-launch reset link.
  Stream<void> get passwordRecoveryStream;

  /// Spec 005 D-01 — sets a new password for the session established by the
  /// recovery link.
  ///
  /// Returns [UnknownAuthError] with message `recovery_session_missing` when
  /// there is no active session (expired or already-consumed link), so the UI
  /// can offer "request a new link" instead of a generic error.
  Future<Result<void>> updatePassword({required String newPassword});

  /// Fetches the latest rejection reason for [userId], or null.
  /// Used by the Rejected screen to show why the admin rejected the account.
  Future<String?> fetchRejectionReason({required String userId});

  /// Release stream subscriptions and close the internal broadcast controller.
  Future<void> dispose();
}
