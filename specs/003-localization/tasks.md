---
description: "Tasks list for Phase 3 — Localization (specs/003-localization)"
---

# Tasks: Localization

**Input**: Design documents from `/specs/003-localization/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: NOT included — durable no-new-tests rule (`feedback_no_new_tests.md`). Verification is manual UI walkthrough on the Infinix Note 8 reference device + the two build-blocking static-analysis scripts (`tool/lint_l10n_literals.dart`, `tool/lint_l10n_parity.dart`). The Phase 2 `PropertyCard` golden suite is preserved unchanged but is NOT a Phase 3 acceptance gate.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently.

## Format: `[ID] [P?] [Story?] Description`

- **[P]** = different files, no dependency on incomplete tasks → can run in parallel
- **[USx]** = task belongs to user story x (only on Phase 3+ tasks)
- Each task carries a `**Verify**:` line with the concrete acceptance check (Constitution Principle X). For Phase 3 every Verify is either a manual UI step on the Infinix Note 8 OR a CLI command that exits 0 / non-zero (the lint scripts) — no new automated tests.

## Path Conventions

This is a Flutter Android app. Paths below are relative to the repo root `H:\alnujom-project\`.

- Flutter source: `lib/`
- ARB sources: `lib/l10n/`
- Generated localizations: `lib/l10n/app_localizations*.dart`
- Localization runtime: `lib/core/localization/`
- Debug-only surfaces: `lib/debug/`
- Lint tools: `tool/`
- CI: `.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the lint exemption configuration that the foundational scripts and lint guards will read.

