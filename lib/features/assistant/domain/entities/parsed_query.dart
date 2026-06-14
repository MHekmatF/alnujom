// lib/features/assistant/domain/entities/parsed_query.dart
//
// Phase 28 (WS-6) — smart search assistant: the deterministic parser's output.
// A [ParsedQuery] is the bridge between free-form natural language and the
// existing structured [FilterState]: whatever dimensions the rule-based parser
// recognized are populated on [filters], and each recognized span of the
// user's own words is kept as a [MatchedFragment] so the UI can render
// "here's what I understood" chips verbatim (language-neutral by construction
// — the chips echo the user's words back, no extra l10n needed).

import 'package:equatable/equatable.dart';

import '../../../locations/domain/entities/governorate.dart';
import '../../../search/domain/entities/filter_state.dart';

/// Which filter dimension a matched fragment belongs to — drives the chip
/// icon in the assistant reply bubble.
enum AssistantFragmentKind {
  propertyType,
  purpose,
  location,

  /// Phase 031 (WS-D) — a matched CITY span (distinct from [location], which is
  /// the governorate). Renders with a different icon in the reply bubble.
  city,

  /// Phase 031 (WS-D) — a matched AREA / neighborhood span.
  area,
  price,
  rooms,
  bathrooms,
  currency,

  /// Phase 031 (WS-D) — a matched area-size (m²) span, e.g. "مساحه 150 متر".
  areaSize,

  /// Phase 031 (WS-D) — a matched amenity / feature span (furnished, parking,
  /// garden, elevator, …). The chip text echoes the user's own word.
  amenity,
}

/// One recognized span of the user's input (already normalized), tagged with
/// the filter dimension it mapped to.
class MatchedFragment extends Equatable {
  const MatchedFragment(this.kind, this.text);

  final AssistantFragmentKind kind;

  /// The user's own (normalized) words for this dimension, e.g. "شقه",
  /// "تحت 500 مليون", "aleppo". Shown verbatim as a chip.
  final String text;

  @override
  List<Object?> get props => [kind, text];
}

/// The full parse result: structured filters + provenance + intent flags.
class ParsedQuery extends Equatable {
  const ParsedQuery({
    required this.filters,
    required this.fragments,
    required this.confidence,
    required this.statsIntent,
    this.governorate,
  });

  /// Nothing recognized.
  static const empty = ParsedQuery(
    filters: FilterState.empty,
    fragments: [],
    confidence: 0,
    statsIntent: false,
  );

  /// The existing search [FilterState], populated with whatever matched
  /// (purpose / propertyType / governorateId / price bounds + currency /
  /// rooms / bathrooms). The free-text `query` field is deliberately left
  /// null: the structured dimensions already encode the intent, and feeding
  /// the raw sentence into the title search would over-constrain results.
  final FilterState filters;

  /// Recognized input spans, in canonical display order (type, purpose,
  /// location, rooms, bathrooms, price, currency).
  final List<MatchedFragment> fragments;

  /// Heuristic 0..1 — grows with the number of recognized dimensions. Not a
  /// probability; only used to soften copy choices, never to gate behavior.
  final double confidence;

  /// True when the sentence reads like a market-stats question ("متوسط
  /// أسعار حلب", "how much does ... cost"). The brain answers these with the
  /// `market_area_stats` RPC when a governorate also matched.
  final bool statsIntent;

  /// The resolved governorate entity (when one matched) so the UI can render
  /// its locale-correct display name without another lookup.
  final Governorate? governorate;

  bool get hasAnyFilter => !filters.isEmpty;

  @override
  List<Object?> get props => [
    filters,
    fragments,
    confidence,
    statsIntent,
    governorate,
  ];
}
