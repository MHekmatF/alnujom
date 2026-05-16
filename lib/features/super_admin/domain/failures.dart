import '../../../core/errors/failure.dart';

sealed class SuperAdminFailure extends Failure {
  const SuperAdminFailure(super.message, {super.cause, super.stackTrace});
}

final class BackendFailure extends SuperAdminFailure {
  const BackendFailure(super.message, {super.cause, super.stackTrace});
}
