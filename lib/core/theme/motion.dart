import 'package:flutter/animation.dart';

/// Phase 25 motion tokens (Claude Design): subtle, purposeful durations and a
/// single shared easing curve. Used for micro-interactions (favorite toggle),
/// sheets, and page/element transitions. Durations/Curves are not restricted by
/// the design-token linter, so these may be referenced directly from widgets.
abstract final class AppMotion {
  /// Micro-interactions: button press, heart toggle, icon swap.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions: color/background fades, theme change.
  static const Duration base = Duration(milliseconds: 200);

  /// Larger transitions: sheets opening, page entrance.
  static const Duration slow = Duration(milliseconds: 250);

  /// List-item / content entrance (fade + small slide).
  static const Duration entrance = Duration(milliseconds: 400);

  /// Per-item delay step for staggered list entrances.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Shared easing curve (`cubic-bezier(.2, .7, .3, 1)`).
  static const Curve curve = Cubic(0.2, 0.7, 0.3, 1);
}
