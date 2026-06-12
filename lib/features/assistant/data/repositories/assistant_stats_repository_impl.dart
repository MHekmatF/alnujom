// lib/features/assistant/data/repositories/assistant_stats_repository_impl.dart
//
// Phase 28 (WS-6) — smart search assistant: concrete stats port. Silent
// degradation by contract — any datasource error (offline, RPC missing,
// malformed row) yields null and the brain falls back to the normal parse
// reply. Principle IX: no supabase import here; the datasource owns it.

import 'package:injectable/injectable.dart';

import '../../domain/entities/area_stats.dart';
import '../../domain/repositories/assistant_stats_repository.dart';
import '../datasources/assistant_stats_datasource.dart';

@LazySingleton(as: AssistantStatsRepository)
class AssistantStatsRepositoryImpl implements AssistantStatsRepository {
  AssistantStatsRepositoryImpl(this._datasource);

  final AssistantStatsDatasource _datasource;

  @override
  Future<AreaStats?> fetchAreaStats({
    required String governorateId,
    String? cityId,
    String? propertyType,
    String? purpose,
  }) async {
    try {
      final rows = await _datasource.fetchAreaStats(
        governorateId: governorateId,
        cityId: cityId,
        propertyType: propertyType,
        purpose: purpose,
      );
      if (rows.isEmpty) return null;
      // Rows arrive ordered by listing_count DESC — the first row is the
      // dominant currency for the area (the only one worth quoting).
      return rows.first.toEntity();
    } catch (_) {
      return null;
    }
  }
}
