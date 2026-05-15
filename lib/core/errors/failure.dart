// Phase 5 (spec/005-auth-profile) loosened from `sealed` to `abstract` so
// feature folders can define their own typed failure hierarchies (AuthFailure,
// ProfileFailure) that still slot into `Result<T>` / `FailureResult<T>`.
// The four general failures below remain `final` and Phase 4's call sites are
// unchanged.
abstract class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause, super.stackTrace});
}

final class ConfigFailure extends Failure {
  const ConfigFailure(super.message, {super.cause, super.stackTrace});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}
