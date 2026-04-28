# Feature Specification: Project Foundation

**Feature Branch**: `001-project-foundation`
**Created**: 2026-04-28
**Status**: Draft
**Input**: User description: "Phase 1 — Project foundation: runnable Android app shell with DI, routing, error handling, theme/locale switching scaffolding, backend client wrapper, logging — but no product features yet."

## Clarifications

### Session 2026-04-28

- Q: Minimum supported Android API level (minSdk)? → A: Android 7.0 (API 24). Chosen for broad device reach in Syria's market while avoiding the plugin/notification-compat headaches of API 21–23. API 26 was considered for cleaner Notification Channels in later phases but rejected because the reach loss is meaningful for Syrian users on older devices and the API 24/25 compat path is small.
- Q: Is continuous-integration setup part of Phase 1 scope? → A: Yes. Phase 1 ships a minimal hosted CI pipeline (static analysis + unit/widget tests + debug-APK build) that runs on every push to a feature branch and on every PR targeting `main`. Justified by Constitution Principle X (testable AI workflow): later phases need a green/red signal from day 1 to avoid regression rework.
- Q: Default theme behavior on first launch? → A: Follow the device's current system theme until the user makes an explicit in-app selection; once the user toggles, lock to that selection and stop following system theme changes. Matches Material 3 convention and avoids OS auto-night-mode overriding a deliberate user choice.
- Q: Accessibility baseline for the shell (and floor every later phase inherits)? → A: WCAG 2.1 AA, verified manually by reviewer in Phase 1 — concretely: honor system text scaling (no fixed-px font sizes; layouts accommodate up to 1.3× scale), contrast ≥ 4.5:1 for normal text and ≥ 3:1 for large text and meaningful icons, minimum 48dp touch targets, and a screen-reader label on every interactive element. Automated CI accessibility checks are deferred to a future spec (target: Phase 24 release polish or earlier).
- Q: How is "mid-tier target Android device" in SC-002 quantified? → A: Primary verification device is **Infinix Note 8** (MediaTek Helio G80 octa-core, 6 GB RAM, Android 10/11) — owned by the project lead and used for hands-on Phase 1 acceptance. "Equivalent" devices for QA fungibility: Samsung Galaxy A14 (4G, Helio G80, 4 GB RAM), Redmi Note 12, or any device with a Helio G80-class SoC and 4–6 GB RAM running the Phase 1 minSdk floor (API 24+). The CI emulator profile is sized to match the same class (ARM64, 4 GB RAM image). Higher-end devices are expected to comfortably exceed the SC-002 budget.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Runnable AlNujom Android shell from a clean clone (Priority: P1)

A new contributor clones the repository, follows the documented setup steps, and produces a debug build of the AlNujom Android app that launches on an emulator or physical device, displays an "AlNujom" branded landing surface, and demonstrates that the app's core platform plumbing is in place. No product features (listings, search, auth, etc.) are exercised yet — the goal is a stable shell that every later phase can build on top of.

**Why this priority**: Until the shell launches reliably, no other feature can be developed, demoed, tested, or reviewed. This is the gate that unblocks every subsequent phase of the AlNujom MVP.

**Independent Test**: A reviewer follows the project's documented setup, runs the project's debug build command, installs the resulting artifact on a target Android emulator, and observes the AlNujom shell screen rendering without crashes, with logging output visible in the debug console.

**Acceptance Scenarios**:

1. **Given** a clean clone of the repository on a workstation that meets the documented prerequisites, **When** the contributor runs the documented "setup + run" steps, **Then** an Android debug build is produced and the AlNujom shell launches on the target emulator/device and reaches an interactive state without errors in the debug log.
2. **Given** the shell is running, **When** the device is rotated or the app is backgrounded and resumed, **Then** the shell remains responsive and visual state is preserved.
3. **Given** the configured backend connection details are absent or malformed, **When** the app launches, **Then** the shell still reaches an interactive state and surfaces a clearly logged warning about backend availability rather than crashing.

---

### User Story 2 - Theme switching scaffolding works end-to-end (Priority: P2)

A reviewer running the AlNujom shell can toggle between a light and a dark theme from a visible control on the shell screen. The change is reflected immediately, applies consistently across the visible chrome of the shell, and survives a cold restart of the app.

**Why this priority**: The constitution requires light/dark theme parity through a centralized token module (Principle VI). Phase 2 will deliver the final design tokens, but the wiring for theme selection, propagation, and persistence must be proven in Phase 1 so that Phase 2 only swaps token values, not infrastructure.

**Independent Test**: A reviewer launches the shell, toggles the theme control once, observes the visible UI change, force-closes the app, relaunches it, and observes the previously selected theme is restored.

**Acceptance Scenarios**:

1. **Given** the shell is showing the default theme, **When** the reviewer activates the theme toggle, **Then** the shell visibly switches to the alternate theme within one rendered frame and the new theme is applied consistently to all visible shell chrome.
2. **Given** the reviewer has just switched themes, **When** the reviewer cold-starts the app, **Then** the app launches with the most recently selected theme.

