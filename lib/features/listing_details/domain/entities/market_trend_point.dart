import 'package:equatable/equatable.dart';

/// Spec 028 — one monthly bucket of the market price trend for the listing's
/// area: the average primary asking price (in [currencyCode]) over
/// [listingCount] listings published in [month].
///
/// Produced by the `market_price_trend` RPC, which only ever returns
/// k-anonymous aggregates (every bucket covers >= 2 listings).
class MarketTrendPoint extends Equatable {
  const MarketTrendPoint({
    required this.month,
    required this.currencyCode,
    required this.avgPrice,
    required this.listingCount,
  });

  /// First day of the bucket's calendar month.
  final DateTime month;

  /// ISO currency code of the bucket (e.g. 'USD', 'SYP'). Buckets are grouped
  /// per currency — the chart filters to the listing's own primary currency.
  final String currencyCode;

  /// Average primary asking price across the bucket's listings.
  final num avgPrice;

  /// How many listings the bucket aggregates (always >= 2 — k-anonymity).
  final int listingCount;

  @override
  List<Object?> get props => [month, currencyCode, avgPrice, listingCount];
}
