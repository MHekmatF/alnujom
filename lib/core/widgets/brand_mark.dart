import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Phase 25 (Claude Design) — the AlNujom brand mark: a refined two-tone
/// sparkle (النجوم = "the stars"), a large primary-blue star with a smaller
/// warm-coral companion. Used in the app bar, onboarding, splash and auth.
///
/// A logo is not mirrored for RTL — the composition is fixed in both
/// directions. Colours default to the active palette (primary + accent) but
/// can be overridden for on-colour surfaces (e.g. white-on-blue splash).
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
    this.color,
    this.accentColor,
    this.withWordmark = false,
    this.wordmark = 'النجوم',
  });

  final double size;
  final Color? color;
  final Color? accentColor;
  final bool withWordmark;
  final String wordmark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _StarMarkPainter(
        primary: color ?? colors.primary,
        accent: accentColor ?? colors.accent,
      ),
    );
    if (!withWordmark) return mark;

    final styles = AppTextStyles.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: AppSpacing.sm),
        Text(
          wordmark,
          style: styles.headlineMedium.copyWith(
            color: color ?? colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StarMarkPainter extends CustomPainter {
  _StarMarkPainter({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Large primary star, slightly lower-leading.
    _drawStar(canvas, Offset(w * 0.42, h * 0.57), w * 0.40, 0.42, primary);
    // Smaller coral companion, upper-trailing.
    _drawStar(canvas, Offset(w * 0.79, h * 0.24), w * 0.19, 0.44, accent);
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double rOuter,
    double innerRatio,
    Color color,
  ) {
    final rInner = rOuter * innerRatio;
    final path = Path();
    for (var i = 0; i < 8; i += 1) {
      final r = i.isEven ? rOuter : rInner;
      final angle = -math.pi / 2 + i * math.pi / 4; // top, step 45°
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _StarMarkPainter old) =>
      old.primary != primary || old.accent != accent;
}
