# Feature Specification: App Settings

**Feature Branch**: `023-app-settings`
**Created**: 2026-06-02
**Status**: Draft
**Input**: Phase 23 — App settings, from `docs/IMPLEMENTATION_PLAN.md` (§ "Phase 23 — App settings", plus the `app_settings` schema in §6.2, the RLS posture in §6.4, the `settings.manage` permission in §9.1, the audit-trigger obligation in §9.4 ("App settings changes (Phase 23)"), and the open question in §16 ("Maintenance-mode bypass for super-admin?"))

> **Scope note**: Phase 23 introduces the **app-wide settings layer** — a small, admin-tunable set of product defaults and operational switches that every other already-built flow reads, rather than having those values hard-coded. The phase ships exactly: **(a) a server-side `app_settings` store** (key → typed value + description + last-updater + timestamp, per §6.2) holding a **closed v1 catalog** of admin-tunable settings — **default language**, **default currency**, **default publisher-name visibility**, **default exact-location visibility**, **maintenance mode** (plus an optional maintenance message), **support contact**, and **terms / privacy links**; **(b) a typed admin settings editor** at `lib/features/settings/admin/` gated by the existing `settings.manage` permission (no new permission key — §9.1 is unchanged), where booleans render as toggles, enumerated values as pickers, and URLs/contacts as validated text, with every change written to `audit_logs` (the §9.4 "App settings changes (Phase 23)" audited action); **(c) forward-only default seeding** — the admin-set default language and default currency seed a **new** user's preferences at account creation (existing users keep their chosen `user_preferences.locale` / `display_currency`), and the admin-set publisher-name + exact-location defaults pre-select the visibility fields for **new** listings (existing listings are untouched) — the plan's "affects new users only" rule; **(d) a maintenance-mode gate** — when maintenance mode is on, every client shows a localized **maintenance screen** in place of normal use, reflected on all clients within **~1 minute** by the next app load / foreground resume, with a retry affordance and the configured support contact, and turning it off restores normal access on the next check; **(e) a `settings.manage`-only bypass of the maintenance gate** — the super-admins who can toggle the setting keep full app access while maintenance is on (so they are never locked out and can turn it back off), while every other user — including other admins/moderators — and anonymous visitors see the maintenance screen (the user-resolved answer to the plan's §16 open question — see Clarifications); **(f) client consumption of public settings** — the app fetches the public settings on **app load** and re-checks on **foreground resume** (NOT via Realtime — Phase 22's Realtime scope of admin counters + `user_roles` is unchanged; app_settings deliberately uses fetch-on-load/foreground to satisfy the "within 1 minute / next foreground" criterion), surfaces the support contact and terms/privacy links on the appropriate screens, and falls back to **safe built-in defaults** if the fetch fails (a failed settings fetch MUST NOT be treated as maintenance-on and MUST NOT brick or crash the app); **(g) security at both ends** — `app_settings` has RLS with **public read only for keys classified public** (the client needs language/currency defaults, maintenance state, support contact, and terms/privacy links at load, including for anonymous visitors), admin-only read for any key classified sensitive, and **writes restricted to `settings.manage`** verified server-side — so a non-`settings.manage` client cannot write any setting and a non-admin cannot read a sensitive key at the wire level; and **(h) the localization + theming layer** — the settings editor and the maintenance screen (and all their states) flow through `AppLocalizations` with `ar` + `en` entries and render correctly in all four (light / dark) × (Arabic RTL / English LTR) combinations using Phase 2 tokens. Phase 23 honors Principle I (this spec precedes implementation), Principle III (RLS on the new table; public-vs-sensitive read classification; `settings.manage` write checked at both ends), Principle V (all UI strings localized `ar` / `en`), Principle VI (themed via Phase 2 tokens, four-combination correct), Principle VII (the data-driven permission `settings.manage` gates writes; audit on every change), Principle IX (the domain layer stays Supabase-free — no Supabase import under `domain/`), Principle XI (Android-only; no iOS/Web code), and Principle XII (the two product decisions below are recorded, not hidden). Phase 23 does **NOT** add a **"supported currencies" setting** — the user resolved that Phase 9's `currencies.is_active` remains the single source of truth for which currencies the app supports, and `app_settings` stores only the **default** currency (see Clarifications), trimming the plan's eight-item list to seven and avoiding two sources of truth; does **NOT** add a new permission key or change the §9.1 catalog (writes reuse the existing `settings.manage`); does **NOT** introduce per-user settings (those live in `user_preferences` from Phase 5 — this phase is the *app-wide* layer); does **NOT** make settings Realtime-driven (fetch-on-load/foreground only); does **NOT** retroactively re-default existing users or listings; and does **NOT** alter any existing business-data table — the only new backend object is the `app_settings` table plus its policies, seed, and audit trigger.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — An admin tunes the app's product defaults (Priority: P1)

