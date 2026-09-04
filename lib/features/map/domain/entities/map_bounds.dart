// lib/features/map/domain/entities/map_bounds.dart
//
// Plan A17 — the visible map viewport, as the four numbers `search_map` takes.
//
// A domain type rather than flutter_map's `LatLngBounds` so the repository and
// the RPC layer stay free of the map package (and of any notion of a camera).

import 'package:equatable/equatable.dart';

/// The most markers `search_map` will ever return. Mirrors the `LIMIT 500` in
/// `20260904120007_bound_the_map.sql` — the client needs to know when a result
/// was truncated, because a truncated result cannot be reused for a smaller
/// viewport the way a complete one can.
const int kMapMarkerCap = 500;

/// A latitude/longitude rectangle. Latitudes are clamped to ±90 and longitudes
/// to ±180, because a fully zoomed-out camera reports a viewport larger than
/// the world.
class MapBounds extends Equatable {
  MapBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) : minLat = minLat.clamp(-90.0, 90.0),
       maxLat = maxLat.clamp(-90.0, 90.0),
       minLng = minLng.clamp(-180.0, 180.0),
       maxLng = maxLng.clamp(-180.0, 180.0);

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  /// Grows the box by [fraction] of its own size on every side. Requesting a
  /// little more than is visible means a short pan finds its markers already
  /// loaded instead of waiting on a round trip.
  MapBounds padded(double fraction) {
    final latPad = (maxLat - minLat) * fraction;
    final lngPad = (maxLng - minLng) * fraction;
    return MapBounds(
      minLat: minLat - latPad,
      maxLat: maxLat + latPad,
      minLng: minLng - lngPad,
      maxLng: maxLng + lngPad,
    );
  }

  /// True when [inner] lies entirely within this box — i.e. markers fetched for
  /// this box already cover it, provided the fetch was not truncated.
  bool contains(MapBounds inner) =>
      inner.minLat >= minLat &&
      inner.maxLat <= maxLat &&
      inner.minLng >= minLng &&
      inner.maxLng <= maxLng;

  @override
  List<Object?> get props => [minLat, maxLat, minLng, maxLng];

  @override
  String toString() =>
      'MapBounds($minLat..$maxLat, $minLng..$maxLng)';
}
