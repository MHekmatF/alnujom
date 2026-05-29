// Phase 18 (spec/018-reports-moderation) — T036
// ResolveReport: invokes the `resolve_report` Edge Function via the
// repository. Maps 403/409/404 error codes to typed Failures in the impl.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/moderation_action_type.dart';
import '../repositories/reports_admin_repository.dart';

@injectable
class ResolveReport {
  ResolveReport(this._repository);

  final ReportsAdminRepository _repository;

  Future<Result<void>> call(
    String reportId,
    ModerationActionType action, {
    String? note,
  }) {
    return _repository.resolve(reportId, action, note: note);
  }
}