A super-admin (a user holding `settings.manage`) opens an admin settings editor and changes the app-wide defaults: the default language and default currency for new users, the default publisher-name and exact-location visibility for new listings, the support contact shown to users, and the terms-of-service and privacy-policy links. Each control is typed — a toggle for booleans, a picker for enumerated choices (language, currency, visibility), validated text for URLs and contacts — so they cannot save a malformed value. When they save, the new value persists, and an audit record captures who changed which setting from what to what.

**Why this priority**: P1 because the admin settings editor is the foundation of the phase — without a place to read and write `app_settings`, none of the defaults, maintenance switch, or consumed values exist. The plan's frontend deliverable leads with "`lib/features/settings/admin/` — typed settings editor," and §9.4 mandates that "App settings changes (Phase 23)" are audit-logged. Every other story in this phase reads a value this story writes.

**Independent Test**: Sign in as a super-admin on the reference device, open the settings editor, and change the default currency and the support contact. Confirm each control validates input (an invalid URL or an unknown currency code is rejected before save), the saved values persist across app restart, and an `audit_logs` row exists for each change recording actor + key + before/after. Confirm a user without `settings.manage` cannot reach the editor.

**Acceptance Scenarios**:

1. **Given** a user with `settings.manage`, **When** they open the settings editor, **Then** they see the current value of every catalog setting rendered in a type-appropriate control (toggle / picker / validated text).
2. **Given** the editor, **When** the admin changes a setting to a valid value and saves, **Then** the new value persists, is read back on reload, and an `audit_logs` row records the actor, the key, and the before/after values.
3. **Given** the editor, **When** the admin enters a malformed value (e.g., an invalid URL, an unknown/inactive currency code, an unsupported locale), **Then** the save is blocked with a localized validation message and the stored value is unchanged.
4. **Given** a user **without** `settings.manage`, **When** they attempt to open the settings editor or write a setting, **Then** the editor is not reachable (UI gating) and any direct write is denied server-side (Principle III — checks at both ends).

---

### User Story 2 — Maintenance mode takes the app offline for everyone except the admins who run it (Priority: P1)

An admin needs to take the app offline for maintenance. They flip the maintenance-mode toggle on. Within about a minute, every client — on its next app load or foreground resume — shows a localized maintenance screen instead of the normal UI, with a clear message, the configured support contact, and a retry button. The one exception is users who hold `settings.manage`: they keep full access to the app (including the settings editor) so they can verify the work and turn maintenance back off without being locked out. When they flip the toggle off, normal access returns on each client's next check.

**Why this priority**: P1 because maintenance mode is the headline operational capability of the phase and the subject of the plan's first acceptance criterion ("Toggling maintenance mode in admin shows the maintenance screen on all clients within 1 minute") and its first verification ("toggle maintenance, observe second device"). It also resolves the plan's flagged §16 open question (maintenance-mode bypass), which the user answered: only `settings.manage` holders bypass.

**Independent Test**: With the app open on a second device (device B) as a regular user, enable maintenance mode from a super-admin on device A. Confirm device B shows the maintenance screen within ~1 minute (on its next foreground), with localized copy, the support contact, and a retry button. Confirm device A's super-admin still has full access and can re-open the settings editor. Confirm an anonymous (logged-out) client also sees the maintenance screen. Confirm a non-`settings.manage` admin (e.g., a moderator) sees the maintenance screen. Turn maintenance off on A → confirm B returns to normal on its next check / retry.

**Acceptance Scenarios**:

