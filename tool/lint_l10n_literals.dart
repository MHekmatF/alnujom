// Literal-string lint guard for FR-006 / SC-004.
//
// Walks every .dart file under lib/, parses each via package:analyzer, and
// flags raw string literals (including interpolations) passed to a locked
// allowlist of user-visible widget constructor parameters. Files matching
// the `l10n_lint_exempt:` block in analysis_options.yaml are skipped.
//
// Exit codes:
//   0 — no violations
//   1 — one or more literal-string violations (per-line report on stdout)
//   2 — script failure (parse error, exemption-list read error, file IO)
//
// Contract: specs/003-localization/contracts/lint-guard-literals.md

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _exemptionConfigPath = 'analysis_options.yaml';
const _libRoot = 'lib';

const _textWidgetConstructors = <String>{'Text', 'SelectableText'};

const _stringNamedParams = <String, Set<String>>{
  'Tooltip': {'message'},
  'IconButton': {'tooltip'},
  'TextField': {
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'prefixText',
    'suffixText',
    'counterText',
  },
  'TextFormField': {
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'prefixText',
    'suffixText',
    'counterText',
  },
  'InputDecoration': {
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'prefixText',
    'suffixText',
    'counterText',
  },
  'TextSpan': {'text'},
};

void main() {
  try {
    final exempts = _readExemptionList(_exemptionConfigPath);
    final libDir = Directory(_libRoot);
    if (!libDir.existsSync()) {
      stderr.writeln('lint_l10n_literals: lib/ directory not found.');
      exitCode = 2;
      return;
    }

    final violations = <_Violation>[];
    final parseFailures = <String>[];

    for (final file in _walkDartFiles(libDir)) {
      final relPath = _toRelative(file.path);
      if (_isExempt(relPath, exempts)) continue;

      final source = file.readAsStringSync();
      final result = parseString(
        content: source,
        path: file.path,
        throwIfDiagnostics: false,
      );

      final syntacticErrors = result.errors
          .where((e) => e.severity.name == 'ERROR')
          .toList();
      if (syntacticErrors.isNotEmpty) {
        parseFailures.add(
          '$relPath: ${syntacticErrors.length} syntactic error(s); first: ${syntacticErrors.first.message}',
        );
        continue;
      }

      final visitor = _LiteralVisitor(relPath, source, result.lineInfo);
      result.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }

    if (parseFailures.isNotEmpty) {
      stderr.writeln('lint_l10n_literals: parse failures encountered:');
      for (final failure in parseFailures) {
        stderr.writeln('  $failure');
      }
      exitCode = 2;
      return;
    }

    violations.sort((a, b) {
      final p = a.path.compareTo(b.path);
      if (p != 0) return p;
      final l = a.line.compareTo(b.line);
      if (l != 0) return l;
      return a.column.compareTo(b.column);
    });

    if (violations.isEmpty) {
      stdout.writeln('Literal lint check passed (0 violations).');
      exitCode = 0;
      return;
    }

    for (final v in violations) {
      stdout.writeln(v);
    }
    final n = violations.length;
    stdout.writeln('$n ${n == 1 ? 'violation' : 'violations'}.');
    exitCode = 1;
  } on Object catch (e, st) {
    stderr.writeln('lint_l10n_literals: $e');
    stderr.writeln(st);
    exitCode = 2;
  }
}

final class _Violation {
  const _Violation({
    required this.path,
    required this.line,
    required this.column,
    required this.snippet,
    required this.construct,
  });

  final String path;
  final int line;
  final int column;
  final String snippet;
  final String construct;

  @override
  String toString() =>
      '$path:$line:$column: literal $snippet passed to $construct '
      '— replace with AppStrings.of(context).loc.<key>';
}

final class _LiteralVisitor extends RecursiveAstVisitor<void> {
  _LiteralVisitor(this.relPath, this.source, this.lineInfo);

  final String relPath;
  final String source;
  final LineInfo lineInfo;
  final violations = <_Violation>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = _baseTypeName(node);
    final args = node.argumentList.arguments;

