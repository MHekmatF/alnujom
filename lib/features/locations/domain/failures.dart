import '../../../core/errors/failure.dart';

sealed class LocationsFailure extends Failure {
  const LocationsFailure(super.message, {super.cause, super.stackTrace});
}

final class NotAuthorizedFailure extends LocationsFailure {
  const NotAuthorizedFailure([super.message = 'not authorized']);
}

final class KeyAlreadyUsedFailure extends LocationsFailure {
  const KeyAlreadyUsedFailure() : super('key already used');
}

final class SystemRowProtectedFailure extends LocationsFailure {
  const SystemRowProtectedFailure() : super('system row protected');
}

final class ForeignKeyViolationFailure extends LocationsFailure {
  const ForeignKeyViolationFailure() : super('foreign key violation');
}

final class LocationsNetworkFailure extends LocationsFailure {
  const LocationsNetworkFailure([super.message = 'network error']);
}

final class LocationsUnknownFailure extends LocationsFailure {
  const LocationsUnknownFailure(super.message, {super.cause, super.stackTrace});
}
