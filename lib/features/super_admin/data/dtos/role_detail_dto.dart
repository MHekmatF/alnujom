import '../../domain/entities/role_detail.dart';
import 'dto_helpers.dart';

class RoleDetailDto {
  const RoleDetailDto({
    required this.id,
    required this.key,
    required this.displayName,
    required this.description,
    required this.isSystem,
    required this.permissionKeys,
    required this.updatedAt,
  });

  factory RoleDetailDto.fromJson(Map<String, dynamic> json) {
    final rolePermissions = (json['role_permissions'] as List?) ?? const [];
    final permissionKeys = rolePermissions
        .map((rp) => ((rp as Map)['permission'] as Map)['key'] as String)
        .toList();

    return RoleDetailDto(
      id: json['id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      permissionKeys: permissionKeys,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String key;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final List<String> permissionKeys;
  final DateTime updatedAt;

  RoleDetail toEntity() {
    return RoleDetail(
      roleId: id,
      roleKey: key,
      displayName: displayName,
      description: description,
      isSystem: isSystem,
      permissionKeys: permissionKeys,
      updatedAt: updatedAt,
    );
  }
}
