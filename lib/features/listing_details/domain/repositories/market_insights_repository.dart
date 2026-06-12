import '../../../../core/errors/result.dart';
import '../entities/market_trend_point.dart';

/// Spec 028 — abstract repository for the listing-details "Market insights"
/// section.
///
/// Returns the monthly average asking-price trend for the listing's
/// governorate + property type (optionally narrowed by city / purpose) across
/// all currencies; the presentation layer filters to the listing's own primary
/// currency. The backing RPC only emits k-anonymous monthly aggregates.
abstract class MarketInsightsRepository {
  Future<Result<List<MarketTrendPoint>>> fetchPriceTrend({
    required String governorateId,
    required String propertyType,
    String? cityId,
    String? purpose,
    int months,
  });
}
