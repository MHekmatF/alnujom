import '../../domain/entities/governorate.dart';
import 'dto_helpers.dart';

class GovernorateDto {
  const GovernorateDto({
    required this.id,
    required this.key,
    required this.displayName,
    required this.description,
    required this.position,
    required this.isActive,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GovernorateDto.fromJson(Map<String, dynamic> json) {
    return GovernorateDto(
      id: json['id'] as String,
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
  final String key;
  final Map<String, String> displayName;
  final Map<String, String>? description;
  final int? position;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  Governorate toEntity() {
    return Governorate(
      id: id,
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