---

### User Story 3 - Locale switching scaffolding with RTL/LTR mirroring (Priority: P3)

A reviewer running the AlNujom shell can toggle between Arabic (the default) and English from a visible control. When Arabic is active the shell uses a right-to-left layout; when English is active the shell uses a left-to-right layout. Localized strings update on the spot and the choice persists across cold restarts.

**Why this priority**: The product is Arabic-first (Principle V). The full Arabic and English copy lands in Phase 3, but the mechanism for locale selection, layout direction switching, and persistence must be proven in Phase 1 so that Phase 3 only adds translated strings, not infrastructure.

**Independent Test**: A reviewer launches the shell with the device in any system locale, observes the shell defaults to Arabic with RTL layout, toggles to English and observes the layout flips to LTR and any visible placeholder strings switch to English equivalents, force-closes and relaunches, and observes the most recent selection is restored.

**Acceptance Scenarios**:

1. **Given** the app is launched for the first time on the device, **When** the shell renders, **Then** the default locale is Arabic and the layout direction is RTL.
2. **Given** the shell is showing Arabic content, **When** the reviewer activates the locale toggle, **Then** the shell switches to English with LTR layout within one rendered frame and any visible placeholder strings update to their English equivalents.
3. **Given** the reviewer has just switched locales, **When** the reviewer cold-starts the app, **Then** the app launches in the most recently selected locale and direction.

---

### Edge Cases

