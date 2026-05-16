import 'package:equatable/equatable.dart';

class RoleMutationResult extends Equatable {
  const RoleMutationResult({
    required this.roleId,
    required this.roleKey,
    required this.displayName,
    required this.description,
    required this.permissionKeys,
    required this.updatedAt,
  });

  final String roleId;
  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final List<String> permissionKeys;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    roleId,
    roleKey,
    displayName,
    description,
    permissionKeys,
    updatedAt,
  ];
}

sealed class MutateRoleParams extends Equatable {
  const MutateRoleParams();
}

final class CreateRoleParams extends MutateRoleParams {
  const CreateRoleParams({
    required this.roleKey,
    required this.displayName,
    required this.description,
    required this.permissionKeys,
  });

  final String roleKey;
  final Map<String, String> displayName;
  final String? description;
  final List<String> permissionKeys;

  @override
  List<Object?> get props => [
    roleKey,
    displayName,
    description,
    permissionKeys,
  ];
}

final class UpdateRoleParams extends MutateRoleParams {
  const UpdateRoleParams({
    required this.roleId,
    required this.displayName,
    required this.description,
    required this.permissionKeys,
    required this.expectedUpdatedAt,
  });

  final String roleId;
  final Map<String, String> displayName;
  final String? description;
  final List<String> permissionKeys;
  final DateTime expectedUpdatedAt;

  @override
  List<Object?> get props => [
    roleId,
    displayName,
    description,
    permissionKeys,
    expectedUpdatedAt,
  ];
}
