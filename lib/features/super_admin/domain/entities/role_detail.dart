import 'package:equatable/equatable.dart';

class RoleDetail extends Equatable {
  const RoleDetail({
    required this.roleId,
    required this.roleKey,
    required this.displayName,
    required this.description,
    required this.isSystem,
    required this.permissionKeys,
    required this.updatedAt,
  });

  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final bool isSystem;
  final List<String> permissionKeys;
  final DateTime updatedAt;

  RoleDetail copyWith({
    Map<String, String>? displayName,
    String? description,
    List<String>? permissionKeys,
  }) {
    return RoleDetail(
      roleId: roleId,
      roleKey: roleKey,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isSystem: isSystem,
      permissionKeys: permissionKeys ?? this.permissionKeys,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    roleId,
    roleKey,
    displayName,
    description,
    isSystem,
    permissionKeys,
    updatedAt,
  ];
}
