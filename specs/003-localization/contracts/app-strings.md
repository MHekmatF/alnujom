# Contract: AppStrings (FR-008 missing-translation wrapper)

`lib/core/localization/app_strings.dart` — NEW in Phase 3. A thin wrapper around the generated `AppLocalizations` API that, in debug builds only, detects template-fallback (a key missing from `app_ar.arb` causing Flutter to silently fall back to the `app_en.arb` template) and surfaces it.

## Purpose

Make missing-translation gaps visible to developers without paying for the check in production. Serves as the FR-008 runtime safety net for the narrow window between a developer adding a key in one ARB file and the FR-005 parity check catching it in CI.

## Public API

```dart
class AppStrings {
  /// Returns the AppStrings facade for [context]. Throws StateError if
  /// the localization delegates are not yet installed (a sign of
  /// misconfiguration — must be called below MaterialApp).
  static AppStrings of(BuildContext context);

  /// The active AppLocalizations the wrapper delegates to.
  AppLocalizations get loc;
}
```

Feature widgets call `AppStrings.of(context).loc.appTitle` (or whichever generated getter), exactly the same shape they would use against `AppLocalizations.of(context)!`. The thin indirection lets the debug instrumentation (below) sit in one place.

## Behavioral guarantees

| Mode | Behavior |
|------|----------|
| **Release (`!kDebugMode`)** | `AppStrings.of(context).loc` returns the same `AppLocalizations` instance `AppLocalizations.of(context)` would. Zero overhead. No interception. |
| **Debug (`kDebugMode`)** | `AppStrings.of(context).loc` returns a `_DebugAppLocalizations` proxy that, on every getter access, computes the resolved string AND the `app_en.arb` baseline for the same key. If the active locale is `ar` and the resolved string is identical to the en baseline, the proxy: (a) emits `AppLogger.warning('Missing ar translation for key: $key', tag: 'AppStrings')`, and (b) returns the string wrapped in the visible marker `${markerPrefix}${key}${markerSuffix}` (defaults `⟦missing:keyname⟧`; the prefix and suffix are themselves ARB keys — `missingTranslationMarkerPrefix` and `missingTranslationMarkerSuffix` — so QA can adjust without code changes). |

## Implementation notes

- The `_DebugAppLocalizations` proxy is generated alongside the gen-l10n output OR hand-rolled with one method per Phase 3 floor key. **Locked**: hand-rolled is acceptable for the Phase 3 floor (~17 keys); a generated proxy becomes attractive only when the corpus crosses ~50 keys, at which point a follow-up phase can introduce a small build script. For Phase 3, hand-rolling is simpler and avoids a new code-generator dependency.
- `markerPrefix` / `markerSuffix` ARB keys MUST themselves be present in both `app_ar.arb` and `app_en.arb` with sensible defaults; the parity check (FR-005) enforces this.
- The "active locale is `ar` and resolved string equals en baseline" heuristic CAN false-positive on keys whose ar and en values are intentionally identical (proper nouns, single-word numeric tokens). The wrapper does NOT log or mark for English-active locales (since the en baseline IS the en value). This bias is acceptable for Phase 3; refining the heuristic (e.g., adding an "intentionally-untranslated" allowlist in the ARB metadata) is a follow-up if false positives become noisy.

## Invariants

- The wrapper MUST NOT alter the rendered string in release builds.
- The wrapper MUST NOT throw on a missing key; it logs and renders the marker (debug) or delegates straight through (release).
- The wrapper MUST NOT introduce a new package dependency.
- The wrapper MUST NOT bypass the ARB system (no inline string fallbacks in Dart code).

## Out-of-scope (Phase 3)

- A code-generated proxy that mirrors every `AppLocalizations` getter — deferred until the corpus justifies the build-step cost.
- An "intentionally-untranslated" allowlist for ar==en false-positive suppression — deferred; revisit if QA flags real noise.
- Runtime introspection of placeholder declarations — deferred; the parity check handles structural mismatch at build time.

## Verification

Manual, per `quickstart.md` step 7: introduce a temporary key in `app_en.arb` only (omit from `app_ar.arb`), reference it from a test widget in `lib/debug/`, run a debug build on the Infinix Note 8, observe the visible `⟦missing:key⟧` marker on screen and the warning entry in the device log. Then run `dart run tool/lint_l10n_parity.dart` and observe the build failing — restore parity, re-run, observe success.
