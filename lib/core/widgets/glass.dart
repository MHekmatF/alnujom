import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '_widget_support.dart';

/// Design #8 "Glass / Depth" — a frosted-glass panel: a real backdrop blur
/// behind a translucent fill with a hairline highlight. Used for the search
/// bar, filter chips, over-photo pills, the featured hero info card, and the
/// floating bottom nav.
///
/// Blur is GPU work — keep instances modest and prefer [onDark] pills small.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.radius = AppRadii.lg,
    this.blur = 16,
    this.tintOpacity = 0.72,
    this.padding,
    this.onDark = false,
    super.key,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double tintOpacity;
  final EdgeInsetsGeometry? padding;

  /// Over a photo/dark area, use a light translucent white glass; on the
  /// app background, use a card-tinted glass.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final br = appRadius(radius);
    final fill = onDark
        ? Colors.white.withValues(alpha: 0.22)
        : colors.card.withValues(alpha: tintOpacity);
    final borderColor = onDark
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.white.withValues(alpha: 0.85);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: br,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
