import '../../domain/entities/password_reset_outcome.dart';
import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../../currencies/domain/repositories/currencies_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../settings/domain/usecases/load_public_settings.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_auth_datasource.dart';
import '../dtos/session_dto.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._authDs,
    this._profileRepository,
    this._logger,
    this._loadPublicSettings,
    this._currenciesRepository,
  ) {
    // Bridge Supabase's auth-state stream into the domain-shaped session stream.
    _sub = _authDs.authStateChanges.listen(
      (state) {
        _sessionController.add(state.session?.toDomain());
        // Spec 005 D-01 — a recovery deep link was exchanged for a session.
        // Held when nobody is listening yet (cold launch straight from the
        // email link) and replayed to the first subscriber.
        if (_authDs.isPasswordRecoveryEvent(state)) {
          if (_passwordRecoveryController.hasListener) {
            _passwordRecoveryController.add(null);
          } else {
            _pendingPasswordRecovery = true;
          }
        }
      },
      onError: (Object error, StackTrace st) {
        _logger.warning(
          'Auth state stream error.',
          error: error,
          stackTrace: st,
          tag: _tag,
        );
        _sessionController.add(null);
      },
    );
    // Seed the controller with the current snapshot so subscribers don't miss state.
    _sessionController.add(_authDs.currentSession?.toDomain());
  }

  static const _tag = 'AuthRepositoryImpl';

  final SupabaseAuthDataSource _authDs;
  final ProfileRepository _profileRepository;
  final AppLogger _logger;
  // Phase 23 (FC / T026) — registration seeding: read the public settings
  // snapshot for the new user's default language + display currency (R-203).
  final LoadPublicSettings _loadPublicSettings;
  final CurrenciesRepository _currenciesRepository;

  final _sessionController = StreamController<Session?>.broadcast();
  StreamSubscription<supabase.AuthState>? _sub;

  /// Spec 005 D-01 — set when a `passwordRecovery` event arrives before any
  /// widget has subscribed (cold launch from the email link). Replayed by
  /// [_passwordRecoveryController]'s `onListen` and then cleared.
  bool _pendingPasswordRecovery = false;

  late final StreamController<void> _passwordRecoveryController =
      StreamController<void>.broadcast(
        onListen: () {
          if (!_pendingPasswordRecovery) return;
          _pendingPasswordRecovery = false;
          // Deliver on a microtask: a broadcast controller does not guarantee
          // delivery of an event added from inside its own `onListen`.
          scheduleMicrotask(() {
            if (!_passwordRecoveryController.isClosed) {
              _passwordRecoveryController.add(null);
            }
          });
        },
      );

  @override
  Stream<Session?> get sessionStream => _sessionController.stream;

  @override
  Stream<void> get passwordRecoveryStream => _passwordRecoveryController.stream;

  @override
  Session? get currentSession => _authDs.currentSession?.toDomain();

  @override
  Future<Result<Session>> register({
    required PhoneNumber phone,
    required String password,
    required String? fullName,
    required String? optionalRealEmail,
    required Locale deviceLocale,
  }) async {
    try {
      final res = await _authDs.signUp(phone: phone, password: password);
      final supSession = res.session;
      if (supSession == null) {
        return const FailureResult(
          UnknownAuthError('signup_succeeded_without_session'),
        );
      }

      // Phase 4 auto-provision trigger has fired by now. Fill in the profile
      // with the form's full_name, phone (in E.164), and optional real email.
      // Trim user input; pass nulls so the data layer skips unset fields.
      final trimmedName = fullName?.trim();
      final trimmedEmail = optionalRealEmail?.trim();
      final cleanName = (trimmedName?.isEmpty ?? true) ? null : trimmedName;
      final cleanEmail = (trimmedEmail?.isEmpty ?? true)
          ? null
          : trimmedEmail!.toLowerCase();

      // Non-fatal: signUp already created the auth user. If the PATCH hangs
      // (e.g. HiOS network throttling on second registration), time out and
      // continue rather than leaving the BLoC in Authenticating forever.
      try {
        await _profileRepository
            .updateProfile(
              fullName: cleanName,
              phone: phone.e164,
              email: cleanEmail,
            )
            .timeout(const Duration(seconds: 12));
        // Phase 23 (FC / T026) — forward-only new-user seeding (R-203, FR-007).
        // Seed the new user's locale + display currency from the admin-tuned
        // app_settings defaults. Fail-open: if the settings fetch fails, fall
        // back to the device locale (Phase 5 R-11 first-sign-in handoff) and
        // skip the currency seed. Only runs on this registration path; existing
        // users are never rewritten.
        final settingsResult = await _loadPublicSettings();
        final defaults = switch (settingsResult) {
          Success(:final value) => value,
          FailureResult() => null,
        };
        final seedLocale = defaults?.defaultLocale ?? deviceLocale;
        await _profileRepository
            .updateLocale(seedLocale)
            .timeout(const Duration(seconds: 8));
        if (defaults != null) {
          await _currenciesRepository
              .writeUserDisplayCurrency(defaults.defaultCurrency)
              .timeout(const Duration(seconds: 8));
        }
      } on Object catch (e, st) {
        _logger.warning(
          'Post-register profile fill failed (non-fatal); user is registered.',
          error: e,
          stackTrace: st,
          tag: _tag,
        );
      }

      return Success(supSession.toDomain());
    } on Object catch (error, stackTrace) {
      return FailureResult(_authDs.mapAuthException(error, stackTrace));
    }
  }

  @override
  Future<Result<Session>> login({
    required PhoneNumber phone,
    required String password,
  }) async {
    try {
      final res = await _authDs.signInWithPassword(
        phone: phone,
        password: password,
      );
      final supSession = res.session;
      if (supSession == null) {
        return const FailureResult(
          UnknownAuthError('login_succeeded_without_session'),
        );
      }
      return Success(supSession.toDomain());
    } on Object catch (error, stackTrace) {
      return FailureResult(_authDs.mapAuthException(error, stackTrace));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authDs.signOut();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Sign-out failed (ignored).',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  @override
  Future<Result<PasswordResetOutcome>> requestPasswordReset({
    required PhoneNumber phone,
  }) async {
    try {
      final status = await _authDs.invokeRequestPasswordReset(phone: phone);
      return Success(PasswordResetOutcome.fromStatus(status));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'request_password_reset transport error.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(
          'request_password_reset transport failure',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updatePassword({required String newPassword}) async {
    // No session ⇒ the recovery link expired, was already consumed, or the app
    // was opened straight at the completion route. Surface a distinct message
    // key so the UI can offer "request a new link" (the codebase's established
    // idiom — see `UnknownAuthError('phone_required')` handling in login_page).
    if (_authDs.currentSession == null) {
      return const FailureResult(UnknownAuthError('recovery_session_missing'));
    }
    try {
      await _authDs.updatePassword(newPassword: newPassword);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'updatePassword failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(_authDs.mapAuthException(error, stackTrace));
    }
  }

  @override
  Future<String?> fetchRejectionReason({required String userId}) async {
    try {
      return await _authDs.fetchMyRejectionReason(userId: userId);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchRejectionReason failed (ignored).',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return null;
    }
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await _sub?.cancel();
    await _sessionController.close();
    await _passwordRecoveryController.close();
  }
}
