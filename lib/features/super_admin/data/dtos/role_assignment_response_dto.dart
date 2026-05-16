import '../../domain/entities/role_assignment_result.dart';

class RoleAssignmentResponseDto {
  const RoleAssignmentResponseDto({
    required this.userId,
    required this.roleId,
    required this.actorUserId,
    required this.at,
  });

  factory RoleAssignmentResponseDto.fromJson(Map<String, dynamic> json) {
    final at = (json['granted_at'] ?? json['revoked_at']) as String;
    return RoleAssignmentResponseDto(
      userId: json['user_id'] as String,
      roleId: json['role_id'] as String,
      actorUserId: (json['granted_by'] ?? json['revoked_by']) as String?,
      at: DateTime.parse(at),
    );
  }

  final String userId;
  final String roleId;
  final String? actorUserId;
  final DateTime at;

  RoleAssignmentResult toEntity() {
    return RoleAssignmentResult(
      userId: userId,
      roleId: roleId,
      actorUserId: actorUserId,
      at: at,
    );
  }
}
