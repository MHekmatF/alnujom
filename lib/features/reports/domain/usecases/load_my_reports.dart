// Phase 18 (spec/018-reports-moderation) — LoadMyReports use case.
//
// Pages through the authenticated user's own reports via public.v_reports
// (self-scoped by RLS), newest-first, cursor-paginated on created_at DESC.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/report.dart';
import '../repositories/reports_repository.dart';

@injectable
class LoadMyReports {
  const LoadMyReports(this._repository);

  final ReportsRepository _repository;

  /// [cursor] is an ISO-8601 `created_at` timestamp for keyset pagination.
  /// Pass `null` for the first page.
  Future<Result<List<Report>>> call({
    String? cursor,
    int limit = 30,
  }) =>
      _repository.loadMyReports(cursor: cursor, limit: limit);
}
