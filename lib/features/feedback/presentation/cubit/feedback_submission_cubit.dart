// Plan A34 — the feedback sheet's form state and submit.
//
// Attaches the running build ("1.1.3+2005") and the platform name so a bug
// report says where it came from without the person having to know.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/feedback_category.dart';
import '../../domain/usecases/submit_feedback.dart';

part 'feedback_submission_state.dart';

/// Per-sheet cubit (one per sheet instance — not a singleton).
@injectable
class FeedbackSubmissionCubit extends Cubit<FeedbackSubmissionState> {
  FeedbackSubmissionCubit(this._submitFeedback)
    : super(const FeedbackSubmissionState());

  final SubmitFeedback _submitFeedback;

  /// Mirrors the CHECK on `feedback.message`.
  static const int maxLength = 2000;

  void categoryChanged(FeedbackCategory? category) {
    emit(state.copyWith(category: category, clearResult: true));
  }

  void messageChanged(String message) {
    emit(
      state.copyWith(
        message: message.length > maxLength
            ? message.substring(0, maxLength)
            : message,
        clearResult: true,
      ),
    );
  }

  Future<void> submit() async {
    final category = state.category;
    final message = state.message.trim();
    if (category == null || message.isEmpty || state.isSubmitting) return;

    emit(state.copyWith(isSubmitting: true, clearResult: true));

    final result = await _submitFeedback(
      category: category,
      message: message,
      appBuild: await _appBuild(),
      platform: defaultTargetPlatform.name,
    );
    if (isClosed) return;

    switch (result) {
      case Success<String>():
        emit(
          state.copyWith(
            isSubmitting: false,
            result: FeedbackSubmitResult.success,
          ),
        );
      case FailureResult<String>(:final failure):
        emit(
          state.copyWith(
            isSubmitting: false,
            result: switch (failure) {
              ValidationFailure(code: 'rate_limited') =>
                FeedbackSubmitResult.rateLimited,
              PermissionDeniedFailure() => FeedbackSubmitResult.signedOut,
              _ => FeedbackSubmitResult.failure,
            },
          ),
        );
    }
  }

  static Future<String?> _appBuild() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return null;
    }
  }
}
