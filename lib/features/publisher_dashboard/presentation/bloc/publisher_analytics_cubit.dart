// Phase 25 premium uplift v2 — publisher lead analytics.
// PublisherAnalyticsCubit: loads the daily lead trend + per-listing breakdown
// (the two SECURITY DEFINER RPCs) concurrently and folds them into one payload.
// load() and refresh() share one code path; refresh() keeps prior figures
// visible (no skeleton) until the new ones arrive. Mirrors the counts cubit's
// shape minus the Realtime channel (analytics is a pull-to-refresh surface).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/publisher_lead_analytics.dart';
import '../../domain/usecases/load_publisher_daily_lead_totals.dart';
import '../../domain/usecases/load_publisher_listing_breakdown.dart';
import 'publisher_analytics_state.dart';

@injectable
class PublisherAnalyticsCubit extends Cubit<PublisherAnalyticsState> {
  PublisherAnalyticsCubit(this._loadDailyTotals, this._loadBreakdown)
    : super(const PublisherAnalyticsLoading());

  final LoadPublisherDailyLeadTotals _loadDailyTotals;
  final LoadPublisherListingBreakdown _loadBreakdown;

  /// Trailing window for the daily trend bar chart.
  static const int windowDays = 30;

  /// Loads both RPCs on first entry (skeletons while in-flight).
  Future<void> load() => _fetch();

  /// Pull-to-refresh: re-fetches without resetting to the loading skeleton so
  /// the previous figures stay visible until the new ones arrive.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    // Both RPCs are independent → fire concurrently.
    final results = await Future.wait([
      _loadDailyTotals(days: windowDays),
      _loadBreakdown(),
    ]);
    if (isClosed) return;

    final dailyResult =
        results[0] as Result<List<PublisherDailyLeadTotal>>;
    final breakdownResult =
        results[1] as Result<List<PublisherListingLeadAnalytics>>;

    // Surface the first failure (either RPC failing fails the whole surface).
    if (dailyResult case FailureResult(:final failure)) {
      emit(PublisherAnalyticsError(failure.message));
      return;
    }
    if (breakdownResult case FailureResult(:final failure)) {
      emit(PublisherAnalyticsError(failure.message));
      return;
    }

    final byDay = (dailyResult as Success<List<PublisherDailyLeadTotal>>).value;
    final byListing =
        (breakdownResult as Success<List<PublisherListingLeadAnalytics>>).value;

    emit(
      PublisherAnalyticsLoaded(
        PublisherLeadAnalytics(byDay: byDay, byListing: byListing),
      ),
    );
  }
}
