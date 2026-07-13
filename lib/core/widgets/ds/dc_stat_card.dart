import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// DC "Blue Crown" KPI stat card (`AlNujom - Publisher.dc.html`).
///
/// A FLAT card — surface + hairline outline, no gradient wash or shadow (the key
/// contrast with the Phase-25 [StatCard]). A tonal icon chip sits top-start with
/// an optional trend-delta pill top-end; a large [value], a [label], and an
/// optional [sub] caption stack beneath. All strings are pre-localized by the
/// caller. Pass [delta] only when real trend data exists — never fabricate it.
class DcStatCard extends StatelessWidget {
  const DcStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.sub,
    this.delta,
    this.trendUp = true,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? sub;

  /// Optional trend delta (e.g. "+12%"). Renders a green ↑ / red ↓ pill.
  final String? delta;
  final bool trendUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final content = Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: appRadius(AppRadii.sm),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              if (delta != null) _TrendPill(delta: delta!, up: trendUp),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.headlineMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.labelMedium.copyWith(color: colors.onSurface),
          ),
          if (sub != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelSmall.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
        ),
        child: content,
      );
    }

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: appRadius(AppRadii.lg),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: appRadius(AppRadii.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// The up/down trend pill: green ↑ (good) or red ↓ (regression).
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.delta, required this.up});

  final String delta;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final tint = up ? colors.verified : colors.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: tint,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(delta, style: styles.labelSmall.copyWith(color: tint)),
      ],
    );
  }
}
