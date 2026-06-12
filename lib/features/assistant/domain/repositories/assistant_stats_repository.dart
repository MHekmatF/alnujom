// lib/features/assistant/domain/repositories/assistant_stats_repository.dart
//
// Phase 28 (WS-6) — smart search assistant: market-stats port. Errors degrade
// SILENTLY (null) by contract — a stats failure must never break the normal
// parse reply, so there is no Result/Failure channel here on purpose.

import '../entities/area_stats.dart';

abstract class AssistantStatsRepository {
  /// Aggregate price stats for one governorate (optionally narrowed by city /
  /// property type / purpose). Returns the dominant-currency row, or null on
  /// ANY failure or when no approved listings match.
  Future<AreaStats?> fetchAreaStats({
    required String governorateId,
    String? cityId,
    String? propertyType,
    String? purpose,
  });
}
