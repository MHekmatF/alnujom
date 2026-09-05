// Plan A29 — report a PERSON rather than a listing. Calls
// submit_user_report(p_user_id, p_reason, p_note) via the repository.
// Authenticated-only; not yourself; deduped (one open report per reporter and
// person). Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/report_reason.dart';
import '../repositories/reports_repository.dart';

@injectable
class SubmitUserReport {
  const SubmitUserReport(this._repository);

  final ReportsRepository _repository;

  /// Returns the new report UUID string on success.
  Future<Result<String>> call(
    String userId,
    ReportReason reason,
    String? note,
  ) =>
      _repository.submitUserReport(userId, reason, note);
}
