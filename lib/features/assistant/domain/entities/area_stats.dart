// lib/features/assistant/domain/entities/area_stats.dart
//
// Phase 28 (WS-6) — smart search assistant: aggregate market stats for one
// area + currency, as returned by the `market_area_stats` RPC (one row per
// currency; the repository picks the dominant one).

import 'package:equatable/equatable.dart';

class AreaStats extends Equatable {
  const AreaStats({
    required this.currencyCode,
    required this.listingCount,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
  });

  final String currencyCode;
  final int listingCount;
  final double avgPrice;
  final double minPrice;
  final double maxPrice;

  @override
  List<Object?> get props => [
    currencyCode,
    listingCount,
    avgPrice,
    minPrice,
    maxPrice,
  ];
}
