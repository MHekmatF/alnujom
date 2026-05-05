# Contract: lint_l10n_literals.dart

`tool/lint_l10n_literals.dart` — NEW in Phase 3. Standalone Dart script that fails the build on raw string literals passed to user-visible widget constructors anywhere under `lib/`, except files matching the lint exemption list.

Realises FR-006 (literal-string lint guard) and SC-004 (100% of user-visible strings via the translation system).

## Invocation

```bash
dart run tool/lint_l10n_literals.dart
```

No arguments. Reads the exemption list from `analysis_options.yaml` at the repository root.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | No violations. |
| `1` | One or more literal-string violations detected. The script writes one line per violation to stdout. |
| `2` | Script failure (file failed to parse, exemption list malformed, file IO error). The script writes a diagnostic to stderr. |

CI treats `1` and `2` identically (red build).

## Inputs

- All files matching `lib/**/*.dart` in the repository working tree.
- The exemption list from `analysis_options.yaml` → top-level `l10n_lint_exempt:` block (see contract `lint-guard-parity.md` and Phase 0 R-05 for the format).

## Inspected constructor allowlist

The script inspects the AST and flags any string literal (or interpolation, or string concatenation evaluating to a string at compile time) passed as the named or positional argument to ANY of the following constructors / parameters:

| Constructor / parameter | Notes |
|-------------------------|-------|
| `Text(String, ...)` (positional) | The classic flag. Includes `Text('hello')`, `Text('hi $user')`, `Text('a' + 'b')`. |
| `RichText(text: TextSpan(text: ...))` | Indirect — the `TextSpan.text` literal is also flagged. |
| `AppBar.title:` | When the value is `Text('literal')`, the literal is flagged. |
| `AppBar.actions:` | When list items contain `Text('literal')`, each is flagged. |
| `ElevatedButton.child` / `OutlinedButton.child` / `TextButton.child` / `FilledButton.child` | When `Text('literal')`, flagged. |
| `IconButton.tooltip:` | Flagged. |
| `Tooltip.message:` | Flagged. |
| `SnackBar.content:` | When `Text('literal')`, flagged. |
| `AlertDialog.title:` / `AlertDialog.content:` | When `Text('literal')`, flagged. |
| `TextField` / `TextFormField` / `InputDecoration` — `labelText`, `hintText`, `helperText`, `errorText`, `prefixText`, `suffixText`, `counterText` | All flagged. |
| `MenuItem` / `DropdownMenuItem.child` | When `Text('literal')`, flagged. |

**Not flagged** (intentionally narrow scope):
- `debugPrint('...')`, `print('...')`, `assert(..., '...')` — diagnostic strings only, not user-visible.
- Asset paths, route names, log tags, key strings — opaque identifiers, not user copy.
- `Image.asset('assets/...')`, `package:flutter/services.dart` paths — opaque identifiers.

The allowlist is finite and lives as a `const Set<String>` in the script's source. Adding a constructor is a one-line edit reviewed via PR.

## Output format

```text
H:\alnujom-project\lib\features\foo\presentation\foo_page.dart:42:18: literal "Welcome back" passed to Text() — replace with AppStrings.of(context).loc.<key>
H:\alnujom-project\lib\shell\app_shell.dart:118:33: literal "Settings" passed to AppBar.title (Text) — replace with AppStrings.of(context).loc.<key>
2 violations.
```

Paths are absolute on Windows (matching the repo working tree); CI may normalize. The trailing summary line is required so a parser (or human) can confirm the count without recounting.

## Exemption-list semantics

A file is exempt if its repo-relative path matches at least one glob in `analysis_options.yaml` → `l10n_lint_exempt:`. Glob syntax: `**` for any number of path segments, `*` for any sequence within a segment.

Phase 3 floor patterns (verbatim):

```yaml
l10n_lint_exempt:
  - lib/l10n/**.arb
  - lib/l10n/app_localizations*.dart
  - lib/debug/**
  - test/goldens/**
```

## Implementation notes

- Parses each `.dart` file via `package:analyzer` `parseFile` — no resolution / type inference required. Parsing is fast enough that a full repo scan completes in well under 2 s on the dev box; CI overhead is negligible.
- For string interpolation (`'$variable'`, `'literal $variable literal'`), the script flags the whole interpolation as a literal — the developer is expected to migrate to a parameterized translation key.
- For const string variables (`const _kHello = 'hello'; ... Text(_kHello);`), the script flags the literal at the assignment site if the assignment lives under `lib/`. Const-folding chases is left to a future refinement; for Phase 3 floor coverage, flagging at assignment is sufficient because const literals live in the same file as their consumer in 99% of cases.

## Invariants

- The script MUST NOT mutate any file. It is read-only.
- The script MUST be deterministic — the same working tree always produces the same output.
- The script MUST NOT depend on a running Flutter SDK (no `flutter pub get`, no analyzer plugins). Plain `dart run` only.

## Verification

Manual, per `quickstart.md` step 8: add `Text("hello world")` to a temporary file under `lib/features/` (or any non-exempt path), run `dart run tool/lint_l10n_literals.dart`, observe exit code 1 with the file:line:col flag. Replace the literal with an `AppStrings.of(context).loc.<key>` lookup, add the key to both ARB files, re-run, observe exit code 0.
