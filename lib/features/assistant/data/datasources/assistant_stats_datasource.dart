// lib/features/assistant/data/datasources/assistant_stats_datasource.dart
//
// Phase 28 (WS-6) — smart search assistant: the sole Supabase touchpoint of
// the feature (Constitution IX: supabase types confined here). Calls the
// anonymous-accessible `market_area_stats` RPC, which aggregates APPROVED
// listings only.

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/area_stats_dto.dart';

@injectable
class AssistantStatsDatasource {
  AssistantStatsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Invokes `market_area_stats(p_governorate_id, p_property_type, p_city_id,
  /// p_purpose)` — one row per currency seen in the matching approved
  /// listings, ordered by listing_count DESC. Throws on transport/RPC errors;
  /// the repository is the silent-degrade boundary.
  Future<List<AreaStatsDto>> fetchAreaStats({
    required String governorateId,
    String? cityId,
    String? propertyType,
    String? purpose,
  }) async {
    final result = await _client.rpc(
      'market_area_stats',
      params: {
        'p_governorate_id': governorateId,
        'p_property_type': propertyType,
        'p_city_id': cityId,
        'p_purpose': purpose,
      },
    );
    final rows = result as List<dynamic>;
    return rows
        .map(
          (row) =>
              AreaStatsDto.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}
