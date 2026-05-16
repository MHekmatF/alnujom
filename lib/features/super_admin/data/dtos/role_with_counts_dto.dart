import '../../domain/entities/role_with_counts.dart';
import 'dto_helpers.dart';

class RoleWithCountsDto {
  const RoleWithCountsDto({
    required this.id,
    required this.key,
    required this.displayName,
    required this.description,
    required this.isSystem,
    required this.permissionCount,
    required this.userCount,
    required this.updatedAt,
  });

  factory RoleWithCountsDto.fromJson(Map<String, dynamic> json) {
    return RoleWithCountsDto(
      id: json['id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      permissionCount: parseNestedCount(json['role_permissions']),
      userCount: parseNestedCount(json['user_roles']),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String key;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final int permissionCount;
  final int userCount;
  final DateTime updatedAt;

  RoleWithCounts toEntity() {
    return RoleWithCounts(
      roleId: id,
      roleKey: key,
      displayName: displayName,
      description: description,
      isSystem: isSystem,
      permissionCount: permissionCount,
      userCount: userCount,
      updatedAt: updatedAt,
    );
  }
}
