import 'package:equatable/equatable.dart';

class RoleAssignmentSummary extends Equatable {
  const RoleAssignmentSummary({
    required this.roleId,
    required this.roleKey,
    required this.displayName,
    required this.grantedAt,
  });

  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final DateTime grantedAt;

  @override
  List<Object?> get props => [roleId, roleKey, displayName, grantedAt];
}
