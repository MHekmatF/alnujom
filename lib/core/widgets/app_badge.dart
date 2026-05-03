import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

enum AppBadgeVariant {
  featured,
  fresh,
  statusPending,
  statusApproved,
  statusRejected,
  verifiedOffice,
}

class AppBadge extends StatelessWidget {
  const AppBadge({required this.label, required this.variant, super.key});

  final String label;
  final AppBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final color = switch (variant) {
      AppBadgeVariant.featured => colors.warning,
      AppBadgeVariant.fresh => colors.accent,
      AppBadgeVariant.statusPending => colors.warning,
      AppBadgeVariant.statusApproved => colors.success,
      AppBadgeVariant.statusRejected => colors.error,
      AppBadgeVariant.verifiedOffice => colors.primary,
    };
    final icon = switch (variant) {
      AppBadgeVariant.featured => LucideIcons.star,
      AppBadgeVariant.fresh => LucideIcons.sparkles,
      AppBadgeVariant.statusPending => LucideIcons.clock,
      AppBadgeVariant.statusApproved => LucideIcons.circle_check,
      AppBadgeVariant.statusRejected => LucideIcons.circle_x,
      AppBadgeVariant.verifiedOffice => LucideIcons.badge_check,
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x24),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppSpacing.lg),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: styles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
