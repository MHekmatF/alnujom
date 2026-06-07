import 'dart:io';

final class DesignTokenViolation {
  const DesignTokenViolation({
    required this.path,
    required this.line,
    required this.column,
    required this.rule,
    required this.message,
    required this.snippet,
  });

  final String path;
  final int line;
  final int column;
  final String rule;
  final String message;
  final String snippet;

  @override
  String toString() => '$path:$line:$column: $message `$snippet`.';
}

final class DesignTokenLintResult {
  const DesignTokenLintResult(this.violations);

  final List<DesignTokenViolation> violations;

  bool get isClean => violations.isEmpty;
}

const Set<String> _defaultAllowedFiles = {
  'lib/core/theme/colors.dart',
  'lib/core/theme/typography.dart',
  'lib/core/theme/spacing.dart',
  'lib/core/theme/radii.dart',
  'lib/core/theme/elevation.dart',
  'lib/core/theme/color_palette.dart',
  'lib/core/theme/app_theme.dart',
  'lib/core/theme/gradients.dart',
};

final RegExp _rawColor = RegExp(r'\bColor\(\s*0x[0-9A-Fa-f]+');
final RegExp _inlineTextStyle = RegExp(r'\bTextStyle\s*\(');
final RegExp _edgeInsetsLiteral = RegExp(
  // Catches both positional (`EdgeInsets.all(16)`) and named-parameter
  // forms (`EdgeInsets.symmetric(horizontal: 16, vertical: 8)`,
  // `EdgeInsets.only(top: 4)`). The first `\d` group covers the bare
  // positional case; the second covers literals after a name+colon or
  // a comma separator.
  r'\bEdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\('
  r'\s*(?:\d+(?:\.\d+)?|[^)]*[: ,]\s*\d+(?:\.\d+)?)',
);
final RegExp _borderRadiusLiteral = RegExp(
  r'\bBorderRadius\.circular\(\s*\d+(?:\.\d+)?',
);
final RegExp _boxShadowLiteral = RegExp(
  r'\bBoxShadow\s*\([^\)]*(?:blurRadius|spreadRadius|offset)\s*:\s*(?:Offset\(\s*)?\d+(?:\.\d+)?',
);
final RegExp _archiveReference = RegExp(
  r"archive/luxury|Playfair Display|Reem Kufi",
);

DesignTokenLintResult lintDesignTokens({
  Directory? root,
  Iterable<String>? paths,
}) {
  final base = root ?? Directory.current;
  final files = <File>[];
  final requested = paths?.where((path) => path.trim().isNotEmpty).toList();

  if (requested == null || requested.isEmpty) {
    final lib = Directory('${base.path}${Platform.pathSeparator}lib');
    if (lib.existsSync()) {
      files.addAll(_dartFiles(lib));
    }
  } else {
    for (final path in requested) {
      final entity =
          FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound
          ? File('${base.path}${Platform.pathSeparator}$path')
          : File(path);
      if (entity.existsSync()) {
        files.add(entity);
        continue;
      }
      final dir = Directory(entity.path);
      if (dir.existsSync()) {
        files.addAll(_dartFiles(dir));
      }
    }
  }

  final violations = <DesignTokenViolation>[];
  for (final file in files.where((file) => file.path.endsWith('.dart'))) {
    final relativePath = _normalizePath(_relative(file.path, base.path));
    if (_defaultAllowedFiles.contains(relativePath)) {
      continue;
    }

    final isTestFile = relativePath.startsWith('test/');
    final source = file.readAsStringSync();
    violations.addAll(
      _scanFile(relativePath, source, includeSpacingRules: !isTestFile),
    );
  }

  violations.sort((a, b) {
    final pathCompare = a.path.compareTo(b.path);
    if (pathCompare != 0) return pathCompare;
    final lineCompare = a.line.compareTo(b.line);
    if (lineCompare != 0) return lineCompare;
    return a.column.compareTo(b.column);
  });

  return DesignTokenLintResult(violations);
}

List<DesignTokenViolation> lintSource(String path, String source) {
  return _scanFile(_normalizePath(path), source, includeSpacingRules: true);
}

List<DesignTokenViolation> _scanFile(
  String path,
  String source, {
  required bool includeSpacingRules,
}) {
  final checks = <_RuleCheck>[
    _RuleCheck(
      'L1',
      _rawColor,
      'forbidden raw color literal - use AppColors.of(context) instead',
    ),
    _RuleCheck(
      'L2',
      _inlineTextStyle,
      'forbidden inline TextStyle - use AppTextStyles.of(context) instead',
    ),
    _RuleCheck(
      'L6',
      _archiveReference,
      'forbidden archived luxury design reference',
    ),
  ];

  if (includeSpacingRules) {
    checks.addAll([
      _RuleCheck(
        'L3',
        _edgeInsetsLiteral,
        'forbidden raw EdgeInsets literal - use AppSpacing tokens instead',
      ),
      _RuleCheck(
        'L4',
        _borderRadiusLiteral,
        'forbidden raw BorderRadius literal - use AppRadii tokens instead',
      ),
      _RuleCheck(
        'L5',
        _boxShadowLiteral,
        'forbidden raw BoxShadow literal - use AppElevation tokens instead',
      ),
    ]);
  }

  final violations = <DesignTokenViolation>[];
  for (final check in checks) {
    for (final match in check.pattern.allMatches(source)) {
      final position = _lineColumn(source, match.start);
      violations.add(
        DesignTokenViolation(
          path: path,
          line: position.$1,
          column: position.$2,
          rule: check.rule,
          message: check.message,
          snippet: match.group(0) ?? check.rule,
        ),
      );
    }
  }
  return violations;
}

List<File> _dartFiles(Directory directory) {
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

(int, int) _lineColumn(String source, int offset) {
  var line = 1;
  var column = 1;
  for (var i = 0; i < offset; i += 1) {
    if (source.codeUnitAt(i) == 10) {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return (line, column);
}

String _relative(String path, String root) {
  final normalizedPath = _normalizePath(path);
  final normalizedRoot = _normalizePath(root);
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

final class _RuleCheck {
  const _RuleCheck(this.rule, this.pattern, this.message);

  final String rule;
  final RegExp pattern;
  final String message;
}
