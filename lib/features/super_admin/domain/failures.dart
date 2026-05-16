import '../../../core/errors/failure.dart';

sealed class SuperAdminFailure extends Failure {
  const SuperAdminFailure(super.message, {super.cause, super.stackTrace});
}

final class BackendFailure extends SuperAdminFailure {
  const BackendFailure(super.message, {super.cause, super.stackTrace});
}

final class RoleEditConflictFailure extends SuperAdminFailure {
  const RoleEditConflictFailure() : super('role concurrent edit');
}

final class SuperAdminPermissionsImmutableFailure extends SuperAdminFailure {
  const SuperAdminPermissionsImmutableFailure()
    : super('super_admin permission set is immutable');
}

final class SystemRoleImmutableFailure extends SuperAdminFailure {
  const SystemRoleImmutableFailure() : super('system role is immutable');
}

final class RolePermissionDeniedFailure extends SuperAdminFailure {
  const RolePermissionDeniedFailure() : super('permission denied');
}

final class RoleHasUsersFailure extends SuperAdminFailure {
  const RoleHasUsersFailure() : super('role has assigned users');
}

final class RoleKeyDuplicateFailure extends SuperAdminFailure {
  const RoleKeyDuplicateFailure() : super('role key already exists');
}

final class InvalidOpFailure extends SuperAdminFailure {
  const InvalidOpFailure() : super('invalid operation');
}

final class SuperAdminGrantConfirmationFailedFailure extends SuperAdminFailure {
  const SuperAdminGrantConfirmationFailedFailure()
    : super('super_admin grant confirmation failed');
}

final class SuperAdminSelfRevokeForbiddenFailure extends SuperAdminFailure {
  const SuperAdminSelfRevokeForbiddenFailure()
    : super('super_admin self-revoke forbidden');
}

final class AssignPermissionDeniedFailure extends SuperAdminFailure {
  const AssignPermissionDeniedFailure() : super('assign permission denied');
}

final class RevokePermissionDeniedFailure extends SuperAdminFailure {
  const RevokePermissionDeniedFailure() : super('revoke permission denied');
}

final class UserAlreadyHoldsRoleFailure extends SuperAdminFailure {
  const UserAlreadyHoldsRoleFailure() : super('user already holds role');
}

final class UserDoesNotHoldRoleFailure extends SuperAdminFailure {
  const UserDoesNotHoldRoleFailure() : super('user does not hold role');
}
