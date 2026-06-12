// lib/features/assistant/data/dtos/area_stats_dto.dart
//
// Phase 28 (WS-6) — smart search assistant: wire DTO for one
// `market_area_stats` RPC row:
//   RETURNS TABLE(currency_code text, listing_count bigint,
//                 avg_price numeric, min_price numeric, max_price numeric)

import '../../domain/entities/area_stats.dart';

class AreaStatsDto {
  const AreaStatsDto({
    required this.currencyCode,
    required this.listingCount,
    required this.avgPrice,
    required this.minPrice,
    required this.maxPrice,
  });

  factory AreaStatsDto.fromJson(Map<String, dynamic> json) {
    double readDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return AreaStatsDto(
      currencyCode: json['currency_code'] as String? ?? '',
      listingCount: (json['listing_count'] as num?)?.toInt() ?? 0,
      avgPrice: readDouble(json['avg_price']),
      minPrice: readDouble(json['min_price']),
      maxPrice: readDouble(json['max_price']),
    );
  }

  final String currencyCode;
  final int listingCount;
  final double avgPrice;
  final double minPrice;
  final double maxPrice;

  AreaStats toEntity() => AreaStats(
    currencyCode: currencyCode,
    listingCount: listingCount,
    avgPrice: avgPrice,
    minPrice: minPrice,
    maxPrice: maxPrice,
  );
}
