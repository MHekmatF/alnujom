// Phase 29 (029-crm-reels-growth) — W2: admin analytics cubit.
// Loads the four chart series concurrently and folds them into one payload.
// load() and refresh() share one code path; refresh() keeps prior figures
// visible (no skeleton) until the new ones arrive. A transport failure on any
// series fails the surface (retry). Permission gaps are NOT failures — the RPCs
// return zero rows, so those series come back empty and render an empty hint.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../domain/entities/admin_analytics.dart';
import '../../domain/repositories/admin_analytics_repository.dart';
import 'admin_analytics_state.dart';

@injectable
class AdminAnalyticsCubit extends Cubit<AdminAnalyticsState> {
  AdminAnalyticsCubit(this._repository)
    : super(const AdminAnalyticsLoading());

  final AdminAnalyticsRepository _repository;

  /// Trailing windows for the time-series charts.
  static const int monthsWindow = 6;
  static const int daysWindow = 30;

  /// Loads all series on first entry (skeletons while in-flight).
  Future<void> load() => _fetch();

  /// Pull-to-refresh: re-fetches without resetting to the loading skeleton.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final results = await Future.wait([
      _repository.fetchListingsByMonth(months: monthsWindow),
      _repository.fetchProfilesByMonth(months: monthsWindow),
      _repository.fetchLeadEventsByDay(days: daysWindow),
      _repository.fetchListingsByGovernorate(),
    ]);
    if (isClosed) return;

    final listingsResult = results[0] as Result<List<AdminMonthlyTotal>>;
    final profilesResult = results[1] as Result<List<AdminMonthlyTotal>>;
    final leadsResult = results[2] as Result<List<AdminDailyTotal>>;
    final govResult = results[3] as Result<List<AdminGovernorateTotal>>;

    // Surface the first transport failure (a failing RPC fails the surface).
    for (final r in results) {
      if (r case FailureResult(:final failure)) {
        emit(AdminAnalyticsError(failure.message));
        return;
      }
    }

    emit(
      AdminAnalyticsLoaded(
        AdminAnalytics(
          listingsByMonth:
              (listingsResult as Success<List<AdminMonthlyTotal>>).value,
          profilesByMonth:
              (profilesResult as Success<List<AdminMonthlyTotal>>).value,
          leadEventsByDay:
              (leadsResult as Success<List<AdminDailyTotal>>).value,
          listingsByGovernorate:
              (govResult as Success<List<AdminGovernorateTotal>>).value,
        ),
      ),
    );
  }
}
