import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/messaging/push_messaging_service.dart';
import '../../../../core/network/realtime_signals.dart';
import '../../../../core/security/permission_checker.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../notifications/domain/usecases/deregister_push_token.dart';
import '../../../notifications/domain/usecases/register_push_token.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Central auth state machine (Phase 5 R-18 / data-model.md §2.9).
///
/// Subscribes to [AuthRepository.sessionStream] for session changes and to
/// [WidgetsBindingObserver] for foreground-resume suspension detection (R-21).
@LazySingleton()
class AuthBloc extends Bloc<AuthEvent, AuthState> with WidgetsBindingObserver {
  AuthBloc(
    this._authRepository,
    this._profileRepository,
    this._permissionChecker,
    this._registerPushToken,
    this._deregisterPushToken,
    this._pushMessaging,
    this._realtimeSignals,
  ) : super(const Unauthenticated()) {
    WidgetsBinding.instance.addObserver(this);
    on<RegisterRequested>(_onRegisterRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<SessionRefreshed>(_onSessionRefreshed);
    on<ProfileRefreshed>(_onProfileRefreshed);
    on<AppResumedRefresh>(_onAppResumedRefresh);

    _sessionSub = _authRepository.sessionStream.listen(
      (session) => add(SessionRefreshed(session)),
    );

    // Phase 22 (T039): re-register on FCM token rotation while signed in.
    // Inert under NoopPushMessagingService (the stream never emits — FR-013).
    // Track the rotated token so logout deregisters THIS device's current token.
    _tokenRefreshSub = _pushMessaging.onTokenRefresh().listen((token) {
      if (_wiredUserId != null && token.isNotEmpty) {
        _registeredToken = token;
        unawaited(_registerPushToken(token));
      }
    });
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PermissionChecker _permissionChecker;
  final RegisterPushToken _registerPushToken;
  final DeregisterPushToken _deregisterPushToken;
  final PushMessagingService _pushMessaging;
  final RealtimeSignals _realtimeSignals;
  late final StreamSubscription<Session?> _sessionSub;
  late final StreamSubscription<String> _tokenRefreshSub;

  /// The user id whose session signals (push token + `user_roles` channel) are
  /// currently wired, or `null` when signed out. Guards against double-wiring on
  /// repeated `SessionRefreshed` emissions for the same session.
  String? _wiredUserId;

  /// The push token last registered for [_wiredUserId] — used to deregister
  /// exactly that device's token on logout (per-device, R-191/SC-011).
  String? _registeredToken;

  /// The open `user_roles` Realtime channel (the 4th PermissionChecker
  /// observation point, T040). Torn down on logout.
  RealtimeSubscriptionHandle? _userRolesChannel;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      add(const AppResumedRefresh());
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const Authenticating());
    final result = await _authRepository.register(
      phone: event.phone,
      password: event.password,
      fullName: event.fullName,
      optionalRealEmail: event.optionalRealEmail,
      deviceLocale: event.deviceLocale,
    );
    if (result is FailureResult<Session>) {
      final failure = result.failure;
      emit(
        AuthError(
          failure is AuthFailure ? failure : UnknownAuthError(failure.message),
        ),
      );
    }
    // On Success: sessionStream fires SessionRefreshed which computes the state.
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const Authenticating());
    final result = await _authRepository.login(
      phone: event.phone,
      password: event.password,
    );
    if (result is FailureResult<Session>) {
      final failure = result.failure;
      emit(
        AuthError(
          failure is AuthFailure ? failure : UnknownAuthError(failure.message),
        ),
      );
    }
    // On Success: sessionStream fires SessionRefreshed.
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    // sessionStream fires SessionRefreshed(null) → Unauthenticated.
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previousState = state;
    emit(const Authenticating());
    final result = await _authRepository.requestPasswordReset(
      phone: event.phone,
    );
    if (result is FailureResult<void>) {
      emit(
        AuthError(
          UnknownAuthError(
            result.failure.message,
            cause: result.failure.cause,
            stackTrace: result.failure.stackTrace,
          ),
        ),
      );
    } else {
      // Always restore previous state (FR-017: uniform response regardless of outcome).
      emit(previousState);
    }
  }

  Future<void> _onSessionRefreshed(
    SessionRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    final session = event.session;
    if (session == null || !session.isActive) {
      await _teardownSessionSignals();
      _permissionChecker.clear();
      emit(const Unauthenticated());
      return;
    }
    await _permissionChecker.load();
    final profileResult = await _profileRepository.getCurrentProfile();
    if (profileResult is Success<Profile>) {
      // Phase 22 (T039/T040): wire push-token registration + the user_roles
      // permission-refresh channel for this session — regardless of
      // account_status, so a pending user still receives the approval push and
      // a live role grant refreshes their permissions (R-191/FR-011/FR-017).
      await _wireSessionSignals(session.userId);
      emit(await _stateFromProfile(profileResult.value));
    } else {
      await _teardownSessionSignals();
      _permissionChecker.clear();
      emit(const Unauthenticated());
    }
  }

  /// Idempotent per-session wiring (T039/T040). Registers this device's push
  /// token (any account_status — R-191) and opens the `user_roles` Realtime
  /// channel that calls `PermissionChecker.refresh()` on a role change — the
  /// 4th observation point (the existing three in `_onSessionRefreshed.load`,
  /// `_onAppResumedRefresh`, and sign-out `clear` stay intact). FR-017.
  Future<void> _wireSessionSignals(String userId) async {
    if (_wiredUserId == userId) return; // already wired for this user
    if (_wiredUserId != null) {
      // Different user took over without an intervening sign-out — reset first.
      await _teardownSessionSignals();
    }
    _wiredUserId = userId;

    // 4th PermissionChecker observation point: live role changes for THIS user.
    _userRolesChannel = _realtimeSignals.subscribeUserRoles(
      userId: userId,
      onChange: () => unawaited(_permissionChecker.refresh()),
      // Reconcile on (re)subscribe so a change missed during a drop self-heals.
      onResubscribe: () => unawaited(_permissionChecker.refresh()),
    );

    // Register this device's push token (no-op under the no-op adapter — FR-013).
    final token = await _pushMessaging.currentToken();
    if (token != null && token.isNotEmpty) {
      _registeredToken = token;
      await _registerPushToken(token);
    }
  }

  /// Tears down everything [_wireSessionSignals] opened (logout / user switch /
  /// dispose). Deregisters only THIS device's token (per-device — SC-011) and
  /// removes the `user_roles` channel (no leak).
  Future<void> _teardownSessionSignals() async {
    if (_wiredUserId == null) return;
    final token = _registeredToken;
    _wiredUserId = null;
    _registeredToken = null;

    final channel = _userRolesChannel;
    _userRolesChannel = null;
    await channel?.cancel();

    if (token != null && token.isNotEmpty) {
      await _deregisterPushToken(token);
    }
  }

  Future<void> _onProfileRefreshed(
    ProfileRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    if (_authRepository.currentSession == null) return;
    emit(await _stateFromProfile(event.profile));
  }

  Future<void> _onAppResumedRefresh(
    AppResumedRefresh event,
    Emitter<AuthState> emit,
  ) async {
    if (state is Unauthenticated || state is Authenticating) return;
    await _permissionChecker.refresh();
    final result = await _profileRepository.refresh();
    if (result is Success<Profile>) {
      emit(await _stateFromProfile(result.value));
    }
  }

  Future<AuthState> _stateFromProfile(Profile profile) async {
    switch (profile.accountStatus) {
      case AccountStatus.approved:
        return Authenticated(profile);
      case AccountStatus.pending:
        return PendingApproval(profile);
      case AccountStatus.rejected:
        final reason = await _authRepository.fetchRejectionReason(
          userId: profile.userId,
        );
        return Rejected(profile, reason: reason ?? '');
      case AccountStatus.suspended:
        return Suspended(profile);
      case AccountStatus.deleted:
        return const Unauthenticated();
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _sessionSub.cancel();
    await _tokenRefreshSub.cancel();
    await _teardownSessionSignals();
    await close();
  }
}
