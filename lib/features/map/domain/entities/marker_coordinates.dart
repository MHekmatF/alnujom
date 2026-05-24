import 'package:equatable/equatable.dart';

/// A geographic coordinate pair. Domain-pure (no flutter_map / latlong2 import).
/// The data layer maps to/from package:latlong2's LatLng at the data-source
/// boundary.
class MarkerCoordinates extends Equatable {
  const MarkerCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [latitude, longitude];
}
