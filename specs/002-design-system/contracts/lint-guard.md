# Contract: Design-Token Lint Guard

**Status**: Phase 2 deliverable | **Spec**: [../spec.md](../spec.md) FR-007, SC-001 | **Plan**: [../plan.md](../plan.md) | **Research**: [../research.md](../research.md) §R-04

## Purpose

Block any commit / merge that reaches past the design-tokens API and uses raw color, typography, or spacing literals in feature code. Without this guard, FR-007 would be aspirational; with it, Constitution VI's "no hardcoded hex / `TextStyle` / raw paddings" rule becomes a build-time invariant.

## Surface

A standalone Dart script.

```
$ dart run tool/lint_design_tokens.dart [--fix?]
```

- Exit code `0`: no violations.
- Exit code `1`: at least one violation; stdout lists `path:line:column: message` entries.
- `--fix` flag: not implemented in Phase 2 (lint guards are correctness-only — auto-fix risks silently changing semantics).

The same logic is exposed as a Dart library so `test/lint/design_tokens_lint_test.dart` can call it from `flutter test` (catches violations pre-push).

## Banned patterns

The script scans every `.dart` file under `lib/` (and optionally `test/`) excluding the allow-list below. It flags:

| # | Pattern | Regex (illustrative) | Reason |
|---|---|---|---|
| L1 | Raw color literal | `\\bColor\\(\\s*0x[0-9A-Fa-f]+` | Bypasses `AppColors`. |
| L2 | Inline `TextStyle` constructor | `\\bTextStyle\\s*\\(` | Bypasses `AppTextStyles`. |
| L3 | Raw integer in a directional `EdgeInsets` constructor | matches `EdgeInsets(Directional)?\\.\\w+\\(` followed by integer/double literal arguments | Bypasses `AppSpacing`. |
| L4 | Raw integer in a `BorderRadius.circular(N)` call | `\\bBorderRadius\\.circular\\(\\s*\\d+` | Bypasses `AppRadii`. |
| L5 | Raw integer in a `BoxShadow(blurRadius:` argument | `\\bBoxShadow\\s*\\(` followed by integer literals | Bypasses `AppElevation`. |
| L6 | Import or string reference to the archived Luxury direction | `archive/luxury` OR `Playfair Display` OR `Reem Kufi` (in import strings or asset paths) | Enforces FR-014 — Direction A archived fonts / tokens / components MUST NOT be reachable from production code paths. |

L1 and L2 are the highest-value rules (the most-common drift sources). L3–L5 are added to lock down the spacing/radii/elevation surface; if false-positive friction is high during Phase 2 implementation, L3–L5 may be relaxed to "warning" tier in a follow-up while L1 + L2 remain build-blocking. L6 is build-blocking — there is no legitimate reason for any code path under `lib/` to reference the archive.

## Allow-list

The following paths are permitted to use raw literals — they ARE the design-token source:

- `lib/core/theme/colors.dart`
- `lib/core/theme/typography.dart`
- `lib/core/theme/spacing.dart`
- `lib/core/theme/radii.dart`
- `lib/core/theme/elevation.dart`
- `lib/core/theme/color_palette.dart`
- `lib/core/theme/app_theme.dart`

`lib/debug/theme_gallery_page.dart` and `lib/core/widgets/palette_tester.dart` are NOT on the allow-list — debug code is held to the same rule.

Test files (`test/**`) are scanned but with rules L3–L5 relaxed (tests frequently use literal numbers in widget-size assertions). L1 and L2 still apply to test code.

## Invariants

1. **Determinism**: same source tree → same exit code, same output. The script must never flake.
2. **No false positives in the allow-listed files** — the design-system files are explicitly excluded.
3. **Cross-platform**: must run on Linux (CI), macOS, and Windows hosts. Pure Dart, no shell-out.
4. **Fast**: must complete in under 5 seconds on the current `lib/` size; scaling-friendly (regex pre-compiled, single-pass per file).
5. **Self-test**: a fixture file under `test/lint/fixtures/` containing every banned pattern is fed to the script in `test/lint/design_tokens_lint_test.dart`; the test asserts the script flags every fixture line and produces zero false positives on a synthetic clean file.

## CI integration

Add to `.github/workflows/ci.yml` after the existing `flutter analyze` step:

```yaml
- name: Lint design tokens
  run: dart run tool/lint_design_tokens.dart
```

The job MUST fail the workflow on a non-zero exit, blocking PR merge.

## Failure mode UX

When the guard flags a violation, the printed message MUST be specific enough for an agent or human to fix without further investigation:

```
lib/features/home/presentation/home_page.dart:42:18: forbidden raw color literal `Color(0xFF1D4ED8)` — use AppColors.of(context).primary instead.
```

## Test surface

- `test/lint/design_tokens_lint_test.dart` — calls the lint library against `test/lint/fixtures/violations.dart` (intentionally bad) and asserts violations; calls against `test/lint/fixtures/clean.dart` (intentionally clean) and asserts zero.
- The CI step's exit code IS the integration test in production.

## Files

- `tool/lint_design_tokens.dart` — entry point.
- `tool/src/lint_design_tokens_lib.dart` (or similar) — the reusable scanning library.
- `test/lint/design_tokens_lint_test.dart` — `flutter test` integration.
- `test/lint/fixtures/clean.dart`, `violations.dart` — fixtures.
- `.github/workflows/ci.yml` — CI step.

## Out of scope

- Auto-fix.
- Reporting violations as IDE diagnostics (no `custom_lint` plugin in Phase 2 per research R-04).
- Banning additional patterns (e.g., `Padding(padding: const EdgeInsets.all(0))`). The five rules above are the floor; expansion is a follow-up.
