import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/city_with_area_count.dart';
import 'hidden_badge.dart';
import 'system_row_badge.dart';

enum _CardAction { edit, toggleActive, delete }

/// Branded city row — tinted-circle glyph + name/area-count on a hairline
/// surface (replaces the stock [Card]+[ListTile]).
class CityCard extends StatelessWidget {
  const CityCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    this.onDelete,
  });

  final CityWithAreaCount summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final city = summary.city;

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xxl + AppSpacing.lg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.building_2,
                color: colors.primary,
                size: AppSpacing.xl,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(city.localizedName(locale), style: styles.bodyLarge),
                      if (city.isSystem) const SystemRowBadge(),
                      if (!city.isActive) const HiddenBadge(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.subtitleAreaCount(summary.areaCount),
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_CardAction>(
              icon: Icon(
                LucideIcons.ellipsis_vertical,
                color: colors.textMuted,
              ),
              // Batch-2: token popup surface + radius, matching the DS
              // ListingViewModeSwitcher menu (was the bare Material default).
              position: PopupMenuPosition.under,
              color: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: appRadius(AppRadii.lg),
                side: BorderSide(color: colors.outline),
              ),
              onSelected: (action) => switch (action) {
                _CardAction.edit => onEdit(),
                _CardAction.toggleActive => onToggleActive(),
                _CardAction.delete => onDelete?.call(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CardAction.edit,
                  child: Text(l10n.editAffordance),
                ),
                PopupMenuItem(
                  value: _CardAction.toggleActive,
                  child: Text(
                    city.isActive ? l10n.actionDeactivate : l10n.actionActivate,
                  ),
                ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text(l10n.deleteAffordance),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
