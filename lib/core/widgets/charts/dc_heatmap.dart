import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// One cell of a [DcHeatmap]: [value] at row [dow] (1=Mon .. 7=Sun) and column
/// [bucket] (0..columns-1).
class DcHeatmapCell {
  const DcHeatmapCell({
    required this.dow,
    required this.bucket,
    required this.value,
  });

  final int dow;
  final int bucket;
  final int value;
}

/// A native day-of-week × time-bucket activity heatmap — another chart type not
/// used elsewhere. [rows] labelled days (top → bottom) × [columns] time buckets;
/// each cell is tinted from the faint track colour toward [AppColors.primary] by
/// its intensity (value / max). Token-clean; caller supplies localized row
/// labels and shows an empty hint when there is no activity.
class DcHeatmap extends StatelessWidget {
  const DcHeatmap({
    required this.cells,
    required this.rowLabels,
    this.rows = 7,
    this.columns = 6,
    super.key,
  });

  final List<DcHeatmapCell> cells;

  /// One label per row; `rowLabels[0]` labels dow 1 (Monday).
  final List<String> rowLabels;
  final int rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    final grid = <(int, int), int>{
      for (final c in cells) (c.dow, c.bucket): c.value,
    };
    final maxValue = cells.isEmpty
        ? 0
        : cells.map((c) => c.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 1; r <= rows; r++) ...[
          if (r > 1) const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  r - 1 < rowLabels.length ? rowLabels[r - 1] : '',
                  style: styles.labelSmall.copyWith(color: colors.textMuted),
                ),
              ),
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Cell(
                      value: grid[(r, col)] ?? 0,
                      maxValue: maxValue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.maxValue});

  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Empty cells read as the faint track; non-empty cells ramp from a light
    // tint toward the full primary as intensity approaches the busiest cell.
    final intensity = (value <= 0 || maxValue <= 0)
        ? 0.0
        : 0.2 + 0.8 * (value / maxValue);
    final fill = value <= 0
        ? colors.surfaceVariant
        : Color.lerp(colors.surfaceVariant, colors.primary, intensity)!;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: appRadius(AppRadii.sm),
      ),
    );
  }
}
