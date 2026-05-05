# Feature Specification: Localization

**Feature Branch**: `003-localization`
**Created**: 2026-05-05
**Status**: Draft
**Input**: User description: "Phase 3 — Localization. ARB-driven localization wired through the app, RTL/LTR working end-to-end, locale persisted. Initial keys cover the app shell, the Phase 2 Theme Gallery, and the project's standard error messages; a build-blocking lint guard prevents new untranslated literals from leaking into feature code."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First launch in Arabic with RTL out of the box (Priority: P1)

A Syrian user opens AlNujom for the first time on a brand-new install. The app appears in Arabic with a right-to-left layout — every label, button, navigation item, and error message reads in Arabic, all leading-edge controls (back arrows, list bullets, drawer handles) sit on the correct (right) side, and nothing falls back to English placeholders, system defaults, or untranslated keys. The user has done nothing to configure language; this is the default experience.

**Why this priority**: AlNujom's primary audience is Syrian. If the app boots in English or in a half-translated state, the product fails its core users on the very first impression. Arabic-first is a non-negotiable constitutional principle (V); every later phase assumes the localization layer reliably delivers Arabic copy and RTL geometry without per-screen workarounds.

**Independent Test**: Wipe app data (or install fresh) on the reference device. Launch the app. Without touching any setting, confirm: every visible string is Arabic, the layout reads right-to-left, the locale toggle in the app shell reports Arabic as active, and no `key.like.this` placeholder appears anywhere on screen.

**Acceptance Scenarios**:

1. **Given** the app is installed for the first time on any Android device, **When** the user launches the app, **Then** every user-visible string is rendered in Arabic and the layout is right-to-left, regardless of the device's operating-system language preference.
2. **Given** the app shell, the Phase 2 Theme Gallery surface, and the standard error states (offline, missing config, generic failure) are visible at first launch, **When** the user inspects them, **Then** every label and message resolves to a translated Arabic string sourced from the version-controlled translation files — no untranslated keys, no English fallback strings, no system defaults.
3. **Given** any directional asset is on screen (back arrow, chevron, list affordance), **When** rendered in Arabic, **Then** it points and aligns according to right-to-left reading order.

---

### User Story 2 - Switching to English re-renders the entire UI in LTR (Priority: P1)

A user wants to see the app in English. They tap the locale toggle in the app shell. The whole interface — the screen they were on plus every other screen they navigate to next — re-renders in English with a left-to-right layout. Nothing is missed: the headline, the button labels, the bottom-nav captions, the error toast that was already on screen, the dialog they were about to open. The transition happens live in one frame; there is no app restart, no spinner, no flicker, no half-translated screen.

**Why this priority**: English is a co-equal locale (constitution V). A toggle that requires a restart, leaves stale strings on screen, or scrambles the layout breaks the trust contract for bilingual users — and many of AlNujom's brokers, agencies, and admins read English by preference. End-to-end live switching is also the only way to validate the localization wiring across the full widget tree.

**Independent Test**: Launch the app in Arabic. Tap the locale toggle. Walk through the visible screen plus three others (settings, about, theme gallery if available) and confirm every string is now English, the layout is left-to-right, and no string remains in Arabic. Toggle back; confirm the reverse.

**Acceptance Scenarios**:

1. **Given** the app is running in Arabic on any screen, **When** the user activates the locale toggle, **Then** the active locale changes to English and the visible screen rebuilds in English with a left-to-right layout within one frame, without an app restart.
2. **Given** the user has switched to English, **When** they navigate to any other screen, **Then** every string on that screen is English and the layout flows left-to-right; no Arabic copy or RTL alignment leaks through.
3. **Given** a dialog, snackbar, bottom sheet, or other overlay is open at the moment of switching, **When** the locale changes, **Then** the overlay's content rebuilds in the new language alongside the underlying screen — no overlay is left displaying the previous language.
4. **Given** the user toggles back to Arabic, **When** the next frame renders, **Then** the full UI returns to Arabic with right-to-left layout, indistinguishable from a fresh Arabic launch.

