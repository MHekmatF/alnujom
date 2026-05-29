// Phase 18 (spec/018-reports-moderation) — T058
// ReportResolveCubit: drives the report-detail page's start-review + resolve
// actions. Calls StartReportReview (soft-claim) and ResolveReport (Edge Fn).
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../domain/entities/moderation_action_type.dart';
import '../../domain/usecases/resolve_report.dart';
import '../../domain/usecases/start_report_review.dart';

// ─── State ───────────────────────────────────────────────────────────────────

sealed class ReportResolveState extends Equatable {
  const ReportResolveState();
  @override
  List<Object?> get props => const [];
}

class ReportResolveInitial extends ReportResolveState {
  const ReportResolveInitial();
}

class ReportResolveLoading extends ReportResolveState {
  const ReportResolveLoading();
}

class ReportResolveSuccess extends ReportResolveState {
  const ReportResolveSuccess();
}

class ReportResolveFailure extends ReportResolveState {
  const ReportResolveFailure(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

@injectable
class ReportResolveCubit extends Cubit<ReportResolveState> {
  ReportResolveCubit(
    this._startReportReview,
    this._resolveReport,
  ) : super(const ReportResolveInitial());

  final StartReportReview _startReportReview;
  final ResolveReport _resolveReport;

  /// Invokes the `start_report_review` RPC (Q4=B advisory soft-claim).
  /// On success emits [ReportResolveSuccess]; callers may use this to refresh
  /// the detail page (the claim is advisory — failure is surfaced but not fatal).
  Future<void> startReview(String reportId) async {
    emit(const ReportResolveLoading());
    final result = await _startReportReview(reportId);
    switch (result) {
      case Success():
        emit(const ReportResolveSuccess());
      case FailureResult(:final failure):
        emit(ReportResolveFailure(failure));
    }
  }

  /// Invokes the `resolve_report` Edge Function with [action] + optional [note].
  Future<void> resolve(
    String reportId,
    ModerationActionType action, {
    String? note,
  }) async {
    emit(const ReportResolveLoading());
    final result = await _resolveReport(reportId, action, note: note);
    switch (result) {
      case Success():
        emit(const ReportResolveSuccess());
      case FailureResult(:final failure):
        emit(ReportResolveFailure(failure));
    }
  }

  /// Resets state so the UI can show another action without residual state.
  void reset() => emit(const ReportResolveInitial());
}
