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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = 0x80 + (_controller.value * 0x40).round();
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withAlpha(alpha),
            borderRadius: appRadius(widget.radius),
          ),
        );
      },
    );
  }
}