1. **Given** maintenance mode is OFF and a client is in normal use, **When** an admin turns maintenance mode ON, **Then** that client shows the maintenance screen on its next app load or foreground resume, within ~1 minute.
2. **Given** maintenance mode is ON, **When** a user holding `settings.manage` uses the app, **Then** they bypass the maintenance screen and retain full access (including the ability to turn maintenance off).
3. **Given** maintenance mode is ON, **When** a regular user, a non-`settings.manage` admin/moderator, or an anonymous visitor opens or foregrounds the app, **Then** they see the maintenance screen (no bypass).
4. **Given** the maintenance screen, **When** it renders, **Then** it shows a localized message (an admin-set custom message if provided, otherwise the built-in localized message), the configured support contact, and a retry affordance that re-checks the setting.
5. **Given** maintenance mode is ON, **When** an admin turns it OFF, **Then** each client restores normal access on its next check / retry.

---

### User Story 3 — App-wide defaults seed new users and new listings, without disturbing existing ones (Priority: P2)

When an admin changes the default language or default currency, the change applies only to **new** users created afterward — anyone who already has a chosen language or display currency keeps it. Likewise, the admin-set defaults for publisher-name visibility and exact-location visibility pre-select those fields when a publisher creates a **new** listing, but never silently rewrite the visibility of listings that already exist.

**Why this priority**: P2 because it is the second of the plan's two acceptance criteria ("Changing default display currency affects new users only (existing users keep their preference)") and the concrete payoff of having tunable defaults — but it layers on US1 (the values must be settable first) and is independent of the maintenance gate.

**Independent Test**: Note an existing user's chosen display currency. From the admin editor, change the default currency to a different active currency. Confirm the existing user's preference is unchanged after the change. Register a brand-new user and confirm their preferences are seeded with the new default currency (and default language). Change the default publisher-name and exact-location visibility, start a new listing as a publisher, and confirm those fields are pre-selected to the new defaults; confirm an already-published listing's visibility is unchanged.

**Acceptance Scenarios**:

1. **Given** an existing user with a chosen display currency / locale, **When** an admin changes the default currency / default language, **Then** that existing user's preference is unchanged.
2. **Given** the default currency / default language has been changed, **When** a new user account is created, **Then** the new user's preferences are seeded from the current defaults.
3. **Given** the admin has set a default publisher-name visibility and a default exact-location visibility, **When** a publisher starts a new listing, **Then** those visibility fields are pre-selected to the current defaults (the publisher can still override per listing).
4. **Given** existing listings, **When** the visibility defaults change, **Then** the visibility of already-created listings is unchanged.

---

### User Story 4 — The app reads public settings and surfaces them to users (Priority: P2)

Any client — signed-in or anonymous — picks up the public settings when it loads and re-checks them when it returns to the foreground. The support contact, terms-of-service link, and privacy-policy link the admin configured appear where the app shows them (e.g., the about / settings screen and the maintenance screen). If the app cannot reach the backend to read settings, it falls back to safe built-in defaults and keeps working — a failed settings fetch is never mistaken for maintenance mode and never crashes the app.

**Why this priority**: P2 because consuming the settings is what makes them matter to end users, but it depends on US1 having defined the values and is a quieter capability than the maintenance gate. The plan's frontend deliverable states "App-load fetches public settings."

**Independent Test**: As an anonymous client, launch the app and confirm the public settings load (support contact + terms/privacy links appear where the app shows them). Change the support contact in the admin editor and confirm the app reflects the new value on its next load. Put the device offline at launch and confirm the app still opens on safe defaults, does NOT show the maintenance screen because of the failed fetch, and does not crash. Foreground the app after a settings change and confirm it re-reads.

**Acceptance Scenarios**:

1. **Given** the app starts, **When** it loads, **Then** it fetches the public settings; **and When** it returns to the foreground, **Then** it re-checks them (no Realtime dependency).
2. **Given** an admin has set the support contact and terms/privacy links, **When** the app renders the screens that surface them, **Then** the values shown are those from settings; updating them in admin updates what the app shows on the next load.
3. **Given** the settings fetch fails (offline / backend error), **When** the app starts, **Then** it uses safe built-in defaults, does NOT show the maintenance screen on account of the failure, and does not crash.
4. **Given** a terms or privacy link is unset / empty, **When** the app renders that affordance, **Then** it degrades gracefully (the affordance is hidden or shows a localized "unavailable" state) — never a broken link.

