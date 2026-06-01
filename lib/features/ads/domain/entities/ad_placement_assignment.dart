// Phase 21 (spec/021-ads-banners) — AdPlacementAssignment entity.
//
// Represents one row from `public.ad_placements` (ad_id, placement_key, priority).
// Embedded in [Ad.placements] — the list of placements an ad is assigned to.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:equatable/equatable.dart';

import 'ad_placement.dart';

/// Assignment of an [Ad] to a placement slot with a carousel priority.
///
/// Priority controls ordering within a placement's carousel (higher = shown
/// first; tie-break by `created_at DESC` at the data layer).
class AdPlacementAssignment extends Equatable {
  const AdPlacementAssignment({
    required this.placement,
    required this.priority,
  });

  final AdPlacement placement;

  /// Carousel priority within this placement (higher → earlier). Default 0.
  final int priority;

  @override
  List<Object?> get props => [placement, priority];
}
