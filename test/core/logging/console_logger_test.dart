import 'package:alnujom/core/logging/console_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsoleLogger', () {
    test('debug-build calls write severity and tag to the sink', () {
      final records = <({String message, int level, String name})>[];
      final logger = ConsoleLogger.test(
        isDebug: true,
        logSink:
            (
              message, {
              int level = 0,
              String name = '',
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add((message: message, level: level, name: name));
            },
      );

      logger.debug('debug message', tag: 'DebugTag');
      logger.info('info message', tag: 'InfoTag');
      logger.warning('warning message', tag: 'WarningTag');
      logger.error('error message', tag: 'ErrorTag');

      expect(records, [
        (message: 'debug message', level: 300, name: 'DebugTag'),
        (message: 'info message', level: 800, name: 'InfoTag'),
        (message: 'warning message', level: 900, name: 'WarningTag'),
        (message: 'error message', level: 1000, name: 'ErrorTag'),
      ]);
    });

    test('release-build calls are no-ops', () {
      final records = <String>[];
      final logger = ConsoleLogger.test(
        isDebug: false,
        logSink:
            (
              message, {
              int level = 0,
              String name = '',
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(message);
            },
      );

      logger.debug('debug');
      logger.info('info');
      logger.warning('warning');
      logger.error('error');

      expect(records, isEmpty);
    });
  });
}
