import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/area.dart';
import 'hidden_badge.dart';

enum _CardAction { edit, toggleActive, delete }

/// Branded area row — tinted-circle glyph + name/description on a hairline
/// surface (replaces the stock [Card]+[ListTile]).
class AreaCard extends StatelessWidget {
  const AreaCard({
    super.key,
    required this.area,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Area area;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final description = area.description?[locale.languageCode];

    return AppSurface(
      radius: AppRadii.lg,
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
              LucideIcons.map_pin,
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
                Text(
                  area.localizedName(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.bodyLarge,
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (!area.isActive) ...[
            const SizedBox(width: AppSpacing.sm),
            const HiddenBadge(),
          ],
          PopupMenuButton<_CardAction>(
            icon: Icon(LucideIcons.ellipsis_vertical, color: colors.textMuted),
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
              _CardAction.delete => onDelete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _CardAction.edit,
                child: Text(l10n.editAffordance),
              ),
              PopupMenuItem(
                value: _CardAction.toggleActive,
                child: Text(
                  area.isActive ? l10n.actionDeactivate : l10n.actionActivate,
                ),
              ),
              PopupMenuItem(
                value: _CardAction.delete,
                child: Text(l10n.deleteAffordance),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
