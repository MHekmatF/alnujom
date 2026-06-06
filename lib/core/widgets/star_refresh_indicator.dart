import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import 'brand_mark.dart';
import 'reduce_motion.dart';

/// A branded pull-to-refresh: as the user pulls, the AlNujom star mark scales +
/// fades in above the content; while refreshing it gently twinkles. Wraps any
/// scrollable [child] (CustomScrollView, ListView, …) and forwards [onRefresh].
///
/// The pull gesture itself is always available (it's not "motion" to suppress);
/// only the while-loading twinkle is gated by reduced motion.
class StarRefreshIndicator extends StatelessWidget {
  const StarRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// How far (logical px) the content slides down at the trigger point.
  static const double _extent = 88;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      // Keep the content offset modest while the spinner area shows.
      builder: (context, child, controller) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final value = controller.value;
            final reveal = value.clamp(0.0, 1.0);
            final offset = value.clamp(0.0, 1.3) * _extent;
            return Stack(
              children: [
                if (value > 0.01)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    height: offset,
                    child: Center(
                      child: Opacity(
                        opacity: reveal,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * reveal,
                          // Decorative pull affordance — the refresh action is
                          // conveyed by the gesture, not the mark.
                          child: ExcludeSemantics(
                            child: BrandMark(
                              size: 36,
                              animated: !reduce && controller.isLoading,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(offset: Offset(0, offset), child: child),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}
