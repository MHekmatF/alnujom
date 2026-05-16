import 'package:equatable/equatable.dart';

import 'role_assignment_summary.dart';

class UserSearchResult extends Equatable {
  const UserSearchResult({
    required this.userId,
    required this.phone,
    required this.username,
    required this.fullName,
    this.currentRoles = const <RoleAssignmentSummary>[],
  });

  final String userId;
  final String? phone;
  final String? username;
  final String? fullName;
  final List<RoleAssignmentSummary> currentRoles;

  UserSearchResult copyWith({List<RoleAssignmentSummary>? currentRoles}) {
    return UserSearchResult(
      userId: userId,
      phone: phone,
      username: username,
      fullName: fullName,
      currentRoles: currentRoles ?? this.currentRoles,
    );
  }

  @override
  List<Object?> get props => [userId, phone, username, fullName, currentRoles];
}
