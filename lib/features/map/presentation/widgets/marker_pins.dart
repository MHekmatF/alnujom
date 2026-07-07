// lib/features/map/presentation/widgets/marker_pins.dart
//
// Phase 15 Sub-Phase E (T049) — two marker pin widgets per FR-003a visual
// indicator + contracts/phase15-map-page-composition.md §Marker builder.
// Restyled in the Phase-33 royal-blue DS pass: pins + cluster badge now read
// the project colour/type/elevation tokens (AppColors / AppTextStyles /
// AppElevation) instead of the raw colorScheme/textTheme. No marker DATA or
// builder LOGIC changes — purely visual.
//
// Sizes are kept inline as `width`/`height` integer values (40/48) because
// flutter_map sizes the marker chrome at the parent layer and the child widget
// MUST render at the exact target pixel size.
//
// ExactMarkerPin    — solid 40×40 pin (`Icons.place`) for `is_approximate=false`.
// ApproximateMarkerPin — 48×48 with a translucent halo for `is_approximate=true`,
//                       so the visual is distinctive at all zoom levels per
//                       SC-008.
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/typography.dart';

class ExactMarkerPin extends StatelessWidget {
  const ExactMarkerPin({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Icon(
      Icons.place,
      size: 40,
      color: colors.primary,
      shadows: [
        Shadow(
          color: colors.scrim.withValues(alpha: 0.35),
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
    final colors = AppColors.of(context);
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
              color: colors.primary.withValues(alpha: 0.18),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          Icon(
            Icons.place_outlined,
            size: 32,
            color: colors.primary,
            shadows: [
              Shadow(
                color: colors.scrim.withValues(alpha: 0.35),
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
/// A DS royal-blue circular badge with the count centered — a brand-primary
/// fill ringed with [AppColors.onPrimary] so it reads as a single grouped
/// marker on both light and dark tiles.
class ClusterBadge extends StatelessWidget {
  const ClusterBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary,
        border: Border.all(color: colors.onPrimary, width: 2),
        // DS token lift so the badge reads as the same floating family as the
        // map controls/popover (replaces a one-off inline BoxShadow).
        boxShadow: elevation.level1,
      ),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: styles.labelMedium.copyWith(color: colors.onPrimary),
      ),
    );
  }
}
