// Phase 18 (spec/018-reports-moderation) — SubmitReport use case.
//
// Calls submit_report(p_listing_id, p_reason, p_note) SECURITY DEFINER RPC
// via the repository. Authenticated-only; approved listings only; deduped.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/report_reason.dart';
import '../repositories/reports_repository.dart';

@injectable
class SubmitReport {
  const SubmitReport(this._repository);

  final ReportsRepository _repository;

  /// Returns the new report UUID string on success.
  Future<Result<String>> call(
    String listingId,
    ReportReason reason,
    String? note,
  ) =>
      _repository.submitReport(listingId, reason, note);
}
