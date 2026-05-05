# Contract: lint_l10n_parity.dart

`tool/lint_l10n_parity.dart` — NEW in Phase 3. Standalone Dart script that fails the build when the set of translation keys differs between `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`.

Realises FR-005 (translation-key parity check) and SC-005 (every key has both `ar` and `en` entries).

## Invocation

```bash
dart run tool/lint_l10n_parity.dart
```

No arguments.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Perfect parity. Every non-metadata key in `app_ar.arb` is present in `app_en.arb`, and vice versa. |
| `1` | Parity violation. The script writes a per-locale list of missing keys to stdout. |
| `2` | Script failure (file unreadable, invalid JSON, missing). Diagnostic to stderr. |

CI treats `1` and `2` identically (red build).

## Inputs

- `lib/l10n/app_ar.arb` (the Arabic ARB file)
- `lib/l10n/app_en.arb` (the English ARB file)

Both paths are hardcoded in the script. If the project ever adds a third locale, the script is extended (a 5-line change) — out of Phase 3 scope.

## Algorithm

1. Read both files. Decode each as JSON. On parse failure, exit `2`.
2. Extract the set of "translation keys" from each file by filtering JSON keys that **do not** start with `@` (this excludes `@@locale` and per-key `@key` metadata descriptors).
3. Compute `missing_in_ar = en_keys - ar_keys` and `missing_in_en = ar_keys - en_keys`.
4. If both sets are empty, exit `0`.
5. Otherwise, write a report (format below) and exit `1`.

## Output format

When parity is broken:

```text
Translation key parity check FAILED.

Missing in lib/l10n/app_ar.arb (3 keys):
  - errorOffline
  - errorRetryAction
  - themeGalleryComponentsSectionHeader

Missing in lib/l10n/app_en.arb (1 key):
  - appTitleAlt

Total: 4 violations.

To fix: add the missing entries to the indicated ARB file(s) and re-run.
```

When parity is intact, the script prints `Translation key parity check passed (N keys).` and exits `0`.

## Metadata handling

ARB metadata keys are excluded from the parity comparison:
- `@@locale` — locale identifier; tied to filename, not a translation key.
- `@<keyname>` — per-key metadata (placeholder declarations, descriptions). The presence of a `@<keyname>` block in one file but not the other is currently NOT flagged by Phase 3's parity check; this is a known gap. Future refinement: add a "metadata parity" mode that warns (but does not fail) on metadata drift. Out of Phase 3 scope.

## Invariants

- The script MUST NOT mutate any file. It is read-only.
- The script MUST exit deterministically — repeated invocation on an unchanged tree always yields the same output.
- The script MUST NOT require a running Flutter SDK; plain `dart run` only.
- The script MUST share the lint exemption list parsing helper with `tool/lint_l10n_literals.dart` (extracted into a tiny shared module if both scripts grow). For Phase 3, the parity script ignores the exemption list (it only reads the two ARB files, both of which are exempt-by-list anyway), so the shared module can be deferred.

## Verification

Manual, per `quickstart.md` step 9: temporarily delete the `localeToggleLabel` entry from `app_en.arb`, run `dart run tool/lint_l10n_parity.dart`, observe exit code 1 and the missing-key report. Restore the entry, re-run, observe exit code 0.
