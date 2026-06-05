import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import 'reduce_motion.dart';

/// Wraps [child] with a tactile press-down scale (1.0 → [scale]) driven by raw
/// pointer events.
///
/// It uses a [Listener] (not a [GestureDetector]) so it never competes in the
/// gesture arena — any `InkWell`/`onTap`/`onPressed` inside [child] keeps
/// working normally. Collapses to a no-op when [enabled] is false or the
/// platform requests reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      behavior: HitTestBehavior.deferToChild,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
