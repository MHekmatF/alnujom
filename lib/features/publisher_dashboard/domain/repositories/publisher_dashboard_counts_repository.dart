// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardCountsRepository: abstract interface for the summary KPIs.
// Constitution IX: pure Dart, no Supabase import.
import '../../../../core/errors/result.dart';
import '../entities/publisher_dashboard_counts.dart';

abstract class PublisherDashboardCountsRepository {
  Future<Result<PublisherDashboardCounts>> fetchCounts();
}
