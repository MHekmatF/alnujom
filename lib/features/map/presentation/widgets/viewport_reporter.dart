// lib/features/map/presentation/widgets/viewport_reporter.dart
//
// Plan A17 — turns flutter_map's firehose of camera events into one
// [MapViewportChanged] per settled camera.
//
// `onMapEvent` fires on every frame of a drag, a fling and a pinch. Fetching on
// each would be worse than the unbounded load it replaces. This waits for the
// camera to sit still, then reports once.
//
// Shared because both map surfaces need it: the standalone `/map` page and the
// search page's embedded map.

import 'dart:async';

import 'package:flutter_map/flutter_map.dart' show MapEvent;

import '../../domain/entities/map_bounds.dart';

/// How long the camera has to sit still before we ask the server about it.
/// Long enough to swallow a drag, short enough not to feel like a stall.
const Duration kViewportSettleDelay = Duration(milliseconds: 300);

/// Collapses a stream of map events into one callback per settled camera.
///
/// Owned by the State that builds the map; [dispose] must be called with it, or
/// the pending timer fires into a dead widget.
class ViewportReporter {
  ViewportReporter({
    required this.onSettled,
    this.delay = kViewportSettleDelay,
  });

  /// Called with the visible viewport once the camera has been still for
  /// [delay]. Never called after [dispose].
  final void Function(MapBounds bounds) onSettled;

  final Duration delay;

  Timer? _timer;
  bool _disposed = false;

  /// Feed every `onMapEvent` here.
  void report(MapEvent event) {
    if (_disposed) return;
    final visible = event.camera.visibleBounds;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_disposed) return;
      onSettled(
        MapBounds(
          minLat: visible.south,
          maxLat: visible.north,
          minLng: visible.west,
          maxLng: visible.east,
        ),
      );
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
