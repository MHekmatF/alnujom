class AssignRoleRequestDto {
  const AssignRoleRequestDto({
    required this.targetUserId,
    required this.targetRoleId,
    this.confirmationToken,
  });

  final String targetUserId;
  final String targetRoleId;
  final String? confirmationToken;

  Map<String, dynamic> toJson() {
    return {
      'target_user_id': targetUserId,
      'target_role_id': targetRoleId,
      'confirmation_token': confirmationToken,
    };
  }
}
