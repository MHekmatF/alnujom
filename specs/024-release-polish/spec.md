# Feature Specification: Release Polish, Distribution & QA Pass

**Feature Branch**: `024-release-polish`
**Created**: 2026-06-02
**Status**: Draft
**Input**: Phase 24 — Release polish, distribution, QA pass, from `docs/IMPLEMENTATION_PLAN.md` (§ "Phase 24 — Release polish, distribution, QA pass", plus §2 "Critical Syria-specific notes" on crash reporting + distribution, §14 "Distribution & release" (Channel A direct-APK, Channel B Play Store internal track, versioning, crash reporting), §15 "Risks & mitigations" (distribution risk + account-recovery dead-end documented in Phase 24 release notes), §16 "Open questions" ("Crash reporting tool (Sentry self-hosted vs EU vs alternative)? → Resolved by Phase 24 spec"), and §12 "Testing posture" (the four golden paths re-run after Phases 19, 21, 22))

> **Scope note**: Phase 24 is the **release-hardening phase** — it does not add a new product feature; it makes the already-built v1 marketplace **shippable**: a signed, production-grade Android build that real Syrian users can install and keep current, observable enough to operate after launch, and proven end-to-end against the golden-path checklist. The phase ships exactly: **(a) a signed, production-grade release build** — version **`1.0.0`**, the final **app icon + adaptive icon + splash** rendered correctly in both light and dark, no debug-only scaffolding, that installs and boots cleanly on a **fresh Android device** with no prior app data; the release **signing identity** is handled as a secret (keystore + passwords live outside the repository per the ADR-0001 secrets posture, never committed), and the build **fails closed** if the signing config is absent (no accidental debug-signed "release"); **(b) crash & error reporting** — uncaught/fatal Dart and platform errors are captured and surfaced on a **sanctions-safe, Syria-reachable dashboard** (**Sentry**, self-hosted or EU-region instance — Firebase Crashlytics is rejected as sanctions-risky, resolving the §16 open question), wired behind the existing logger abstraction in `lib/core/logging/` so the **domain layer stays provider-agnostic** (Principle IX); a deliberately-forced exception in a dev build appears on the dashboard; crash payloads are **scrubbed of secrets and PII** (no Vault secrets, no synthetic-email→phone mapping, no decrypted personal data) and the reporter **never itself blocks app start or crashes** if the dashboard is unreachable; **(c) an in-app update prompt** — on **cold start** the app reads the latest available version from a **Supabase-hosted version manifest** (Supabase Storage — an existing dependency already reachable from Syrian IPs, with **no Cloudflare/Google CDN dependency**) and, if a newer version exists, shows a **localized** prompt with a **download affordance** pointing to the **Telegram channel** (and the project website when available); a missing, unreachable, or malformed manifest is a **silent, graceful no-op** (the app keeps working, shows no false prompt, and never crashes); **(d) distribution channels live** — the signed APK is published to the **Telegram channel** (primary for Syrian users) with the manifest + APK on a directly-reachable origin, and a **Play Store internal testing track** is configured for QA/stakeholders only (not advertised to end users); **(e) the golden-path QA pass** — all **six** golden paths are verified for `1.0.0` (register → admin-approve → publish → admin-approve → public view → inquiry; anonymous browse + filter + map; admin reports-queue resolution; super-admin role create + assign + revoke; currency switch + exchange-rate update; maintenance mode + recovery), **closing the items earlier phases explicitly deferred to "the Phase 24 golden-path QA pass"** (the Phase 19 agency follow-ups, the Phase 22 live-QA items T044–T046, and the recurring async-cubit `isClosed`-guard sweep) — and the QA evidence is **hybrid**: **manual** on-device (Infinix Note 8) + emulator (Pixel 8 Pro AVD) walks for **all six** paths, **plus one automated integration test** for the **primary publish path**, while the **maintenance-mode (two-device)** and **push-delivery** paths remain **manual** because neither can be observed in a single in-process test; **(f) release documentation** — `docs/release/v1.0.0.md` records the six golden-path results, the install/update instructions, and the **no-email account-recovery support flow** (admin issues a temporary password via the super-admin UI, §15); and **(g) a final localization + theming + stability polish** — every new user-visible string (the update prompt — crash reporting is automatic with **no consent UI**, so there is no consent surface to localize) flows through `AppLocalizations` with `ar` + `en` entries and renders correctly in all four (light / dark) × (Arabic RTL / English LTR) combinations using Phase 2 tokens, and the recurring "missing `isClosed` guard in async cubit loads" issue is swept so the new crash monitoring is not polluted with benign noise. Phase 24 honors Principle V (all new UI strings localized `ar` / `en`), Principle VI (new surfaces themed via Phase 2 tokens, four-combination correct), Principle X (every acceptance criterion has an executed, recorded verification — the golden-path pass), and Principle XI (Android-only; **no iOS/Web code or non-Android-only plugin** is introduced), and also respects Principle II (the version manifest, signing config scaffolding, and any seed are checked-in / source-controlled, secrets excepted), Principle III (crash payloads scrubbed of secrets/PII; signing key never committed), Principle IX (crash + update wiring lives in `core/`, no Supabase import under any `domain/`), and Principle XII (the three release decisions below are recorded, not hidden). Phase 24 does **NOT** add a new product feature, a new business-data table, or a new permission key; does **NOT** add iOS, Flutter Web, or desktop targets; does **NOT** ship in-place / silent auto-update (the update path is a **manual download prompt** only); does **NOT** automate all six golden paths (only the primary publish path is automated — the standing "no new automated tests until the MVP is feature-complete" convention is relaxed for exactly this one release-hardening test); and does **NOT** introduce paid promoted-listing checkout, auto-translation, advanced analytics, or any third-party ad-network keys (all forward-stated future work per the plan's non-goals).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — A signed, production-grade build boots on a fresh device (Priority: P1)

A QA tester (or an end user) installs the signed `1.0.0` release APK on a **fresh** Android device that has never run the app, and it boots cleanly to the first usable screen — showing the final app icon on the launcher and the final splash — in both light and dark system themes, with no debug banners, no developer scaffolding, and no missing-asset placeholders.

**Why this priority**: P1 because the signed, bootable release artifact is the entire point of the phase and the plan's first acceptance criterion ("Signed APK boots on a fresh Android device"). Every other story either hardens, distributes, or verifies this one build.

**Independent Test**: Build the signed release APK at version `1.0.0`, install it on a wiped device / fresh emulator profile with no prior app data, and confirm it launches to the first usable screen with the final icon and splash, in both light and dark, with no debug-only UI. Confirm the build fails to produce a release artifact if the signing config is missing (no debug-signed fallback).

**Acceptance Scenarios**:

1. **Given** the signed `1.0.0` release APK, **When** it is installed on a fresh Android device and launched, **Then** it boots to the first usable screen without crashing, in both light and dark system themes.
2. **Given** the installed build, **When** the launcher and splash render, **Then** the final app icon (including adaptive icon) and splash appear correctly in light and dark — no placeholder, no clipped or mis-tinted asset.
3. **Given** a release build attempt with the signing config absent, **When** the build runs, **Then** it fails closed (no debug-signed artifact is silently produced).
4. **Given** the running release build, **When** any screen renders, **Then** no debug banner, debug-only route, or developer scaffolding is visible.

---

### User Story 2 — Crashes and fatal errors are captured and visible to the team (Priority: P1)

When the app hits an uncaught or fatal error in the field, the failure is captured and surfaced on a dashboard the team can actually reach from Syria, without sanctions risk and without leaking any user's private data. An engineer can open the dashboard, see the error with a usable stack trace, and confirm no secrets or personal data are in the payload.

**Why this priority**: P1 because a launched product cannot be operated blind, and this is the plan's second acceptance criterion ("Crash-reporting captures a forced exception in dev build"). It also resolves the §16 open question by committing to **Sentry (self-hosted or EU instance)** and rejecting Crashlytics (sanctions risk).

**Independent Test**: In a dev build, deliberately trigger an uncaught exception and confirm it appears on the crash dashboard within a few minutes with a usable stack trace. Inspect the report payload and confirm it contains **no** secrets (no Vault material), **no** synthetic-email→phone mapping, and **no** decrypted PII. Take the dashboard offline / unreachable and confirm the app still starts and runs normally.

**Acceptance Scenarios**:

1. **Given** a dev build wired to the crash dashboard, **When** an uncaught exception is forced, **Then** the error appears on the dashboard with a usable stack trace within a few minutes.
2. **Given** any captured report, **When** its payload is inspected, **Then** it contains no secrets, no synthetic-email→phone mapping, and no decrypted PII (scrubbed before send).
3. **Given** the crash dashboard is unreachable (offline / endpoint down), **When** the app starts and runs, **Then** the reporter degrades silently — it never blocks app start and never itself crashes the app.
4. **Given** the crash reporting wiring, **When** the codebase is inspected, **Then** it lives behind the existing logger abstraction in `lib/core/logging/` and no `domain/` layer imports the crash-reporting SDK (Principle IX).

---

### User Story 3 — The six golden paths pass end-to-end for the release (Priority: P1)

Before the build ships, the whole product is exercised end-to-end against the golden-path checklist: a user registers and is admin-approved, publishes a listing that an admin approves and that then appears publicly and receives an inquiry; an anonymous visitor browses, filters, and views the map; an admin resolves a report; a super-admin creates, assigns, and revokes a role; a user switches display currency after an admin updates the exchange rate; and maintenance mode is toggled on and recovered. Each path is confirmed working on the release build, and any defect prior phases deferred to "the Phase 24 QA pass" is closed or explicitly re-deferred with a reason.

**Why this priority**: P1 because the golden-path pass is the release gate and the plan's third acceptance criterion ("All six golden paths pass"). It is also where the items earlier phases punted to "the Phase 24 golden-path QA pass" (Phase 19 agency follow-ups; Phase 22 live-QA T044–T046; the recurring `isClosed`-guard cleanup) come due.

**Independent Test**: On the release build, run each of the six golden paths on the reference Infinix Note 8 and the Pixel 8 Pro AVD, recording the result of each. Additionally run the one automated integration test covering the primary publish path (register → admin-approve → publish → admin-approve → public view → inquiry) and confirm it passes. Confirm the maintenance (two-device) and push paths are verified manually. Confirm each previously-deferred-to-Phase-24 item (Phase 19 agency follow-ups, Phase 22 T044–T046, the async-cubit `isClosed` sweep) is **fixed in this PR**.

**Acceptance Scenarios**:

1. **Given** the release build, **When** the six golden paths are walked, **Then** each completes successfully and the result is recorded (Principle X — verification executed and recorded).
2. **Given** the primary publish path, **When** the automated integration test runs, **Then** it passes (register → approve → publish → approve → view → inquiry).
3. **Given** the maintenance-mode and push paths, **When** they are verified, **Then** they are verified **manually** (maintenance two-device; push real-delivery) because neither is observable in a single in-process test.
4. **Given** the items earlier phases deferred to the Phase 24 QA pass (Phase 19 agency follow-ups, Phase 22 T044–T046, the async-cubit `isClosed` sweep), **When** the QA pass completes, **Then** each is **resolved (fixed) in this PR** — no re-deferral of these named items.

---

### User Story 4 — Users are prompted to update to the latest APK (Priority: P2)

Because most Syrian users install by direct APK rather than through an app store, the app keeps them current itself: on cold start it checks whether a newer version is available, and if so shows a clear, localized prompt with a button that takes them to the download (the Telegram channel, or the project website when available). If the check cannot reach the version source, the app simply opens normally — no error, no false prompt, no crash.

**Why this priority**: P2 because keeping the direct-APK audience current is important for the primary Syrian distribution channel, but the app is fully usable without the prompt; it layers on the shippable build (US1) rather than gating it.

**Independent Test**: Publish a manifest entry whose latest version is higher than the installed build and cold-start the app → confirm a localized update prompt appears with a working download affordance. Set the manifest equal to / lower than the installed version → confirm no prompt. Make the manifest unreachable / malformed and cold-start → confirm the app opens normally with no prompt and no crash.

**Acceptance Scenarios**:

1. **Given** the version manifest advertises a newer version than the installed build, **When** the app cold-starts, **Then** it shows a localized update prompt with a download affordance pointing to the Telegram channel (and/or the project website).
2. **Given** the manifest advertises the same or an older version than installed, **When** the app cold-starts, **Then** no update prompt is shown.
3. **Given** the manifest is unreachable or malformed, **When** the app cold-starts, **Then** the version check is a silent no-op — the app opens normally, shows no prompt, and does not crash.
4. **Given** the update source, **When** it is inspected, **Then** it is the Supabase-hosted version manifest with no dependency on Cloudflare / Google CDNs (reachable from Syrian IPs).

---

### User Story 5 — Distribution channels are live and the release is documented (Priority: P2)

The signed `1.0.0` APK is actually reachable by the people who need it: it is posted to the Telegram channel for end users, and an internal Play Store testing track is configured so QA and stakeholders can install it without it being advertised publicly. A release-notes document records what shipped, the golden-path results, how to install and update, and what a user without an email does if they forget their password.

**Why this priority**: P2 because a build nobody can reach is not a release; distribution + documentation make the verified build usable and operable. It depends on US1's signed artifact.

**Independent Test**: Confirm the signed APK is downloadable from the Telegram channel and installs on a fresh device. Confirm the Play Store internal testing track shows the build to an enrolled QA tester. Confirm `docs/release/v1.0.0.md` exists and covers the six golden-path results, install/update instructions, and the no-email account-recovery support flow.

**Acceptance Scenarios**:

1. **Given** the signed `1.0.0` APK, **When** a user opens the Telegram channel, **Then** the APK is retrievable and installs on a fresh Android device.
2. **Given** the Play Store internal testing track, **When** an enrolled QA tester checks it, **Then** the `1.0.0` build is available to them and is not advertised to the public.
3. **Given** the release, **When** `docs/release/v1.0.0.md` is opened, **Then** it documents the golden-path results, install/update instructions, and the no-email account-recovery support flow (admin-issued temporary password via super-admin UI).

---

### User Story 6 — Final localization, theming & stability polish (Priority: P3)

Every surface added or touched in this phase — the update prompt and the splash — reads correctly in Arabic (RTL) and English (LTR), in light and dark, with no untranslated text and no hardcoded styling. The recurring background noise from cubits that emit after close is cleaned up so the new crash monitoring shows real problems, not benign churn.

**Why this priority**: P3 because localization and theming are cross-cutting quality gates the plan enforces for every phase (Principles V, VI), and the stability sweep refines signal quality for the new observability rather than being a standalone capability.

**Independent Test**: Open the update prompt and cycle the four combinations — (light, ar), (dark, ar), (light, en), (dark, en) — on the Infinix Note 8 and a 412 dp emulator profile; confirm every string is localized (no raw literals), layout is direction-correct, and styling comes from Phase 2 tokens. Exercise the previously-noisy async-cubit navigations and confirm the "emit after close" errors no longer appear in the logs / crash stream.

**Acceptance Scenarios**:

1. **Given** the app locale is Arabic, **When** the update prompt renders, **Then** all strings appear in Arabic and the layout is RTL-correct.
2. **Given** the app locale is English, **When** the same surface renders, **Then** all strings appear in English and the layout is LTR-correct.
3. **Given** light and dark themes, **When** the new surfaces render in each, **Then** all colors, typography, spacing, and elevation come from Phase 2 tokens (no inline hex, no raw font size, no ad-hoc padding).
4. **Given** the navigations that previously logged "emit after close", **When** they are exercised on the release build, **Then** those benign errors no longer appear in the logs / crash stream.

---

### Edge Cases

- **Signing config absent at build time**: the release build **fails closed** — no debug-signed artifact is silently produced and shipped as a "release."
- **Signing keystore handling**: the keystore and its passwords are **never committed** to the repository; they are supplied at build time from outside the repo (per the ADR-0001 secrets posture), and the build references them, not literal key material.
- **Crash dashboard unreachable**: captured reports are dropped/queued locally; the app **never blocks start or crashes** because the crash endpoint is down.
- **Crash payload would contain PII/secrets**: synthetic-email/phone, Vault secrets, and decrypted personal data are **scrubbed before send** — a report never leaks private data.
- **Fresh-device first boot with no network**: the app reaches its first usable screen on safe defaults (consistent with the Phase 23 fail-open posture); neither the crash-reporter init nor the update check blocks boot.
- **Version manifest unreachable / malformed / empty**: the cold-start version check is a **silent no-op** — no prompt, no error toast, no crash.
- **Installed version newer than the manifest** (a dev/QA build): no update prompt is shown.
- **Update-prompt cadence**: the prompt appears **once per cold start** while a newer version exists; tapping "Later" hides it for that session only and it **re-appears on the next cold start** until the user updates (no persisted "dismissed version" in v1).
- **A future "minimum-supported version"**: a force-update (blocking) prompt is **forward-stated** — v1 ships a **dismissible** update prompt only; a hard minimum-version gate is a later spec.
- **Play Store track unreachable from Syria for a tester**: the Telegram / direct-APK channel is the fallback and is documented as the primary path (the Play Store track is QA-only).
- **Golden path touching maintenance or push**: verified **manually** (maintenance is a two-device observation; push needs a real FCM round-trip) — these are explicitly **not** in the one automated test.
- **An item earlier phases deferred to the Phase 24 QA pass**: the three named carried-over items (Phase 19 agency follow-ups, Phase 22 T044–T046, the async-cubit `isClosed` sweep) are **fixed in this PR — no re-deferral**; a *new* issue first surfaced during the QA walk that is out of release scope is still recorded in `DEFERRED.md` with a rationale rather than silently dropped.
- **No-email user forgets password**: handled by the documented support flow (admin issues a temporary password via the super-admin UI) — recorded in the release notes, not new code.
- **Build number vs release version**: the user-facing release version is `1.0.0`; the build number (`+N`) may increment per build without changing the release version shown to users.

## Requirements *(mandatory)*

### Functional Requirements

#### Release build & app identity

- **FR-001**: The system MUST produce a **signed release Android build** at version **`1.0.0`** that **installs and boots cleanly on a fresh Android device** (no prior app data) to the first usable screen, with **no debug-only scaffolding** (no debug banner, no developer-only routes) visible in the release build.
- **FR-002**: The build MUST ship the **final app icon** (including Android adaptive icon) and **splash**, rendering correctly in **both light and dark**.
- **FR-003**: The release **signing identity** MUST be handled as a secret — the keystore and its passwords MUST NOT be committed to the repository (supplied at build time per the ADR-0001 secrets posture) — and the release build MUST **fail closed** if the signing config is absent (no debug-signed artifact is silently produced as a "release").

#### Crash & error reporting

- **FR-004**: The app MUST **capture uncaught/fatal Dart and platform errors automatically** (reporting is always on — **no consent prompt and no crash-consent screen** in v1; a user-facing opt-out toggle is forward-stated) and surface them to a **sanctions-safe, Syria-reachable** crash dashboard — **Sentry (self-hosted or EU-region instance)** — wired **behind the existing logger abstraction in `lib/core/logging/`**; Firebase Crashlytics MUST NOT be adopted (sanctions risk). This resolves the §16 open question.
- **FR-005**: A **deliberately-forced exception in a dev build** MUST appear on the crash dashboard with a usable stack trace (the plan's crash acceptance criterion).
- **FR-006**: Crash/error report payloads MUST be **scrubbed of secrets and PII** before send — no Vault secret material, no synthetic-email→phone mapping, and no decrypted personal data may appear in a report (Principle III).
- **FR-007**: The crash reporter MUST **degrade silently** when its dashboard is unreachable — it MUST NOT block app start and MUST NOT itself crash the app. The crash-reporting integration MUST keep the **domain layer free of the crash-reporting SDK** (Principle IX).

#### In-app update prompt

- **FR-008**: On **cold start**, the app MUST check the latest available version against a **Supabase-hosted version manifest** (Supabase Storage), with **no dependency on Cloudflare / Google CDNs** so the check works from Syrian IPs. "Newer" MUST be determined by **semantic-version comparison** (`major.minor.patch`, matching the plan's `1.<phase>.<patch>` scheme and the `pubspec` `1.0.0+1` format), using the **build number `+N` only as a tiebreaker** when the semantic versions are equal.
- **FR-009**: When the manifest advertises a **newer** version than the installed build, the app MUST show a **localized update prompt** with two actions — an **"Update"** affordance opening the download (the **Telegram channel**, and/or the project website when available) and a **"Later"** action that dismisses the prompt **for the current session**. The prompt is shown **once per cold start** while a newer version exists and **re-shows on the next cold start** until the user updates; **no "dismissed version" state is persisted** in v1 (a force / minimum-supported-version gate is forward-stated future work).
- **FR-010**: When the manifest is **unreachable, malformed, empty, or advertises the same/older version**, the version check MUST be a **silent, graceful no-op** — the app opens normally, shows no prompt, and does not crash.

#### Distribution & release documentation

- **FR-011**: The signed `1.0.0` APK MUST be **published to the Telegram channel** (primary Syrian channel), with the APK and the version manifest hosted on a **directly-reachable origin** (Supabase Storage); a **Play Store internal testing track** MUST be configured for QA/stakeholders only (not advertised to end users).
- **FR-012**: The repository MUST contain **`docs/release/v1.0.0.md`** documenting the **six golden-path results**, **install/update instructions**, the **no-email account-recovery support flow** (admin issues a temporary password via the super-admin UI, §15), and a **recorded cold-start baseline** measured on the reference Infinix Note 8 against the §15 < 3 s budget — captured as an **advisory baseline, NOT a release gate** (per §12, hard performance benchmarks are deferred for v1; a slower-than-budget reading is noted, not a ship-blocker).

#### Golden-path QA pass

- **FR-013**: All **six golden paths** MUST be verified for the `1.0.0` release: **(1)** register → admin-approve → publish → admin-approve → public view → inquiry; **(2)** anonymous browse + filter + map; **(3)** admin reports-queue resolution; **(4)** super-admin role create + assign + revoke; **(5)** currency switch + exchange-rate update; **(6)** maintenance mode + recovery. The QA pass MUST also **resolve (fix in this PR)** the items earlier phases deferred to "the Phase 24 golden-path QA pass" — the **Phase 19 agency follow-ups**, the **Phase 22 live-QA items T044–T046**, and the recurring async-cubit **`isClosed`-guard sweep** — with **no re-deferral of these specific items**. (A new, out-of-release-scope issue surfaced *during* the QA walk may still be recorded in `DEFERRED.md` with a rationale; only the three named carried-over items are mandated as fixed.)
- **FR-014**: The QA evidence MUST be **hybrid**: **manual** on-device (Infinix Note 8) + emulator (Pixel 8 Pro AVD) walks for **all six** paths, **plus one automated integration test** for the **primary publish path** (path 1). The **maintenance-mode (two-device)** and **push-delivery** paths MUST remain **manual** (neither is observable in a single in-process test). This one automated test is the sanctioned exception to the standing "no new automated tests until the MVP is feature-complete" convention; no other new automated tests are added in this phase.

#### Localization, theming, stability & scope constraints

- **FR-015**: Every new user-visible string introduced in this phase (the update prompt) MUST flow through `AppLocalizations` with both `ar` and `en` entries (Principle V).
- **FR-016**: The new surfaces (update prompt, splash) and their states MUST render correctly in all four combinations of (light / dark theme) × (Arabic RTL / English LTR), using logical/direction-aware insets and Phase 2 design tokens — no inline hex literals, no raw font sizes, no ad-hoc paddings (Principle VI).
- **FR-017**: The phase MUST perform the recurring **async-cubit `isClosed`-guard sweep** so cubits no longer emit after close, keeping the new crash/error stream free of benign "emit after close" noise.
- **FR-018**: This phase MUST add **no new product feature, no new business-data table, and no new permission key**; MUST add **no iOS / Flutter Web / desktop code** and **no non-Android-only plugin** (Principle XI); MUST keep the **domain layer free of Supabase / crash-SDK imports** (Principle IX); and MUST keep all source-controlled backend artifacts (the version manifest content, any signing-config scaffolding, any seed) as **checked-in files**, secrets excepted (Principle II).

### Key Entities

- **Release Build / Artifact**: The signed `1.0.0` Android APK — its version (`1.0.0`), build number (`+N`), signing identity (handled as an external secret, never committed), final icon + splash, and "boots on a fresh device" guarantee.
- **Version Manifest**: The Supabase-hosted record of the **latest available version** — a **semantic version** string (`major.minor.patch`, optional build number) compared semver-first with the build number as tiebreaker — and a forward-stated optional **minimum-supported version**, plus the **download URL(s)** (Telegram / website) and optional release-note text. Read by the app on cold start; reachable from Syrian IPs without a Cloudflare/Google CDN dependency.
- **Crash / Error Report**: An uncaught-error event sent to the crash dashboard (Sentry self/EU) — carries a stack trace and diagnostic context but is **scrubbed of secrets and PII** before send.
- **Golden Path**: One of the six end-to-end product flows verified for the release, each with a recorded result; path 1 (primary publish) also has an automated integration test; the maintenance and push legs are verified manually.
- **Release Notes**: `docs/release/v1.0.0.md` — the human-readable record of what shipped, the golden-path results, install/update steps, and the no-email account-recovery support flow.
- **Distribution Channel**: The Telegram channel + project website (Channel A, primary for Syria) and the Play Store internal testing track (Channel B, QA-only).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The signed **`1.0.0`** release APK installs and boots on a **fresh** Android device (no prior app data) to the first usable screen, with the final app icon and splash correct in both light and dark, and no debug-only scaffolding — verified on the reference Infinix Note 8 and a fresh Pixel 8 Pro AVD profile.
- **SC-002**: A deliberately-triggered fatal error in a dev build appears on the crash dashboard within a few minutes with a usable stack trace, and the report payload contains **no** secrets, **no** synthetic-email→phone mapping, and **no** decrypted PII — verified by inspecting the dashboard entry.
- **SC-003**: With the manifest advertising a newer version, a cold start shows the localized update prompt with a working download affordance; with the manifest unreachable/malformed, the app cold-starts normally with **no** prompt and **no** crash — both verified on-device.
- **SC-004**: **All six golden paths pass** on the release build (manual walks for all six **and** the automated primary-publish integration test green); the maintenance (two-device) and push legs pass their **manual** verification — results recorded per path (Principle X).
- **SC-005**: The signed APK is **retrievable from the Telegram channel** and installs on a fresh device, and the **Play Store internal testing track** shows the `1.0.0` build to an enrolled QA tester (not advertised publicly) — verified end-to-end.
- **SC-006**: **`docs/release/v1.0.0.md`** exists and covers the six golden-path results, install/update instructions, and the no-email account-recovery support flow — verified by review.
- **SC-007**: The new Phase 24 surface (update prompt) renders correctly in all four (light/dark) × (Arabic RTL / English LTR) combinations on the Infinix Note 8 (≈480 dp) and a 412 dp emulator profile, with no untranslated literals and styling from Phase 2 tokens.
- **SC-008**: A repository-wide structural check confirms: the release version is **`1.0.0`**; **no new business-data table** and **no new permission key** were added; the crash + update wiring lives in **`core/` (`logging/` / `network/`)** with **no Supabase or crash-SDK import under any `domain/`** (Principle IX); **no iOS/Web** code or non-Android-only plugin was added (Principle XI); and every item earlier phases deferred to the Phase 24 QA pass (Phase 19 agency follow-ups, Phase 22 T044–T046, the async-cubit `isClosed` sweep) is **closed — fixed in this PR (no re-deferral of these named items)**.
- **SC-009**: The previously-recurring "emit after close" async-cubit errors no longer appear in the logs / crash stream when the affected navigations are exercised on the release build — verified on-device.

## Assumptions

- **Phase 24 is the release-hardening phase** (`specs/024-release-polish/`), distinct from the feature phases before it. It adds **no new product feature** — it makes the existing v1 marketplace shippable, observable, and proven. v1 non-goals (iOS/Web, custom backend, paid promoted-listing checkout, auto-translation, advanced analytics) remain out of scope.
- **Three release decisions were resolved with the user on 2026-06-02** (folded in here — see Clarifications): **(1) crash reporting = Sentry (self-hosted or EU-region instance)**, sanctions-safe and Syria-reachable, wired in `lib/core/logging/`; Crashlytics is rejected (resolves the §16 open question); **(2) the in-app version check reads a Supabase-hosted version manifest** (Supabase Storage — already a dependency, already Syria-reachable), with Telegram as the primary APK download channel and no Cloudflare/Google CDN dependency; **(3) the golden-path QA evidence is hybrid** — manual on-device/AVD walks for all six paths plus **one** automated integration test for the **primary publish path**; maintenance (two-device) and push remain manual.
- **The version is already `1.0.0+1` in `pubspec.yaml`.** The spec formalizes `1.0.0` as the release version; the `+N` build number may increment per build without changing the user-facing version. No code currently wires crash reporting or an update check — both are introduced fresh in this phase.
- **AVD walks count as primary QA evidence** for this MVP (per the project rule); the Infinix Note 8 is used for performance-sensitive checks. The §15 cold-start budget of < 3 s is **measured on the Infinix Note 8 and recorded in the release notes as an advisory baseline, not a release gate** (per §12, hard performance benchmarks are deferred for v1 — see Clarifications). The maintenance path requires a **second device** for its two-device observation.
- **The standing "no new automated tests until the MVP is feature-complete" convention is relaxed for exactly one test** — the primary-publish integration test (the sanctioned release-hardening exception). No other new automated tests are added; existing tests remain.
- **The release signing keystore and passwords live outside the repository** and are supplied at build time (ADR-0001 secrets posture); the build references them rather than embedding key material, and fails closed when they are absent.
- **Crash reports are scrubbed of secrets/PII before send.** A best-effort scrubbing of synthetic-email/phone, Vault material, and decrypted PII is applied; the reporter is non-blocking and tolerant of an unreachable dashboard.
- **The update prompt is dismissible (best-effort, non-blocking) in v1.** A hard minimum-supported-version / force-update gate is forward-stated future work, as is in-place / silent auto-update (v1 is a manual download prompt only).
- **The Play Store internal testing track is QA-only** and not advertised to end users; the Telegram / direct-APK channel is the primary path for Syrian users and the documented fallback if the Play Store track is unreachable from Syria.
- **The account-recovery support flow is documentation, not new code** — the admin issues a temporary password via the existing super-admin UI (§15); Phase 24 records the flow in the release notes.
- **The QA pass closes prior deferrals**: the items earlier phases explicitly deferred to "the Phase 24 golden-path QA pass" (Phase 19 agency follow-ups; Phase 22 live-QA T044–T046; the async-cubit `isClosed`-guard sweep) are **all fixed in this PR — no re-deferral of these named items** (resolved 2026-06-02 — see Clarifications). This expands the phase's workload accordingly. This phase does **not** undertake to clear every *other* open `DEFERRED.md` item across all phases — only those explicitly parked for the Phase 24 QA pass.
- **No new automated test infrastructure beyond the one integration test**; verification is otherwise by manual on-device/AVD walks plus direct inspection (crash dashboard entry, Telegram/Play Store availability, `SELECT`-level checks where relevant), recorded against the Success Criteria.
- **Backend stays Supabase, source-controlled** — the version manifest content and any signing-config scaffolding are checked in (secrets excepted, Principle II); the domain layer stays provider-agnostic (Principle IX); the feature is Android-only (Principle XI).

## Clarifications

### Session 2026-06-02

- Q: The plan flags "Crash reporting tool (Sentry self-hosted vs EU vs alternative)?" as the §16 open question for this spec — which tool and hosting model does Phase 24 commit to? → A: **Sentry, self-hosted or EU-region instance** — sanctions-safe and reachable from Syria, wired behind the existing logger abstraction in `lib/core/logging/`. **Firebase Crashlytics is rejected** (sanctions risk). Crash payloads are scrubbed of secrets/PII; the reporter never blocks app start or crashes the app if the dashboard is unreachable (FR-004, FR-006, FR-007, US2).
- Q: The in-app "manual update prompt (version-check on cold start)" needs a source of truth for the latest available version, but the project website may not exist yet and Cloudflare/Google CDNs may be unreachable from Syria — where does the check read from? → A: **A Supabase-hosted version manifest** (Supabase Storage — already a dependency and already Syria-reachable), with the **Telegram channel** as the primary APK download channel (and the project website when available); no Cloudflare/Google CDN dependency (FR-008, FR-009, FR-010, US4).
- Q: Phase 24 must verify the six golden paths; given the standing "no new automated tests" convention and that only some paths are automatable — how is the QA pass evidenced? → A: **Hybrid** — **manual** on-device (Infinix Note 8) + emulator (Pixel 8 Pro AVD) walks for **all six** paths, **plus one automated integration test** for the **primary publish path** (register → approve → publish → approve → view → inquiry). The **maintenance-mode (two-device)** and **push-delivery** legs remain **manual**, since neither can be observed in a single in-process test. This one test is the sanctioned exception to the no-new-tests convention (FR-013, FR-014, US3).
- Q: Does crash reporting require a user consent gate, and is there a consent affordance to localize/theme? → A: **Automatic capture, no consent UI** — crash reporting is always on (payloads PII-scrubbed per FR-006), so there is **no consent prompt and no crash-consent screen** in v1; a user-facing **opt-out toggle is forward-stated** future work. This removes the "crash-consent affordance" from the phase's localization/theming scope (FR-004, FR-015, FR-016, US2, US6, SC-007).
- Q: The §15 cold-start budget (< 3 s) conflicts with §12 ("performance benchmarks not required for v1"); does the QA pass gate the release on it? → A: **Measured but advisory** — cold-start time is measured on the reference Infinix Note 8 and **recorded in the release notes as a baseline**, but it is **NOT release-gating**; a slower-than-budget reading is noted, not a ship-blocker (FR-012, Assumptions).
- Q: How does the update prompt behave on dismissal — does it persist a "dismissed" state or re-prompt? → A: **Once per cold start, dismiss-for-session** — the prompt shows once per cold start while a newer version exists, with **"Update"** (opens download) and **"Later"** (hides for the session); it **re-appears on the next cold start** until the user updates, with **no persisted dismissed-version state** in v1 (FR-009, Edge Cases).
- Q: How does the app decide a manifest version is "newer" than the installed build? → A: **Semantic-version comparison** (`major.minor.patch`, matching the `1.<phase>.<patch>` scheme and `pubspec` `1.0.0+1`), with the **build number `+N` as a tiebreaker** only when the semantic versions are equal (FR-008, Version Manifest entity).
- Q: For the items earlier phases deferred to the Phase 24 QA pass, what must be fixed here versus re-deferred? → A: **Fix all of the named carried-over items in this PR — no re-deferral**: the Phase 19 agency follow-ups, the Phase 22 live-QA items T044–T046, and the recurring async-cubit `isClosed`-guard sweep. (A *new* out-of-scope issue surfaced during the QA walk may still be recorded in `DEFERRED.md` with a rationale; this phase does not undertake to clear *unrelated* deferrals.) This expands the phase's workload accordingly (FR-013, US3, SC-008, Assumptions).
