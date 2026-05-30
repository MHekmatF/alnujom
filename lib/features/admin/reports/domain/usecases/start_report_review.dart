// Phase 18 (spec/018-reports-moderation) — T035
// StartReportReview: invokes the `start_report_review` RPC to soft-claim a
// report for review (Q4=B advisory lock, FR-036).
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/reports_admin_repository.dart';

@injectable
class StartReportReview {
  StartReportReview(this._repository);

  final ReportsAdminRepository _repository;

  Future<Result<void>> call(String reportId) {
    return _repository.startReview(reportId);
  }
}
