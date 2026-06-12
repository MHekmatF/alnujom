import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/market_trend_point.dart';
import '../../domain/repositories/market_insights_repository.dart';
import '../datasources/supabase_market_insights_datasource.dart';

/// Spec 028 — concrete [MarketInsightsRepository].
///
/// Maps `market_price_trend` RPC rows to [MarketTrendPoint]s. A network /
/// PostgREST failure surfaces as [NetworkFailure]; an empty trend is a
/// [Success] with an empty list (the section simply renders nothing).
@LazySingleton(as: MarketInsightsRepository)
class MarketInsightsRepositoryImpl implements MarketInsightsRepository {
  const MarketInsightsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'MarketInsightsRepositoryImpl';

  final SupabaseMarketInsightsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<List<MarketTrendPoint>>> fetchPriceTrend({
    required String governorateId,
    required String propertyType,
    String? cityId,
    String? purpose,
    int months = 6,
  }) async {
    try {
      final rows = await _datasource.fetchPriceTrend(
        governorateId: governorateId,
        propertyType: propertyType,
        cityId: cityId,
        purpose: purpose,
        months: months,
      );
      final points = rows.map(_toPoint).toList(growable: false);
      return Success(points);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchPriceTrend failed for governorate=$governorateId '
        'type=$propertyType',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }

  MarketTrendPoint _toPoint(Map<String, dynamic> row) {
    return MarketTrendPoint(
      month: DateTime.parse(row['month'] as String),
      currencyCode: row['currency_code'] as String,
      avgPrice: _asNum(row['avg_price']),
      listingCount: _asNum(row['listing_count']).toInt(),
    );
  }

  /// PostgREST serializes `numeric` as a JSON number in most paths but can
  /// fall back to a string for high-precision values — accept both.
  num _asNum(Object? value) =>
      value is num ? value : (num.tryParse(value?.toString() ?? '') ?? 0);
}
