import '../../domain/entities/area.dart';
import 'dto_helpers.dart';

class AreaDto {
  const AreaDto({
    required this.id,
    required this.cityId,
    required this.key,
    required this.displayName,
    required this.description,
    required this.position,
    required this.isActive,
    required this.centroidLat,
    required this.centroidLng,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AreaDto.fromJson(Map<String, dynamic> json) {
    return AreaDto(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] != null
          ? parseLocalizedMap(json['description'])
          : null,
      position: json['position'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      // centroid_* are NOT NULL in the DB; parse defensively (Postgres may
      // serialize numeric as either num or String over PostgREST).
      centroidLat: _parseDouble(json['centroid_lat']),
      centroidLng: _parseDouble(json['centroid_lng']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String cityId;
  final String key;
  final Map<String, String> displayName;
  final Map<String, String>? description;
  final int? position;
  final bool isActive;
  final double centroidLat;
  final double centroidLng;
  final DateTime createdAt;
  final DateTime updatedAt;

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    return 0;
  }

  Area toEntity() {
    return Area(
      id: id,
      cityId: cityId,
      key: key,
      displayName: displayName,
      description: description,
      position: position,
      isActive: isActive,
      centroidLat: centroidLat,
      centroidLng: centroidLng,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
