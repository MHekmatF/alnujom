// lib/features/map/presentation/widgets/osm_attribution_widget.dart
//
// Phase 15 Sub-Phase E (T046) — OSM tile-provider attribution per
// contracts/phase15-map-page-composition.md §Attribution widget. Always
// visible at the bottom-start of the map overlay (FR-008, SC-007).
// Restyled in the Phase-33 royal-blue DS pass to read the colour/type tokens
// (AppColors / AppTextStyles) directly.
//
// FR-019 / R-94 compliance: OSMF public-tile policy requires visible
// attribution on every map surface.
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

class OsmAttributionWidget extends StatelessWidget {
  const OsmAttributionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        // Theme-aware translucent surface so the text reads on both light
        // and dark OSM tile palettes.
        color: colors.surface.withValues(alpha: 0.85),
        borderRadius: appRadius(AppRadii.sm),
        border: Border.all(color: colors.outline),
      ),
      child: Text(
        l10n.map_osm_attribution,
        style: styles.labelMedium.copyWith(color: colors.onSurface),
      ),
    );
  }
}
