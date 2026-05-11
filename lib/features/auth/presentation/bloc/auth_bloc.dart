import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
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
class AuthBloc extends Bloc<AuthEvent, AuthState>
    with WidgetsBindingObserver {
  AuthBloc(this._authRepository, this._profileRepository)
    : super(const Unauthenticated()) {
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
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  late final StreamSubscription<Session?> _sessionSub;

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
          failure is AuthFailure
              ? failure
              : UnknownAuthError(failure.message),
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
          failure is AuthFailure
              ? failure
              : UnknownAuthError(failure.message),
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
      emit(const Unauthenticated());
      return;
    }
    final profileResult = await _profileRepository.getCurrentProfile();
    if (profileResult is Success<Profile>) {
      emit(_stateFromProfile(profileResult.value));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onProfileRefreshed(
    ProfileRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    if (_authRepository.currentSession == null) return;
    emit(_stateFromProfile(event.profile));
  }

  Future<void> _onAppResumedRefresh(
    AppResumedRefresh event,
    Emitter<AuthState> emit,
  ) async {
    if (state is Unauthenticated || state is Authenticating) return;
    final result = await _profileRepository.refresh();
    if (result is Success<Profile>) {
      emit(_stateFromProfile(result.value));
    }
  }

  AuthState _stateFromProfile(Profile profile) {
    return switch (profile.accountStatus) {
      AccountStatus.approved => Authenticated(profile),
      AccountStatus.pending => PendingApproval(profile),
      AccountStatus.rejected => Rejected(profile),
      AccountStatus.suspended => Suspended(profile),
      AccountStatus.deleted => const Unauthenticated(),
    };
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _sessionSub.cancel();
    await close();
  }
}
