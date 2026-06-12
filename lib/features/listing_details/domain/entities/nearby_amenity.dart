import 'package:equatable/equatable.dart';

/// Spec 028 — the closed set of amenity kinds surfaced on the listing details
/// "Nearby" section. Mapped from OpenStreetMap `amenity` tags by the Overpass
/// datasource (`place_of_worship` → [mosque], `marketplace` → [market]).
enum NearbyAmenityKind { school, hospital, pharmacy, market, mosque }

/// Spec 028 — a single point of interest near the listing's coordinates,
/// sourced from OpenStreetMap via the Overpass API.
class NearbyAmenity extends Equatable {
  const NearbyAmenity({
    required this.kind,
    this.name,
    required this.distanceMeters,
  });

  final NearbyAmenityKind kind;

  /// The OSM `name` tag when present (Arabic name preferred); null for
  /// unnamed map features.
  final String? name;

  /// Great-circle distance from the listing's coordinates, in meters.
  final double distanceMeters;

  @override
  List<Object?> get props => [kind, name, distanceMeters];
}
