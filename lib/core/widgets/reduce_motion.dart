import 'package:flutter/widgets.dart';

/// Whether the platform has requested reduced motion ("Remove animations").
///
/// `flutter_animate` does NOT honour [MediaQueryData.disableAnimations] on its
/// own, so every entrance / press / transition helper in the app checks this
/// and degrades to an instant (no-motion) result when it returns true.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
