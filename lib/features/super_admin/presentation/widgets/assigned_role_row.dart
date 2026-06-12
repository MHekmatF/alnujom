import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../domain/entities/role_assignment_summary.dart';

class AssignedRoleRow extends StatelessWidget {
  const AssignedRoleRow({
    required this.row,
    required this.showRemoveAffordance,
    required this.onRemove,
    super.key,
  });

  final RoleAssignmentSummary row;
  final bool showRemoveAffordance;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final title = row.displayName[locale]?.trim().isNotEmpty == true
        ? row.displayName[locale]!
        : row.displayName['en']?.trim().isNotEmpty == true
        ? row.displayName['en']!
        : row.roleKey;

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
              LucideIcons.shield_check,
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
                Text(
                  row.roleKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (showRemoveAffordance) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onRemove,
              icon: Icon(LucideIcons.circle_minus, color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
