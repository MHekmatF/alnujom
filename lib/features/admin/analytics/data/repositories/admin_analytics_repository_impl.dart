// Phase 29 (029-crm-reels-growth) — W2: admin analytics repository impl.
// One method per chart series. The month/day series gap-fill (the RPCs omit
// empty buckets) so each chart has a continuous axis. Constitution IX: only
// imports the datasource + domain.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../domain/entities/admin_analytics.dart';
import '../../domain/repositories/admin_analytics_repository.dart';
import '../datasources/admin_analytics_datasource.dart';

@LazySingleton(as: AdminAnalyticsRepository)
class AdminAnalyticsRepositoryImpl implements AdminAnalyticsRepository {
  AdminAnalyticsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'AdminAnalyticsRepositoryImpl';

  /// Per-series network cap. A single stalled RPC must not hang the whole
  /// analytics surface forever — on timeout the series fails to an empty/retry
  /// state instead of an indefinite blank skeleton.
  static const _rpcTimeout = Duration(seconds: 15);

  final AdminAnalyticsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<AdminMonthlyTotal>>> fetchListingsByMonth({
    int months = 6,
  }) async {
    try {
      final dtos = await _datasource
          .fetchListingsByMonth(months: months)
          .timeout(_rpcTimeout);
      final sparse = <String, int>{
        for (final dto in dtos) _monthKey(dto.month): dto.total,
      };
      return Success(_gapFillMonths(sparse: sparse, months: months));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchListingsByMonth failed.',
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
  Future<Result<List<AdminMonthlyTotal>>> fetchProfilesByMonth({
    int months = 6,
  }) async {
    try {
      final dtos = await _datasource
          .fetchProfilesByMonth(months: months)
          .timeout(_rpcTimeout);
      final sparse = <String, int>{
        for (final dto in dtos) _monthKey(dto.month): dto.total,
      };
      return Success(_gapFillMonths(sparse: sparse, months: months));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchProfilesByMonth failed.',
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
  Future<Result<List<AdminDailyTotal>>> fetchLeadEventsByDay({
    int days = 30,
  }) async {
    try {
      final dtos = await _datasource
          .fetchLeadEventsByDay(days: days)
          .timeout(_rpcTimeout);
      final sparse = <String, int>{
        for (final dto in dtos) _dateKey(dto.day): dto.total,
      };
      return Success(_gapFillDays(sparse: sparse, days: days));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchLeadEventsByDay failed.',
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
  Future<Result<List<AdminGovernorateTotal>>>
  fetchListingsByGovernorate() async {
    try {
      final dtos = await _datasource
          .fetchListingsByGovernorate()
          .timeout(_rpcTimeout);
      return Success(
        dtos.map((dto) => dto.toEntity()).toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchListingsByGovernorate failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  /// One [AdminMonthlyTotal] per calendar month across the trailing [months]
  /// window (oldest → newest, ending this month). Absent months default to 0.
  /// Returns empty when [sparse] is empty so the page can show an empty hint
  /// (an unpermitted admin gets zero rows, not a zeroed chart).
  List<AdminMonthlyTotal> _gapFillMonths({
    required Map<String, int> sparse,
    required int months,
  }) {
    if (sparse.isEmpty) return const [];
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final span = months < 1 ? 1 : months;
    final out = <AdminMonthlyTotal>[];
    for (var offset = span - 1; offset >= 0; offset--) {
      final month = DateTime(thisMonth.year, thisMonth.month - offset);
      out.add(
        AdminMonthlyTotal(month: month, total: sparse[_monthKey(month)] ?? 0),
      );
    }
    return out;
  }

  /// One [AdminDailyTotal] per calendar day across the trailing [days] window
  /// (oldest → newest, ending today). Absent days default to 0. Returns empty
  /// when [sparse] is empty (unpermitted / no data → empty hint).
  List<AdminDailyTotal> _gapFillDays({
    required Map<String, int> sparse,
    required int days,
  }) {
    if (sparse.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final span = days < 1 ? 1 : days;
    final out = <AdminDailyTotal>[];
    for (var offset = span - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      out.add(AdminDailyTotal(day: day, total: sparse[_dateKey(day)] ?? 0));
    }
    return out;
  }

  String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
