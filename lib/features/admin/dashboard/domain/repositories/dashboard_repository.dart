// Phase 20 (spec/020-admin-dashboard) — T013
// DashboardRepository: abstract repository interface for the dashboard feature.
// Constitution IX: pure Dart, no Supabase import.
import '../../../../../core/errors/result.dart';
import '../entities/dashboard_counts.dart';

abstract class DashboardRepository {
  Future<Result<DashboardCounts>> fetchCounts();
}