---

### User Story 3 - Locale choice persists across app restarts (Priority: P2)

A user switches the app to English on Monday, uses it briefly, and closes it. On Tuesday they reopen the app. The app remembers their choice and launches directly in English with a left-to-right layout — they do not have to toggle again. The same is true in the other direction: a user who switched to English and then back to Arabic finds the app in Arabic on the next cold start.

**Why this priority**: A locale toggle that resets every launch is a usability defect, not a feature. Persistence is the difference between a real preference and a momentary override. It is P2 (not P1) only because it is not on the critical path for first-time experience or the design-system-to-localization integration; the primary value still ships if persistence lands one increment later, which is why it is split out as its own slice.

**Independent Test**: In a debug build, switch the app to English. Force-stop or cold-restart the app. Relaunch and confirm the app boots straight into English without a transient flash of Arabic. Switch back to Arabic, restart, confirm Arabic. Wipe app data — confirm the default Arabic experience returns.

**Acceptance Scenarios**:

1. **Given** the user has switched the active locale (in either direction), **When** the app is force-stopped and cold-launched, **Then** the previously selected locale is the active locale at first frame — no transient flash of the other language.
2. **Given** Phase 5 (auth & profile) has not yet shipped, **When** the locale preference is written, **Then** it is stored in device-local secure storage and is read back on next launch.
3. **Given** the user clears the app's storage, **When** the app is launched, **Then** the default Arabic experience returns (US 1's acceptance scenarios apply again).

---

### User Story 4 - Build fails when a developer adds a new untranslated literal (Priority: P2)

A developer (human or AI agent) adds a new screen and writes `Text("Welcome back")` directly in a widget. They commit and push. An automated, build-blocking check runs over every file under `lib/` (except the explicit exemption list), detects the literal string, and fails the build with a message naming the file and line. The developer replaces the literal with a translation key reference, adds the key with both an Arabic and an English entry to the translation files, and the build passes. A second developer who tries to add only the Arabic entry (omitting English, or vice versa) is caught by a second check that enforces key parity between the two translation files.

**Why this priority**: Without an enforced guard, the localization layer rots within weeks: every feature added is a new way for an untranslated string to ship. The guard is the only durable mechanism that keeps the system honest as the team scales and as AI agents author code. It is P2 because the localization runtime can ship before the guard does — but the guard is the difference between Phase 3 holding the line forever and Phase 3 being the high-water mark.

**Independent Test**: On a development branch, add `Text("hello world")` to any widget anywhere under `lib/` that is not on the lint exemption list (e.g., a file under `lib/features/`, `lib/shell/`, or `lib/core/widgets/` consumer). Run the build / lint pipeline. Observe a build-blocking failure that names the offending file and line. Replace the literal with a translation key lookup, add the key to both translation files, re-run — build passes. Then drop the English entry from the translation file — observe the parity check fail. Restore — passes again.

**Acceptance Scenarios**:

1. **Given** a file anywhere under `lib/` that is not on the lint exemption list contains a literal string passed to a user-visible widget, **When** the lint / build pipeline runs, **Then** it fails with a message identifying the file, line, and offending literal, and the change cannot merge until the literal is replaced or the file is added to the explicit, version-controlled exemption list.
2. **Given** a translation key exists in only one of the two translation files, **When** the parity check runs, **Then** it fails with a message naming the missing key and the locale where it is absent.
3. **Given** a file is on the explicit exemption list (translation source files themselves, generated localization files, debug-only design tools, golden test fixtures), **When** the lint runs, **Then** literals in those files do not fail the build.

---

### Edge Cases

