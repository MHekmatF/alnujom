# Contract: AppLogger

**Layer**: `lib/core/logging/`
**Spec requirement**: FR-011
**Phase 1 sink**: `dart:developer.log` in debug; no-op in release (research.md Decision 7)

## Purpose

A project-defined logging interface usable from any architectural layer. A future phase can register a different implementation (Sentry, Crashlytics, file sink) by changing the DI binding — call sites do not change.

## Public surface

```dart
// lib/core/logging/app_logger.dart

abstract interface class AppLogger {
  void debug(String message, {Object? error, StackTrace? stackTrace, String? tag});
  void info(String message, {String? tag});
  void warning(String message, {Object? error, StackTrace? stackTrace, String? tag});
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag});
}
```

```dart
// lib/core/logging/console_logger.dart

@LazySingleton(as: AppLogger)
final class ConsoleLogger implements AppLogger {
  // In debug builds (kDebugMode), forward to dart:developer.log with severity.
  // In release builds, all methods are no-ops (FR-011: verbose only in debug).
}
```

## Rules

- Every `lib/core/` module MAY accept an `AppLogger` via constructor; production wiring is via DI.
- No call site uses `print(...)` — `flutter analyze` is configured to flag `avoid_print` as a fatal rule.
- A `tag` is conventionally the class or feature name (e.g., `tag: 'SupabaseClientWrapper'`); used as a `name` argument to `dart:developer.log`.
- `debug` level: noisy diagnostic data; `info`: significant state transitions; `warning`: recoverable problems including FR-013 backend-config-missing; `error`: unrecoverable problems that would normally throw.

## Phase 1 usage points

- `SupabaseClientWrapperImpl.initialize(...)` logs a `warning` when config is missing (FR-013).
- `ThemeCubit` and `LocaleCubit` log a `warning` when `PreferencesStore` write fails.
- `main.dart` logs an `info` when DI configuration completes.

## Phase 1 verification

- `test/core/logging/console_logger_test.dart` confirms: in `kDebugMode`-true tests, calling `info(...)` produces a single `dart:developer.log` invocation with the right severity and name; in `kDebugMode`-false simulated tests (via build flag), the same calls are no-ops.

## Future replacement plug-point

A later spec adding crash reporting or remote logging registers a different `AppLogger` impl in DI:

```dart
@LazySingleton(as: AppLogger, env: ['prod'])
final class SentryLogger implements AppLogger { ... }
```

Call sites do not change.
