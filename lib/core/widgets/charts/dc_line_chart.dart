import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// DC "Blue Crown" line-chart card (`AlNujom - Admin.dc.html` «التطوّر عبر الزمن»).
///
/// A flat surface card with a header (title + optional running total) over a
/// single-hue [colors.primary] area+line chart with dots and per-point x-axis
/// labels. Hand-built with a [CustomPainter] — no chart package, token-clean.
/// This is the NATIVE side of the admin chart-package comparison.
class DcLineChart extends StatelessWidget {
  const DcLineChart({
    required this.values,
    required this.labels,
    required this.title,
    this.totalValue,
    this.totalLabel,
    this.rangeLabel,
    this.height = 140,
    super.key,
  });

  final List<num> values;
  final List<String> labels;
  final String title;
  final String? totalValue;
  final String? totalLabel;
  final String? rangeLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

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
          DcLineChartPlot(values: values, height: height),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: styles.labelSmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Just the plot area of a [DcLineChart] — the single-hue area+line+dots, no
/// card/header/axis. Rendered with a hand-written [CustomPainter]. Split out so
/// the admin analytics screen can reuse the bare plot under its own shared shell
/// (title, running total, month axis).
class DcLineChartPlot extends StatelessWidget {
  const DcLineChartPlot({
    required this.values,
    this.height = 140,
    super.key,
  });

  final List<num> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          values: values.map((v) => v.toDouble()).toList(growable: false),
          line: colors.primary,
          area: colors.primary.withValues(alpha: 0.13),
          dotFill: colors.card,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.line,
    required this.area,
    required this.dotFill,
  });

  final List<double> values;
  final Color line;
  final Color area;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV <= 0 ? 1.0 : maxV;
    // Inset the plot a touch so dots at the edges aren't clipped.
    const pad = 4.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final n = values.length;

    Offset pointAt(int i) {
      final x = n == 1 ? w / 2 : (i / (n - 1)) * w;
      final y = h - (values[i] / range) * h;
      return Offset(pad + x, pad + y);
    }

    final pts = [for (var i = 0; i < n; i++) pointAt(i)];

    // Area fill under the line.
    final areaPath = Path()..moveTo(pts.first.dx, size.height - pad);
    for (final p in pts) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(pts.last.dx, size.height - pad);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = area);

    // The line itself.
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dots (surface fill + primary ring) — only when the series is short enough
    // that they read as points rather than clutter.
    if (n <= 12) {
      final ring = Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final fill = Paint()..color = dotFill;
      for (final p in pts) {
        canvas.drawCircle(p, 3, fill);
        canvas.drawCircle(p, 3, ring);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.line != line ||
      old.area != area ||
      old.dotFill != dotFill;
}
