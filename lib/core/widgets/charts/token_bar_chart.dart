// Phase 29 (029-crm-reels-growth) — shared, token-clean bar chart.
//
// TokenBarChart: a hand-built (no chart package) vertical bar chart extracted
// from the publisher lead-analytics _DailyBarChart idiom. One token-styled bar
// per value, height normalized to the tallest bar, a minimum visible nib for
// non-zero values, and a faint baseline stub for zeros so the axis still reads
// as continuous. An optional start/end caption row sits under the plot.
//
// Token-clean: uses AppColors / AppTextStyles / AppSpacing / appRadius /
// AppElevation only — no inline colour, text-style, or numeric-padding literals.
// RTL-safe: the Row lays out start→end so it reverses naturally under RTL;
// captions use a directional spread.
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/elevation.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// A single plottable bar: its numeric [value] and whether it is [filled]
/// (a real, non-zero data point) vs. a gap/zero day rendered as a faint stub.
class TokenBarChartBar {
  const TokenBarChartBar({required this.value, this.filled = true});

  /// The bar's magnitude. Negative values are treated as zero.
  final num value;

  /// When false the bar renders as a faint baseline stub (zero / gap day).
  final bool filled;
}

/// A token-styled vertical bar chart inside a card. Pass either pre-built
/// [bars] (full control over filled vs. stub) or a plain list of [values]
/// (each non-zero value is treated as filled, zeros as stubs). Provide
/// [startCaption] / [endCaption] to label the first/last bar (e.g. the date
/// range of a daily series).
class TokenBarChart extends StatelessWidget {
  const TokenBarChart({
    super.key,
    this.bars,
    this.values,
    this.height = 140,
    this.barColor,
    this.startCaption,
    this.endCaption,
  }) : assert(
         bars != null || values != null,
         'TokenBarChart needs either bars or values.',
       );

  /// Explicit bars (filled/stub controlled per bar). Takes precedence over
  /// [values] when both are supplied.
  final List<TokenBarChartBar>? bars;

  /// Convenience input: each value becomes a bar, non-zero → filled.
  final List<num>? values;

  /// Plot height for the tallest bar.
  final double height;

  /// Override for the filled-bar colour; defaults to the brand primary.
  final Color? barColor;

  /// Optional caption under the first bar (start) — e.g. the window's first day.
  final String? startCaption;

  /// Optional caption under the last bar (end) — e.g. the window's last day.
  final String? endCaption;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    final resolvedBars =
        bars ??
        (values ?? const <num>[])
            .map((v) => TokenBarChartBar(value: v, filled: v > 0))
            .toList(growable: false);

    final maxValue = resolvedBars.fold<double>(
      0,
      (peak, bar) => bar.value > peak ? bar.value.toDouble() : peak,
    );

    final hasCaptions = startCaption != null || endCaption != null;

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in resolvedBars)
                  Expanded(
                    child: _Bar(
                      fraction: maxValue == 0
                          ? 0
                          : (bar.value <= 0 ? 0 : bar.value / maxValue),
                      maxHeight: height,
                      filled: bar.filled && bar.value > 0,
                      barColor: barColor ?? colors.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (hasCaptions) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startCaption ?? '',
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
                Text(
                  endCaption ?? '',
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A single token-styled bar. Non-zero bars clamp to a minimum visible nib so
/// they never collapse to nothing; zero/stub bars render a faint baseline.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.maxHeight,
    required this.filled,
    required this.barColor,
  });

  final double fraction;
  final double maxHeight;
  final bool filled;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final double height = filled
        ? (maxHeight * fraction).clamp(AppSpacing.xs, maxHeight)
        : AppSpacing.xs / 2;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xxs),
      child: Align(
        alignment: AlignmentDirectional.bottomCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: filled ? barColor : colors.outline.withValues(alpha: 0.6),
            borderRadius: appRadius(AppRadii.sm),
          ),
        ),
      ),
    );
  }
}
