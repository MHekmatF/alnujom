import 'dart:async' show EventSink, StreamTransformer;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../errors/failure.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';
import 'secure_session_storage.dart';
import 'supabase_client_wrapper.dart';
import 'types/auth_state.dart';
import 'types/realtime_channel.dart';

@LazySingleton(as: SupabaseClientWrapper)
final class SupabaseClientWrapperImpl implements SupabaseClientWrapper {
  SupabaseClientWrapperImpl(this._logger);

  static const _tag = 'SupabaseClientWrapper';

  final AppLogger _logger;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<Result<void>> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (url.isEmpty || anonKey.isEmpty) {
      return const FailureResult(
        ConfigFailure(
          'Backend configuration missing or invalid; continuing without backend.',
        ),
      );
    }

    try {
      // Security (auth H1): persist the session (incl. refresh token) in the
      // platform secure keystore rather than plaintext SharedPreferences.
      // The legacy key mirrors supabase_flutter's own default so the one-time
      // migration inside SecureLocalStorage can find + wipe the old plaintext
      // session (see secure_session_storage.dart).
      final legacyPersistSessionKey =
          'sb-${Uri.parse(url).host.split('.').first}-auth-token';
      await supabase.Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: supabase.FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(
            legacyPersistSessionKey: legacyPersistSessionKey,
          ),
          pkceAsyncStorage: SecureGotrueAsyncStorage(),
          // Spec 005 D-01 (password-reset completion) — the recovery mail is
          // generated SERVER-SIDE by the `request_password_reset` Edge Function
          // via `auth.admin.generateLink({type:'recovery'})`. That path never
          // hands the device a PKCE code verifier, so GoTrue's /verify redirect
          // carries implicit tokens in the URL fragment
          // (`alnujom://auth/reset-password#access_token=…&type=recovery`)
          // rather than a `?code=` query. supabase_flutter's deep-link observer
          // only forwards fragment links to `getSessionFromUrl` when the flow
          // type is `implicit` (SupabaseAuth._isAuthCallbackDeeplink), and
          // `exchangeCodeForSession` would throw "Code verifier could not be
          // found in local storage" regardless — so PKCE cannot complete this
          // app's reset flow at all. Implicit is the only workable setting here.
          //
          // Safe for the rest of the app: the client only ever calls
          // signUp / signInWithPassword (phone + password, email confirmation
          // OFF — `register` requires a session back immediately). There is no
          // OAuth, magic-link or SSO sign-in, which are the flows PKCE protects.
          authFlowType: supabase.AuthFlowType.implicit,
        ),
      );
      _isInitialized = true;
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to initialize Supabase client.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        ConfigFailure(
          'Failed to initialize Supabase client.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  @override
  Stream<AuthState> authStateChanges() {
    if (!_isInitialized) {
      return Stream<AuthState>.value(AuthState.signedOut);
    }
    return supabase.Supabase.instance.client.auth.onAuthStateChange
        .map(_mapAuthChangeEvent)
        .transform(
          StreamTransformer<AuthState, AuthState>.fromHandlers(
            handleError:
                (
                  Object error,
                  StackTrace stackTrace,
                  EventSink<AuthState> sink,
                ) {
                  _logger.warning(
                    'Auth state subscription error.',
                    error: error,
                    stackTrace: stackTrace,
                    tag: _tag,
                  );
                  sink.add(AuthState.error);
                },
          ),
        );
  }

  AuthState _mapAuthChangeEvent(supabase.AuthState data) {
    switch (data.event) {
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
      case supabase.AuthChangeEvent.initialSession:
        return data.session != null ? AuthState.signedIn : AuthState.signedOut;
      case supabase.AuthChangeEvent.passwordRecovery:
      case supabase.AuthChangeEvent.mfaChallengeVerified:
        return AuthState.signedIn;
      case supabase.AuthChangeEvent.signedOut:
      default:
        return AuthState.signedOut;
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> selectRows({
    required String table,
    Map<String, dynamic>? filters,
    int? limit,
  }) {
    throw UnimplementedError('wired up in Phase 5');
  }

  @override
  Future<Result<dynamic>> rpc(String fn, {Map<String, dynamic>? params}) {
    throw UnimplementedError('wired up in Phase 5');
  }

  @override
  Future<Result<String>> uploadObject({
    required String bucket,
    required String path,
    required List<int> bytes,
  }) {
    throw UnimplementedError('wired up in Phase 11');
  }

  @override
  RealtimeChannel realtimeChannel(String topic) {
    throw UnimplementedError('wired up in Phase 22');
  }
}
