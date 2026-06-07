import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/gradients.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Phase 25 premium uplift — a single KPI stat card for dashboards.
///
/// A rounded [card]-coloured surface with a hairline outline and a soft
/// [AppElevation.level1] shadow, washed with a whisper-soft
/// [AppGradients.featuredTint]. The [icon] sits in a tinted circle (driven by
/// [accent], falling back to the brand primary), with the [value] rendered large
/// and the [label] muted beneath it.
///
/// RTL-safe (directional padding/alignment) and fills the available width. When
/// [onTap] is supplied the whole card becomes a tappable Material+InkWell with a
/// matching ripple radius. All display strings ([value], [label]) are provided
/// by the caller — this widget does no localization.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
    this.onTap,
    super.key,
  });

  /// Leading glyph shown inside the tinted circle.
  final IconData icon;

  /// The headline KPI figure (already formatted/localized by the caller).
  final String value;

  /// Caption beneath the value (already localized by the caller).
  final String label;

  /// Optional accent driving the icon circle + glyph. Defaults to the brand
  /// primary.
  final Color? accent;

  /// When non-null the whole card becomes tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final gradients = AppGradients.of(context);
    final tint = accent ?? colors.primary;

    final content = Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSpacing.xl, color: tint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.headlineMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: styles.labelMedium.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );

    // The whisper-soft brand wash sits behind the content; the outline + shadow
    // live on the outer decoration so the tint never bleeds past the radius.
    final tinted = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradients.featuredTint,
        borderRadius: appRadius(AppRadii.lg),
      ),
      child: content,
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
          boxShadow: elevation.level1,
        ),
        child: ClipRRect(
          borderRadius: appRadius(AppRadii.lg),
          child: tinted,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: appRadius(AppRadii.lg),
        boxShadow: elevation.level1,
      ),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: appRadius(AppRadii.lg),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: appRadius(AppRadii.lg),
          onTap: onTap,
          child: tinted,
        ),
      ),
    );
  }
}
