import '../../domain/entities/city.dart';
import 'dto_helpers.dart';

class CityDto {
  const CityDto({
    required this.id,
    required this.governorateId,
    required this.key,
    required this.displayName,
    required this.description,
    required this.position,
    required this.isActive,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CityDto.fromJson(Map<String, dynamic> json) {
    return CityDto(
      id: json['id'] as String,
      governorateId: json['governorate_id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] != null
          ? parseLocalizedMap(json['description'])
          : null,
      position: json['position'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String governorateId;
  final String key;
  final Map<String, String> displayName;
  final Map<String, String>? description;
  final int? position;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  City toEntity() {
    return City(
      id: id,
      governorateId: governorateId,
      key: key,
      displayName: displayName,
      description: description,
      position: position,
      isActive: isActive,
      isSystem: isSystem,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
