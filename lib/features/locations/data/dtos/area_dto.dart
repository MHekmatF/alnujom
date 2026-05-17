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
  final DateTime createdAt;
  final DateTime updatedAt;

  Area toEntity() {
    return Area(
      id: id,
      cityId: cityId,
      key: key,
      displayName: displayName,
      description: description,
      position: position,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