- **Missing translation key at runtime**: When a key is referenced from a widget but is absent in the active locale's translation file, the app MUST NOT crash and MUST NOT display an empty string. It logs a warning naming the missing key and falls back to the Arabic (default) string if available. In debug builds, the missing key is visibly surfaced (e.g., wrapped in a recognizable marker) so the gap is obvious during development.
- **Translation key collisions or rename**: A renamed key whose old name still exists somewhere in code is caught by the literal/key-existence check (the lint guard already rejects code that references a nonexistent key). The build fails until the rename is consistent.
- **Locale switch in the middle of a flow**: If the user has a partially-filled form open and toggles the locale, the form's *labels* and *placeholders* re-render in the new language while the user's *input* (their own data) is preserved untouched. The user does not lose progress.
- **Operating-system language change at runtime**: The app's active locale is the user's explicit choice (or the Arabic default), not the OS locale. Changing the OS language while the app is running does not change the app's locale. (Auto-following the OS locale is explicitly out of scope; see Assumptions.)
- **Strings with placeholders**: Translation entries may include named or positional placeholders (e.g., `{count}`, `{name}`). The translation system MUST render placeholders correctly in both directions; a placeholder appearing inside an Arabic string MUST not break RTL flow.
- **Pluralization and select forms**: Plural and gender-aware forms are supported by the underlying tooling. Phase 3 introduces them only where the initial corpus needs them; bulk rework of existing keys is not required.
- **Directional assets and gestures**: Back arrows, chevrons, swipe-to-dismiss directions, and list-row leading affordances flip with the locale. No directional value is hardcoded.
- **Bilingual font fallback (Phase 2 boundary)**: When the active locale is Arabic, the bilingual font stack already shipped in Phase 2 resolves to Arabic-script families (Cairo, IBM Plex Sans Arabic); when the locale is English, the same stack resolves to Inter. Phase 3 does not introduce new font assets; it only ensures the stack is consulted with the correct locale.
- **Numeric, date, and currency formatting**: OUT OF SCOPE for Phase 3 (locked in Assumptions and FR-013). These are owned by the phases that introduce those data types (currency: Phase 9; dates: in-context per feature).
- **Exemption list abuse**: The lint exemption list is explicit, version-controlled, and reviewed; adding an entry to it is a code change that goes through the standard PR review. There is no implicit exemption based on file naming or directory.

## Clarifications

### Session 2026-05-05

