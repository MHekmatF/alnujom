import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../domain/entities/auth_failure.dart';
import '../internal/synthetic_email.dart';

/// Wraps Supabase Auth + the request_password_reset Edge Function.
/// Maps Supabase errors into the domain [AuthFailure] sealed hierarchy.
///
/// Constitution IX boundary: this is the only auth-feature file (besides the
/// session DTO mapper) that imports `package:supabase_flutter`.
@LazySingleton()
class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._logger);

  static const _tag = 'SupabaseAuthDataSource';

  final AppLogger _logger;

  supabase.GoTrueClient get _auth => supabase.Supabase.instance.client.auth;

  Stream<supabase.AuthState> get authStateChanges =>
      supabase.Supabase.instance.client.auth.onAuthStateChange;

  supabase.Session? get currentSession => _auth.currentSession;

  Future<supabase.AuthResponse> signUp({
    required PhoneNumber phone,
    required String password,
  }) async {
    return _auth.signUp(
      email: syntheticEmailFor(phone),
      password: password,
    );
  }

  Future<supabase.AuthResponse> signInWithPassword({
    required PhoneNumber phone,
    required String password,
  }) async {
    return _auth.signInWithPassword(
      email: syntheticEmailFor(phone),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> invokeRequestPasswordReset({
    required PhoneNumber phone,
  }) async {
    await supabase.Supabase.instance.client.functions.invoke(
      'request_password_reset',
      body: {'phone': phone.e164},
    );
  }

  /// Fetches the most recent rejection reason for the current user, or null.
  /// Used by the rejected screen to show the admin's reason.
  Future<String?> fetchMyRejectionReason({required String userId}) async {
    final row = await supabase.Supabase.instance.client
        .from('account_approval_requests')
        .select('rejection_reason')
        .eq('user_id', userId)
        .eq('status', 'rejected')
        .order('reviewed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['rejection_reason'] as String?;
  }

  /// Maps a Supabase auth exception to a domain [AuthFailure].
  AuthFailure mapAuthException(Object error, [StackTrace? stackTrace]) {
    if (error is supabase.AuthApiException) {
      _logger.warning(
        'Supabase auth error: ${error.code} ${error.message}',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Supabase error codes vary by version. Match by message + status as best-effort.
      final code = error.code ?? '';
      final msg = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        return InvalidPhoneOrPassword(cause: error, stackTrace: stackTrace);
      }
      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          msg.contains('already registered') ||
          msg.contains('already been registered') ||
          msg.contains('user already')) {
        return AccountAlreadyExists(cause: error, stackTrace: stackTrace);
      }
      if (code == 'weak_password' ||
          msg.contains('password should be') ||
          msg.contains('password is too short')) {
        return PasswordTooShort(cause: error, stackTrace: stackTrace);
      }
      return UnknownAuthError(
        error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    _logger.warning(
      'Unmapped auth error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    return UnknownAuthError(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