---

### User Story 5 — Settings access is enforced at the data layer, not just the UI (Priority: P2)

The product MUST guarantee that only authorized admins can change app settings and that sensitive settings are not exposed to the public. A client without `settings.manage` cannot write any setting; a non-admin cannot read any key classified as sensitive; public keys are readable by anyone (including anonymous clients) because the app needs them at load. These guarantees hold at the wire level, not merely by hiding UI.

**Why this priority**: P2 because Constitution Principle III ("checks at both ends") and the §6.4 RLS matrix ("public read for non-sensitive keys; admins for all"; write by `settings.manage`) make a UI-only posture insufficient — a malformed maintenance flag or an unauthorized currency-default change is a real operational risk. It layers over the P1 capabilities.

**Independent Test**: From a session lacking `settings.manage`, attempt at the wire level to write each setting (including maintenance mode) → confirm each is denied. From a non-admin session, attempt to read a key classified sensitive → confirm it is denied while a public key (e.g., maintenance state, support contact) is readable. From an anonymous session, confirm the public keys are readable. Confirm every successful admin write left an `audit_logs` row.

**Acceptance Scenarios**:

1. **Given** a client without `settings.manage`, **When** it attempts to write any `app_settings` key at the wire level, **Then** the write is denied (server-side), regardless of UI state.
2. **Given** a key classified **public**, **When** any client (including anonymous) reads it, **Then** the read succeeds; **and Given** a key classified **sensitive/admin-only**, **When** a non-admin reads it, **Then** the read is denied.
3. **Given** any successful settings change, **When** it completes, **Then** an `audit_logs` row records the actor, the key, and the before/after values (§9.4).

---

### User Story 6 — The settings editor and maintenance screen are fully localized and themed in every combination (Priority: P3)

Every admin using the settings editor and every user seeing the maintenance screen gets a correct, readable experience in Arabic (RTL) or English (LTR), in light or dark theme: localized labels, descriptions, validation messages, and maintenance copy; direction-aware layout; and design-token styling.

**Why this priority**: P3 because localization and theming are cross-cutting quality gates the plan calls out for every phase (Principles V and VI); they refine the experience delivered by the P1/P2 stories rather than being a standalone capability.

**Independent Test**: Open the settings editor and the maintenance screen and cycle the four combinations — (light, ar), (dark, ar), (light, en), (dark, en) — on the reference Infinix Note 8 and a 412 dp emulator profile; confirm every string is localized (no raw literals), controls/labels/validation and the maintenance screen lay out correctly RTL and LTR, and colors/typography/spacing come from Phase 2 tokens (no clipped text, no mis-mirrored icons, no inline hex).

**Acceptance Scenarios**:

1. **Given** the app locale is Arabic, **When** the settings editor and the maintenance screen render, **Then** all strings appear in Arabic and the layout is RTL-correct.
2. **Given** the app locale is English, **When** the same surfaces render, **Then** all strings appear in English and the layout is LTR-correct.
3. **Given** light and dark themes, **When** the surfaces render in each, **Then** all colors, typography, spacing, and elevation come from the Phase 2 design tokens with no inline hex / raw font size / ad-hoc padding.

---

### Edge Cases

