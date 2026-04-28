import 'package:alnujom/core/errors/failure.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/utils/result_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success carries its value', () {
      const result = Success<int>(42);

      expect(result.value, 42);
    });

    test('FailureResult carries its failure', () {
      const failure = CacheFailure('cache miss');
      const result = FailureResult<int>(failure);

      expect(result.failure, same(failure));
    });

    test('sealed switch is exhaustive', () {
      String describe(Result<int> result) => switch (result) {
        Success(:final value) => 'success:$value',
        FailureResult(:final failure) => failure.message,
      };

      expect(describe(const Success(1)), 'success:1');
      expect(
        describe(const FailureResult(NetworkFailure('offline'))),
        'offline',
      );
    });

    test('map transforms success values', () {
      const result = Success<int>(2);

      expect(result.map((value) => value * 3), isA<Success<int>>());
      expect((result.map((value) => value * 3) as Success<int>).value, 6);
    });

    test('map propagates the original failure instance', () {
      const failure = UnknownFailure('unknown');
      const result = FailureResult<int>(failure);

      final mapped = result.map((value) => value.toString());

      expect(mapped, isA<FailureResult<String>>());
      expect((mapped as FailureResult<String>).failure, same(failure));
    });
  });
}
