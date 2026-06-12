import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/nearby_amenity.dart';

/// Spec 028 — datasource for the listing-details "Nearby" section, backed by
/// the public Overpass API over OpenStreetMap data.
///
/// One POST per listing (results are cached in-memory by listing id for the
/// app session), an 8-second hard timeout on both the HTTP call and the
/// Overpass server-side query, and a small result cap. Best-effort by design:
/// any failure throws and the repository maps it to a [FailureResult] so the
/// section simply collapses.
@injectable
class OverpassNearbyAmenitiesDatasource {
  const OverpassNearbyAmenitiesDatasource();

  /// Overpass endpoint as a const so a mirror swap (e.g. overpass.kumi.systems)
  /// is a one-line change.
  static const String endpoint = 'https://overpass-api.de/api/interpreter';

  /// Search radius around the listing's coordinates, in meters.
  static const int _radiusMeters = 1500;

  /// Hard timeout for the HTTP round-trip (matches the server-side
  /// `[timeout:8]` in the Overpass QL query).
  static const Duration _timeout = Duration(seconds: 8);

  /// At most this many nearest amenities are returned.
  static const int _maxResults = 10;

  /// OSM `amenity` tag regex covering the five supported kinds.
  static const String _amenityRegex =
      'school|hospital|pharmacy|marketplace|place_of_worship';

  /// Identifying User-Agent per the Overpass usage policy. Required in
  /// practice: overpass-api.de answers HTTP 406 to Dart's default
  /// `Dart/x.y (dart:io)` agent (and to curl's), which silently collapsed
  /// the section on device.
  static const Map<String, String> _headers = {
    'User-Agent': 'AlNujom/1.0 (+https://alnujom.app)',
  };

  /// Session-scoped cache keyed by listing id — a details page revisit never
  /// re-hits Overpass for the same listing.
  static final Map<String, List<NearbyAmenity>> _cache =
      <String, List<NearbyAmenity>>{};

  Future<List<NearbyAmenity>> fetchNearby({
    required String listingId,
    required double latitude,
    required double longitude,
  }) async {
    final cached = _cache[listingId];
    if (cached != null) return cached;

    // Nodes carry lat/lon directly; ways need `out center` for a centroid.
    final query =
        '[out:json][timeout:8];'
        '(node(around:$_radiusMeters,$latitude,$longitude)'
        '[amenity~"$_amenityRegex"];'
        'way(around:$_radiusMeters,$latitude,$longitude)'
        '[amenity~"$_amenityRegex"];'
        ');out center 30;';

    final response = await http
        .post(Uri.parse(endpoint), headers: _headers, body: {'data': query})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Overpass returned HTTP ${response.statusCode}',
        Uri.parse(endpoint),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];

    const distance = Distance();
    final origin = LatLng(latitude, longitude);

    final amenities = <NearbyAmenity>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final element = Map<String, dynamic>.from(raw);
      final tags = element['tags'];
      if (tags is! Map) continue;

      final kind = _kindFromTag(tags['amenity']?.toString());
      if (kind == null) continue;

      // Node → top-level lat/lon; way → center {lat, lon}.
      double? lat = (element['lat'] as num?)?.toDouble();
      double? lon = (element['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) {
        final center = element['center'];
        if (center is Map) {
          lat = (center['lat'] as num?)?.toDouble();
          lon = (center['lon'] as num?)?.toDouble();
        }
      }
      if (lat == null || lon == null) continue;

      // Arabic-first: prefer the localized name tag when OSM carries one.
      final name = (tags['name:ar'] ?? tags['name'])?.toString();

      amenities.add(
        NearbyAmenity(
          kind: kind,
          name: name == null || name.isEmpty ? null : name,
          distanceMeters: distance.as(
            LengthUnit.Meter,
            origin,
            LatLng(lat, lon),
          ),
        ),
      );
    }

    amenities.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final result = amenities.take(_maxResults).toList(growable: false);
    _cache[listingId] = result;
    return result;
  }

  /// Maps an OSM `amenity` tag value onto the closed [NearbyAmenityKind] set
  /// (`place_of_worship` → mosque, `marketplace` → market); null = unsupported.
  NearbyAmenityKind? _kindFromTag(String? amenityTag) {
    switch (amenityTag) {
      case 'school':
        return NearbyAmenityKind.school;
      case 'hospital':
        return NearbyAmenityKind.hospital;
      case 'pharmacy':
        return NearbyAmenityKind.pharmacy;
      case 'marketplace':
        return NearbyAmenityKind.market;
      case 'place_of_worship':
        return NearbyAmenityKind.mosque;
      default:
        return null;
    }
  }
}