- **Self-lockout prevention**: because only `settings.manage` holders bypass the maintenance screen, the person who turned maintenance on can always reach the editor to turn it off — maintenance can never lock every operator out (the resolved §16 decision).
- **A non-`settings.manage` admin during maintenance**: a moderator or other admin without `settings.manage` sees the maintenance screen like any user (no partial bypass in v1).
- **Settings fetch fails at launch (offline / backend error)**: the app opens on safe built-in defaults, does NOT treat the failure as maintenance-on, and does not crash; it re-checks on the next foreground.
- **Maintenance toggled on while a `settings.manage` admin is mid-session**: the admin keeps access (bypass); other users transition to the maintenance screen on their next load/foreground.
- **Default currency points at a currency Phase 9 has deactivated**: the editor offers only **active** Phase 9 currencies as the default-currency choice, so the default can't be set to an inactive code; if a previously-set default later becomes inactive, the app falls back to a safe built-in currency for seeding.
- **Default language is an unsupported locale**: the editor offers only the supported locales (`ar`, `en`); the default cannot be set to anything else.
- **Changing a default never rewrites history**: existing users keep their chosen language/currency; existing listings keep their visibility — defaults are forward-only seeds.
- **Terms / privacy / support unset**: the corresponding affordance is hidden or shows a localized "unavailable" state — never a broken link or empty tappable element.
- **Maintenance custom message language**: the maintenance screen's standard frame (title, retry, support label) is ARB-localized; the optional admin-set custom message is provided as an **Arabic and an English** variant (each optional), and the **active-locale** variant is shown, falling back to the built-in localized message when the active-locale variant is unset.
- **Concurrent admin edits**: two `settings.manage` admins editing at once is last-write-wins; both writes are audited (no locking in v1).
- **Sensitive key never leaks to anonymous**: a key classified sensitive is denied to a non-admin/anonymous client at the wire level even though public keys on the same table are readable.
- **Public vs sensitive read on one table**: the table mixes public-readable and admin-only keys; the read policy MUST distinguish them per-key (not table-wide public read).

## Requirements *(mandatory)*

### Functional Requirements

#### Settings store & catalog

- **FR-001**: The system MUST provide a server-side `app_settings` store keyed by a setting **key**, holding a **typed value**, a human-readable **description**, the **last updater**, and an **update timestamp** (per §6.2). The closed v1 catalog is exactly: **default language**, **default currency**, **default publisher-name visibility**, **default exact-location visibility**, **maintenance mode** (plus an optional **bilingual `ar`/`en` maintenance message**), **support contact** (a structured value with optional **phone**, **WhatsApp**, and **email** channels), **terms URL**, and **privacy URL**. The catalog MUST NOT include a "supported currencies" key — Phase 9's `currencies.is_active` remains the source of truth for which currencies are supported (user-resolved — see Clarifications).
- **FR-002**: Each setting MUST carry a **visibility classification** — **public** (readable by any client, including anonymous, because the app needs it at load) or **sensitive/admin-only** (readable only by admins). The v1 catalog keys the client needs at load — default language, default currency, both listing-visibility defaults, maintenance state + message, support contact, terms URL, privacy URL — are **public**; the schema MUST support sensitive keys for future use even though v1 seeds none.
- **FR-003**: The store MUST ship with **seeded default values** for every catalog key (so a fresh install behaves sensibly before any admin edits), and the repository MUST contain the table migration, its RLS policies, the seed, and the audit trigger as checked-in files (Principle II).

#### Admin management

- **FR-004**: A user holding **`settings.manage`** MUST be able to **view and edit** every catalog setting through a **typed editor** — booleans as toggles, enumerated values (language, currency, visibility) as pickers constrained to valid choices, URLs/contacts as validated text — and each value MUST be **validated to its type/domain** before it is saved (an invalid URL, an unsupported locale, or an unknown/inactive currency code is rejected).
- **FR-005**: Writes to `app_settings` MUST be restricted to **`settings.manage`**, enforced at **both ends** — the editor is reachable only to holders of the permission (UI gating) AND the server denies any write from a client lacking it (RLS / permission check). No new permission key is introduced — this reuses the existing §9.1 `settings.manage` (Principles III, VII, XII).
- **FR-006**: Every change to a setting MUST write an **`audit_logs`** row capturing the **actor**, the **key**, and the **before/after** values, via the Phase 4 `log_audit()` mechanism — this is the §9.4 "App settings changes (Phase 23)" audited action.

#### Defaults applied to new users & listings (forward-only)

- **FR-007**: The admin-set **default language** and **default currency** MUST seed a **new** user's preferences **at registration, applied client-side** — the registration flow reads the public settings and writes the new user's initial `user_preferences.locale` / `display_currency` (resolved 2026-06-02 — see Clarifications). They MUST NOT retroactively change any existing user's chosen preferences (the plan's "affects new users only" rule).
- **FR-008**: The admin-set **default publisher-name visibility** and **default exact-location visibility** MUST be the **pre-selected** values for the corresponding fields when a publisher creates a **new** listing (the publisher MAY still override per listing). They MUST NOT alter the visibility of any existing listing.

