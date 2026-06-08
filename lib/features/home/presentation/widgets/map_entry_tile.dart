// lib/features/home/presentation/widgets/map_entry_tile.dart
//
// Phase 15 Sub-Phase G1 — home-shell map entry point per
// contracts/phase15-home-map-tile.md (R-91 slot: between PropertyTypeShortcutRow
// and the Latest Listings header).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../features/map/domain/entities/map_entry_context.dart';
import '../../../../l10n/app_localizations.dart';

/// Card-styled tappable tile that navigates to the MapPage with a
/// [MapEntryFromHome] context.
///
/// Phase 25 (Claude Design) — a distinct primary-tinted "browse on map" card
/// with a warm accent pin. Inserted between [PropertyTypeShortcutRow] and the
/// "Latest listings" header sliver per R-91. Directionally-aware chevron.
class MapEntryTile extends StatelessWidget {
  const MapEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: PressScale(
        child: Material(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.go(AppRoutes.map, extra: const MapEntryFromHome());
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Soft accent disc so the pin reads as a deliberate
                  // affordance, not a floating glyph.
                  Container(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.accentContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      size: 28,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.home_map_tile_title,
                          style: styles.titleMedium.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.home_map_tile_subtitle,
                          style: styles.bodyMedium.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_ios
                        : Icons.arrow_forward_ios,
                    size: 16,
                    color: colors.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
