import 'package:equatable/equatable.dart';

class RoleAssignmentResult extends Equatable {
  const RoleAssignmentResult({
    required this.userId,
    required this.roleId,
    required this.actorUserId,
    required this.at,
  });

  final String userId;
  final String roleId;
  final String? actorUserId;
  final DateTime at;

  @override
  List<Object?> get props => [userId, roleId, actorUserId, at];
}
