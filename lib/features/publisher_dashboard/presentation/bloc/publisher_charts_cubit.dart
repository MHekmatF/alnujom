// Phase 29 (029-crm-reels-growth) — W2: publisher dashboard charts cubit.
// Loads the three additive chart series concurrently (leads/day, inquiries/day,
// viewings-by-status) and folds them into one payload. load() and refresh()
// share one code path; refresh() keeps prior figures visible (no skeleton)
// until the new ones arrive. Injects the analytics repository directly (same
// pattern as MarketInsightsCubit) — no extra use-case classes needed.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/publisher_lead_analytics.dart';
import '../../domain/repositories/publisher_analytics_repository.dart';
import 'publisher_charts_state.dart';

@injectable
class PublisherChartsCubit extends Cubit<PublisherChartsState> {
  PublisherChartsCubit(this._repository)
    : super(const PublisherChartsLoading());

  final PublisherAnalyticsRepository _repository;

  /// Trailing window for the daily trend bar charts.
  static const int windowDays = 30;

  Future<void> load() => _fetch();

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final results = await Future.wait([
      _repository.fetchDailyTotals(days: windowDays),
      _repository.fetchDailyInquiries(days: windowDays),
      _repository.fetchViewingsByStatus(),
    ]);
    if (isClosed) return;

    final leadsResult = results[0] as Result<List<PublisherDailyLeadTotal>>;
    final inquiriesResult = results[1] as Result<List<PublisherDailyLeadTotal>>;
    final viewingsResult = results[2] as Result<List<PublisherStatusTotal>>;

    for (final r in results) {
      if (r case FailureResult(:final failure)) {
        emit(PublisherChartsError(failure.message));
        return;
      }
    }

    emit(
      PublisherChartsLoaded(
        leadsByDay:
            (leadsResult as Success<List<PublisherDailyLeadTotal>>).value,
        inquiriesByDay:
            (inquiriesResult as Success<List<PublisherDailyLeadTotal>>).value,
        viewingsByStatus:
            (viewingsResult as Success<List<PublisherStatusTotal>>).value,
      ),
    );
  }
}