- Q: Which directory trees does the literal-string lint guard scan? → A: All of `lib/` except the explicit, version-controlled exemption list (translation source files, generated localization files, debug-only design tools, golden test fixtures).
- Q: Does Phase 3 ship a separate Syrian-Arabic locked terms list, or is it deferred? → A: Defer the standalone artifact, but seed 7 high-recurrence terms inline in FR-011 so the next several phases have anchors. The full content-style spec is owned by a future operations/content phase.
- Q: How much of the Phase 2 Theme Gallery must be translated by Phase 3? → A: Top-level chrome only — page title, palette/theme/locale toggle labels, and section headers. Per-component and per-state labels remain English in this debug-only, tree-shaken surface and may be translated lazily by later phases that expose those components in production screens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST default to Arabic (locale `ar`) on first launch with full right-to-left layout, regardless of the device's operating-system language preference.
- **FR-002**: System MUST support English (locale `en`) as a co-equal locale; the user MUST be able to switch between `ar` and `en` from the app shell control wired in Phase 1.
- **FR-003**: A locale switch MUST rebuild every visible surface (active screen, dialogs, sheets, snackbars, navigation chrome) in the new language and corresponding layout direction (RTL ↔ LTR) within one frame, without an app restart and without a transient flash of the previous language.
- **FR-004**: All user-visible strings rendered by the application MUST be sourced from version-controlled translation files: `app_ar.arb` (default) and `app_en.arb`. No code under `lib/` (outside the explicit lint exemption list) MUST contain a literal string passed to a user-visible widget.
- **FR-005**: Adding a translation key MUST require both an `ar` and an `en` entry. An automated, build-blocking parity check MUST fail the build when a key exists in one translation file but not the other.
- **FR-006**: System MUST provide an automated, build-blocking guard that scans all of `lib/` — except the files matching the explicit, version-controlled exemption list — for literal strings passed to user-visible widget constructors, and fails the build until each detected literal is replaced by a translation-key lookup. The exemption list MUST cover, at minimum, translation source files, generated localization files, debug-only design tools, and golden test fixtures, and MUST be reviewable as part of the codebase. There is no implicit exemption based on directory naming or file path patterns outside the list.
- **FR-007**: System MUST persist the user's selected locale across app cold restarts. Until Phase 5 (Auth & Profile) ships, persistence MUST use device-local secure storage. Once Phase 5 ships, the user-scoped `user_preferences.locale` row MUST become the source of truth, and the migration from local-only to user-scoped storage MUST be owned by the Phase 5 spec.
- **FR-008**: When a translation key referenced at runtime is absent from the active locale's translation file, the app MUST NOT crash, MUST NOT render an empty string, MUST log a warning identifying the missing key, and MUST fall back to the Arabic (default) string if one exists. In debug builds, the missing key MUST be visibly surfaced so the gap is obvious during development.
- **FR-009**: Layouts MUST use directional alignment primitives only (logical insets, directionality-aware widgets); hardcoded `left`/`right` positional values are forbidden in feature code. Directional assets (back arrows, chevrons, list affordances, gesture directions) MUST flip with the active locale.
- **FR-010**: Initial translation coverage MUST include, at minimum: app shell strings (titles, navigation labels, theme/locale toggle controls), the Phase 2 Theme Gallery **chrome only** (page title, palette/theme/locale toggle labels, section headers), and the project's standard error messages (offline, missing backend configuration, generic failure). Per-component and per-state labels inside the Theme Gallery — being part of a debug-only, tree-shaken surface — MAY remain English in Phase 3 and are translated lazily by whichever later phase exposes the underlying component in a production screen. The set of initial keys is the floor — features that ship after Phase 3 add their own keys; they MUST NOT regress this floor.
- **FR-011**: Arabic copy MUST be Syrian-friendly, professional, and clear. Phrasings that read stiff or overly formal in Modern Standard Arabic MUST be replaced by natural Syrian-friendly equivalents when one exists. The seed terms below are the locked Phase 3 anchors; later phases that introduce new domain vocabulary extend this seed in their own specs. A full standalone glossary / style guide is deferred to a future content-style spec.

  | English source | Syrian-friendly Arabic | Note |
  |----------------|------------------------|------|
  | listing        | إعلان                   | The posted property entry. "قائمة" reads as menu/list, not as a marketplace post. |
  | office / agency | مكتب                   | Everyday Syrian term for a real-estate office; "وكالة" reads corporate/formal. |
  | broker / agent | وسيط                    | Direct Syrian usage for the person who connects buyer and seller. |
  | approve        | موافقة                  | Used for admin approval actions; "اعتماد" reads bureaucratic. |
  | pending review | قيد المراجعة             | Status label for items awaiting moderator action. |
  | contact        | تواصل                   | Preferred over "اتصال" for in-app contact buttons and CTAs. |
  | inquiry        | استفسار                 | A buyer-to-seller question on a listing. |

  *(The Arabic column is a first-draft Syrian anchor; reviewers may refine wording during translation passes without amending this requirement.)*
- **FR-012**: Locale switching MUST be exposed via the existing app shell control (`LocaleCubit.toggle()`); Phase 3 MUST NOT introduce a new top-level locale-management surface or migration UI. Settings-level locale management is owned by Phase 23 (App Settings) and is out of scope here.
- **FR-013**: Numeric, date, and currency formatting MUST NOT be introduced as part of this feature. Localization-aware formatting lands with the phase that owns the corresponding data type (currency: Phase 9; dates: in-context per feature). FR-013 is a scope boundary, not a behavior requirement, and exists explicitly to prevent scope creep.
- **FR-014**: When the active locale is Arabic, the bilingual font stack shipped in Phase 2 MUST resolve to Arabic-script families (Cairo, IBM Plex Sans Arabic); when the locale is English, the same stack MUST resolve to Inter. Phase 3 MUST NOT introduce new font assets; it ensures the stack is consulted with the correct locale.
- **FR-015**: A locale switch performed while the user has unsubmitted form input on screen MUST NOT discard the user's input; only the surrounding labels, placeholders, helper text, and validation messages MUST change language. The user's typed values are preserved verbatim.

