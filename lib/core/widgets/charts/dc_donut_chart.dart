import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../../shared/util/localized_numbers.dart';
import '../_widget_support.dart';

/// One slice of a [DcDonutChart].
class DcDonutSlice {
  const DcDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// A native (CustomPaint) donut chart with a side legend — a chart type not yet
/// used elsewhere in the app. Draws proportional ring arcs for each slice over a
/// faint track, with the grand total in the hole; the legend lists each slice's
/// colour dot, label, and value. Token-clean; empty/zero-total handled by the
/// caller (shows an empty hint instead).
class DcDonutChart extends StatelessWidget {
  const DcDonutChart({required this.slices, required this.centerLabel, super.key});

  final List<DcDonutSlice> slices;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    final total = slices.fold<int>(0, (sum, s) => sum + s.value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: slices,
              total: total,
              trackColor: colors.surfaceVariant,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatLocalizedNumber(total, locale),
                    style: styles.titleLarge.copyWith(color: colors.onSurface),
                  ),
                  Text(
                    centerLabel,
                    style: styles.labelSmall.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < slices.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _LegendRow(slice: slices[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final DcDonutSlice slice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: appRadius(AppRadii.sm),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.bodyMedium.copyWith(color: colors.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatLocalizedNumber(slice.value, locale),
          style: styles.labelLarge.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.trackColor,
  });

  final List<DcDonutSlice> slices;
  final int total;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.shortestSide * 0.16;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full-circle track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0) return;

    var startAngle = -math.pi / 2; // 12 o'clock
    const gap = 0.03; // small radian gap between slices
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * (2 * math.pi) - gap;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total ||
      old.trackColor != trackColor ||
      old.slices != slices;
}
