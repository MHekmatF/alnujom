sealed class Failure {
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
