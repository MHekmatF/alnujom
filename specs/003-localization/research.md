# Phase 0 Research — Localization

This document locks the technical decisions Phase 3 inherits or chooses, with the alternatives considered. Every decision below is stable enough that `/speckit-tasks` can rely on it without re-asking the user.

---

## R-01 — ARB tooling

**Decision**: `flutter gen-l10n` (Flutter's built-in localization generator) using the existing `l10n.yaml` config carried over from Phase 1.

**Rationale**: `l10n.yaml` already exists and is already wired in `lib/l10n/`; `MaterialApp.localizationsDelegates` and `supportedLocales` are already pointed at the generated `AppLocalizations`. Switching to a third-party tool (`intl_translation`, `slang`, `easy_localization`) would force a rewrite of working infrastructure for zero behavioral gain and would invalidate the existing scaffolding-era keys. `flutter gen-l10n` produces typed, compile-checked Dart getters — referencing a non-existent key is a compile error, not a runtime miss, which complements (rather than duplicates) the FR-005 build-time parity check.

**Alternatives considered**:
- `slang` — cleaner type system and richer ICU support, but adds a new package, requires migrating the 6 existing scaffolding keys, and breaks the Phase 2 spec's casual reference to ARB files.
- `easy_localization` — runtime key lookup via JSON; rejected because it loses compile-time safety (untyped `t('key')` calls survive a key rename until QA catches them).

**l10n.yaml contents (verified, no changes needed)**:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
synthetic-package: false
```

**Note on regeneration and tracking**: Combined with `flutter.generate: true` in `pubspec.yaml`, `flutter pub get` auto-runs `gen_localizations` — so the generated `app_localizations*.dart` outputs are gitignored as reproducible build artifacts (see `.gitignore:69-76`). CI's `flutter pub get` step regenerates them before `flutter analyze` runs; ARB files are the source of truth.

**Note on the template-ARB choice**: `template-arb-file: app_en.arb` is the existing setting. The template determines which ARB drives placeholder declarations and key-existence; runtime locale defaulting is governed by `MaterialApp.locale`, which Phase 1 already pins to the Arabic-default value via `LocaleCubit.defaultLocale`. Keeping the template as `app_en.arb` (rather than flipping to `app_ar.arb`) avoids an unnecessary diff and is orthogonal to the Arabic-first runtime behavior.

---

## R-02 — Locale persistence backend

**Decision**: `flutter_secure_storage` via the existing `SecurePreferencesStore` implementation of the `PreferencesStore` interface.

**Rationale**: The repository already has `SecurePreferencesStore` (DI-bound as `@LazySingleton(as: PreferencesStore)`) with `readLocale()` / `writeLocale()` methods that round-trip through `flutter_secure_storage` under the key `com.alnujom.preferences.locale_code`. `LocaleCubit.toggle()` already calls `_preferencesStore.writeLocale(nextLocale)`. `main.dart` already reads `preferencesStore.readLocale()` at bootstrap and passes the result into `App(initialLocale: ...)`. **FR-007 is therefore structurally satisfied today**; Phase 3 does not modify this path.

**Alternatives considered**:
- `SharedPreferences` (non-secure) — rejected; Constitution III's "Security-First Supabase" spirit and the cross-cutting decision in [ADR-0001](../../docs/decisions/0001-secrets-and-pii-storage.md) push toward secure storage for any per-user preference, even non-sensitive ones, until the authenticated `user_preferences.locale` column lands in Phase 4 / Phase 5.
- A new dedicated `LocaleStore` interface — rejected; `PreferencesStore` already has the right shape and the right DI binding; introducing a parallel store would split the bootstrap read into two paths and invite drift.

**Phase 5 handoff**: Once Phase 5 ships authenticated profiles, the `user_preferences.locale` row becomes the source of truth. The Phase 5 spec — not Phase 3 — owns the migration of the local secure-storage value into the user-scoped row at first sign-in. Phase 3's `LocaleCubit` continues to read/write secure storage; Phase 5 will layer a sync step on top.

---

## R-03 — Missing-translation runtime strategy (FR-008)

**Decision**: A thin `AppStrings.of(context)` wrapper at `lib/core/localization/app_strings.dart` that delegates to `AppLocalizations` for every key but, in **debug builds only**, intercepts each lookup to detect template-fallback (i.e., `flutter gen-l10n`'s default behavior of returning the `app_en.arb` template value when the key is missing in `app_ar.arb`). On detection it (a) emits an `AppLogger.warning` naming the missing key, and (b) wraps the rendered string in a visibly distinct marker `⟦missing:keyname⟧` so the gap is obvious during development. In **release builds**, the wrapper is a zero-cost passthrough — the same calls hit `AppLocalizations` directly.

**Rationale**: With `flutter gen-l10n`, key references are typed Dart getters — referencing a non-existent key is a compile error. The genuine runtime "missing-translation" path is therefore narrow: a key exists in the template (`app_en.arb`) but is missing from `app_ar.arb`, in which case Flutter silently falls back to the template value. In production, the FR-005 parity-check script makes this case impossible (it fails the build); the wrapper is the developer-side safety net while parity is being restored locally. Limiting the wrapper to debug builds keeps the release path clean of any per-string overhead.

**Detection mechanism**: The wrapper holds a reference to the resolved `AppLocalizations` for the active locale and, separately, to the `AppLocalizationsEn` baseline. On every key access in debug mode, if the active locale is `ar` AND the resolved string equals the en-baseline string, the wrapper logs and marks. (False-positives are possible for keys whose ar and en values are intentionally identical — e.g., proper nouns or numeric tokens. Those will be rare in this corpus and will surface during quickstart review; if they become a real-world problem, the wrapper can be tightened to compare against an "explicitly-translated" allowlist in a follow-up phase.)

**Alternatives considered**:
- Custom code generator that emits `t(String key)` with try-catch and warning — rejected; loses compile-time safety, duplicates the work `flutter gen-l10n` already does.
- Override `LocalizationsDelegate` to return a fallback wrapper — rejected; touches infrastructure unnecessarily and complicates the gen-l10n upgrade path.
- Skip FR-008's runtime wrapper entirely; rely on the FR-005 parity check alone — rejected; leaves the dev-loop blind during the window between writing a key and running the parity check, which is exactly when missing keys are introduced.

---

## R-04 — Lint guard implementation: literal-string detection (FR-006)

**Decision**: A standalone Dart script at `tool/lint_l10n_literals.dart` that uses the `analyzer` package (already a transitive dev dependency of the Flutter SDK) to walk the Dart AST of every file under `lib/` and flag string literals passed to a fixed allowlist of user-visible widget constructor parameters: `Text(...)`, `AppBar.title`, `AppBar.leading`/`actions` text children, `ElevatedButton.child`/`OutlinedButton.child`/`TextButton.child`/`FilledButton.child` when the child is a `Text(literal)`, `SnackBar.content`, `AlertDialog.title`/`content`, `TextField.labelText`/`hintText`/`helperText`/`errorText`, `InputDecoration.labelText`/`hintText`/`helperText`/`errorText`, `Tooltip.message`, `MenuAnchor` items with text labels. The exemption list is read from a top-level `l10n_lint_exempt:` block in `analysis_options.yaml` (see R-05). The script runs as `dart run tool/lint_l10n_literals.dart` and exits non-zero with one line per violation in the format `path/to/file.dart:LINE:COL: literal "..." passed to <constructor>.<param>`.

**Rationale**: The `analyzer` package is the standard, supported way to do AST-level inspection in Dart and is already on the dev classpath (the Phase 2 `tool/lint_design_tokens.dart` script also uses it, per the Phase 2 plan). Walking the AST means the lint correctly handles edge cases (string interpolation `'$variable'` is also flagged; concatenation `'a' + 'b'` is flagged; string from a const variable like `const _kHello = 'hello'; Text(_kHello)` is flagged because the AST sees the literal at the assignment site if the const lives under `lib/`). A pure-regex script would generate false positives on doc comments, string concatenations across lines, and literal-looking identifiers; rejecting that approach saves review time.

**Allowlist of inspected constructors/params**: locked in `contracts/lint-guard-literals.md`. The allowlist is intentionally finite and conservative — it covers the constructors that demonstrably reach end-user pixels. Adding a constructor to the allowlist is a code change (a one-line edit to the script's allowlist constant) and goes through normal review.

**Exit code**: `0` if no violations, `1` if any violation, `2` on script failure (e.g., a file failed to parse). CI treats `1` and `2` identically (red build).

**Alternatives considered**:
- A regex grep on `Text\(["']` modeled after the IMPLEMENTATION_PLAN's verification example — rejected; too noisy on edge cases (multi-line, interpolation, comments) and brittle when widget constructors evolve.
- A `custom_lint` plugin — rejected for Phase 3 because it adds a new dev dependency and a separate runner; the standalone script is faster to ship and simpler for CI to wire.
- Compile-time `// l10n: ignore` annotations on every literal — rejected; defeats the purpose of the guard.

---

## R-05 — Lint exemption list format

**Decision**: A top-level YAML block in `analysis_options.yaml` named `l10n_lint_exempt:` containing a list of file glob patterns. Both `tool/lint_l10n_literals.dart` and `tool/lint_l10n_parity.dart` parse this same block and skip matching files.

```yaml
# analysis_options.yaml (excerpt)
l10n_lint_exempt:
  - lib/l10n/**.arb
  - lib/l10n/app_localizations*.dart
  - lib/debug/**             # Theme Gallery and any future debug-only design-tools surface
  - test/goldens/**          # golden test fixture files
```

**Rationale**: Keeping the exemption list inside `analysis_options.yaml` (rather than in a separate `.l10nignore` file) means there is one canonical place to review what's exempt from lint guards — both the design-token guard from Phase 2 and the localization guard from Phase 3 can grow to share this convention. Glob patterns are familiar, easy to review in a PR, and broad enough to express the four locked exemption categories without requiring per-file enumeration.

**Lockable categories** (per FR-006 + Q1 clarification):
1. **Translation source files** — `lib/l10n/**.arb`
2. **Generated localization files** — `lib/l10n/app_localizations*.dart`
3. **Debug-only design tools** — `lib/debug/**`
4. **Golden test fixture files** — `test/goldens/**` (these are checked-in PNGs, not Dart, but the test files generating them are also exempt; per the durable no-new-tests rule, no new golden tests are added in Phase 3, but existing ones are preserved.)

Adding a fifth pattern is a reviewable code change — there is **no implicit exemption based on directory naming or file path patterns outside this list** (per FR-006).

**Alternatives considered**:
- Inline `// l10n_lint:exempt-file` comment marker at the top of each exempt file — rejected; harder to audit (requires reading every file), and silently breakable if someone removes the comment.
- A separate `.l10nignore` file — rejected; bifurcates the lint-config surface for no benefit.
- A `pubspec.yaml` block — rejected; pubspec is for package metadata, not analysis config.

---

## R-06 — Lint guard implementation: ARB parity (FR-005)

**Decision**: A standalone Dart script at `tool/lint_l10n_parity.dart` that loads `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`, decodes them as JSON maps, computes the symmetric set difference of their non-metadata keys (keys that don't start with `@@` or `@`), and exits non-zero if either side has missing entries. The error report enumerates each missing key with the locale where it's absent: `Missing in app_ar.arb: errorOffline, errorMissingConfig` / `Missing in app_en.arb: appTitle (typo?)`.

**Rationale**: ARB files are JSON; parity checking is a 30-line script. No AST work is needed. The script is small, fast, deterministic, and easy to extend later if the team wants to also compare placeholder declarations across locales. Wiring it as a separate script (rather than folding it into `lint_l10n_literals.dart`) keeps each guard's failure message focused — a parity violation reads cleanly, a literal violation reads cleanly, and CI logs are easier to scan.

**Exit code**: `0` if perfect parity, `1` if any key missing on either side, `2` on script failure (file unreadable or invalid JSON).

**Alternatives considered**:
- Use `flutter gen-l10n`'s built-in `untranslated-messages-file` flag (which dumps a JSON of missing keys at build time) — rejected because (a) it fires at gen time, not at lint time, so the failure surface is less obvious in CI logs; (b) it doesn't fail the build by itself, which would force us to re-parse its output anyway.
- A YAML-based comparison tool — rejected; ARBs are JSON, no point converting.

---

## R-07 — Live UI rebuild on locale switch (FR-003)

**Decision**: No new code needed. The existing `BlocBuilder<LocaleCubit, Locale>` in `lib/app.dart` wraps the `MaterialApp.router` builder; when `LocaleCubit.toggle()` emits a new `Locale`, the builder re-fires and `MaterialApp.locale` changes value, which propagates through the `Localizations` widget tree to every descendant — including any open dialog, sheet, snackbar, or navigation-overlay surface. This is Flutter's built-in behavior; the Phase 1 wiring is correct and unchanged.

**Verification path**: Manual, per `quickstart.md` step 4 (toggle locale with a dialog and a snackbar visible; observe both rebuild in the new language without an app restart).

**Alternatives considered**:
- Forcing a `Navigator.popUntil` on locale switch to ensure overlays rebuild — rejected; unnecessary because the `Localizations` widget propagates locale changes downward through every overlay route. Tested informally during Phase 1; works in Flutter SDK ≥ 3.x.

---

## R-08 — Form-input preservation across locale switch (FR-015)

**Decision**: No new code needed. Flutter's `TextEditingController` and form-state objects are owned by widget `State` classes that survive locale changes (locale change is a rebuild, not a `Widget` replacement). User input persists automatically.

**Verification path**: Manual, per `quickstart.md` step 6 (open any form-bearing screen reachable in Phase 3, type into a field, toggle locale, observe input is preserved while labels/placeholders flip language).

**Risk**: Forms that incorrectly use `key: ValueKey(locale)` on their fields would lose state on locale change. We do not currently have such code; the lint guard does not check for it (out of scope). This becomes a per-feature review concern when feature phases ship form-bearing screens.

---

## R-09 — Bilingual font fallback per locale (FR-014)

**Decision**: No new code needed. Phase 2's `buildAppTheme(palette: , brightness: , locale: )` already takes a `Locale` parameter and resolves `AppTextStyles` to either the Arabic-script families (Cairo for display/headline/title; IBM Plex Sans Arabic for body/label) or Inter (for English). The wiring exists; Phase 3 only verifies it during the quickstart on the reference device.

**Risk**: If `buildAppTheme` is called with a stale `locale` (e.g., from a cache that doesn't update on toggle), the font stack could lag. The existing `BlocBuilder<LocaleCubit, Locale>` in `app.dart` (R-07) prevents this by re-invoking `buildAppTheme(locale: locale)` on every cubit emission.

**Verification path**: Manual, per `quickstart.md` step 5 (compare font appearance side-by-side across locales).

---

## R-10 — Default locale on first launch ignores OS locale (FR-001)

**Decision**: Hardcoded default of `Locale('ar')` via the existing `LocaleCubit.defaultLocale` constant. `main.dart`'s bootstrap path (`PreferencesStore.readLocale()`) returns null on a fresh install (no persisted value), and the `??` fallback applies the constant. The OS locale (`PlatformDispatcher.instance.locale`) is intentionally NOT consulted.

**Rationale**: Constitution V locks Arabic as the default; auto-following the OS locale would make English speakers boot into English on first launch, which is exactly what the Arabic-first principle prevents. The decision is recorded in the spec's `## Assumptions` ("Default locale on first launch is Arabic, regardless of the device's operating-system locale") and re-confirmed here.

**Alternatives considered**:
- Auto-detect: if OS locale is `en-*`, default to en; otherwise ar. Rejected; introduces a hidden product decision (Constitution XII) that English-speaking Syrian users in a Syrian-Arabic market should boot into English by default — which is wrong for the target market. If a Settings-level "follow OS locale" option is desired later, Phase 23 owns it.

---

## R-11 — Initial ARB corpus content (FR-010)

**Decision**: Phase 3's ARB corpus floor is composed of three groups:

1. **App shell strings** (already present from Phase 1, may be renamed for clarity but not removed without parity):
   - `appTitle`
   - `themeToggleLabel`, `currentTheme`
   - `localeToggleLabel`, `currentLocale`
   - `backendConfigMissingWarning`

2. **Theme Gallery chrome** (new, Q3 clarification — chrome only, NOT per-component):
   - `themeGalleryTitle` (page title)
   - `themeGalleryPaletteSectionHeader`
   - `themeGalleryThemeSectionHeader`
   - `themeGalleryLocaleSectionHeader`
   - `themeGalleryComponentsSectionHeader`
   - (Per-component / per-state labels remain English in this debug-only, tree-shaken surface — see Q3 in `spec.md` `## Clarifications`.)

3. **Standard error messages** (new, FR-010):
   - `errorOffline` — "you appear to be offline" / "أنت غير متصل بالإنترنت" (Syrian-friendly tone TBD by reviewer)
   - `errorGeneric` — "something went wrong" / generic catch-all
   - `errorMissingBackendConfig` — refines the existing `backendConfigMissingWarning` for production phrasing
   - `errorRetryAction` — "try again" / "حاول مرة أخرى"

4. **Missing-key marker copy** (FR-008, debug-only):
   - `missingTranslationMarkerPrefix` — defaults to `⟦missing:` (mostly cosmetic; keyed so QA can adjust)
   - `missingTranslationMarkerSuffix` — defaults to `⟧`

Total: ~17 keys at the floor. Subsequent phases extend this set; Phase 3 is responsible only for landing the floor and the parity check that prevents future regressions.

**Rationale**: Pinning the corpus floor here (rather than discovering it during implementation) gives `/speckit-tasks` an exhaustive list to enumerate, prevents review-time scope creep, and makes the FR-005 parity check trivially testable.

**Note on Arabic copy quality**: The Arabic strings landed in Phase 3 are first-draft anchored against the Syrian-friendly seed terms in FR-011. A reviewer pass for tone — preferring everyday Syrian Arabic over stiff Modern Standard phrasing — happens during the manual quickstart walkthrough; it does not require a separate spec.

---

## R-12 — CI integration

**Decision**: Two new analysis-only steps are added to `.github/workflows/ci.yml`:

```yaml
- name: Run l10n literal-string lint guard
  run: dart run tool/lint_l10n_literals.dart

- name: Run l10n ARB parity check
  run: dart run tool/lint_l10n_parity.dart
```

No `flutter test` step is added, and the existing CI workflow is otherwise unchanged. The Phase 2 `dart run tool/lint_design_tokens.dart` step (if present in `ci.yml`) remains untouched.

**Rationale**: Per the durable session feedback (`feedback_no_new_tests.md`), Phase 3 ships static analysis only — no test runners. The two new steps fit into the existing analyze-and-build flow without introducing a test phase.

**Alternatives considered**:
- Combine both lint scripts into one `tool/lint_l10n.dart` entry-point — rejected; separate scripts produce focused failure messages and let CI cache one even if the other fails.
- Run only the parity check in CI; defer literal-guard to local pre-commit — rejected; the guard's whole value is catching what humans miss, including in PRs from agents who don't run pre-commit.