#### Maintenance mode

- **FR-009**: When **maintenance mode** is ON, every client MUST present a **localized maintenance screen** in place of normal app use, reflected on all clients within **~1 minute** — i.e., by the client's next **app load** or **foreground resume**.
- **FR-010**: Users holding **`settings.manage`** MUST **bypass** the maintenance screen and retain full app access (so they can verify and disable maintenance); all other users — including admins/moderators **without** `settings.manage` — and anonymous visitors MUST see the maintenance screen (user-resolved §16 decision — see Clarifications).
- **FR-011**: The maintenance screen MUST present a **localized message** — an admin-set custom message if provided (the admin sets an **Arabic and an English** variant, each optional, and the screen shows the **active-locale** variant, falling back to the built-in localized message when that variant is unset), otherwise the built-in localized message — the configured **support contact** (its set channels: phone / WhatsApp / email), and a **retry** affordance that re-checks the setting; turning maintenance OFF MUST restore normal access on the next check / retry.

#### Client consumption & fetch posture

- **FR-012**: The app MUST fetch the **public** settings on **app load** and re-check them on **foreground resume**. Settings MUST NOT be delivered via Realtime — Phase 22's Realtime scope (admin counters + `user_roles`) is unchanged; the fetch-on-load/foreground posture is what satisfies the "within 1 minute / next foreground" criterion.
- **FR-013**: The app MUST surface the **support contact** — its set channels (**phone**, **WhatsApp**, **email**), each rendered as the appropriate call / chat / mail affordance and **omitted when unset** — and the **terms / privacy links** from settings on the appropriate screen(s) (e.g., about / settings, and the maintenance screen), using the stored values; an unset channel or link MUST degrade gracefully (hidden or a localized "unavailable" state), never a broken link or affordance.
- **FR-014**: If settings cannot be fetched (offline / backend error), the app MUST fall back to **safe built-in defaults** and continue to function; a failed settings fetch MUST NOT be treated as maintenance-mode-ON and MUST NOT crash the app.

#### Security & enforcement (checks at both ends)

- **FR-015**: `app_settings` MUST have **RLS enabled** with: **public read only for keys classified public**; **admin-only read for keys classified sensitive**; and **writes only via `settings.manage`**. A non-admin MUST NOT read a sensitive key, and a client lacking `settings.manage` MUST NOT write any key — both denied at the **wire level** (Principle III), independent of UI state.

#### Localization, theming & scope constraints

- **FR-016**: Every user-visible string in the admin settings editor and the maintenance screen (labels, descriptions, validation messages, maintenance copy, retry/support affordances) MUST flow through `AppLocalizations` with both `ar` and `en` entries (Principle V).
- **FR-017**: The settings editor and the maintenance screen, and all their states (loading, error, empty, validation), MUST render correctly in all four combinations of (light / dark theme) × (Arabic RTL / English LTR), using logical/direction-aware insets and Phase 2 design tokens — no inline hex literals, no raw font sizes, no ad-hoc paddings (Principle VI).
- **FR-018**: The new backend surface MUST be limited to: the **`app_settings`** table (RLS on; per-key public/sensitive read; `settings.manage` write) + its **seed defaults** + the settings **audit trigger** + the read/write paths. This phase MUST NOT add a new permission key or change the §9.1 catalog, MUST NOT add a "supported currencies" key (Phase 9 owns that), MUST NOT introduce per-user settings (those remain in `user_preferences`), and MUST NOT alter any existing business-data table. The **domain layer** MUST remain Supabase-free (Principle IX) and the phase MUST add **no iOS/Web code** (Principle XI).

### Key Entities

