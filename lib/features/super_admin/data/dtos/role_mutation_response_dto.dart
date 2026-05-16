import '../../domain/entities/role_mutation_result.dart';
import 'dto_helpers.dart';

class RoleMutationResponseDto {
  const RoleMutationResponseDto({
    required this.roleId,
    required this.key,
    required this.displayName,
    required this.description,
    required this.permissionKeys,
    required this.updatedAt,
  });

  factory RoleMutationResponseDto.fromJson(Map<String, dynamic> json) {
    final rawPermissions = (json['permission_keys'] as List?) ?? const [];
    return RoleMutationResponseDto(
      roleId: json['role_id'] as String,
      key: json['key'] as String,
      displayName: parseLocalizedMap(json['display_name']),
      description: json['description'] as String?,
      permissionKeys: rawPermissions.map((value) => value.toString()).toList(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String roleId;
  final String key;
  final Map<String, String> displayName;
  final String? description;
  final List<String> permissionKeys;
  final DateTime updatedAt;

  RoleMutationResult toEntity() {
    return RoleMutationResult(
      roleId: roleId,
      roleKey: key,
      displayName: displayName,
      description: description,
      permissionKeys: permissionKeys,
      updatedAt: updatedAt,
    );
  }
}
