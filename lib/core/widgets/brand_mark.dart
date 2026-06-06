import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'reduce_motion.dart';

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
    this.animated = false,
  });

  final double size;
  final Color? color;
  final Color? accentColor;
  final bool withWordmark;
  final String wordmark;

  /// When true (and reduced motion is off), the coral companion star gently
  /// twinkles. Reserve for transient brand moments (splash, onboarding) — not
  /// the always-on app bar, where persistent decorative motion would distract.
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final primary = color ?? colors.primary;
    final accent = accentColor ?? colors.accent;
    final mark = (animated && !reduceMotion(context))
        ? _TwinklingMark(size: size, primary: primary, accent: accent)
        : CustomPaint(
            size: Size.square(size),
            painter: _StarMarkPainter(primary: primary, accent: accent),
          );
    // Standalone (no wordmark, e.g. the app bar): announce the brand name as a
    // single image. With the wordmark, the Text below is the label, so the mark
    // is excluded to avoid a duplicate announcement.
    if (!withWordmark) {
      return Semantics(label: wordmark, image: true, child: mark);
    }

    final styles = AppTextStyles.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: mark),
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

/// Hosts the gentle twinkle: a repeating controller drives a 0→1 sine that the
/// painter maps onto the companion star's size + opacity.
class _TwinklingMark extends StatefulWidget {
  const _TwinklingMark({
    required this.size,
    required this.primary,
    required this.accent,
  });

  final double size;
  final Color primary;
  final Color accent;

  @override
  State<_TwinklingMark> createState() => _TwinklingMarkState();
}

class _TwinklingMarkState extends State<_TwinklingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _StarMarkPainter(
            primary: widget.primary,
            accent: widget.accent,
            twinkle: t,
          ),
        );
      },
    );
  }
}

class _StarMarkPainter extends CustomPainter {
  _StarMarkPainter({
    required this.primary,
    required this.accent,
    this.twinkle = 1.0,
  });

  final Color primary;
  final Color accent;

  /// 0..1 — modulates the companion star's size and opacity (1.0 = static/full).
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Large primary star, slightly lower-leading.
    _drawStar(canvas, Offset(w * 0.42, h * 0.57), w * 0.40, 0.42, primary);
    // Smaller coral companion, upper-trailing — twinkles when animated.
    _drawStar(
      canvas,
      Offset(w * 0.79, h * 0.24),
      w * 0.19 * (0.82 + 0.24 * twinkle),
      0.44,
      accent.withValues(alpha: 0.6 + 0.4 * twinkle),
    );
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
      old.primary != primary || old.accent != accent || old.twinkle != twinkle;
}