- **App Setting**: A single admin-tunable app-wide value. Attributes: **key** (the catalog identifier), **typed value**, **description**, **visibility classification** (public / sensitive), **updated_by**, **updated_at**. Readable per its classification; writable only via `settings.manage`; every change audited. Corresponds to the plan's `app_settings` table (§6.2).
- **Settings Catalog**: The closed v1 set of keys — default language, default currency, default publisher-name visibility, default exact-location visibility, maintenance mode (+ optional bilingual `ar`/`en` message), support contact (structured: optional phone / WhatsApp / email), terms URL, privacy URL. Notably **excludes** "supported currencies" (Phase 9 `currencies.is_active` owns that).
- **Maintenance Switch**: The boolean setting (plus optional custom message) that, when on, gates the app for all non-`settings.manage` users. Read by every client at load/foreground.
- **Maintenance Gate / Screen**: The client-side guard that shows the localized maintenance screen when maintenance is on and the viewer lacks `settings.manage`; presents the message, support contact, and a retry that re-checks the setting.
- **Default Seeds**: The forward-only defaults — default language + default currency seed a **new** user's `user_preferences` (applied **client-side at registration**); default publisher-name + exact-location visibility pre-select a **new** listing's visibility fields. Never retroactive.
- **Settings Consumer**: The app-load / foreground-resume read path that loads public settings and surfaces the support contact + terms/privacy links, with a safe-default fallback on fetch failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A `settings.manage` admin can change any catalog setting through the typed editor; the new value persists across an app restart, is read back correctly, and leaves exactly one `audit_logs` row recording actor + key + before/after — verified per setting type (toggle, picker, validated text) on the reference Infinix Note 8.
- **SC-002**: Turning maintenance mode ON makes the maintenance screen appear on a second device within **~1 minute** (its next foreground), and turning it OFF restores normal access on that device's next check / retry — verified two-device (toggle on A, observe B), matching the plan's verification.
- **SC-003**: While maintenance mode is ON, a user holding `settings.manage` retains full app access (bypasses the screen and can disable maintenance), and a regular user, a non-`settings.manage` admin/moderator, and an anonymous visitor all see the maintenance screen — verified across those four viewer types.
- **SC-004**: Changing the **default currency** (and **default language**) affects **only new users** — an existing user's chosen preference is unchanged after the default changes, and a newly-created user is seeded with the new default — verified by inspecting an existing user's preference before/after and registering a fresh account.
- **SC-005**: A new listing's publisher-name and exact-location visibility default to the admin-set values, and changing those defaults does not alter any existing listing's visibility — verified on-device by starting a new listing and inspecting an existing one.
- **SC-006**: From a session lacking `settings.manage`, a direct wire-level write to any setting (including maintenance mode) is **DENIED**; a non-admin read of a sensitive key is **DENIED** while a public key (e.g., maintenance state, support contact) is readable, including by an anonymous client — all checks pass.
- **SC-007**: With the settings fetch failing (device offline at launch), the app **opens on safe defaults**, does **NOT** show the maintenance screen because of the failure, and does **not crash** — verified on-device.
- **SC-008**: The settings editor and the maintenance screen render correctly in all four (light/dark) × (Arabic RTL / English LTR) combinations on the reference Infinix Note 8 (≈480 dp) and a 412 dp emulator profile — all strings localized, layout direction-correct, styling from Phase 2 tokens.
- **SC-009**: The support contact and terms/privacy links shown in the app come from settings; updating them in the admin editor updates what the app shows on its next load; an unset link degrades gracefully (no broken link) — verified on-device.
- **SC-010**: A repository-wide structural check confirms: exactly **one** new table (`app_settings`) with RLS + per-key public/sensitive read + `settings.manage` write + seed + audit trigger; **no new permission key** (reuses `settings.manage`); **no "supported_currencies" key**; **no change** to any other existing table; **no Supabase import** under any `domain/` (Principle IX); and **no iOS/Web** code (Principle XI).

## Assumptions

