import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../shared/util/localized_numbers.dart';
import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Phase 25 uplift — a tappable dashboard navigation tile.
///
/// A rounded card (card colour, hairline outline, [AppRadii.lg], level-1 depth)
/// with the [icon] in a tinted circle (tinted from [accent] ?? primary), the
/// [title] and optional [subtitle], an optional count [badgeCount] pill pinned
/// to the trailing-top, and a directional chevron that follows the chevron of
/// travel (right in LTR, left in RTL). Material + InkWell own the tap so the
/// splash is clipped to the card radius.
///
/// Display strings are passed in by the caller (already localized). RTL-safe via
/// [EdgeInsetsDirectional] / [AlignmentDirectional].
class AppDashboardTile extends StatelessWidget {
  const AppDashboardTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional unread/pending count shown in a pill at the trailing-top.
  /// Null or <= 0 hides the badge.
  final int? badgeCount;

  /// Tint for the icon circle + glyph. Defaults to the brand primary.
  final Color? accent;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);
    final tint = accent ?? colors.primary;
    final showBadge = badgeCount != null && badgeCount! > 0;

    final card = Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.lg),
        side: BorderSide(color: colors.outline),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: appRadius(AppRadii.lg),
          boxShadow: elevation.level1,
        ),
        child: InkWell(
          borderRadius: appRadius(AppRadii.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              children: [
                _IconBadge(icon: icon, tint: tint),
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
                        style: styles.titleMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  LucideIcons.chevron_right,
                  size: AppSpacing.xl,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!showBadge) return card;

    // Pin the count pill to the trailing-top, lifted slightly outside the card
    // edge for a premium "floating badge" feel.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        PositionedDirectional(
          top: -AppSpacing.xs,
          end: -AppSpacing.xs,
          child: _CountBadge(count: badgeCount!, tint: tint),
        ),
      ],
    );
  }
}

/// The icon inside a soft tinted circle.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xxl + AppSpacing.lg,
      height: AppSpacing.xxl + AppSpacing.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: tint, size: AppSpacing.xl),
    );
  }
}

/// A solid count pill (tinted fill, on-primary number) for the trailing-top.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.tint});

  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final label = count > 99
        ? '${formatLocalizedNumber(99, locale)}+'
        : formatLocalizedNumber(count, locale);

    return Container(
      constraints: const BoxConstraints(minWidth: AppSpacing.xl),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: colors.card),
      ),
      alignment: AlignmentDirectional.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: styles.labelMedium.copyWith(color: colors.onPrimary),
      ),
    );
  }
}
