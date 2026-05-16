import 'package:equatable/equatable.dart';

class RoleWithCounts extends Equatable {
  const RoleWithCounts({
    required this.roleId,
    required this.roleKey,
    required this.displayName,
    required this.description,
    required this.isSystem,
    required this.permissionCount,
    required this.userCount,
    required this.updatedAt,
  });

  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final int permissionCount;
  final int userCount;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    roleId,
    roleKey,
    displayName,
    description,
    isSystem,
    permissionCount,
    userCount,
    updatedAt,
  ];
}
