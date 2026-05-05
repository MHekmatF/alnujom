import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/lint_design_tokens_lib.dart';

void main() {
  test('clean fixture has no design-token violations', () {
    final result = lintDesignTokens(paths: ['test/lint/fixtures/clean.dart']);

    expect(result.violations, isEmpty);
  });

  test('violations fixture reports every lint rule', () {
    final source = File(
      'test/lint/fixtures/violations.dart',
    ).readAsStringSync();
    final violations = lintSource('test/lint/fixtures/violations.dart', source);
    final rules = violations.map((violation) => violation.rule).toSet();

    expect(violations, hasLength(greaterThanOrEqualTo(6)));
    expect(rules, containsAll(<String>{'L1', 'L2', 'L3', 'L4', 'L5', 'L6'}));
  });
}
