import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// A single plottable bar for [DcBarChart]: a magnitude [value] and the [label]
/// shown under it on the x-axis.
class DcBarChartBar {
  const DcBarChartBar({required this.value, required this.label});

  final num value;
  final String label;
}

/// DC "Blue Crown" bar-chart card (`AlNujom - Publisher.dc.html` «المشاهدات»).
///
/// A flat surface card with a header (title + optional range on the start, an
/// optional running total on the end) over a single-hue [colors.primary] bar
/// plot with per-bar x-axis labels. No chart package, no rainbow — token-clean
/// and cheap on low-end devices. Strings are pre-localized by the caller.
class DcBarChart extends StatelessWidget {
  const DcBarChart({
    required this.title,
    required this.bars,
    this.rangeLabel,
    this.totalValue,
    this.totalLabel,
    this.height = 128,
    super.key,
  });

  final String title;
  final List<DcBarChartBar> bars;
  final String? rangeLabel;
  final String? totalValue;
  final String? totalLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final maxValue = bars.fold<double>(
      0,
      (peak, bar) => bar.value > peak ? bar.value.toDouble() : peak,
    );

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: styles.labelLarge.copyWith(color: colors.onSurface),
                    ),
                    if (rangeLabel != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        rangeLabel!,
                        style: styles.labelSmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (totalValue != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalValue!,
                      style: styles.titleLarge.copyWith(color: colors.onSurface),
                    ),
                    if (totalLabel != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        totalLabel!,
                        style: styles.labelSmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: _Column(
                      bar: bar,
                      fraction: maxValue == 0
                          ? 0
                          : (bar.value <= 0 ? 0 : bar.value / maxValue),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.bar, required this.fraction});

  final DcBarChartBar bar;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final hasValue = bar.value > 0;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: hasValue
                    ? fraction.clamp(0.05, 1.0)
                    : 0.02,
                child: Container(
                  width: 22,
                  decoration: BoxDecoration(
                    color: hasValue
                        ? colors.primary
                        : colors.outlineStrong.withValues(alpha: 0.5),
                    borderRadius: const BorderRadiusDirectional.vertical(
                      top: Radius.circular(AppRadii.sm),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            bar.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.labelSmall.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
