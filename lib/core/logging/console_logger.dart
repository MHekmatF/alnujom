import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'app_logger.dart';
import 'log_redaction.dart';

typedef DeveloperLogSink =
    void Function(
      String message, {
      int level,
      String name,
      Object? error,
      StackTrace? stackTrace,
    });

@LazySingleton(as: AppLogger)
final class ConsoleLogger implements AppLogger {
  ConsoleLogger() : this._(isDebug: kDebugMode, logSink: _developerLog);

  @visibleForTesting
  ConsoleLogger.test({required bool isDebug, required DeveloperLogSink logSink})
    : this._(isDebug: isDebug, logSink: logSink);

  ConsoleLogger._({required bool isDebug, required DeveloperLogSink logSink})
    : _isDebug = isDebug,
      _logSink = logSink;

  final bool _isDebug;
  final DeveloperLogSink _logSink;

  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) =>
      _log(message, level: 300, error: error, stackTrace: stackTrace, tag: tag);

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) =>
      _log(message, level: 800, error: error, stackTrace: stackTrace, tag: tag);

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) =>
      _log(message, level: 900, error: error, stackTrace: stackTrace, tag: tag);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) => _log(
    message,
    level: 1000,
    error: error,
    stackTrace: stackTrace,
    tag: tag,
  );

  void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_isDebug) {
      return;
    }

    // Scrub tokens/PII even from debug output, so a leaked debug APK or an
    // attached debug session never surfaces a credential (security L1/logging).
    final safeMessage = LogRedaction.redactText(message);
    final safeError = error == null
        ? null
        : LogRedaction.redactText(error.toString());

    _logSink(
      safeMessage,
      level: level,
      name: tag ?? 'AlNujom',
      error: safeError,
      stackTrace: stackTrace,
    );

    // `developer.log` only surfaces in DevTools; mirror to `debugPrint` so the
    // line is also visible in `flutter run`'s terminal (spec.md AS-1.3).
    final severity = switch (level) {
      >= 1000 => 'ERROR',
      >= 900 => 'WARNING',
      >= 800 => 'INFO',
      _ => 'DEBUG',
    };
    debugPrint('[${tag ?? 'AlNujom'}] $severity: $safeMessage');
    if (safeError != null) {
      debugPrint('  error: $safeError');
    }
    if (stackTrace != null) {
      debugPrint('  stack: $stackTrace');
    }
  }

  static void _developerLog(
    String message, {
    int level = 0,
    String name = '',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      level: level,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
