// Phase 19 (spec/019-agencies) — T068
// AgencyModerationCubit: drives the agency-detail page's moderation actions.
// Calls ApproveAgency / RejectAgency / SuspendAgency / ReinstateAgency via the
// admin use cases. Mirrors ReportResolveCubit (Phase 18).
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../domain/usecases/approve_agency.dart';
import '../../domain/usecases/reinstate_agency.dart';
import '../../domain/usecases/reject_agency.dart';
import '../../domain/usecases/suspend_agency.dart';

// ─── State ───────────────────────────────────────────────────────────────────

sealed class AgencyModerationState extends Equatable {
  const AgencyModerationState();
  @override
  List<Object?> get props => const [];
}

class AgencyModerationInitial extends AgencyModerationState {
  const AgencyModerationInitial();
}

class AgencyModerationLoading extends AgencyModerationState {
  const AgencyModerationLoading();
}

class AgencyModerationSuccess extends AgencyModerationState {
  const AgencyModerationSuccess();
}

class AgencyModerationFailure extends AgencyModerationState {
  const AgencyModerationFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

@injectable
class AgencyModerationCubit extends Cubit<AgencyModerationState> {
  AgencyModerationCubit(
    this._approveAgency,
    this._rejectAgency,
    this._suspendAgency,
    this._reinstateAgency,
  ) : super(const AgencyModerationInitial());

  final ApproveAgency _approveAgency;
  final RejectAgency _rejectAgency;
  final SuspendAgency _suspendAgency;
  final ReinstateAgency _reinstateAgency;

  /// Invokes the `moderate_agency` Edge Function with action=`approve`.
  Future<void> approve(String agencyId) async {
    emit(const AgencyModerationLoading());
    final result = await _approveAgency(agencyId);
    _handleResult(result);
  }

  /// Invokes the `moderate_agency` Edge Function with action=`reject`.
  Future<void> reject(
    String agencyId, {
    required String preset,
    String? detail,
  }) async {
    emit(const AgencyModerationLoading());
    final result =
        await _rejectAgency(agencyId, preset: preset, detail: detail);
    _handleResult(result);
  }

  /// Invokes the `moderate_agency` Edge Function with action=`suspend`.
  Future<void> suspend(String agencyId, {String? reason}) async {
    emit(const AgencyModerationLoading());
    final result = await _suspendAgency(agencyId, reason: reason);
    _handleResult(result);
  }

  /// Invokes the `moderate_agency` Edge Function with action=`reinstate`.
  Future<void> reinstate(String agencyId) async {
    emit(const AgencyModerationLoading());
    final result = await _reinstateAgency(agencyId);
    _handleResult(result);
  }

  /// Resets state so the UI can show another action without residual state.
  void reset() => emit(const AgencyModerationInitial());

  void _handleResult(Result<void> result) {
    switch (result) {
      case Success():
        emit(const AgencyModerationSuccess());
      case FailureResult(:final failure):
        emit(AgencyModerationFailure(failure));
    }
  }
}