### Key Entities

- **Locale Preference**: The user's active locale (`ar` or `en`). Persisted device-locally (secure storage) until Phase 5; migrates to the user-scoped `user_preferences.locale` row once authenticated profiles ship.
- **Translation File**: A version-controlled ARB document — one per supported locale (`app_ar.arb`, `app_en.arb`). Single source of truth for user-visible copy. Each translation key has exactly one entry per file.
- **Translation Key**: A namespaced identifier (e.g., `homeWelcome`, `errorOffline`) that resolves to a localized string at render time. Keys are referenced from widget code; they MUST exist in every translation file or the build fails.
- **Layout Direction**: Derived from the active locale (Arabic → RTL, English → LTR). Drives every directional alignment primitive in the app — there is no separate "direction" preference exposed to users.
- **Lint Exemption List**: An explicit, version-controlled allowlist of file patterns that are exempt from the literal-string-in-widget guard (translation source files, generated localization files, debug-only design tools, golden test fixtures). Maintained in `analysis_options.yaml`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh install of the app boots into Arabic with right-to-left layout across every fresh-install verification, regardless of the device's operating-system locale, with no transient flash of any other language at first frame. Verified by manual launch on the reference device.
- **SC-002**: A locale toggle propagates across the entire visible UI within one frame (≤ 16 ms after the toggle action) and leaves zero pages, dialogs, sheets, or snackbars in the previous language.
- **SC-003**: A user's chosen locale persists across cold restarts; opening the app after a force-stop displays the locale active at the close of the previous session. Verified by manual switch-and-restart walkthrough on the reference device.
- **SC-004**: 100% of user-visible strings rendered by code under `lib/` resolve through the translation system — verified by an automated build-blocking guard that detects zero literal strings in any file under `lib/` outside the explicit exemption list.
- **SC-005**: Every translation key has both an `ar` and an `en` entry — verified by an automated parity check that fails the build on any key drift between the two translation files.
- **SC-006**: When a translation key is missing from the active locale at runtime, the app does not crash and does not render an empty string — verified during quickstart by intentionally referencing a key absent from `app_ar.arb`, launching on the reference device, and observing the warning log alongside the documented fallback rendering.
- **SC-007**: Wiring localization end-to-end introduces no visible regression in the existing `PropertyCard` rendering — verified by manual side-by-side review on the reference device across the four ar/en × light/dark combinations before and after the Phase 3 change. (The Phase 2 golden suite remains in source for later use but is not required to run as part of Phase 3 acceptance.)
- **SC-008**: A reviewer can trace any user-visible string from its on-screen position back to its translation key and to both translation file entries by reading only the screen's widget tree and the two translation files — no source code spelunking beyond the screen.
- **SC-009**: Switching the active locale while a form has unsubmitted input preserves the user's input across every verification scenario — only the surrounding labels, placeholders, helper text, and validation messages re-render in the new language. Verified manually on the reference device by toggling locale mid-flow on at least one form-bearing screen reachable in this phase.
- **SC-010**: On the reference device (Infinix Note 8, Helio G80, 6 GB RAM, Android 10/11), a fresh install reaches the first usable Arabic screen within the project's standard cold-start budget (≤ 3 s, per the constitution's performance baseline), and a runtime locale toggle is perceptibly instant (no spinner, no jank, no full-screen rebuild visible to the user).

## Assumptions

