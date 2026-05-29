// Phase 18 (spec/018-reports-moderation) — T034
// LoadReportsQueue: loads one page of the admin moderation queue.
// Cursor-paginated; first page passes cursor: null.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../entities/report_queue_item.dart';
import '../repositories/reports_admin_repository.dart';

@injectable
class LoadReportsQueue {
  LoadReportsQueue(this._repository);

  final ReportsAdminRepository _repository;

  Future<Result<List<ReportQueueItem>>> call({
    ReportStatus? status,
    ReportReason? reason,
    String? cursor,
    int limit = 30,
  }) {
    return _repository.loadQueue(
      status: status,
      reason: reason,
      cursor: cursor,
      limit: limit,
    );
  }
}
