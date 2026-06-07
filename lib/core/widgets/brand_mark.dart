import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'reduce_motion.dart';

/// Phase 25 premium uplift — the AlNujom brand mark, unified to the shipped
/// **N-logo** identity (`assets/branding/logo_mark.png`) so the in-app mark
/// matches the launcher icon / splash / auth logo (no more two-mark drift).
///
/// The emblem is the full-colour N by default. When [color] is supplied (e.g.
/// a white mark over a photo / coloured splash) it is rendered as a tinted
/// silhouette via [ColorFiltered] so it stays legible on any surface. A logo is
/// never mirrored for RTL — the composition is fixed in both directions.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
    this.color,
    this.withWordmark = false,
    this.wordmark = 'النجوم',
    this.animated = false,
  });

  final double size;

  /// When set, the emblem renders as a solid-colour silhouette (for on-photo /
  /// on-colour surfaces). When null, the full-colour N-logo is shown.
  final Color? color;
  final bool withWordmark;
  final String wordmark;

  /// When true (and reduced motion is off), the emblem gently rotates — used by
  /// the pull-to-refresh indicator as a branded spinner. Reserve for transient
  /// moments, not the always-on app bar.
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget mark = Image.asset(
      'assets/branding/logo_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (color != null) {
      mark = ColorFiltered(
        colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
        child: mark,
      );
    }
    if (animated && !reduceMotion(context)) {
      mark = _SpinningMark(size: size, child: mark);
    }

    // Standalone (no wordmark): announce the brand name as a single image.
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

/// A continuous, gentle rotation for the emblem — a branded loading spinner.
class _SpinningMark extends StatefulWidget {
  const _SpinningMark({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<_SpinningMark> createState() => _SpinningMarkState();
}

class _SpinningMarkState extends State<_SpinningMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
