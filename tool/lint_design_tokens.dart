import 'dart:io';

import 'src/lint_design_tokens_lib.dart';

void main(List<String> args) {
  if (args.contains('--fix')) {
    stderr.writeln('--fix is not implemented for the design-token lint guard.');
    exitCode = 2;
    return;
  }

  final paths = args.where((arg) => !arg.startsWith('--')).toList();
  final result = lintDesignTokens(paths: paths);
  for (final violation in result.violations) {
    stdout.writeln(violation);
  }
  exitCode = result.isClean ? 0 : 1;
}
