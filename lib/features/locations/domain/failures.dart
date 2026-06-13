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

/// Phase 10 — raised when `getAreaCentroid` finds the row but its centroid
/// columns are NULL. Should never happen post-T008 seed; defensive only.
final class CentroidMissingFailure extends LocationsFailure {
  const CentroidMissingFailure() : super('centroid missing for area');
}

/// Phase 29 — the area form was saved without picking a map centroid.
/// Surfaced as a friendly l10n message so the user never hits a raw 23502.
final class CentroidRequiredFailure extends LocationsFailure {
  const CentroidRequiredFailure() : super('centroid required for area');
}

/// Phase 29 — the picked/entered centroid is outside Syria's valid bounds
/// (lat 32..37, lng 35..43). Surfaced before the insert so the user never
/// hits a raw 23514 CHECK violation.
final class CentroidOutOfBoundsFailure extends LocationsFailure {
  const CentroidOutOfBoundsFailure() : super('centroid out of bounds');
}
