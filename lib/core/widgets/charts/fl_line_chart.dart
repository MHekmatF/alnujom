import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// The fl_chart rendering of the same plot [DcLineChartPlot] paints natively —
/// single-hue [colors.primary] area + line + dots, no grid/axis/border/touch.
///
/// This is the PACKAGE side of the admin analytics engine comparison: identical
/// data, identical styling, a different renderer, under the same card shell. It
/// deliberately mirrors the native `_LinePainter` (straight segments, area fill
/// at 13% alpha, 2.5 stroke, 3px surface-filled dots ringed in primary, edge
/// dots un-clipped) so the only variable the design is judging is the engine.
class FlLineChartPlot extends StatelessWidget {
  const FlLineChartPlot({
    required this.values,
    this.height = 140,
    super.key,
  });

  final List<num> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final line = colors.primary;
    final area = colors.primary.withValues(alpha: 0.13);
    final dotFill = colors.card;

    final doubles = values.map((v) => v.toDouble()).toList(growable: false);
    final maxV = doubles.isEmpty ? 1.0 : doubles.reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV;
    final showDots = doubles.length <= 12;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (doubles.length - 1).clamp(0, double.infinity).toDouble(),
          minY: 0,
          maxY: maxY,
          clipData: const FlClipData.none(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < doubles.length; i++)
                  FlSpot(i.toDouble(), doubles[i]),
              ],
              isCurved: false,
              color: line,
              barWidth: 2.5,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                show: showDots,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: dotFill,
                      strokeColor: line,
                      strokeWidth: 2,
                    ),
              ),
              belowBarData: BarAreaData(show: true, color: area),
            ),
          ],
        ),
      ),
    );
  }
}
