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

/// Phase 32 redesign — the listing-detail key-facts grid, rebuilt to the Al
/// Nujom Design System "facts" block: compact **vertical tiles laid out 4-up**,
/// each a soft card (card colour, hairline outline, [AppRadii.lg], level-1
/// shadow) carrying a rounded-square tinted icon chip on top, then the bold
/// [value] and the muted [label] beneath. Falls back to fewer columns when the
/// width is too tight for four. Renders nothing when [items] is empty. RTL-safe.
class FactsGrid extends StatelessWidget {
  const FactsGrid({required this.items, super.key});

  final List<FactItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        // Target the DS 4-up grid, but never let a tile get narrower than ~76dp
        // (Arabic labels need the room) — drop to 3 then 2 columns on tight
        // widths / large text scales.
        var columns = 4;
        while (columns > 2 &&
            (constraints.maxWidth - gap * (columns - 1)) / columns < 76) {
          columns--;
        }
        // Don't leave a single orphan tile on its own row when it would look
        // lonely (e.g. 5 items at 4-up → use 3-up so rows read 3 + 2).
        if (items.length == columns + 1 && columns > 2) columns--;

        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: tileWidth, child: _FactTile(item: item)),
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
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FactIcon(icon: item.icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.titleMedium.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.labelMedium.copyWith(color: colors.textMuted),
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
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Icon(icon, size: AppSpacing.lg, color: colors.primary),
    );
  }
}
