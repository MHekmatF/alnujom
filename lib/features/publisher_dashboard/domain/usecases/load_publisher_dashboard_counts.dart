// Phase 25 premium uplift v2 — publisher summary dashboard.
// LoadPublisherDashboardCounts use-case: single RPC call, no pagination.
// Constitution IX: pure Dart, no Supabase import.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/publisher_dashboard_counts.dart';
import '../repositories/publisher_dashboard_counts_repository.dart';

@injectable
class LoadPublisherDashboardCounts {
  LoadPublisherDashboardCounts(this._repository);

  final PublisherDashboardCountsRepository _repository;

  Future<Result<PublisherDashboardCounts>> call() {
    return _repository.fetchCounts();
  }
}