- **Phase 1 and Phase 2 foundations are in place**: `LocaleCubit`, `PreferencesStore`, the secure-storage abstraction, the design-token module, and the bilingual font stack from `specs/001-project-foundation/` and `specs/002-design-system/` are already shipped. Phase 3 wires translations into them rather than reintroducing infrastructure.
- **Default locale on first launch is Arabic**, regardless of the device's operating-system locale. This honors the Arabic-first constitutional principle (V); auto-following the OS locale is explicitly out of scope and is not a feature toggle.
- **Locale persistence storage transitions in two stages**: device-local secure storage during Phases 3–4, then `user_preferences.locale` once Phase 5 ships authenticated profiles. The migration of an existing local choice into the user-scoped row at first sign-in is owned by the Phase 5 spec, not Phase 3.
- **Missing-translation policy** (chosen MVP behavior, recorded per Principle XII): log a warning, render the Arabic default if available; in debug builds, surface the missing key visibly. Rejected alternatives: silently render an empty string (hides the gap) and crash on missing key (unsafe).
- **Pluralization, gender-aware, and ICU select expressions** are supported by the underlying ARB tooling but are introduced lazily — only when a feature spec actually needs them. Phase 3 does not bulk-rework existing keys to add plural forms preemptively.
- **Numeric, date, and currency formatting localization is OUT OF SCOPE for Phase 3** and is owned by feature phases that introduce those data types (currency: Phase 9; dates: in-context per feature). FR-013 makes this scope boundary explicit so it cannot be silently expanded during implementation.
- **Lint guard exemption list** covers, at minimum: translation source files (`lib/l10n/`), generated localization files (`lib/l10n/app_localizations*.dart`), debug-only design tools (Theme Gallery, Palette Tester), and golden test fixture files. Exemptions are explicit and version-controlled in `analysis_options.yaml`; adding a new entry is a reviewable code change.
- **Initial translation corpus**: the scaffolding-era ARB keys added during Phase 1 (app title, theme/locale toggle labels, current-theme/locale labels, the missing-config warning) carry over as the starting set. Phase 3 expands this set to cover the Phase 2 Theme Gallery labels and the project's standard error messages; it MAY rename or remove a scaffolding key only if the resulting translation gap is filled in the same change.
- **No new top-level locale UI**: Phase 3 wires the existing `LocaleCubit.toggle()` control surfaced in Phase 1; a fuller Settings-level locale management screen (with explicit "auto / ar / en" choices, per-account vs per-device clarification, and an "About translations" pane) is owned by Phase 23 (App Settings).
- **No backend dependency**: Phase 3 is frontend-only. No Supabase tables, RLS policies, or edge functions are introduced or modified. The `user_preferences.locale` column referenced by FR-007 is created by Phase 4 (Supabase base schema), not by Phase 3.
- **No app icon, splash branding, or marketing-locale assets**: Phase 3 covers translated copy and layout directionality only. Locale-specific imagery, app-store metadata, and splash text are out of scope here.
- **Reference device for sign-off**: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) per project memory.
- **Translator workflow and external translation services** (e.g., handing ARB files to a professional translator, importing back) are out of scope for Phase 3. Phase 3 ships the runtime, the guard, and the initial corpus authored in-repo; a downstream operations spec MAY introduce the translator workflow when the corpus grows beyond what the team can maintain inline.
- **Verification posture is manual until the MVP is feature-complete**: Phase 3 does NOT introduce new automated tests of any kind — no unit tests, widget tests, integration tests, golden tests, runtime smoke tests, or CI test jobs. The build-time **lint guard** (FR-006) and the **translation-key parity check** (FR-005) are static analysis, not tests, and ARE in scope. All other acceptance criteria are validated by manual UI walkthrough on the reference device. The Phase 2 `PropertyCard` golden suite already in the repository is preserved unchanged but is not required to run as a Phase 3 gate. This posture is durable across the remaining phases of the IMPLEMENTATION_PLAN; revisiting test coverage is a deliberate post-MVP exercise.
