import '../../domain/entities/role_assignment_summary.dart';
import 'dto_helpers.dart';

class AssignedRoleDto {
  const AssignedRoleDto({
    required this.roleId,
    required this.roleKey,
    required this.displayName,
    required this.grantedAt,
  });

  factory AssignedRoleDto.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as Map;
    return AssignedRoleDto(
      roleId: role['id'] as String,
      roleKey: role['key'] as String,
      displayName: parseLocalizedMap(role['display_name']),
      grantedAt: DateTime.parse(json['granted_at'] as String),
    );
  }

  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final DateTime grantedAt;

  RoleAssignmentSummary toEntity() {
    return RoleAssignmentSummary(
      roleId: roleId,
      roleKey: roleKey,
      displayName: displayName,
      grantedAt: grantedAt,
    );
  }
}
