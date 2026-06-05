import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion.dart';
import 'reduce_motion.dart';

/// A list/grid item that fades + slides in, staggered by its [index].
///
/// The per-item delay is capped (so deep-scroll items appear promptly rather
/// than after a long cascade), and the whole effect is skipped under reduced
/// motion. Pass `enabled: false` during pagination/refresh so appended pages
/// don't replay the entrance wave.
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  final int index;
  final Widget child;
  final bool enabled;

  /// Beyond this position, all items share the same (capped) delay.
  static const int _cap = 8;

  @override
  Widget build(BuildContext context) {
    if (!enabled || reduceMotion(context)) return child;
    final clamped = index < 0 ? 0 : (index > _cap ? _cap : index);
    final delay = AppMotion.stagger * clamped;
    return child
        .animate()
        .fadeIn(
          duration: AppMotion.entrance,
          curve: AppMotion.curve,
          delay: delay,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: AppMotion.entrance,
          curve: AppMotion.curve,
          delay: delay,
        );
  }
}
