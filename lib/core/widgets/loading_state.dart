import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '_widget_support.dart';
import 'dimens.dart';

class LoadingState extends StatefulWidget {
  const LoadingState.card({super.key})
    : width = double.infinity,
      height = AppDimens.skeletonCardHeight,
      radius = AppRadii.md;

  const LoadingState.row({super.key})
    : width = double.infinity,
      height = AppSpacing.xxxl,
      radius = AppRadii.sm;

  const LoadingState.avatar({super.key})
    : width = AppSpacing.xxxl,
      height = AppSpacing.xxxl,
      radius = AppRadii.pill;

  /// A single text-line shimmer (body height) — for skeletoning copy lines.
  const LoadingState.line({super.key})
    : width = double.infinity,
      height = AppSpacing.lg,
      radius = AppRadii.sm;

  /// A taller heading/title-line shimmer.
  const LoadingState.heading({super.key})
    : width = double.infinity,
      height = AppSpacing.xl,
      radius = AppRadii.sm;

  final double width;
  final double height;
  final double radius;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.of(context).disableAnimations;
    if (disabled == _animationsDisabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller.stop();
      _controller.value = 0.5; // Mid-shimmer alpha — neutral, static look.
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_animationsDisabled) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withAlpha(0xA0),
          borderRadius: appRadius(widget.radius),
        ),
      );
    }
    // A highlight that reads in both themes: the base nudged toward the
    // foreground tint (never a hardcoded white, which vanishes in light mode).
    final base = colors.surfaceVariant;
    final highlight = Color.alphaBlend(
      colors.onSurfaceVariant.withValues(alpha: 0.14),
      base,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: appRadius(widget.radius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.30, 0.5, 0.70],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SweepGradientTransform(_controller.value),
            ),
          ),
        );
      },
    );
  }
}

/// Translates a [LinearGradient] horizontally across its bounds so the bright
/// band sweeps with the reading direction (LTR: value 0→1 maps the highlight
/// from off-left to off-right; RTL flips the sign so it sweeps off-right to
/// off-left, matching Arabic surfaces).
class _SweepGradientTransform extends GradientTransform {
  const _SweepGradientTransform(this.value);

  final double value;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final sign = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final dx = bounds.width * (value * 2 - 1) * sign;
    return Matrix4.translationValues(dx, 0, 0);
  }
}
