import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
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
    // "Featured / مميّز" is the premium tier signal — a SOLID gold pill with
    // dark ink + a soft lift, so it reads as a badge of value over photos and
    // in lists alike. Every other variant stays a soft tinted chip.
    final isFeatured = variant == AppBadgeVariant.featured;
    final color = switch (variant) {
      AppBadgeVariant.featured => colors.tertiary,
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
    // Gold fails contrast as text/icon on white, so the featured pill flips to
    // a constant dark ink (colorScheme.onTertiary) on the gold fill.
    final foreground = isFeatured
        ? Theme.of(context).colorScheme.onTertiary
        : color;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isFeatured ? color : color.withAlpha(0x24),
        borderRadius: appRadius(AppRadii.pill),
        border: isFeatured ? null : Border.all(color: color),
        boxShadow: isFeatured ? AppElevation.of(context).level1 : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: AppSpacing.lg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: styles.labelMedium.copyWith(
              color: foreground,
              fontWeight: isFeatured ? FontWeight.w800 : null,
            ),
          ),
        ],
      ),
    );
  }
}