    if (typeName != null && _textWidgetConstructors.contains(typeName)) {
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is! NamedExpression && first is StringLiteral) {
          _flag(first, '$typeName()');
        }
      }
    }

    final allowedParams = typeName == null
        ? null
        : _stringNamedParams[typeName];
    if (allowedParams != null) {
      for (final arg in args) {
        if (arg is! NamedExpression) continue;
        final paramName = arg.name.label.name;
        if (!allowedParams.contains(paramName)) continue;
        final value = arg.expression;
        if (value is StringLiteral) {
          _flag(value, '$typeName.$paramName');
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  void _flag(AstNode node, String construct) {
    final loc = lineInfo.getLocation(node.offset);
    violations.add(
      _Violation(
        path: relPath,
        line: loc.lineNumber,
        column: loc.columnNumber,
        snippet: _excerpt(node),
        construct: construct,
      ),
    );
  }

  String _excerpt(AstNode node) {
    var text = source.substring(node.offset, node.end);
    text = text.replaceAll('\n', '\\n').replaceAll('\r', '');
    if (text.length > 60) {
      text = '${text.substring(0, 57)}...';
    }
    return text;
  }
}

String? _baseTypeName(InstanceCreationExpression node) {
  final raw = node.constructorName.type.toString();
  final withoutGeneric = raw.contains('<')
      ? raw.substring(0, raw.indexOf('<'))
      : raw;
  final withoutPrefix = withoutGeneric.contains('.')
      ? withoutGeneric.substring(withoutGeneric.lastIndexOf('.') + 1)
      : withoutGeneric;
  final trimmed = withoutPrefix.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Iterable<File> _walkDartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _toRelative(String absolutePath) {
  final cwd = Directory.current.path.replaceAll('\\', '/');
  final norm = absolutePath.replaceAll('\\', '/');
  if (norm.startsWith('$cwd/')) {
    return norm.substring(cwd.length + 1);
  }
  return norm;
}

bool _isExempt(String relPath, List<String> patterns) {
  return patterns.any((pat) => _matchesGlob(pat, relPath));
}

bool _matchesGlob(String pattern, String path) {
  final buffer = StringBuffer('^');
  var i = 0;
  while (i < pattern.length) {
    final c = pattern[i];
    if (c == '*') {
      if (i + 1 < pattern.length && pattern[i + 1] == '*') {
        buffer.write('.*');
        i += 2;
      } else {
        buffer.write('[^/]*');
        i += 1;
      }
    } else if (r'.+^$()|[]{}\'.contains(c)) {
      buffer.write('\\');
      buffer.write(c);
      i += 1;
    } else if (c == '?') {
      buffer.write('.');
      i += 1;
    } else {
      buffer.write(c);
      i += 1;
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString()).hasMatch(path);
}

List<String> _readExemptionList(String yamlPath) {
  final file = File(yamlPath);
  if (!file.existsSync()) {
    throw StateError('exemption config not found: $yamlPath');
  }
  final lines = file.readAsLinesSync();
  final exempt = <String>[];
  var inBlock = false;
  for (final raw in lines) {
    final stripped = raw.split('#').first;
    if (RegExp(r'^l10n_lint_exempt\s*:').hasMatch(stripped)) {
      inBlock = true;
      continue;
    }
    if (!inBlock) continue;

    final listMatch = RegExp(r'^\s+-\s*(.+?)\s*$').firstMatch(stripped);
    if (listMatch != null) {
      var pattern = listMatch.group(1)!.trim();
      if ((pattern.startsWith("'") && pattern.endsWith("'")) ||
          (pattern.startsWith('"') && pattern.endsWith('"'))) {
        pattern = pattern.substring(1, pattern.length - 1);
      }
      if (pattern.isNotEmpty) exempt.add(pattern);
      continue;
    }

    if (stripped.trim().isEmpty) continue;
    if (!RegExp(r'^\s').hasMatch(stripped)) break;
    break;
  }
  return exempt;
}
