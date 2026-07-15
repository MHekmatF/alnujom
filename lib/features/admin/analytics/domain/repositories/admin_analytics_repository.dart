// Phase 29 (029-crm-reels-growth) — W2: admin analytics repository interface.
// Pure Dart (Constitution IX): no Supabase import. One method per chart series;
// the month/day series are gap-filled by the implementation so each chart has a
// continuous axis across its window.
import '../../../../../core/errors/result.dart';
import '../entities/admin_analytics.dart';

abstract class AdminAnalyticsRepository {
  /// Listings created per month over the trailing [months]-month window,
  /// gap-filled (one entry per month, oldest → newest).
  Future<Result<List<AdminMonthlyTotal>>> fetchListingsByMonth({int months = 6});

  /// Profiles created per month over the trailing [months]-month window,
  /// gap-filled (one entry per month, oldest → newest).
  Future<Result<List<AdminMonthlyTotal>>> fetchProfilesByMonth({int months = 6});

  /// Lead events per day over the trailing [days]-day window, gap-filled (one
  /// entry per calendar day, oldest → newest).
  Future<Result<List<AdminDailyTotal>>> fetchLeadEventsByDay({int days = 30});

  /// Active listings per governorate, busiest first (top 10), ordered as
  /// returned by the RPC.
  Future<Result<List<AdminGovernorateTotal>>> fetchListingsByGovernorate();

  /// Approved listings grouped by property type, busiest first.
  Future<Result<List<AdminCategoryTotal>>> fetchListingsByCategory();

  /// Lead-event activity cells (ISO day-of-week × 4-hour bucket) over the
  /// trailing [days]-day window; empty buckets omitted.
  Future<Result<List<AdminActivityCell>>> fetchActivityByDowHour({
    int days = 30,
  });
}
