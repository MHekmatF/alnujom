import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/role_with_counts.dart';

class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.role,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final RoleWithCounts role;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final localizedName = role.displayName[locale];
    final fallbackName = role.displayName['en'];
    final title = localizedName?.trim().isNotEmpty == true
        ? localizedName!
        : fallbackName?.trim().isNotEmpty == true
        ? fallbackName!
        : role.roleKey;

    return PressScale(
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: appRadius(AppRadii.lg),
          side: BorderSide(color: colors.outline),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          borderRadius: appRadius(AppRadii.lg),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
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
                    LucideIcons.shield,
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.rolePermissionsCount(role.permissionCount),
                            style: styles.bodyMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          Icon(
                            LucideIcons.users,
                            size: AppSpacing.lg,
                            color: colors.textMuted,
                          ),
                          Text(
                            role.userCount.toString(),
                            style: styles.bodyMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (role.isSystem)
                  _SystemPill(label: l10n.roleBadgeSystem)
                else
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.chevron_left
                        : LucideIcons.chevron_right,
                    size: AppSpacing.xl,
                    color: colors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft tinted "system role" pill (replaces the stock Material [Chip]).
class _SystemPill extends StatelessWidget {
  const _SystemPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.outline),
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(color: colors.textMuted),
      ),
    );
  }
}
