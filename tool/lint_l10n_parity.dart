// Translation-key parity guard for FR-005 / SC-005.
//
// Compares the non-metadata key sets of lib/l10n/app_ar.arb and
// lib/l10n/app_en.arb. Exit codes:
//   0 — perfect parity
//   1 — parity violation (per-locale missing-key report on stdout)
//   2 — script failure (file IO or JSON parse error; diagnostic on stderr)
//
// Contract: specs/003-localization/contracts/lint-guard-parity.md

import 'dart:convert';
import 'dart:io';

const _arPath = 'lib/l10n/app_ar.arb';
const _enPath = 'lib/l10n/app_en.arb';

void main() {
  final arKeys = _readTranslationKeys(_arPath);
  final enKeys = _readTranslationKeys(_enPath);
  if (arKeys == null || enKeys == null) {
    exitCode = 2;
    return;
  }

  final missingInAr = enKeys.difference(arKeys);
  final missingInEn = arKeys.difference(enKeys);

  if (missingInAr.isEmpty && missingInEn.isEmpty) {
    final total = arKeys.length;
    stdout.writeln('Translation key parity check passed ($total keys).');
    exitCode = 0;
    return;
  }

  stdout.writeln('Translation key parity check FAILED.');
  stdout.writeln('');
  if (missingInAr.isNotEmpty) {
    _writeMissingSection(_arPath, missingInAr);
  }
  if (missingInEn.isNotEmpty) {
    _writeMissingSection(_enPath, missingInEn);
  }
  final total = missingInAr.length + missingInEn.length;
  stdout.writeln('Total: $total ${total == 1 ? 'violation' : 'violations'}.');
  stdout.writeln('');
  stdout.writeln(
    'To fix: add the missing entries to the indicated ARB file(s) and re-run.',
  );
  exitCode = 1;
}

Set<String>? _readTranslationKeys(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('lint_l10n_parity: file not found: $path');
    return null;
  }

  final String raw;
  try {
    raw = file.readAsStringSync();
  } on FileSystemException catch (e) {
    stderr.writeln('lint_l10n_parity: cannot read $path: ${e.message}');
    return null;
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    stderr.writeln('lint_l10n_parity: invalid JSON in $path: ${e.message}');
    return null;
  }

  if (decoded is! Map<String, dynamic>) {
    stderr.writeln(
      'lint_l10n_parity: expected JSON object at the root of $path; got ${decoded.runtimeType}.',
    );
    return null;
  }

  return decoded.keys.where((key) => !key.startsWith('@')).toSet();
}

void _writeMissingSection(String path, Set<String> keys) {
  final sorted = keys.toList()..sort();
  final count = sorted.length;
  stdout.writeln(
    'Missing in $path ($count ${count == 1 ? 'key' : 'keys'}):',
  );
  for (final key in sorted) {
    stdout.writeln('  - $key');
  }
  stdout.writeln('');
}
