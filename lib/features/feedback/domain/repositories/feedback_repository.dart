// Plan A34 — FeedbackRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.

import '../../../../core/errors/result.dart';
import '../entities/feedback_category.dart';

abstract interface class FeedbackRepository {
  /// Calls `submit_feedback(p_category, p_message, p_app_build, p_platform)`.
  /// Authenticated-only; 1–2000 characters; at most ten messages an hour.
  ///
  /// Returns the new row's id on success. Fails with:
  ///   - PermissionDeniedFailure (42501) — signed out
  ///   - ValidationFailure `rate_limited` / `invalid_message_length` /
  ///     `invalid_category`
  ///   - NetworkFailure / UnknownFailure
  Future<Result<String>> submit({
    required FeedbackCategory category,
    required String message,
    String? appBuild,
    String? platform,
  });
}
