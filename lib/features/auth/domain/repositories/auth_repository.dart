import 'package:flutter/widgets.dart' show Locale;

import '../../../../core/errors/result.dart';
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

  /// Reset-password (account-enumeration-resistant per FR-017).
  /// Always returns Success on parseable input; only transport failures surface.
  Future<Result<void>> requestPasswordReset({required PhoneNumber phone});

  /// Fetches the latest rejection reason for [userId], or null.
  /// Used by the Rejected screen to show why the admin rejected the account.
  Future<String?> fetchRejectionReason({required String userId});

  /// Release stream subscriptions and close the internal broadcast controller.
  Future<void> dispose();
}
