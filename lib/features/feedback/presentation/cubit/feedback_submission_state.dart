// Plan A34 — feedback sheet state.
part of 'feedback_submission_cubit.dart';

enum FeedbackSubmitResult { success, rateLimited, signedOut, failure }

class FeedbackSubmissionState {
  const FeedbackSubmissionState({
    this.category,
    this.message = '',
    this.isSubmitting = false,
    this.result,
  });

  final FeedbackCategory? category;
  final String message;
  final bool isSubmitting;

  /// Terminal result; null while the sheet is still being filled in or the
  /// RPC is in flight.
  final FeedbackSubmitResult? result;

  bool get canSubmit =>
      category != null && message.trim().isNotEmpty && !isSubmitting;

  FeedbackSubmissionState copyWith({
    FeedbackCategory? category,
    String? message,
    bool? isSubmitting,
    FeedbackSubmitResult? result,
    bool clearResult = false,
  }) {
    return FeedbackSubmissionState(
      category: category ?? this.category,
      message: message ?? this.message,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}
