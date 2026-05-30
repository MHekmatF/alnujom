// lib/features/reports/presentation/cubit/report_submission_state.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T041).
part of 'report_submission_cubit.dart';

enum SubmitResult { success, alreadyReported, failure }

class ReportSubmissionState {
  const ReportSubmissionState({
    this.reason,
    this.note,
    this.isSubmitting = false,
    this.result,
  });

  final ReportReason? reason;
  final String? note;
  final bool isSubmitting;

  /// Terminal result; null while the sheet is still being filled in or in-
  /// flight.
  final SubmitResult? result;

  bool get canSubmit => reason != null && !isSubmitting;

  ReportSubmissionState copyWith({
    ReportReason? reason,
    String? note,
    bool? isSubmitting,
    SubmitResult? result,
    bool clearError = false,
  }) {
    return ReportSubmissionState(
      reason: reason ?? this.reason,
      note: note ?? this.note,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: clearError ? null : (result ?? this.result),
    );
  }
}
