// lib/features/reports/presentation/cubit/report_submission_cubit.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T041).
// Sheet reason/note state + submit() → SubmitReport use case.
// Surfaces success / already_reported / failure.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/usecases/submit_report.dart';
import '../../domain/usecases/submit_user_report.dart';

part 'report_submission_state.dart';

/// Per-sheet cubit: drives the report bottom sheet form state.
///
/// Registered as @injectable (one per sheet instance — not a singleton).
@injectable
class ReportSubmissionCubit extends Cubit<ReportSubmissionState> {
  ReportSubmissionCubit(this._submitReport, this._submitUserReport)
      : super(const ReportSubmissionState());

  final SubmitReport _submitReport;
  final SubmitUserReport _submitUserReport;

  /// Updates the currently selected [reason].
  void reasonChanged(ReportReason? reason) {
    emit(state.copyWith(reason: reason, clearError: true));
  }

  /// Updates the note text (max 1000 chars enforced by the sheet's TextField
  /// inputFormatters, but we clamp here too for safety).
  void noteChanged(String note) {
    emit(
      state.copyWith(
        note: note.length > 1000 ? note.substring(0, 1000) : note,
      ),
    );
  }

  /// Submits the report for [listingId].
  ///
  /// Emits [ReportSubmissionSubmitting] while the RPC is in flight, then one
  /// of [ReportSubmissionSuccess] / [ReportSubmissionAlreadyReported] /
  /// [ReportSubmissionFailure].
  Future<void> submit(String listingId) => submitFor(listingId: listingId);

  /// Plan A29 — one submit for both targets: a listing, or a person.
  Future<void> submitFor({String? listingId, String? userId}) async {
    final reason = state.reason;
    if (reason == null) return; // guard — submit button is disabled when null.
    if (listingId == null && userId == null) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));

    final result = userId != null
        ? await _submitUserReport(userId, reason, state.note)
        : await _submitReport(listingId!, reason, state.note);
    if (isClosed) return;

    switch (result) {
      case Success<String>():
        emit(state.copyWith(isSubmitting: false, result: SubmitResult.success));
      case FailureResult<String>(:final failure):
        // Detect the dedup error code returned by the submit_report RPC.
        final isDedup = failure.message.contains('P0001') ||
            failure.message.contains('already_reported') ||
            failure.message.contains('existing open report');
        emit(
          state.copyWith(
            isSubmitting: false,
            result: isDedup
                ? SubmitResult.alreadyReported
                : SubmitResult.failure,
          ),
        );
    }
  }

  /// Resets the terminal state so the sheet can show the error inline and the
  /// caller can dismiss.
  void reset() => emit(const ReportSubmissionState());
}
