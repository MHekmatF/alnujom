import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// A single key fact rendered inside a [FactsGrid] tile.
///
/// [icon] is a Lucide (or Material) glyph; [value] is the prominent figure
/// (e.g. the bedroom count, area, year); [label] is the muted caption beneath
/// it. The caller is responsible for localizing both strings.
@immutable
class FactItem {
  const FactItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

/// Phase 25 uplift — responsive key-facts grid for the listing-detail page.
///
/// Lays [items] out two-per-row on phones, each in a soft AppSurface-style tile
/// (card colour, hairline outline, [AppRadii.md], level-1 shadow) carrying a
/// tinted Lucide icon in a [primaryContainer] circle, the bold [value], and the
/// muted [label] caption. Renders nothing when [items] is empty. RTL-safe.
class FactsGrid extends StatelessWidget {
  const FactsGrid({required this.items, super.key});

  final List<FactItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones; the spacing between them is reclaimed so the
        // tiles split the available width evenly.
        const columns = 2;
        const gap = AppSpacing.md;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _FactTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.item});

  final FactItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.md),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _FactIcon(icon: item.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.titleMedium.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactIcon extends StatelessWidget {
  const _FactIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: AppSpacing.xxl,
      height: AppSpacing.xxl,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Icon(icon, size: AppSpacing.lg, color: colors.primary),
    );
  }
}
