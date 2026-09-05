// Plan A34 — send a problem, an idea or a question from inside the app.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/feedback_category.dart';
import '../repositories/feedback_repository.dart';

@injectable
class SubmitFeedback {
  const SubmitFeedback(this._repository);

  final FeedbackRepository _repository;

  /// Returns the new feedback row id on success.
  Future<Result<String>> call({
    required FeedbackCategory category,
    required String message,
    String? appBuild,
    String? platform,
  }) => _repository.submit(
    category: category,
    message: message,
    appBuild: appBuild,
    platform: platform,
  );
}
