// Phase 25 premium uplift v2 — publisher lead analytics.
// PublisherAnalyticsRepositoryImpl: one method per RPC. The daily-totals path
// gap-fills the trend (the RPC omits zero days) so the bar chart has one bar per
// calendar day. Mirrors the counts repo wiring. Constitution IX: only imports
// the datasource + domain.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/publisher_lead_analytics.dart';
import '../../domain/repositories/publisher_analytics_repository.dart';
import '../datasources/publisher_analytics_datasource.dart';

@LazySingleton(as: PublisherAnalyticsRepository)
class PublisherAnalyticsRepositoryImpl implements PublisherAnalyticsRepository {
  PublisherAnalyticsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'PublisherAnalyticsRepositoryImpl';

  final PublisherAnalyticsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<PublisherListingLeadAnalytics>>>
  fetchListingBreakdown() async {
    try {
      final dtos = await _datasource.fetchByListing();
      final entities = dtos
          .map((dto) => dto.toEntity())
          .toList(growable: false);
      return Success(entities);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchListingBreakdown failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<List<PublisherDailyLeadTotal>>> fetchDailyTotals({
    int days = 30,
  }) async {
    try {
      final dtos = await _datasource.fetchTotalsByDay(days: days);
      final sparse = <String, int>{};
      for (final dto in dtos) {
        final point = dto.toEntity();
        sparse[_dateKey(point.day)] = point.total;
      }
      return Success(_gapFill(sparse: sparse, days: days));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchDailyTotals failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  /// Produces one [PublisherDailyLeadTotal] per calendar day across the trailing
  /// [days]-day window (oldest → newest, ending today), pulling totals from the
  /// [sparse] map and defaulting absent days to 0.
  List<PublisherDailyLeadTotal> _gapFill({
    required Map<String, int> sparse,
    required int days,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final span = days < 1 ? 1 : days;
    final out = <PublisherDailyLeadTotal>[];
    // Window is the trailing [span] days inclusive of today.
    for (var offset = span - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      out.add(
        PublisherDailyLeadTotal(day: day, total: sparse[_dateKey(day)] ?? 0),
      );
    }
    return out;
  }

  /// A stable yyyy-mm-dd key for matching sparse RPC days to the filled window.
  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
