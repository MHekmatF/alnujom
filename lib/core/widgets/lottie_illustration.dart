import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

import 'reduce_motion.dart';

/// Plays a looping, theme-recoloured Lottie illustration (used for richer empty
/// states). The asset is monochrome and authored in-repo (ours, no third-party
/// licence); [color] recolours every fill + stroke to match the surface.
///
/// Under reduced motion — or if the asset ever fails to render — it falls back
/// to [fallback] (a static icon), so the empty state is never blank or moving
/// when it shouldn't be.
class LottieIllustration extends StatelessWidget {
  const LottieIllustration({
    super.key,
    required this.asset,
    required this.size,
    required this.color,
    required this.fallback,
  });

  final String asset;
  final double size;
  final Color color;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final Widget child = reduceMotion(context)
        ? fallback
        : Lottie.asset(
            asset,
            width: size,
            height: size,
            repeat: true,
            delegates: LottieDelegates(
              values: [
                ValueDelegate.color(const ['**'], value: color),
                ValueDelegate.strokeColor(const ['**'], value: color),
              ],
            ),
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    // Purely decorative — the empty-state headline + body carry the meaning,
    // so keep the illustration out of the screen-reader tree.
    return ExcludeSemantics(child: child);
  }
}
