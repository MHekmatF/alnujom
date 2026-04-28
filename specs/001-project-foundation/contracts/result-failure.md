# Contract: Result + Failure

**Layer**: `lib/core/errors/`
**Constitution**: Principle IV (Clean Architecture Flutter)
**Spec requirement**: FR-010

## Purpose

A uniform success/failure return type so that use cases in later phases never throw across architectural boundaries. Data sources catch SDK exceptions and translate them into `FailureResult`; domain code switches exhaustively on the result; presentation code emits BLoC states.

## Public surface

```dart
// lib/core/errors/result.dart

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
```

```dart
// lib/core/errors/failure.dart

sealed class Failure {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.cause, this.stackTrace});
}

final class NetworkFailure extends Failure { ... }
final class CacheFailure extends Failure { ... }
final class ConfigFailure extends Failure { ... }    // backend config missing/invalid (FR-013)
final class UnknownFailure extends Failure { ... }
```

Future phases extend `Failure` with feature-specific subtypes (e.g., `AuthFailure`, `ListingFailure`) — but all must extend `Failure` and supply a `message` consumable by user-facing copy.

## Phase 1 usage points

- `SupabaseClientWrapper.initialize(...)` returns `Result<void>` — `FailureResult(ConfigFailure)` if URL or key is empty (FR-013).
- `PreferencesStore.read*(...)` returns `Result<T?>` — `FailureResult(CacheFailure)` if storage I/O fails.
- `PreferencesStore.write*(...)` returns `Result<void>` — same.

## Rules

- Domain layer code MUST NOT throw across the data → domain → presentation boundary. Catch at the data source; return a `FailureResult`.
- Pattern-match exhaustively in BLoCs/cubits using Dart 3 sealed-class switch:

  ```dart
  switch (result) {
    case Success(:final value):  emit(LoadedState(value));
    case FailureResult(:final failure): emit(ErrorState(failure.message));
  }
  ```

- A `try/catch` block inside a use case is a code-smell and should fail review unless it's adapting a non-Result legacy boundary.

## Helpers (non-exhaustive)

```dart
// lib/core/utils/result_extensions.dart
extension ResultMap<T> on Result<T> {
  Result<U> map<U>(U Function(T) f) => switch (this) {
    Success(:final value) => Success(f(value)),
    FailureResult(:final failure) => FailureResult(failure),
  };
}
```

## Phase 1 verification

- `test/core/errors/result_test.dart` covers: `Success.value` round-trip; `FailureResult.failure` round-trip; sealed-class exhaustiveness compiles; `map` propagates failures.
