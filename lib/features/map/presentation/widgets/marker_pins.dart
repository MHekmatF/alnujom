// lib/features/map/presentation/widgets/marker_pins.dart
//
// Phase 15 Sub-Phase E (T049) — two marker pin widgets per FR-003a visual
// indicator + contracts/phase15-map-page-composition.md §Marker builder.
//
// Both use Phase 2 design tokens (`Theme.colorScheme.primary`); no hex
// literals. Sizes are kept inline as `width`/`height` integer values (40/48)
// because flutter_map sizes the marker chrome at the parent layer and the
// child widget MUST render at the exact target pixel size.
//
// ExactMarkerPin    — solid 40×40 pin (`Icons.place`) for `is_approximate=false`.
// ApproximateMarkerPin — 48×48 with a translucent halo for `is_approximate=true`,
//                       so the visual is distinctive at all zoom levels per
//                       SC-008.
import 'package:flutter/material.dart';

class ExactMarkerPin extends StatelessWidget {
  const ExactMarkerPin({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.place,
      size: 40,
      color: scheme.primary,
      shadows: [
        Shadow(
          color: scheme.shadow.withValues(alpha: 0.35),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class ApproximateMarkerPin extends StatelessWidget {
  const ApproximateMarkerPin({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo: translucent ring sized to fill the bounds so the eye can
          // distinguish "approximate" from "exact" at a glance per FR-003a.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.18),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          Icon(
            Icons.place_outlined,
            size: 32,
            color: scheme.primary,
            shadows: [
              Shadow(
                color: scheme.shadow.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cluster badge rendered by [MarkerClusterLayerWidget.options.builder].
/// Sized 40×40 with the count centered, themed with [colorScheme.primary].
class ClusterBadge extends StatelessWidget {
  const ClusterBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        border: Border.all(color: scheme.onPrimary, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
