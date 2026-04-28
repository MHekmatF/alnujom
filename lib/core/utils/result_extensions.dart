import '../errors/result.dart';

extension ResultExtensions<T> on Result<T> {
  Result<U> map<U>(U Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    FailureResult(:final failure) => FailureResult(failure),
  };

  U fold<U>(
    U Function(T value) onSuccess,
    U Function(FailureResult<T> failure) onFailure,
  ) => switch (this) {
    Success(:final value) => onSuccess(value),
    final FailureResult<T> failure => onFailure(failure),
  };
}
