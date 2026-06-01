// Phase 20 (spec/020-admin-dashboard) — T014
// LoadDashboardCounts use-case: single RPC call, no pagination, no Timer.
// Constitution IX: pure Dart, no Supabase import.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/dashboard_counts.dart';
import '../repositories/dashboard_repository.dart';

@injectable
class LoadDashboardCounts {
  LoadDashboardCounts(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardCounts>> call() {
    return _repository.fetchCounts();
  }
}
