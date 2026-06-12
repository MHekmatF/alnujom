// lib/features/assistant/domain/assistant_brain.dart
//
// Phase 28 (WS-6) — smart search assistant: the "brain" seam.
//
// ┌─ SWAPPABLE-BRAIN ARCHITECTURE ─────────────────────────────────────────┐
// │ [AssistantBrain] is the ONLY contract the presentation layer knows:    │
// │ free-form text in → structured [AssistantReply] out. Today the bound   │
// │ implementation is [RuleBasedAssistantBrain] — a deterministic keyword  │
// │ parser with ZERO network/LLM cost. To upgrade to an LLM later, ship a  │
// │ new `LlmAssistantBrain implements AssistantBrain` (e.g. an Edge        │
// │ Function that returns the same FilterState JSON), swap the @Injectable │
// │ binding, and NOTHING else changes — the cubit, the page, the chips and │
// │ the "Show results" routing all consume the same structured reply.      │
// └────────────────────────────────────────────────────────────────────────┘

import 'package:injectable/injectable.dart';

import '../../listing_form/domain/entities/listing.dart';
import '../../locations/domain/entities/governorate.dart';
import '../../locations/domain/usecases/list_governorates.dart';
import 'entities/assistant_message.dart';
import 'query_parser.dart';
import 'repositories/assistant_stats_repository.dart';

/// Text in → structured reply out. See the swappable-brain note above.
abstract class AssistantBrain {
  Future<AssistantReply> handle(String input);
}

/// Deterministic, on-device implementation: pure-Dart parsing against the
/// keyword tables + the runtime governorate list, with ONE optional Supabase
/// RPC (`market_area_stats`) for stats-flavored questions. Works fully
/// offline except for that stats path, which degrades silently.
@Injectable(as: AssistantBrain)
class RuleBasedAssistantBrain implements AssistantBrain {
  RuleBasedAssistantBrain(this._parser, this._listGovernorates, this._stats);

  final QueryParser _parser;
  final ListGovernorates _listGovernorates;
  final AssistantStatsRepository _stats;

  /// Session cache — governorates are small and effectively static. Cities
  /// are NOT matched at this stage: there is no cheap "list ALL cities"
  /// usecase (the existing ones are per-governorate), so location matching
  /// is governorate-granular for now. The parser API already carries
  /// `filters.cityId` so a city table can slot in without contract changes.
  List<Governorate>? _governoratesCache;

  @override
  Future<AssistantReply> handle(String input) async {
    final governorates = await _governorates();
    final parsed = _parser.parse(input, governorates: governorates);

    // Stats-flavored question with a recognized area → try the market RPC.
    // Any failure (offline, RPC missing, empty area) falls through to the
    // normal parse reply — never an error bubble.
    if (parsed.statsIntent && parsed.governorate != null) {
      final stats = await _stats.fetchAreaStats(
        governorateId: parsed.governorate!.id,
        cityId: parsed.filters.cityId,
        propertyType: parsed.filters.propertyType?.toDbValue(),
        purpose: parsed.filters.purpose?.toDbValue(),
      );
      if (stats != null && stats.listingCount > 0) {
        return AssistantReply(
          kind: AssistantReplyKind.stats,
          parsed: parsed,
          stats: stats,
        );
      }
    }

    if (parsed.fragments.isEmpty) {
      return const AssistantReply(kind: AssistantReplyKind.noMatch);
    }
    return AssistantReply(kind: AssistantReplyKind.parsed, parsed: parsed);
  }

  Future<List<Governorate>> _governorates() async {
    final cached = _governoratesCache;
    if (cached != null) return cached;
    try {
      final withCounts = await _listGovernorates(includeInactive: false);
      return _governoratesCache = withCounts
          .map((g) => g.governorate)
          .toList(growable: false);
    } catch (_) {
      // Offline / fetch failure: parsing still works, just without location
      // matching. Not cached so the next message retries.
      return const [];
    }
  }
}