- [X] T001 Add a top-level `l10n_lint_exempt:` YAML block to `analysis_options.yaml` listing the four locked exemption patterns from research [R-05](research.md#r-05--lint-exemption-list-format): `lib/l10n/**.arb`, `lib/l10n/app_localizations*.dart`, `lib/debug/**`, `test/goldens/**`. The block sits at the top level — NOT nested inside `analyzer:` or `linter:` — so the two `tool/` scripts can parse it directly.
  - **Verify**: `Get-Content analysis_options.yaml | Select-String -Pattern 'l10n_lint_exempt:'` finds exactly one match at top level; `flutter analyze` reports no new warnings (the analyzer ignores the unknown top-level block); the four patterns are present verbatim.

**Checkpoint**: lint configuration is in place; foundational tasks can now reference the exemption list.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Expand the ARB corpus to the Phase 3 floor, regenerate the typed `AppLocalizations` API, and ship the `AppStrings` wrapper that every user-story task depends on. **No user story can begin until this phase is complete.**

> Contracts: [`contracts/app-strings.md`](contracts/app-strings.md). Corpus floor: research [R-11](research.md#r-11--initial-arb-corpus-content-fr-010).

### ARB corpus floor

- [X] T002 [P] Expand `lib/l10n/app_ar.arb` to the Phase 3 floor — add the Theme Gallery chrome keys (`themeGalleryTitle`, `themeGalleryPaletteSectionHeader`, `themeGalleryThemeSectionHeader`, `themeGalleryLocaleSectionHeader`, `themeGalleryComponentsSectionHeader`), the standard error keys (`errorOffline`, `errorGeneric`, `errorMissingBackendConfig`, `errorRetryAction`), and the missing-key marker copy keys (`missingTranslationMarkerPrefix` defaulting to `⟦missing:`, `missingTranslationMarkerSuffix` defaulting to `⟧`); preserve the six Phase 1 scaffolding keys (`appTitle`, `themeToggleLabel`, `currentTheme`, `localeToggleLabel`, `currentLocale`, `backendConfigMissingWarning`). Arabic copy follows the Syrian-friendly seed terms in [FR-011](spec.md#requirements-mandatory).
  - **Verify**: `Get-Content lib/l10n/app_ar.arb -Raw | ConvertFrom-Json` succeeds (valid JSON); the file contains all ~17 floor keys + the `@@locale: ar` metadata key; manual reviewer pass confirms Arabic strings respect FR-011's tone (no stiff MSA where a Syrian-friendly equivalent exists).

- [X] T003 [P] Expand `lib/l10n/app_en.arb` with the parallel English entries for every key landed in T002. The set of non-metadata keys in `app_en.arb` MUST be identical to `app_ar.arb` so the parity check (T013) will pass. English copy is professional and clear.
  - **Verify**: `Get-Content lib/l10n/app_en.arb -Raw | ConvertFrom-Json` succeeds; running T013's parity script (after it lands) on this state exits 0 with `Translation key parity check passed (~17 keys).`; before T013 lands, manual diff of the two ARB key sets confirms parity.

- [X] T004 Run `flutter gen-l10n` from the repo root (or rely on `flutter pub get`, which auto-runs gen-l10n because `pubspec.yaml` sets `flutter.generate: true`) to (re)generate `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_ar.dart`, and `lib/l10n/app_localizations_en.dart` from the expanded ARB corpus. **Do NOT commit the generated files** — they are gitignored per `.gitignore:69-76` (build artifacts; ARB files are the source of truth, the `.dart` outputs are reproducible). CI's `flutter pub get` step regenerates them before `flutter analyze` runs. Depends on T002, T003.
  - **Verify**: `flutter gen-l10n` exits 0 with no errors; `Get-Content lib\l10n\app_localizations.dart | Select-String -Pattern 'String get themeGalleryTitle'` finds the new typed getter (and similarly for every floor key); `flutter analyze` passes against the regenerated files.

### Localization runtime safety net

- [X] T005 Create `lib/core/localization/app_strings.dart` implementing the `AppStrings` facade per [`contracts/app-strings.md`](contracts/app-strings.md). In release builds (`!kDebugMode`) `AppStrings.of(context).loc` returns the same `AppLocalizations` instance `AppLocalizations.of(context)!` would (zero-cost passthrough). In debug builds (`kDebugMode`) it returns a hand-rolled `_DebugAppLocalizations` proxy that holds both the active `AppLocalizations` and the `AppLocalizationsEn` baseline; for each Phase 3 floor key getter, if the active locale is `ar` and the resolved string equals the en baseline, the proxy emits `AppLogger.warning('Missing ar translation for key: <name>', tag: 'AppStrings')` and returns `${prefix}<name>${suffix}` where prefix/suffix come from `missingTranslationMarkerPrefix`/`missingTranslationMarkerSuffix` ARB keys. Hand-rolled (~17 floor-key getters) is acceptable per research [R-03](research.md#r-03--missing-translation-runtime-strategy-fr-008). Depends on T004.
  - **Verify**: `flutter analyze` passes; in a debug `flutter run`, `AppStrings.of(context).loc.appTitle` returns the same string as `AppLocalizations.of(context)!.appTitle`; deliberately removing the `appTitle` entry from `app_ar.arb` and re-running `flutter gen-l10n` produces a debug-build screen showing `⟦missing:appTitle⟧` and a matching warning log entry. Restore parity before continuing.

**Checkpoint**: ARB corpus floor is in place; `AppStrings` is available to every consumer; the runtime missing-key safety net is live. **User story phases can now begin in parallel.**

---

## Phase 3: User Story 1 — First launch in Arabic with RTL out of the box (Priority: P1) 🎯 MVP

**Goal**: A fresh install on the Infinix Note 8 boots into Arabic with full RTL layout, every visible string sourced from the ARB corpus floor, no English fallback, no untranslated keys (FR-001, FR-009, SC-001, SC-010).

**Independent Test**: Wipe app data on the reference device, launch from the launcher cold, observe Arabic + RTL throughout the first reachable surfaces, no `⟦missing:...⟧` markers, cold-start ≤ 3 s. Quickstart [Step 1](quickstart.md#step-1--fresh-install-arabic-boot-fr-001-sc-001-sc-010).

### Implementation for User Story 1

- [ ] T006 [US1] Audit every file under `lib/shell/` for hardcoded user-visible strings (any `Text("...")`, `AppBar.title: const Text("...")`, button labels, snackbar content, etc.). Replace each with an `AppStrings.of(context).loc.<key>` lookup. If a string has no matching floor key, add the new key to BOTH `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` and re-run `flutter gen-l10n` (T004) before the replacement compiles.
  - **Verify**: Once T013 lands, `dart run tool/lint_l10n_literals.dart` exits 0 against the working tree; before T013 lands, manual scroll through every `lib/shell/*.dart` file confirms no literal strings reach a user-visible widget constructor; any new ARB keys appear in both files with parity preserved.

- [ ] T007 [US1] Audit every file under `lib/core/widgets/` for user-visible strings supplied as widget defaults (placeholder text, accessibility hints, fallback empty/error/loading copy). Phase 2 components are designed to RECEIVE strings from callers rather than own them, so this audit is mostly verification — but any `EmptyState`, `ErrorState`, `LoadingState`, or default-tooltip strings still hardcoded MUST be replaced with `AppStrings.of(context).loc.<key>` lookups, adding new ARB keys where needed.
  - **Verify**: Once T013 lands, `dart run tool/lint_l10n_literals.dart` exits 0 against the working tree; manual review of `lib/core/widgets/empty_state.dart`, `error_state.dart`, `loading_state.dart` confirms any default fallback strings resolve through ARB.

- [ ] T008 [US1] Manual verification on the reference device — quickstart [Step 1](quickstart.md#step-1--fresh-install-arabic-boot-fr-001-sc-001-sc-010): clear the app's data on the Infinix Note 8, launch cold from the launcher, walk every reachable Phase 3 surface (app shell + reachable screens). Confirm Arabic + RTL throughout, no transient English flash at first frame, no `⟦missing:...⟧` placeholder anywhere, cold-start ≤ 3 s.
  - **Verify**: Quickstart Step 1 pass-criteria all green: no transient English flash, no untranslated placeholder, app-bar / locale-toggle / theme-toggle labels read in Arabic with RTL geometry, cold-start within the constitution's 3 s baseline.

**Checkpoint**: User Story 1 (the MVP slice) is fully functional and independently demoable.

---

## Phase 4: User Story 2 — Switching to English re-renders the entire UI in LTR (Priority: P1)

**Goal**: Tapping the locale toggle re-renders the entire visible UI in English with LTR layout in one frame, with no app restart and no overlay left in the previous language; the bilingual font stack flips per locale; mid-flow form input is preserved (FR-002, FR-003, FR-014, FR-015, SC-002, SC-009).

**Independent Test**: From a running Arabic app, tap the toggle, walk through the visible screen plus three reachable surfaces, confirm full English + LTR; with a snackbar / dialog open at the moment of toggle, confirm the overlay re-renders in the new language alongside its parent; type into a form field, toggle locale, observe input is preserved while labels flip. Quickstart [Steps 2, 4, 5, 6](quickstart.md).

### Implementation for User Story 2

- [ ] T009 [US2] Update `lib/debug/theme_gallery_page.dart` to replace the page title, palette/theme/locale toggle labels, and section headers with `AppStrings.of(context).loc.<themeGallery*>` lookups (Q3 clarification — chrome only). Per-component labels and per-state captions inside the gallery may remain English (debug-only, tree-shaken surface, intentional). Use the `themeGallery*` keys landed in T002/T003.
  - **Verify**: `flutter run --dart-define=DESIGN_TOOLS=true` opens the gallery; in Arabic, the page title and section headers read in Arabic; in English (after toggle), they read in English; per-component labels remain English in both locales (intentional). `dart run tool/lint_l10n_literals.dart` does NOT flag the gallery file (it matches `lib/debug/**` in the exemption list per T001).

- [ ] T010 [US2] Manual verification on the reference device — quickstart [Steps 2, 4, 5, 6](quickstart.md): live toggle propagation across the visible screen + three navigated screens (Step 2); overlay rebuild on toggle (Step 4 — use the gallery's debug controls if no feature snackbar is reachable, or record Step 4 as deferred per the quickstart's own guidance); bilingual font-stack flip Cairo / IBM Plex Sans Arabic ↔ Inter (Step 5); form-input preservation across a mid-flow toggle (Step 6 — use a temporary debug `TextField` in the gallery if no real form ships in Phase 3, then revert before merge).
  - **Verify**: All four quickstart pass-criteria checklists green — single-frame rebuild on toggle, zero pages remain in the previous language, overlay rebuilds in the new language, font families flip per locale, typed form input is unchanged after a mid-flow toggle.

**Checkpoint**: User Stories 1 AND 2 both work independently; the bilingual UX is exercised end-to-end.

---

## Phase 5: User Story 3 — Locale choice persists across app restarts (Priority: P2)

**Goal**: After the user toggles the locale, force-stopping and cold-launching the app retains the chosen locale (FR-007, SC-003). Until Phase 5 ships, persistence uses device-local secure storage via the existing `SecurePreferencesStore` (already wired in Phase 1 — see research [R-02](research.md#r-02--locale-persistence-backend)). The migration path to `user_preferences.locale` is owned by the Phase 5 spec, not this phase.

**Independent Test**: Toggle to English, force-stop, cold-launch — boot directly into English with no transient Arabic flash. Toggle back to Arabic, force-stop, cold-launch — boot in Arabic. Wipe app data, cold-launch — return to the Arabic default. Quickstart [Step 3](quickstart.md#step-3--persistence-across-cold-restart-fr-007-sc-003-r-02).

### Implementation for User Story 3

- [ ] T011 [US3] Manual verification on the reference device — quickstart [Step 3](quickstart.md#step-3--persistence-across-cold-restart-fr-007-sc-003-r-02): toggle to English → force-stop → cold-launch → confirm the app boots straight into English with no transient Arabic flash. Toggle back to Arabic → force-stop → cold-launch → confirm Arabic. Wipe app data → cold-launch → confirm the Arabic default returns. (No new code is required — Phase 1 already wires `main.dart` → `PreferencesStore.readLocale()` (bound to `SecurePreferencesStore`) → `App(initialLocale)` → `BlocBuilder<LocaleCubit, Locale>` → `MaterialApp.locale`. This task validates that the Phase 1 wiring still satisfies FR-007 after the Phase 3 changes.)
  - **Verify**: All three Step 3 pass-criteria green — English persists across cold restart, Arabic persists across cold restart, wiping data resets to the Arabic default.

**Checkpoint**: All three runtime user stories (US1, US2, US3) work independently and persist correctly.

---

## Phase 6: User Story 4 — Build fails when a developer adds a new untranslated literal (Priority: P2)

**Goal**: Two build-blocking static-analysis scripts catch any regression — `tool/lint_l10n_parity.dart` for FR-005 and `tool/lint_l10n_literals.dart` for FR-006 — and both run as analysis-only steps in CI alongside the existing Phase 2 design-token guard. No automated tests; the scripts ARE the durable mechanism (FR-006, FR-005, SC-004, SC-005).

**Independent Test**: Add a literal to a non-exempt file under `lib/`, run the literal-lint script — observe exit 1 + the file:line:col report. Add a literal inside the exempt Theme Gallery — observe exit 0. Delete a key from one ARB file, run the parity script — observe exit 1 + the missing-key report. Quickstart [Steps 8 and 9](quickstart.md).

### Implementation for User Story 4

- [ ] T012 [P] [US4] Create `tool/lint_l10n_parity.dart` per [`contracts/lint-guard-parity.md`](contracts/lint-guard-parity.md): read `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`, decode each as JSON, compute the symmetric set difference of non-metadata keys (filter out keys starting with `@`), exit `1` with the per-locale missing-key report when the sets differ, exit `0` with `Translation key parity check passed (N keys).` otherwise, exit `2` on file IO / parse failure.
  - **Verify**: `dart run tool/lint_l10n_parity.dart` exits 0 against the Phase 3 floor; temporarily delete one entry from `app_en.arb` and observe exit 1 with a report listing the missing key under "Missing in lib/l10n/app_en.arb"; restore the entry and re-run to confirm exit 0; delete the file entirely (or corrupt the JSON) to confirm exit 2 with a stderr diagnostic.

- [ ] T013 [P] [US4] Create `tool/lint_l10n_literals.dart` per [`contracts/lint-guard-literals.md`](contracts/lint-guard-literals.md): walk every `.dart` file under `lib/` (skip files matching the `l10n_lint_exempt:` patterns from `analysis_options.yaml` per T001) using `package:analyzer`'s `parseFile`, flag string literals (including interpolations and concatenations) passed to the locked allowlist of user-visible widget constructor parameters (Text positional, AppBar.title, button.child Text, SnackBar.content, AlertDialog.title/content, TextField/InputDecoration label/hint/helper/error/prefix/suffix/counter, Tooltip.message, IconButton.tooltip, MenuItem text, RichText TextSpan.text). Output one line per violation as `path/to/file.dart:LINE:COL: literal "..." passed to <constructor>.<param> — replace with AppStrings.of(context).loc.<key>`. Exit `1` on any violation, `0` on clean tree, `2` on script failure.
  - **Verify**: `dart run tool/lint_l10n_literals.dart` exits 0 against the working tree after T006/T007/T009 land; temporarily add `Text("hello world")` to a non-exempt file (e.g., `lib/shell/app_shell.dart`) and observe exit 1 with the file:line:col flag; replace with `AppStrings.of(context).loc.<key>` and re-run for exit 0; add `Text("ignored")` inside `lib/debug/theme_gallery_page.dart` (exempt) and re-run to confirm exit 0 (literal correctly suppressed).

- [ ] T014 [US4] Update `.github/workflows/ci.yml` to add two analysis-only steps after the existing Phase 2 design-token guard step: `dart run tool/lint_l10n_literals.dart` and `dart run tool/lint_l10n_parity.dart`. Do NOT add a `flutter test` step (durable no-new-tests rule). Depends on T012, T013.
  - **Verify**: `Get-Content .github/workflows/ci.yml | Select-String -Pattern 'lint_l10n_'` finds both new steps; pushing the branch triggers a CI run that includes both steps; the workflow contains zero `flutter test` invocations (`Select-String -Pattern 'flutter test'` returns no matches); CI fails when either lint script exits non-zero.

- [ ] T015 [US4] Manual verification on the reference device + repo — quickstart [Steps 8 and 9](quickstart.md): introduce a non-exempt literal, run `dart run tool/lint_l10n_literals.dart`, observe failure; replace with `AppStrings`, re-run, observe success; introduce a literal inside the exempt gallery, observe success; delete an ARB key, run `dart run tool/lint_l10n_parity.dart`, observe failure; restore, re-run, observe success.
  - **Verify**: All quickstart Step 8 and Step 9 pass-criteria green.

**Checkpoint**: All four user stories (US1–US4) are independently functional. The lint guards are now the durable enforcement layer.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end manual sweep on the reference device, no-regression review against the Phase 2 PropertyCard surfaces, the FR-008 missing-key marker walk, and a final clean-tree CI confirmation before opening the spec PR.

- [ ] T016 [P] Manual no-regression review of the existing Phase 2 PropertyCard rendering — quickstart [Step 10](quickstart.md): on the reference device with the Theme Gallery open, walk the PropertyCard preview at light × ar, light × en, dark × en, dark × ar. Mentally compare against the Phase 2 sign-off baseline; confirm no visible change.
  - **Verify**: Step 10 pass-criteria green — no clipping, no font-stack flicker, no alignment shift across the four combinations. (The Phase 2 golden suite is preserved in source under `test/widgets/property_card_golden_test.dart` but is NOT required to run for Phase 3 acceptance.)

- [ ] T017 [P] Manual end-to-end walk of the FR-008 missing-translation runtime marker — quickstart [Step 7](quickstart.md): temporarily introduce a key in `app_en.arb` only (e.g., `_temp_missing_ar_key`), run `flutter gen-l10n`, reference the key from a debug widget, run a debug build on the reference device, observe the visible `⟦missing:_temp_missing_ar_key⟧` marker AND the `[AppStrings] Missing ar translation for key: _temp_missing_ar_key` log entry. Restore parity and remove the temporary widget reference before merge.
  - **Verify**: Step 7 pass-criteria green — visible marker on screen in debug, warning log entry naming the missing key, parity script exits non-zero on the gap and zero after restoration; cleanup leaves no temporary keys or widget references behind.

- [ ] T018 Run the final clean-tree pass: `dart run tool/lint_l10n_literals.dart` (exits 0), `dart run tool/lint_l10n_parity.dart` (exits 0). Confirm CI for the same commit is green for both new steps and the existing Phase 2 design-token guard step.
  - **Verify**: Both scripts exit 0 locally on a clean working tree; the latest CI run on the pushed commit shows green for the analyze-and-build job (no `flutter test` step present, per the durable no-new-tests rule).

- [ ] T019 Update `specs/003-localization/spec.md` `**Status**` line from `Draft` to `Implemented`. Per the durable git-workflow contract (`feedback_git_workflow.md`), open the squash-merge PR for the entire `003-localization` branch (one PR per spec, NOT per phase); reference the seven Phase 3 artifact files (`spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md`, `tasks.md`) and the implementation files in the PR body. End the git turn with the standard one-line summary.
  - **Verify**: `git status` is clean; `git log --oneline 003-localization ^main` shows the Phase 3 commits; PR is opened with the standard one-PR-per-spec structure; `**Status**: Implemented` appears in `spec.md`'s head matter; the one-line summary closes the turn.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1, T001)**: No dependencies — can start immediately.
- **Foundational (Phase 2, T002–T005)**: Depends on T001 (the lint exemption block must exist before the lint scripts in Phase 6 can read it; the configuration is foundational even though its consumers ship in US4). T002 + T003 are parallelizable (different files); T004 depends on T002 + T003; T005 depends on T004.
- **User Stories (Phases 3–6)**: All depend on Foundational completion. After T005 lands, US1, US2, US3, US4 can proceed in parallel if multiple developers are available; otherwise sequentially in priority order (US1 → US2 → US3 → US4).
- **Polish (Phase 7)**: Depends on all four user stories landing.

### User Story Dependencies (within Phase 3+)

- **US1 (P1, MVP)**: Foundational → T006 + T007 (audit + replace literals) → T008 (manual verify Step 1). No cross-story dependencies.
- **US2 (P1)**: Foundational → T009 (gallery chrome translation) → T010 (manual verify Steps 2/4/5/6). Independent of US1, US3, US4.
- **US3 (P2)**: Foundational → T011 (manual verify Step 3). No code change required; Phase 1 already wires the persistence path.
- **US4 (P2)**: Foundational → T012 + T013 (parallelizable lint scripts) → T014 (CI wiring) → T015 (manual verify Steps 8/9). Mostly independent — note that T013's "lint passes against the working tree" check implicitly verifies that US1 and US2 have actually replaced their literals. If US4 ships before US1 / US2 land their literal replacements, T013's verify will fail until they do; this is the intended interlock.

### Within Each User Story

- US1: T006 and T007 operate on different directories and can be done in either order or in parallel; both must be complete before T008.
- US2: T009 must be complete before T010.
- US3: single task.
- US4: T012 and T013 are parallelizable; T014 depends on both; T015 depends on T014.

### Parallel Opportunities

- **Phase 2**: T002 (`app_ar.arb`) and T003 (`app_en.arb`) are different files; can be edited in parallel. Both must complete before T004.
- **Phase 6 (US4)**: T012 (`tool/lint_l10n_parity.dart`) and T013 (`tool/lint_l10n_literals.dart`) are different files; can be implemented in parallel.
- **Phase 7 (Polish)**: T016 and T017 are independent manual sweeps; can be performed in any order or in parallel by two reviewers.
- **Across user stories**: After Foundational, US1 / US2 / US3 / US4 can be worked on by separate developers in parallel (subject to the US4 → US1/US2 interlock noted above).

---

## Parallel Example: Foundational Phase

```text
[parallel]   T002 — Expand lib/l10n/app_ar.arb to the floor
[parallel]   T003 — Expand lib/l10n/app_en.arb in parallel
[after both] T004 — flutter gen-l10n regenerates AppLocalizations
[after T004] T005 — Create lib/core/localization/app_strings.dart
```

## Parallel Example: User Story 4

```text
[parallel]   T012 — Create tool/lint_l10n_parity.dart
[parallel]   T013 — Create tool/lint_l10n_literals.dart
[after both] T014 — Wire both into .github/workflows/ci.yml
[after T014] T015 — Manual quickstart Steps 8 + 9
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002 → T003 → T004 → T005).
3. Complete Phase 3: User Story 1 (T006 → T007 → T008).
4. **Stop and validate**: walk quickstart Step 1 on the Infinix Note 8.
5. The MVP increment is the "fresh-install Arabic + RTL" experience; this is enough to unblock subsequent feature phases that depend on a working localization layer.

### Incremental Delivery

1. Setup + Foundational → Foundation ready.
2. Add US1 → quickstart Step 1 → demo (MVP).
3. Add US2 → quickstart Steps 2, 4, 5, 6 → demo (full bilingual UX).
4. Add US3 → quickstart Step 3 → demo (persistence works).
5. Add US4 → quickstart Steps 8, 9 → demo (regression guard locked).
6. Polish → quickstart Step 7 + Step 10 + final CI sweep → ready to merge.
7. Each story adds value without breaking the previous ones.

### Single-Developer Strategy (most likely path here)

1. Knock out Setup and Foundational in one sitting (T001 → T005).
2. **Pull US4 forward** — implement T012 / T013 immediately after Foundational, even though they're labeled P2. Reason: once the lint guards are live, every subsequent literal-replacement task (T006, T007, T009) gets immediate feedback. Without the guards you'll discover stragglers manually during quickstart Step 1.
3. Then US1 → US2 → US3 in priority order, each followed by its manual quickstart verification.
4. Polish (Phase 7) at the end.

---

## Notes

- [P] tasks operate on different files and have no dependency on incomplete tasks → parallelizable in a multi-developer setting.
- [USx] label maps a task to its user story for traceability.
- Each user story is independently completable and testable on the reference device.
- **No automated tests are added in Phase 3** (durable no-new-tests rule per `feedback_no_new_tests.md`). Verification = manual UI walkthrough on the Infinix Note 8 + the two static-analysis scripts.
- Per the durable git-workflow contract (`feedback_git_workflow.md`), commit after each task or logical group; ONE PR per spec at the end (not per phase); end the git turn with a one-line summary.
- The Phase 2 PropertyCard golden suite under `test/widgets/property_card_golden_test.dart` is preserved unchanged; it is NOT required to run as a Phase 3 acceptance gate.
- Total tasks: 19 (1 setup + 4 foundational + 3 + 2 + 1 + 4 + 4).