- **Backend configuration missing or invalid at launch**: the shell still reaches an interactive state; a clear warning is logged; no crash dialog is shown to the user.
- **Rapid repeated toggling of theme or locale**: the final selected value is persisted exactly once and the visible state matches the persisted value with no flicker artifacts after the toggling stops.
- **Device-local preferences storage unavailable or denied**: the shell still launches with default theme and default locale; a warning is logged; toggling still works for the current session even if persistence fails.
- **Configuration change (rotation, system theme change, system locale change at OS level)**: once the user has made an in-app selection, that selection is not overridden by OS-level changes. Before any in-app theme selection has been made, OS-level theme changes ARE reflected in the shell (consistent with FR-016's "follow system until first explicit toggle"). For locale, the in-app default is always Arabic on first launch regardless of the device's system locale (FR-005).
- **Cold start under low-memory conditions**: the shell launches and persisted preferences load before the first interactive frame, or fall back to defaults with a logged warning if loading fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST produce an installable Android debug build artifact from the documented build command, runnable on a supported Android emulator or physical device.
- **FR-002**: On launch, the system MUST present an "AlNujom"-branded shell surface that reaches an interactive state without crashes on a freshly initialized install.
- **FR-003**: The shell MUST expose a visible control that toggles between light and dark themes, with the change applied to all visible shell chrome within one rendered frame.
- **FR-004**: The shell MUST expose a visible control that toggles between Arabic and English, applying right-to-left layout for Arabic and left-to-right layout for English, with the change applied within one rendered frame.
- **FR-005**: The default locale on first launch MUST be Arabic with right-to-left layout, regardless of the device's system locale.
- **FR-006**: The system MUST persist the user's theme and locale selections to device-local storage and restore them on subsequent cold starts.
- **FR-007**: The system MUST provide a centralized navigation mechanism that all later features will use to declare routes, with placeholder routes wired in Phase 1 so that future features add routes without changing the navigation foundation.
- **FR-008**: The system MUST provide a centralized service-locator/dependency-injection mechanism so future feature modules can register their own dependencies and resolve cross-cutting services without reaching into platform internals.
- **FR-009**: The system MUST wrap access to the backend client behind a project-defined interface so that domain-layer code in later phases never imports backend SDK types directly.
- **FR-010**: The system MUST provide a uniform success/failure result model so that use cases in later phases return outcomes without throwing exceptions across architectural boundaries.
- **FR-011**: The system MUST provide an application-wide logging mechanism with severity levels (debug, info, warning, error) usable from any layer, with verbose output enabled only in debug builds.
- **FR-012**: The system MUST provide a smoke test that exercises (a) the shell launches, (b) the theme toggle changes the active theme, and (c) the locale toggle changes the active locale and layout direction; this smoke test MUST pass on every CI run for the foundation branch.
- **FR-013**: When the backend client cannot be initialized due to missing or invalid configuration, the system MUST log a clear warning and continue to launch the shell rather than crashing the app.
- **FR-014**: The shell MUST avoid embedding any product feature (listings, search, authentication, profiles, admin functions, etc.); these arrive only in later phases.
- **FR-015**: The repository MUST include a hosted CI pipeline that, on every push to a feature branch (`001-*` or any future feature-branch prefix) and on every pull request (regardless of base branch), runs (a) static analysis, (b) the unit/widget test suite (including the smoke test from FR-012), and (c) a debug Android APK build. Pipeline failure MUST block merge; pipeline success MUST be visible on the PR status surface. Merge enforcement is implemented via GitHub branch protection requiring the `verify` workflow as a required status check on `main`.
- **FR-016**: On a first-ever launch (no persisted theme preference exists), the shell MUST adopt the device's current system theme (light or dark). After the user activates the theme toggle for the first time, the system MUST persist that explicit selection and MUST stop following subsequent device system-theme changes for the lifetime of that selection.
- **FR-017**: The shell and every later-phase screen MUST meet a WCAG 2.1 AA accessibility floor: (a) honor the device's system text-scaling setting up to at least 1.3× without truncation, overflow, or unreadable layout; (b) maintain a contrast ratio of at least 4.5:1 for body text and at least 3:1 for large text, icons, and other meaningful non-text UI; (c) ensure every interactive element has a touch target of at least 48dp in its minor dimension; (d) attach a screen-reader (TalkBack) label that describes purpose and current state to every interactive element. Phase 1 verifies these manually; future phases inherit the same floor.

### Key Entities *(include if feature involves data)*

- **App Shell**: the branded entry surface a user sees when the AlNujom Android app launches. In Phase 1 it carries only the brand mark and the theme/locale toggles; in later phases it becomes the host for the home, search, and other top-level surfaces.
- **User Preferences (local)**: the device-local record of the user's chosen theme (light/dark) and chosen locale (Arabic/English). Persisted only on the device, not tied to a user account in this phase.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new contributor with the documented prerequisites installed can produce a running debug build on an Android emulator within 30 minutes of cloning the repository, with no undocumented manual steps required.
- **SC-002**: On the primary verification device (Infinix Note 8 — MediaTek Helio G80, 6 GB RAM, Android 10/11) or an equivalent lower-mid-tier Android device (Galaxy A14 4G, Redmi Note 12, or any Helio G80-class SoC with 4–6 GB RAM on API 24+), the app reaches an interactive shell within 3 seconds of cold start in 95% of attempts across 20 consecutive launches.
- **SC-003**: A user toggling the theme or the locale sees the change applied within one rendered frame and the selection survives a cold restart in 100% of attempts across 20 consecutive toggle-and-restart cycles.
- **SC-004**: 100% of the smoke-test suite (shell launches; theme toggle works; locale toggle works; layout direction flips with Arabic) passes on every CI run for this phase.
- **SC-005**: A reviewer can confirm that no product feature (listings, search, auth, profiles, admin) is reachable from the shell — verified by manual exploration of every navigable surface in under 5 minutes.
- **SC-006**: After Phase 1 lands, Phase 2's first work item ("introduce design tokens") can be started without modifying any file outside the design-token module — verified at Phase 2 kickoff.

## Assumptions

- The technology stack (Flutter, Android target, Supabase as the v1 backend, BLoC/Cubit state management, feature-first Clean Architecture, Arabic and English as the two app locales) is fixed by the AlNujom Constitution v1.0.0 and is therefore not re-decided in this spec.
- The MVP target is Android only; iOS, Flutter Web, and desktop targets are explicitly out of scope per Constitution Principle XI.
- The minimum supported Android version is **Android 7.0 (API 24)**. This is the Phase 1 floor and applies to all subsequent phases unless an explicitly approved future spec changes it. The Gradle config and CI emulator image MUST target this floor.
- Backend connection details (project URL and anonymous client key) are supplied through environment-injected configuration at build/run time and are NOT committed to the repository.
- The Phase 1 shell carries placeholder visuals only; final design tokens land in Phase 2 and final translated copy lands in Phase 3. Stakeholder visual review of the shell is deferred until Phase 2 delivers the tokens.
- The theme and locale toggles in Phase 1 are placed on the shell screen itself for ease of testing; a real Settings screen lands in Phase 23 and will replace these placeholders.
- Authentication is out of scope for this phase; the shell does not gate behind a sign-in screen. Auth lands in Phase 5.
- Crash reporting, analytics, push notifications, deep linking, and feature flags are out of scope for this phase.
- A "successful launch" in this phase means reaching an interactive shell screen; it does not require the backend to be reachable, since real backend-dependent features arrive in later phases.
- Device-local persistence of theme and locale uses platform-standard secure local storage; no encryption requirement is mandated for these specific preferences in this phase.
- The smoke test runs against the debug build; release-build hardening is deferred to Phase 24.
- The hosted CI pipeline runs on GitHub Actions (the repository's existing GitHub host); switching CI providers is out of scope. The CI runner uses Linux + an Android SDK image targeting the Phase 1 minSdk floor.

## Out of Scope

- Any product feature: listings, search, map, contact/inquiries, favorites, reports, agencies, admin dashboards, ads, push notifications, profiles.
- Final design tokens, final translated strings, real Settings screen.
- iOS, Web, or desktop targets.
- Authentication, role/permission system, audit logging.
- Backend schema beyond the empty initialization stub required for the local Supabase project to start.
