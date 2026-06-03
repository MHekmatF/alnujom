# Contract — Crash reporting & the `CrashReporter` seam (CR)

**Owner phase**: CR. **Principles**: III (no PII/secret leak), IX (domain SDK-free), XI (Android-only dep).

## Symbols CR exports (new)

```dart
// lib/core/logging/crash_reporter.dart
abstract interface class CrashReporter {
  Future<void> init({required String dsn, required String environment});
  Future<void> recordError(Object error, StackTrace? stack, {Map<String, Object?> context});
  void addBreadcrumb(String message, {String? category});
  Future<void> close();
}
```

- `SentryCrashReporter implements CrashReporter` — `@LazySingleton(as: CrashReporter)` when DSN non-empty; wraps `sentry_flutter`; installs the **`beforeSend` scrub** (data-model §2).
- `NoopCrashReporter implements CrashReporter` — bound when DSN empty; all methods no-op (mirrors `NoopPushMessagingService`).

## Wiring (`main.dart`, amended)

1. Read DSN from dart-define (`--dart-define-from-file=.env.json`, key e.g. `SENTRY_DSN`). Empty ⇒ Noop path, **no init**.
2. Guarded init (`try/catch` like the Phase 22 Firebase guard) — a throw/timeout MUST NOT block `runApp` (FR-007).
3. Run the existing bootstrap inside `runZonedGuarded`; set `FlutterError.onError` and `PlatformDispatcher.onError` to forward to `CrashReporter.recordError`.
4. Enablement: release/profile only; debug stays console-only (`ConsoleLogger` already no-ops outside `kDebugMode`).

## Invariants (verified)

- The **existing `AppLogger` interface is unchanged**; CR adds a parallel `CrashReporter` seam (the two may be composed later, but CR does not break `AppLogger`'s contract).
- **No `domain/` file imports `package:sentry_flutter`** or `CrashReporter`'s impl — only `core` + `main.dart` reference it (SC-008, Principle IX).
- Every transmitted event is scrubbed (data-model §2): no synthetic-email/phone, no Vault material, no decrypted PII, no tokens (FR-006).
- Empty-DSN ⇒ inert; unreachable dashboard ⇒ app runs normally (FR-007).
