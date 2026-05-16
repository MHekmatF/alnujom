import '../../domain/entities/role_detail.dart';
import 'dto_helpers.dart';

class RoleDto {
  const RoleDto({
    required this.id,
    required this.key,
    required this.displayName,
    required this.description,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoleDto.fromJson(Map<String, dynamic> json) {
    return RoleDto(
      id: json['id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String key;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoleDetail toEntity({List<String> permissionKeys = const <String>[]}) {
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
