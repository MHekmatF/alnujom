// lib/features/home/presentation/widgets/map_entry_tile.dart
//
// Phase 15 Sub-Phase G1 — home-shell map entry point per
// contracts/phase15-home-map-tile.md (R-91 slot: between PropertyTypeShortcutRow
// and the Latest Listings header).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../features/map/domain/entities/map_entry_context.dart';
import '../../../../l10n/app_localizations.dart';

/// Card-styled tappable tile that navigates to the MapPage with a
/// [MapEntryFromHome] context.
///
/// Inserted between [PropertyTypeShortcutRow] and the "Latest listings" header
/// sliver per R-91. Directionally-aware chevron per the contract.
class MapEntryTile extends StatelessWidget {
  const MapEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: InkWell(
          onTap: () => context.go(
            AppRoutes.map,
            extra: const MapEntryFromHome(),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.home_map_tile_title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.home_map_tile_subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_ios
                      : Icons.arrow_forward_ios,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