- **Phase 23 is the app-settings layer** (`specs/023-app-settings/`), distinct from Phase 22 (notifications + Realtime) and Phase 24 (release polish). It is the **app-wide** settings layer; **per-user** settings remain in `user_preferences` (Phase 5) and **which currencies exist/are active** remains in `currencies` (Phase 9).
- **Two decisions were resolved with the user on 2026-06-02** (folded in here — see Clarifications): (1) when maintenance mode is on, **only `settings.manage` holders bypass** the maintenance screen — every other user, including other admins/moderators, and anonymous visitors see it (the plan's §16 open question); (2) **"supported currencies" is NOT a Phase 23 setting** — Phase 9's `currencies.is_active` is the single source of truth for supported currencies, so `app_settings` stores only the **default** currency, trimming the plan's eight-item list to seven and avoiding two sources of truth.
- **Maintenance propagation is fetch-on-load + foreground-resume (~1 minute), NOT Realtime.** Phase 22's Realtime scope (admin counters + `user_roles`) is deliberately unchanged; app_settings uses the polling/fetch posture that the plan's "within 1 minute / next app foreground" criterion implies.
- **Defaults are forward-only, and user-preference seeding is client-side at registration.** Default language/currency seed new users only — the registration flow reads the public settings and writes the new user's initial preferences (resolved 2026-06-02); publisher-name/location-visibility defaults pre-select fields on new listings only. Existing users and listings are never retroactively rewritten (the plan's explicit rule).
- **A failed settings fetch is fail-open for availability, fail-safe for maintenance.** If the backend is unreachable, the app runs on safe built-in defaults and is NOT placed into maintenance mode by the failure; a missing/unreachable setting never bricks the app.
- **`settings.manage` already exists (Phase 6 / §9.1)** and is held by `super_admin`; this phase adds **no new permission key** and makes **no §9.1 change** (Principle XII). Reads of any future sensitive key use the existing admin read posture.
- **The default currency must be an active Phase 9 currency and the default language a supported locale (`ar` / `en`).** The editor constrains both pickers to valid choices; if a previously-set default later becomes invalid (e.g., a currency is deactivated), seeding falls back to a safe built-in.
- **The maintenance custom message is optional and bilingual.** The maintenance screen's standard frame is ARB-localized; the optional admin-set custom message is stored as an Arabic + English pair (each optional) and shown for the active locale, falling back to the built-in localized message (resolved 2026-06-02).
- **The `app_settings` table mixes public and sensitive keys**, so the read policy is **per-key**, not a table-wide public read; all v1 catalog keys are public.
- **Audit uses the Phase 4 `log_audit()` path**; §9.4 lists app-settings changes as an audited action — no new audit infrastructure is built, only a trigger wired to `app_settings`.
- **Admin entry point**: the Phase 20 admin dashboard already lists a **Settings** tile (gated by the relevant permission); Phase 23 fills it with the typed editor at `lib/features/settings/admin/`.
- **No new automated tests** are added, per the project's MVP manual-verification convention; verification is by manual on-device walks (two-device for maintenance) plus direct wire-level / SQL inspection (`SELECT * FROM app_settings`, audit-log checks), recorded against the Success Criteria.
- **Backend backed by Supabase, source-controlled** — the table migration, RLS policies, seed, and audit trigger are all checked in (Principle II); the domain layer stays provider-agnostic (Principle IX); the feature is Android-only (Principle XI).

## Clarifications

### Session 2026-06-02

- Q: The plan flags "Maintenance-mode bypass for super-admin?" as the open question for this spec — when maintenance mode is on, who keeps access? → A: **Only users holding `settings.manage` bypass** the maintenance screen (the super-admins who can toggle it, so they are never locked out and can turn it back off); every other user — including admins/moderators **without** `settings.manage` — and anonymous visitors see the maintenance screen (FR-010, US2).
- Q: The plan lists "supported currencies" as an app setting, but Phase 9 already has a `currencies` table with `is_active` governing which currencies exist — how should Phase 23 treat it? → A: **Do not add a "supported currencies" setting.** Phase 9's `currencies.is_active` stays the single source of truth for supported currencies; `app_settings` stores only the **default** currency (and the other catalog settings), avoiding two sources of truth (FR-001, Key Entities).
- Q: Where is the admin-set default language / default currency applied for a new user? → A: **Client-side at registration** — the registration flow reads the public settings and writes the new user's initial `user_preferences.locale` / `display_currency`; existing users are never re-defaulted (FR-007).
- Q: What shape should the "support contact" setting take? → A: **Structured multi-channel** — a single `support_contact` setting holding optional **phone**, **WhatsApp**, and **email** channels, each surfaced (as the matching call / chat / mail affordance) only when set (FR-001, FR-013, Key Entities).
- Q: How is the optional admin-set maintenance message localized? → A: **Bilingual (`ar` + `en`)** — the admin sets an Arabic and an English variant (each optional); the maintenance screen shows the **active-locale** variant, falling back to the built-in localized copy when that variant is unset (FR-011).
