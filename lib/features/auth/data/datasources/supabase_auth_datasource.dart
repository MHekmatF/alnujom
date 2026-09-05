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
    return _auth.signUp(email: syntheticEmailFor(phone), password: password);
  }

  Future<supabase.AuthResponse> signInWithPassword({
    required PhoneNumber phone,
    required String password,
  }) async {
    // Option B fix: auth.users.email may be the user's REAL email (if they
    // provided one) or the synthetic <phone>@alnujom.local (if they didn't).
    // We can't know which from the client, so we ask the lookup Edge Function
    // and use whatever it returns. For unknown phones it returns the synthetic
    // form, which fails signIn with `invalid_credentials` — same as a wrong
    // password against a known phone (account-enumeration resistant).
    String email = syntheticEmailFor(phone);
    try {
      final response = await supabase.Supabase.instance.client.functions.invoke(
        'lookup_email_by_phone',
        body: {'phone': phone.e164},
      );
      final data = response.data;
      if (data is Map && data['email'] is String) {
        final candidate = data['email'] as String;
        if (candidate.isNotEmpty) email = candidate;
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'lookup_email_by_phone failed; falling back to synthetic email.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }

    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Returns the Edge Function's `status`: `sent`, `no_email` or `not_found`.
  /// An unrecognised or missing status is reported as `not_found` so the UI
  /// never claims a mail was sent that was not.
  Future<String> invokeRequestPasswordReset({required PhoneNumber phone}) async {
    final res = await supabase.Supabase.instance.client.functions.invoke(
      'request_password_reset',
      body: {'phone': phone.e164},
    );
    final data = res.data;
    if (data is Map && data['status'] is String) return data['status'] as String;
    return 'not_found';
  }

  /// Spec 005 D-01 — sets a new password on the CURRENTLY signed-in user.
  ///
  /// Used to complete a password reset after the `alnujom://auth/reset-password`
  /// recovery deep link established a session (GoTrue then emits
  /// [supabase.AuthChangeEvent.passwordRecovery]). Throws when no session is
  /// active or the password is rejected server-side; the repository maps the
  /// throw through [mapAuthException].
  Future<void> updatePassword({required String newPassword}) async {
    await _auth.updateUser(supabase.UserAttributes(password: newPassword));
  }

  /// Plan A27 — records that the signed-in user accepted the terms at
  /// [version] (`accept_terms` RPC; writes the caller's own profile only).
  Future<void> acceptTerms({required String version}) async {
    await supabase.Supabase.instance.client.rpc<dynamic>(
      'accept_terms',
      params: {'p_version': version},
    );
  }

  /// Whether the incoming auth-state event signals that a password-recovery
  /// deep link was processed and a recovery session is now active.
  ///
  /// Keeps the `AuthChangeEvent` enum inside the data layer (Constitution IX):
  /// the repository asks this instead of importing the Supabase type itself.
  bool isPasswordRecoveryEvent(supabase.AuthState state) =>
      state.event == supabase.AuthChangeEvent.passwordRecovery;

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
