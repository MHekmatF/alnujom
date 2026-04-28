# AlNujom Real Estate — Implementation Plan

> **Status**: Approved plan v1.0 — 2026-04-27
> **Aligned with constitution**: `.specify/memory/constitution.md` v1.0.0
> **Project framing**: Full v1, phased delivery. This is *not* a stripped MVP.

This document is the single source of truth for how AlNujom Real Estate is built.
Every spec under `specs/<###-feature>/` derives from a phase listed here.
Every PR is reviewed against the constitution principles cited in its phase.

---

## Glossary

- **Publisher**: a user (owner, agent, or agency member) who has been approved by an admin to create listings.
- **Listing**: a real-estate offering with a purpose (sale / rent / daily_rent / investment) and a property type.
- **Governorate / City / Area**: the three-tier structured location hierarchy used for filtering and display.
- **Role**: a named bundle of permissions (e.g., `moderator`, `admin`, `super_admin`) attached to one or more users.
- **Permission**: a fine-grained capability key (e.g., `listings.approve`) that gates a specific action.
- **Audit log**: an append-only record of a sensitive action (actor, action, target, before/after, timestamp).
- **Synthetic email**: a Supabase Auth identifier of the form `<phone>@alnujom.local`, used because Supabase Auth requires an email but our users authenticate by phone.

---

## 1. Product direction

AlNujom Real Estate is an **Arabic-first real estate marketplace for Syria**, built as a Flutter Android app on top of Supabase. The product serves users (browsers), owners, agents, agencies, moderators, admins, and super admins, and supports listings for **sale**, **rent**, **daily_rent**, and **investment**.

Property types covered in v1: **apartment, villa, land, shop, office, farm, warehouse, other**.

The v1 release is the **full product** — registration, account approval, listing publishing with admin approval, search, filters, map view, contact / inquiry / lead tracking, favorites, reports, agencies, dynamic role/permission management with a super-admin UI, ads/banners admin module, push notifications, realtime admin signals, and admin dashboard. It is delivered in 24 sequenced phases.

**Explicit non-goals for v1**:

- iOS, Flutter Web, or desktop targets.
- Custom (non-Supabase) backend.
- Paid promoted-listing flow (schema is prepared; checkout is post-v1).
- Automatic duplicate detection (manual admin action only in v1).
- Auto-translation of listing content.
- Payment processing or commission settlement.
- Advanced analytics dashboards beyond admin counters.

---

## 2. Locked decisions

| Area | Decision | Rationale |
|---|---|---|
| **Project framing** | Full v1, phased delivery (24 phases) | User explicitly rejected MVP framing; product launches as a complete marketplace. |
| **Map provider** | `flutter_map` + OpenStreetMap tiles | No API key, no billing account, no OFAC/sanctions risk, works from Syrian IPs. Google Maps and Mapbox both ruled out. |
| **Auth strategy** | Phone + password with synthetic email under the hood | Most Syrian users don't have/know an email. Phone is universal. SMS-OTP deferred (Twilio doesn't reliably serve Syria); admin approval is the phone-verification gate. |
| **Routing** | `go_router` | Declarative, deep-link friendly, well-supported, idiomatic Flutter. |
| **DI** | `get_it` + `injectable` (codegen) | Typed DI with annotation-driven registration; standard pattern in modern Flutter. |
| **Localization** | `flutter_localizations` + `intl` + ARB files | Flutter-native tooling; better tooling than JSON files; overrides ChatGPT plan's `assets/translations/*.json` suggestion. |
| **State management** | BLoC / Cubit | Constitution Principle IV. Simpler local state allowed only with explicit per-feature spec approval. |
| **Backend** | Supabase, source-controlled | Constitution Principle II. All schema, migrations, policies, functions, seed in repo. Supabase MCP and Studio used for inspection only. |

### Critical Syria-specific notes

- **Distribution**: Google Play Store is unreliable for Syrian users. Primary channel is **direct APK** (project website + Telegram). Play Store is used for an internal QA testing track only.
- **SMS-OTP**: Deferred from v1. Twilio, MessageBird, and most international SMS providers either don't serve Syria or have poor delivery reliability. Phone numbers are verified via the **admin account-approval call/WhatsApp**.
- **CDN / image delivery**: Supabase Storage egress is the v1 path. Cloudflare and Google CDNs may be inaccessible from Syria; do not introduce them as a dependency.
- **Crash reporting**: Firebase Crashlytics flagged as sanctions-risky. Sentry (self-hosted or EU instance) is the leading candidate; final decision in Phase 24.
- **Maps**: Tile attribution to OpenStreetMap is required and shown on every map screen.

---

## 3. Constitution alignment

Every constitution principle (`.specify/memory/constitution.md` v1.0.0) is enforced by at least one section of this plan. Reviewers use this table to spot drift.

| Principle | Title | Enforced by |
|---|---|---|
| I | Spec-First Development (NON-NEGOTIABLE) | §10 (every phase has a spec folder); §11 (Definition of Done item 1); §13 (agents read spec before coding). |
| II | Source-Controlled Backend | §4 (`supabase/` tree); §6 (every backend deliverable is a checked-in file); §11 (DoD item 2); §15 (Risk: agent backend drift). |
| III | Security-First Supabase (NON-NEGOTIABLE) | §6.4 (RLS posture per table); §9 (permission system); §11 (DoD item 6); §12 (RLS smoke tests mandatory). |
| IV | Clean Architecture Flutter | §4 (`lib/features/<feature>/{data,domain,presentation}`); §5 (architecture rules); §11 (DoD item 3). |
| V | Arabic-First Localization | §7 (ARB files, Arabic default, RTL/LTR rules); §11 (DoD item 4). |
| VI | Theme System & Design Tokens | §7 (theme tokens); Phase 2; §11 (DoD item 4). |
| VII | Dynamic Roles & Permissions | §9 (permission catalog); Phases 6, 7; §11 (DoD item 5). |
| VIII | Approval Workflow & Publisher Identity | Phases 5, 12; §6.6 (auth flow); §6.4 (publisher private fields RLS). |
| IX | Future Backend Portability | §5 (no Supabase imports in `domain/`); §11 (DoD item 3). |
| X | Testable AI Workflow | §10 (every phase has acceptance criteria + verification steps); §11 (DoD item 7); §13 (specs updated in same PR). |
| XI | Android-First MVP | §1 (non-goals); §11 (DoD item 8); §15 (no iOS dependencies). |
| XII | No Hidden Product Decisions | §16 (open questions tracked); per-phase Assumptions sections in specs; §11 (DoD item 9). |

---

## 4. Repository structure

The repository organizes the Flutter app, Supabase backend, and project documentation into three top-level trees, plus the existing Spec Kit scaffold.

```
H:\alnujom-project\
├── .claude/                       # Claude Code skills (existing)
├── .specify/                      # Spec Kit scaffold (existing)
│   └── memory/constitution.md     # v1.0.0 — source of truth for principles
├── docs/                          # Project documentation
│   ├── IMPLEMENTATION_PLAN.md     # This file
│   ├── product/                   # Product briefs, wireframes
│   ├── architecture/              # Architecture decision records (ADRs)
│   ├── database/                  # Schema diagrams, RLS overview
│   ├── api-contracts/             # Edge Function and RPC contracts
│   ├── design/                    # Figma exports, design-token references
│   ├── testing/                   # Test plans, golden-path checklists
│   └── release/                   # Distribution, versioning, runbooks
├── specs/                         # Spec Kit feature folders (created per phase)
│   ├── 001-project-foundation/
│   ├── 002-design-system/
│   └── ...
├── lib/                           # Flutter app source
│   ├── main.dart
│   ├── app.dart                   # MaterialApp + theme + l10n + router wiring
│   ├── core/
│   │   ├── config/                # Env config, Supabase URL/anon-key loaders
│   │   ├── constants/             # App-wide constants (no feature data)
│   │   ├── di/                    # get_it container + injectable config
│   │   ├── errors/                # Failure hierarchy, exception → Failure mapping
│   │   ├── extensions/            # BuildContext, Iterable, DateTime helpers
│   │   ├── localization/          # Locale switcher, RTL helpers, Intl plurals
│   │   ├── logging/               # Structured logger
│   │   ├── network/               # Supabase client wrapper, retry, error mapping
│   │   ├── routing/               # go_router config, route guards
│   │   ├── security/              # PermissionChecker service
│   │   ├── storage/               # SecureStorage, prefs wrapper
│   │   ├── theme/                 # Design tokens, ThemeData light/dark
│   │   ├── utils/                 # Pure functions (formatters, parsers)
│   │   ├── validators/            # Form validators (phone, price, area)
│   │   └── widgets/               # Cross-feature reusable widgets
│   ├── l10n/
│   │   ├── app_ar.arb             # Arabic (default)
│   │   └── app_en.arb             # English
│   ├── features/
│   │   ├── auth/                  # Phase 5
│   │   │   ├── data/{datasources,models,repositories}/
│   │   │   ├── domain/{entities,repositories,usecases}/
│   │   │   └── presentation/{bloc,pages,widgets}/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── listings/
│   │   ├── listing_details/
│   │   ├── listing_form/
│   │   ├── search/
│   │   ├── map/
│   │   ├── favorites/
│   │   ├── inquiries/
│   │   ├── profile/
│   │   ├── agency/
│   │   ├── publisher_dashboard/
│   │   ├── admin/
│   │   ├── super_admin/
│   │   ├── currencies/
│   │   ├── locations/
│   │   ├── reports/
│   │   ├── ads/
│   │   ├── notifications/
│   │   └── settings/
│   └── shared/
│       ├── domain/                # Cross-feature value objects (Money, Phone)
│       ├── data/                  # Shared DTOs, base mappers
│       └── presentation/          # Shared cubits, layouts
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/
│   └── fonts/
├── supabase/                      # Source-controlled backend (Principle II)
│   ├── config.toml                # Supabase CLI config
│   ├── migrations/                # SQL migrations (timestamp-prefixed)
│   ├── functions/                 # Edge Functions (TypeScript)
│   ├── policies/                  # RLS policy SQL files (one per table group)
│   ├── storage/                   # Bucket setup SQL + access policies
│   ├── seed.sql                   # Reference data (currencies, governorates)
│   └── docs/                      # Per-table READMEs (schema, RLS, indexes)
├── test/                          # Unit + widget tests
└── integration_test/              # Flutter integration tests
```

The `lib/features/<feature>/{data,domain,presentation}/` shape is **not optional** — every feature folder follows it. The `core/` module never imports from `features/`. The `domain/` of any feature never imports `package:supabase_flutter` (Principle IX).

---

## 5. Architecture rules

These rules are enforceable at code review. A PR that breaks one is rejected.

1. **Layered call flow**: `Widget → Cubit/BLoC → UseCase → Repository (domain interface) → DataSource (Supabase impl)`. No layer skips. No widget calls Supabase, a `Repository` impl, or a `DataSource` directly.

2. **Domain purity**: files under `lib/features/<feature>/domain/` MUST NOT import `package:supabase_flutter`, `package:postgrest`, or any Supabase type. Repositories in `domain/` are abstract Dart classes; concrete impls live in `data/`.

3. **DI registration**: every service, repository, use case, and Cubit/BLoC is registered with `injectable` annotations (`@injectable`, `@lazySingleton`, `@factoryMethod`). The generated `injection.config.dart` is checked in. Manual `getIt.registerXxx` calls are reserved for `core/` infrastructure that can't be annotated.

4. **No hardcoded styles**: feature widgets read colors, typography, spacing, radii, and elevation from `Theme.of(context)` or the project's design-token API. Inline hex literals, raw font sizes, or numeric padding constants in feature code fail review (Principle VI).

5. **Localization discipline**: every user-visible string flows through the generated `AppLocalizations` (Flutter ARB-based l10n). Inline `Text('السلام')` or `Text('Hello')` in feature code fails review (Principle V).

6. **Direction-agnostic layouts**: feature code uses `EdgeInsetsDirectional`, `AlignmentDirectional`, and `Directionality`-aware widgets. Raw `EdgeInsets.only(left: ...)` in feature code is a review failure unless the Cubit owns the LTR/RTL decision (rare).

7. **Permission checks at both ends**: every sensitive action (approve, reject, suspend, delete, role-edit) is gated by (a) frontend `PermissionChecker` for UX hiding AND (b) Supabase RLS / Edge Function permission verification. Frontend-only checks are insufficient (Principle III, VII).

8. **Audit logs are mandatory** for sensitive admin actions: account approval/rejection/suspension, listing approval/rejection/deletion, role/permission mutations, exchange-rate updates, ad creation/deletion, settings changes (Principle VII).

9. **No iOS / Web code**: PRs that add iOS-specific or Flutter Web code, plugins with no Android support, or cross-platform abstractions for non-Android targets are rejected (Principle XI).

---

## 6. Supabase backend plan

### 6.1 Source-control discipline (Principle II)

Every backend change is a **file checked into `supabase/`**. The Supabase MCP and Studio MAY be used for inspection, prototyping, and applying changes — but the resulting SQL is then captured as a migration file in the same PR. Studio-only changes that don't land as a checked-in migration are reverted at PR review.

Folder convention:

- `supabase/migrations/<timestamp>_<description>.sql` — schema changes (tables, columns, indexes, enums).
- `supabase/policies/<table_group>_policies.sql` — RLS policies for one logical table group (e.g., `listings_policies.sql`).
- `supabase/functions/<name>/index.ts` — Edge Function source.
- `supabase/storage/buckets.sql` — bucket creation + policies.
- `supabase/seed.sql` — idempotent reference data.
- `supabase/docs/<table>.md` — per-table notes (purpose, RLS posture, indexes, gotchas).

### 6.2 Schema (full table list)

**Identity**

- `profiles` — user_id (PK = `auth.users.id`), full_name, username (unique), phone (unique), email (nullable), avatar_url, preferred_language, preferred_currency, account_status, publisher_status, created_at, updated_at.
- `account_approval_requests` — id, user_id, submitted_at, reviewed_by, reviewed_at, decision, decision_reason.
- `user_preferences` — user_id (PK), display_currency, locale, theme_mode, notifications_enabled.

**Roles & permissions**

- `roles` — id, key (unique, e.g., `moderator`), name_ar, name_en, is_system (true for built-ins), created_at.
- `permissions` — id, key (unique, e.g., `listings.approve`), description_ar, description_en, category.
- `role_permissions` — role_id, permission_id (PK pair).
- `user_roles` — user_id, role_id, granted_by, granted_at (PK pair).

**Agencies**

- `agencies` — id, owner_user_id, name, description, phone, whatsapp, address, logo_url, status (pending/approved/rejected/suspended), created_at.
- `agency_members` — agency_id, user_id, member_role (admin/agent), status, invited_by, joined_at.
- `agency_verification_requests` — id, agency_id, submitted_at, reviewed_by, reviewed_at, decision, decision_reason, evidence_urls.

**Locations**

- `governorates` — id, name_ar, name_en, code, sort_order.
- `cities` — id, governorate_id, name_ar, name_en, sort_order.
- `areas` — id, city_id, name_ar, name_en, sort_order.

**Listings**

- `listings` — id, publisher_user_id, agency_id (nullable), purpose, property_type, status, title, governorate_id, city_id, area_id, address_text, latitude, longitude, location_visibility (hidden/approximate/exact/admin_only), phone, whatsapp, contact_name_visibility (public/admin_only), area_size, rooms, bathrooms, floor, created_at, updated_at, published_at, expires_at.
- `listing_details` — listing_id (PK), description, amenities (jsonb), year_built, furnished, parking, etc.
- `listing_prices` — id, listing_id, currency_code, amount, is_primary, created_at.
- `listing_media` — id, listing_id, kind (image/video/external_link), storage_path, external_url, ordering, is_main, watermarked.
- `listing_visibility` — listing_id (PK), location_visibility, contact_visibility, hide_until, last_updated_by.
- `listing_status_history` — id, listing_id, previous_status, new_status, changed_by, changed_at, reason.

**Currencies**

- `currencies` — code (PK, e.g., `USD`, `SYP`), name_ar, name_en, symbol, is_active, sort_order.
- `exchange_rates` — id, base_currency, target_currency, rate, effective_at, set_by, source.

**Engagement**

- `inquiries` — id, listing_id, sender_user_id (nullable for anonymous), sender_phone, sender_name, message, status (new/seen/responded/closed/spam), created_at.
- `lead_events` — id, listing_id, user_id (nullable), event_type, metadata (jsonb), created_at.
- `favorites` — user_id, listing_id (PK pair), created_at.

**Moderation**

- `reports` — id, listing_id, reporter_user_id, reason, note, status (new/reviewing/resolved/dismissed), resolved_by, resolved_at, resolution.
- `moderation_actions` — id, target_type, target_id, action, performed_by, performed_at, reason, before_state (jsonb), after_state (jsonb).

**Ads**

- `ads` — id, title, image_url, link_url, start_at, end_at, is_active, created_by.
- `ad_placements` — ad_id, placement_key (home_top_banner / home_middle_banner / search_results_banner / listing_details_banner / category_banner), priority.
- `ad_impressions` — id, ad_id, placement_key, user_id (nullable), occurred_at, kind (impression/click).

**Audit**

- `audit_logs` — id, actor_user_id, action, target_type, target_id, before_state (jsonb), after_state (jsonb), ip, user_agent, created_at.

**Settings**

- `app_settings` — key (PK), value (jsonb), description, updated_by, updated_at.

### 6.3 Status enums

- **Account / publisher**: `pending`, `approved`, `rejected`, `suspended`, `deleted`.
- **Listing**: `draft`, `pending_review`, `approved`, `rejected`, `paused`, `sold`, `rented`, `expired`, `deleted`.
- **Inquiry**: `new`, `seen`, `responded`, `closed`, `spam`.
- **Report**: `new`, `reviewing`, `resolved`, `dismissed`.
- **Listing purpose**: `sale`, `rent`, `daily_rent`, `investment`.
- **Property type**: `apartment`, `villa`, `land`, `shop`, `office`, `farm`, `warehouse`, `other`.
- **Location visibility**: `hidden`, `approximate`, `exact`, `admin_only`.
- **Report reason**: `fake_listing`, `wrong_price`, `already_sold_or_rented`, `duplicate`, `spam`, `wrong_location`, `inappropriate_content`, `other`.

All enums are defined as Postgres `CHECK` constraints or native enum types in the first migration that introduces them; they are also encoded as Dart enums in `lib/features/<feature>/domain/entities/` so the domain layer never depends on string literals.

### 6.4 RLS posture per table

Every table has RLS enabled. The constitution (Principle III) requires explicit documentation when a table opts out — no v1 table opts out. The matrix below summarizes who can read/write each table; full policy SQL lives under `supabase/policies/`.

| Table | Read | Write | Audit-logged |
|---|---|---|---|
| `profiles` | Self (full); admins (full); other users (only public fields when `contact_name_visibility = public`) | Self (most fields); admins (status, publisher_status) | Status changes |
| `account_approval_requests` | Self; admins with `users.view` | Self (insert); admins with `users.approve` (update) | Decision |
| `user_preferences` | Self only | Self only | No |
| `roles`, `permissions` | Authenticated readers (UI needs catalog); writes by `roles.create` / `permissions.manage` | Super-admin only | Yes |
| `role_permissions`, `user_roles` | Authenticated readers; `users.view` for cross-user | `roles.create` (role mapping); super-admin (user mapping) | Yes |
| `agencies` | Public (approved); members; admins | Owner (own draft); admins (status) | Status changes |
| `agency_members` | Members of same agency; admins | Agency admin (own agency); admins | Member adds / removes |
| `governorates`, `cities`, `areas` | Public read | `locations.manage` | Inserts and renames |
| `listings` (public read) | Public (`status = approved` AND publish window) | Owner (own draft / rejected); admins with `listings.edit_any` | Status, edit_any, deletes |
| `listing_details`, `listing_prices`, `listing_media` | Same as parent listing | Same as parent listing | Inherited |
| `listing_visibility` | Owner; admins | Owner; admins | Yes (visibility changes) |
| `listing_status_history` | Owner; admins | System triggers only | Implicit (this IS the log) |
| `currencies` | Public read | `currencies.manage` | Yes |
| `exchange_rates` | Public read (latest active) | `currencies.manage` | Yes |
| `inquiries` | Sender; listing publisher; admins | Sender (insert); listing publisher / admins (status) | Inquiry resolution |
| `lead_events` | Listing publisher; admins | System (Edge Function) | No (high volume) |
| `favorites` | Self only | Self only | No |
| `reports` | Reporter (own); admins with `reports.manage` | Anyone (insert); admins (resolve) | Resolution |
| `moderation_actions` | Admins | System triggers only | Implicit |
| `ads`, `ad_placements` | Public read (active window) | `ads.manage` | Yes |
| `ad_impressions` | Admins | System (Edge Function) | No |
| `audit_logs` | Admins with `audit_logs.view` | System triggers only | Implicit |
| `app_settings` | Public read for non-sensitive keys; admins for all | `settings.manage` | Yes |

### 6.5 Storage buckets

| Bucket | Read access | Write access | Notes |
|---|---|---|---|
| `listing-images` | Public (only paths under approved listings) | Listing owner; admins | Watermark applied client-side before upload (v1); server-side later. |
| `listing-videos` | Public (approved listings) | Listing owner; admins | v1 supports external links primarily; uploads capped at 2 per listing. |
| `profile-images` | Public for avatars | Self | Cap 1 per user. |
| `agency-assets` | Public for logos | Agency admins | Logo + cover. |
| `admin-assets` | Admins | Admins | Internal admin imagery. |
| `ads` | Public (active ads) | `ads.manage` | Banner imagery. |
| `documents` | Owner; admins | Owner | Verification docs (agency, owner ID). Never public. |

Bucket policies live in `supabase/storage/buckets.sql`.

### 6.6 Auth flow (synthetic-email pattern)

Supabase Auth requires a unique identifier per user; for v1 we use a synthetic email derived from the phone number.

**Registration**

1. User enters phone (with country code, default `+963`) + password + optional real email.
2. Client computes synthetic email: `+963XXXXXXXXX@alnujom.local` (E.164 normalized).
3. Client calls `supabase.auth.signUp({ email: <synthetic>, password })`. Supabase creates `auth.users` row.
4. A trigger inserts into `profiles` with `phone`, real `email` (nullable), `account_status = pending`, `publisher_status = pending`.
5. An `account_approval_requests` row is auto-inserted; admin queue picks it up.
6. UI shows "Account pending approval" screen.

**Login**

1. User enters phone + password.
2. Client computes synthetic email and calls `supabase.auth.signInWithPassword({ email: <synthetic>, password })`.
3. On success, app reads `profiles.account_status`. `pending` → pending screen; `rejected` → rejection screen with reason; `suspended` → suspension screen; `approved` → home.

**Recovery**

- If real email is on file: standard Supabase `resetPasswordForEmail` against the real email.
- If no real email: user contacts admin (in-app "Contact support" link). Admin issues a temporary password via the super-admin UI; user changes on next login.

**Phone verification**

- Phone is **unverified** at registration.
- Admin reviewing the account-approval request calls or WhatsApps the phone number; on confirmation, sets `account_status = approved`, which gates publishing.
- Real SMS-OTP is post-v1.

### 6.7 Edge Functions (v1)

Edge Functions exist only when an action requires server-side privilege checks or atomic multi-step writes that RLS cannot express cleanly.

| Function | Purpose |
|---|---|
| `submit_listing` | Atomic transition `draft → pending_review` with validation + status_history insert. |
| `approve_listing` | Permission check (`listings.approve`), status transition, `published_at` set, audit log, optional notification fan-out. |
| `reject_listing` | Permission check, status transition with reason, audit log, notification. |
| `update_exchange_rate` | Permission check (`currencies.manage`), historical record (never UPDATE — INSERT new row), audit log. |
| `record_lead_event` | Light validation, IP/user-agent capture, write to `lead_events` (high-volume; bypasses RLS for batched inserts). |
| `resolve_report` | Permission check (`reports.manage`), atomic resolution + linked moderation action + audit log. |

Each function has a contract file under `docs/api-contracts/` (request/response schema + permission requirement + audit-log fields).

---

## 7. Localization & theming

### Localization

- Default locale: `ar` (Syrian-friendly, professional, clear; avoid stiff Modern Standard Arabic when a natural Levantine equivalent exists).
- Co-equal locale: `en`.
- ARB files: `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`. Generated `AppLocalizations` class via `flutter gen-l10n`.
- A user-visible string MUST NOT be added without entries in both ARB files; the `localization` gate (DoD item 4) blocks merge otherwise.
- `MaterialApp.localizationsDelegates` and `supportedLocales` wired in `app.dart`. App-wide locale toggle stored in `user_preferences.locale`.

### RTL / LTR

- `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional` used everywhere in feature code.
- Avoid `EdgeInsets.only(left: ...)`, `Alignment.centerLeft`, etc. — they break in RTL.
- Icons that imply direction (back arrow, chevron) use `Directionality.of(context)`-aware variants.
- A widget test in Phase 3 enforces RTL/LTR rendering for the listing card, listing form, and admin queue.

### Theming (Principle VI)

- Token module at `lib/core/theme/`:
  - `colors.dart` — semantic color tokens (primary, surface, on_surface, success, warning, danger, etc.) with light + dark variants.
  - `typography.dart` — Arabic + Latin type scales (display, headline, title, body, label).
  - `spacing.dart`, `radii.dart`, `elevation.dart`.
- `ThemeData.light()` and `ThemeData.dark()` built from tokens.
- Two design directions explored in Figma **before** Phase 2 starts coding:
  - Direction A — **Luxury / Premium**: dark elegant base, gold/warm accent, large photography, soft shadows, premium cards.
  - Direction B — **Modern Tech**: clean light base, strong search affordance, marketplace card density, high readability.
- One direction is selected; tokens implement the chosen direction. The rejected direction stays in `docs/design/archive/` for reference (Principle XII — no hidden product decisions).

---

## 8. Currency system

- `currencies` seed for v1: `USD`, `SYP`. Schema accepts arbitrary additional codes — adding `EUR` or `TRY` later requires only a `currencies` row + active `exchange_rates` rows. No destructive migration.
- A listing has 1+ rows in `listing_prices`, exactly one with `is_primary = true`. The primary price is what the publisher entered in their preferred currency.
- **Original prices are never overwritten by conversion.** Display-time conversion uses the latest active `exchange_rates` row.
- User's `preferred_currency` (in `user_preferences`) drives the displayed currency on listing cards and details.
- Admins update exchange rates via the super-admin / admin UI (`currencies.manage` permission). Each update inserts a new `exchange_rates` row; old rows are kept for historical accuracy.
- Money formatting goes through a single utility: `MoneyFormatter.format(amount, currency, locale)` — handles RTL digit grouping, currency symbol position, and locale rules.

---

## 9. Permission system

The permission system is fully data-driven (Principle VII). Hardcoded role checks (`if (user.role == 'admin')`) are forbidden in feature code.

### 9.1 Permission catalog (initial v1 set, refined in Phase 6 spec)

Categories and keys:

- **users**: `users.view`, `users.approve`, `users.reject`, `users.suspend`.
- **listings**: `listings.view_all`, `listings.approve`, `listings.reject`, `listings.edit_any`, `listings.delete_any`.
- **roles**: `roles.view`, `roles.create`, `roles.update`, `roles.delete`, `permissions.manage`.
- **locations**: `locations.manage`.
- **currencies**: `currencies.manage`.
- **ads**: `ads.manage`.
- **reports**: `reports.manage`.
- **agencies**: `agencies.view`, `agencies.approve`, `agencies.suspend`.
- **settings**: `settings.manage`.
- **audit**: `audit_logs.view`.
- **inquiries**: `inquiries.view_all` (cross-publisher visibility for admins).

Default role-permission mapping (seeded):

- `user` — none of the above (default capabilities only: own profile, own listings).
- `owner` / `agent` / `agency_admin` — own-listings capabilities only; `agency_admin` adds agency-member management.
- `moderator` — `users.view`, `listings.view_all`, `listings.approve`, `listings.reject`, `reports.manage`.
- `admin` — moderator + `users.approve`, `users.reject`, `users.suspend`, `listings.edit_any`, `locations.manage`, `currencies.manage`, `ads.manage`, `agencies.approve`, `agencies.suspend`, `audit_logs.view`.
- `super_admin` — all permissions including `roles.*`, `permissions.manage`, `settings.manage`, `listings.delete_any`.

### 9.2 Frontend `PermissionChecker`

`lib/core/security/permission_checker.dart` — caches the current user's permission keys, exposes `bool has(String permKey)` and `bool any(List<String>)`. Cubits and widgets call it to hide UI; it is **not** a security boundary.

### 9.3 Backend RLS + Edge Function checks

Every sensitive write is protected by RLS policies that join `user_roles → role_permissions → permissions` and check the required permission key. Edge Functions re-check before performing the action server-side. The two layers together enforce Principle III.

### 9.4 Audit triggers

A trigger function `log_audit(action, target_type, target_id, before, after)` is called from:

- Account approval / rejection / suspension (Phase 5).
- Role / permission mutations (Phase 7).
- Listing approval / rejection / deletion (Phase 12).
- Exchange rate updates (Phase 9).
- Ad creation / deletion (Phase 21).
- App settings changes (Phase 23).

---

## 10. Phased build order

Each phase produces a `specs/<###-name>/` folder via `/speckit.specify`, followed by `/speckit.plan` and `/speckit.tasks`. The **Goal**, **Backend deliverables**, **Frontend deliverables**, **Acceptance criteria**, and **Verification** below are the seed for those specs — they are not the spec itself.

### Phase 0 — Constitution & repo bootstrap

- Already complete. `.specify/memory/constitution.md` v1.0.0 ratified 2026-04-27.
- This implementation plan checked in.
- No spec folder.

---

### Phase 1 — Project foundation
**Spec**: `specs/001-project-foundation/`
**Principles**: I, IV, IX, XI, XII

**Goal**: A runnable Flutter Android app shell with DI, routing, error handling, theme/locale switching scaffolding, Supabase client wrapper, logging — but no features yet.

**Backend deliverables**:
- `supabase/config.toml` — local Supabase CLI project initialized.
- `supabase/migrations/00000000000000_init_extensions.sql` — `pgcrypto`, `uuid-ossp`.
- `supabase/seed.sql` — empty stub.

**Frontend deliverables**:
- `pubspec.yaml` with locked deps: `flutter_bloc`, `go_router`, `get_it`, `injectable`, `supabase_flutter`, `flutter_localizations`, `intl`, `cached_network_image`, `flutter_secure_storage`, `equatable`, plus dev deps `injectable_generator`, `build_runner`, `bloc_test`, `mockito`.
- `lib/main.dart`, `lib/app.dart`, `lib/core/{config,di,errors,logging,network,routing,storage,theme,utils,widgets}/`.
- `lib/core/network/supabase_client.dart` — wrapper that hides the Supabase SDK behind a thin interface (Principle IX).
- `lib/core/routing/app_router.dart` — `go_router` config with placeholder routes.
- `lib/core/theme/` — token stubs (real tokens land in Phase 2).
- `Result<T>` / `Failure` types in `lib/core/errors/`.

**Acceptance criteria**:
- `flutter run` on an Android emulator launches a screen showing "AlNujom" + locale + theme toggle (toggles work).
- `flutter test` passes (one smoke test).
- `flutter build apk --debug` succeeds.
- DI container builds; `getIt<SupabaseClientWrapper>()` returns a live instance.
- No imports of `package:supabase_flutter` outside `lib/core/network/`.

**Verification**:
- Inspect `pubspec.lock` — all deps resolved, no iOS-only or Web-only plugins.
- `grep -R "package:supabase_flutter" lib/features lib/shared/domain` returns no results.
- Manual: launch app, toggle theme (light↔dark), toggle locale (ar↔en).

---

### Phase 2 — Design system & theme tokens
**Spec**: `specs/002-design-system/`
**Principles**: V, VI, XI, XII

**Goal**: A complete, themed design-token module and a kit of reusable widgets used by every later phase.

**Pre-phase**: Figma exploration of Direction A (Luxury) and Direction B (Modern Tech). Stakeholder picks one. Decision recorded in `docs/design/decision.md`.

**Backend deliverables**: none.

**Frontend deliverables**:
- `lib/core/theme/colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, `elevation.dart`.
- `ThemeData.light()` and `ThemeData.dark()` exported via `app_theme.dart`.
- Reusable widgets in `lib/core/widgets/`: `AppButton`, `AppTextField`, `AppCard`, `EmptyState`, `LoadingState`, `ErrorState`, `AppDialog`, `AppBottomNav`, `AppAppBar`.
- Feature-specific shared widgets (in `lib/shared/presentation/widgets/`): `ListingCard`, `PriceDisplay`, `AdminListItem`.
- A `theme_gallery_page.dart` (debug-only) exercising every component in light + dark + ar + en.

**Acceptance criteria**:
- The gallery page renders cleanly in 4 combinations (light/dark × ar/en).
- No hex literal or raw `TextStyle(...)` exists in feature code (`grep` check).
- Buttons, inputs, cards expose disabled / loading / error variants.

**Verification**:
- Open `theme_gallery_page` in the running app and toggle through all 4 combinations.
- Widget test takes golden screenshots for ListingCard in 4 combinations.

---

### Phase 3 — Localization
**Spec**: `specs/003-localization/`
**Principles**: V, XII

**Goal**: ARB-driven localization wired through the app, RTL/LTR working end-to-end, locale persisted.

**Backend deliverables**: none.

**Frontend deliverables**:
- `lib/l10n/app_ar.arb` (default), `lib/l10n/app_en.arb`. Initial keys: app shell strings, theme gallery strings, common errors.
- `flutter gen-l10n` generates `AppLocalizations`.
- `MaterialApp.localizationsDelegates` and `supportedLocales` wired.
- Locale toggle reads/writes `user_preferences.locale` (until Phase 5 ships, falls back to local secure storage).
- Lint rule (custom `analysis_options.yaml` exception list) flagging string literals in widget files.

**Acceptance criteria**:
- App launches in `ar` by default.
- Switching to `en` rebuilds the entire UI in LTR.
- Listing card test renders correctly in both directions (golden test).

**Verification**:
- Manual: launch fresh install, confirm Arabic + RTL.
- `grep -RE "Text\\([\"']" lib/features/` returns no untranslated literals.

---

### Phase 4 — Supabase base schema + RLS scaffolding
**Spec**: `specs/004-supabase-foundation/`
**Principles**: II, III, IX
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md)

**Goal**: Source-controlled Supabase project with the skeleton tables that everything else depends on, RLS enabled by default, and the Vault scaffolding ready for later phases to encrypt secrets and PII.

**Backend deliverables**:
- Migrations:
  - `0001_init_enums.sql` — all status enums from §6.3.
  - `0002_create_profiles.sql` + trigger to insert profile on `auth.users` insert.
  - `0003_create_user_preferences.sql`.
  - `0004_create_audit_logs.sql` + trigger function `log_audit()`.
  - `0005_enable_rls_default.sql` — RLS on the three tables above.
  - `0006_enable_vault.sql` — enable `pgsodium` + Supabase Vault (`vault` schema), plus a thin SQL helper `app_vault_secret(name)` for Edge Functions to read secrets. No secrets are stored yet; this is forward-prep for Phases 5, 16, 19, 21, 22 per ADR-0001.
- Policies:
  - `profiles_policies.sql` — self-read/write, admins-read-all (admin perm check stub for now).
  - `user_preferences_policies.sql` — self-only.
  - `audit_logs_policies.sql` — admin-read-only, no client writes.
- `supabase/docs/profiles.md`, `audit_logs.md`.

**Frontend deliverables**:
- `lib/core/network/supabase_client.dart` extended with auth-state listener.
- Domain entities in `lib/shared/domain/entities/`: `Profile`, `UserPreferences`.

**Acceptance criteria**:
- `supabase db reset` rebuilds the local DB from migrations cleanly.
- Inserting a row into `auth.users` (via test fixture) auto-creates a `profiles` row.
- An anonymous client cannot read another user's `profiles` row (RLS smoke test).
- An admin trigger writes to `audit_logs`.

**Verification**:
- Run `supabase db reset && supabase test db` — RLS smoke tests pass.
- SQL: `SELECT * FROM profiles WHERE user_id = '<other-user>'` from a non-admin session returns 0 rows.

---

### Phase 5 — Auth & profile
**Spec**: `specs/005-auth-profile/`
**Principles**: I, III, IV, V, VIII, IX, XII
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md) — `profiles.legal_name`, `profiles.national_id`, and `profiles.private_contact_methods` are stored via Supabase Vault, not as plaintext columns.

**Goal**: Phone+password registration with synthetic email, login, account-approval workflow gating publishing.

**Backend deliverables**:
- Migration `0007_create_account_approval_requests.sql` + trigger to auto-insert request on profile creation.
- Migration `0008_profiles_vault_columns.sql` — adds Vault-backed columns for `legal_name`, `national_id`, `private_contact_methods` per ADR-0001; admin-only decrypt views.
- Policies for `account_approval_requests` (self-read, admin-read-all).
- (Note: `users.approve` permission key is reserved; full `roles`/`permissions` tables land in Phase 6. For Phase 5, an interim env-flag `is_admin` boolean on `profiles` is used, replaced when Phase 6 ships.)

**Frontend deliverables**:
- `lib/features/auth/`:
  - `data/datasources/supabase_auth_datasource.dart` — synthetic-email construction + Supabase Auth calls.
  - `data/repositories/auth_repository_impl.dart`.
  - `domain/entities/{credentials,phone_number,session}.dart`, `domain/repositories/auth_repository.dart`, `domain/usecases/{register,login,logout,reset_password}.dart`.
  - `presentation/bloc/auth_bloc.dart`, `pages/{login_page,register_page,pending_approval_page,rejected_page,suspended_page}.dart`.
- `lib/features/profile/`:
  - Profile view + edit pages, Cubit, repository, datasource.
- `lib/features/onboarding/` — splash + onboarding screens.
- Phone-number value object in `lib/shared/domain/` with E.164 normalization.

**Acceptance criteria**:
- New user registers with phone `+963991234567` + password; profile row exists, `account_status = pending`.
- User sees "Pending approval" screen after first login until admin approves.
- Admin (interim flag) sets `account_status = approved`; user lands on home on next login.
- Wrong password / unknown phone shows localized error.
- Real email field is optional; password reset works only when real email is set.

**Verification**:
- Manual: register flow end-to-end on emulator.
- SQL: `SELECT account_status FROM profiles WHERE phone = '+963991234567'`.
- RLS smoke: another user cannot read this user's profile via the client.

---

### Phase 6 — Roles & permissions
**Spec**: `specs/006-roles-permissions/`
**Principles**: III, VII, IX

**Goal**: Dynamic role/permission system live in DB and frontend; replaces interim `is_admin` flag.

**Backend deliverables**:
- Migrations `0007_create_roles.sql`, `0008_create_permissions.sql`, `0009_create_role_permissions.sql`, `0010_create_user_roles.sql`.
- Seed: full §9.1 permission catalog + default role mappings (user / owner / agent / agency_admin / moderator / admin / super_admin).
- Helper SQL function `current_user_has_permission(perm_key text) RETURNS boolean` used by all RLS policies.
- Backfill migration: convert existing `is_admin` users to `admin` role; drop the column.
- Policy files for each new table.

**Frontend deliverables**:
- `lib/core/security/permission_checker.dart`.
- `lib/features/admin/` skeleton (admin home, gated by any admin permission).
- `lib/features/profile/` extended to show user's roles (read-only).

**Acceptance criteria**:
- A user with `admin` role sees admin home; a user without does not.
- `permission_checker.has('listings.approve')` matches the DB.
- RLS on `profiles` now uses `current_user_has_permission('users.view')` for cross-user reads.

**Verification**:
- SQL: `SELECT current_user_has_permission('listings.approve')` from an admin and a non-admin session.
- Manual: log in as admin → admin tile visible; log in as user → admin tile hidden.

---

### Phase 7 — Super-admin role UI
**Spec**: `specs/007-super-admin-roles/`
**Principles**: I, III, VII

**Goal**: Super admin can create roles, edit permissions on roles, and assign roles to users — fully in-app.

**Backend deliverables**:
- Edge Function `mutate_role` — wraps role create/update/delete with permission re-check and audit-log emission. (Direct SQL also allowed via `roles.create` RLS, but the Edge Function exists to bundle the role-permission delta atomically.)
- Audit triggers on `roles`, `role_permissions`, `user_roles`.

**Frontend deliverables**:
- `lib/features/super_admin/` — `RolesListPage`, `RoleEditorPage` (toggle permissions per role, save), `AssignRolePage` (search user → assign/remove roles).
- BLoCs and use cases in domain.
- Confirmation dialogs on destructive actions (delete role, remove role from user).

**Acceptance criteria**:
- Super admin can create a custom `finance` role with `currencies.manage` only.
- Assigning that role to a user grants them the currency-management UI on next session refresh.
- A non-super-admin cannot reach the super-admin pages (route guard + RLS).
- Every mutation writes an `audit_logs` row.

**Verification**:
- Manual: create role, assign, verify on second account.
- SQL: `SELECT * FROM audit_logs WHERE target_type = 'role' ORDER BY created_at DESC LIMIT 5`.

---

### Phase 8 — Locations
**Spec**: `specs/008-locations/`
**Principles**: I, III, V, VII

**Goal**: Structured Syrian governorates / cities / areas managed by admins; selectable in listing form.

**Backend deliverables**:
- Migrations `0011_create_governorates.sql`, `0012_create_cities.sql`, `0013_create_areas.sql`.
- Seed: all 14 Syrian governorates + major cities (Damascus, Aleppo, Homs, Latakia, Tartus, Hama, etc.) + a starter set of areas.
- Policies: public read; `locations.manage` write.

**Frontend deliverables**:
- `lib/features/locations/` — admin CRUD pages.
- `LocationPicker` widget (cascading dropdown: governorate → city → area) reused later by listing form.

**Acceptance criteria**:
- Public users see seed data on app launch.
- Admin with `locations.manage` can add a new area; it appears in the picker.
- Renaming a governorate updates everywhere.

**Verification**:
- SQL: row counts for seeded governorates / cities.
- Manual: location picker cascade works in both ar/en.

---

### Phase 9 — Currencies & exchange rates
**Spec**: `specs/009-currencies/`
**Principles**: I, III, VII

**Goal**: Multi-currency price storage + admin-managed exchange rates + user-preferred display currency.

**Backend deliverables**:
- Migrations `0014_create_currencies.sql`, `0015_create_exchange_rates.sql`.
- Seed: `USD`, `SYP` rows.
- Edge Function `update_exchange_rate` (insert-only, audit-logged).
- Policies.

**Frontend deliverables**:
- `lib/features/currencies/` — admin pages (currency list, exchange-rate history, "set new rate").
- `lib/shared/domain/value_objects/money.dart` + `MoneyFormatter` utility.
- Profile/settings page extended with display-currency toggle.

**Acceptance criteria**:
- Admin sets `USD → SYP` rate; subsequent listing prices are convertible.
- A USD listing displays its SYP equivalent when display currency = SYP, but the stored row never changes.
- Old rates are visible in history.

**Verification**:
- SQL: `SELECT * FROM exchange_rates WHERE base_currency = 'USD' AND target_currency = 'SYP' ORDER BY effective_at DESC`.
- Unit test: `MoneyFormatter` golden cases (10 fixed inputs → expected strings) in ar + en.

---

### Phase 10 — Listing creation
**Spec**: `specs/010-listing-creation/`
**Principles**: I, III, IV, V, VIII, IX, X, XII

**Goal**: Approved publishers can create draft listings with all v1 fields; submit changes status to `pending_review`.

**Backend deliverables**:
- Migrations: `0016_create_listings.sql`, `0017_create_listing_details.sql`, `0018_create_listing_prices.sql`, `0019_create_listing_visibility.sql`, `0020_create_listing_status_history.sql`.
- Status-transition trigger that writes `listing_status_history` rows.
- Edge Function `submit_listing` (validates required fields, sets status, writes history).
- Policies — owner draft/edit, public approved-read, admin edit_any.

**Frontend deliverables**:
- `lib/features/listing_form/` — multi-step form (basics → location → details → prices → visibility settings → media placeholder → review).
- `lib/features/publisher_dashboard/` — `MyListingsPage`, status filters.
- Validators in `lib/core/validators/` for area, price, phone.

**Acceptance criteria**:
- An approved publisher creates a draft, fills all required fields, submits → status becomes `pending_review`.
- A non-approved user cannot reach the form.
- A rejected listing is editable and resubmittable; status history shows the transition chain.

**Verification**:
- SQL: `SELECT status, COUNT(*) FROM listings GROUP BY status` after each transition.
- Unit tests for validators.
- RLS smoke: anonymous client cannot read a `draft` row.

---

### Phase 11 — Media upload & client-side watermark
**Spec**: `specs/011-media-watermark/`
**Principles**: I, III, IX

**Goal**: Listing form supports up to 10 images with watermark and 2 videos (or external links).

**Backend deliverables**:
- Migration `0021_create_listing_media.sql`.
- Storage policies for `listing-images`, `listing-videos`.
- Trigger enforcing the 10-image / 2-video caps server-side.

**Frontend deliverables**:
- `lib/features/listing_form/widgets/media_picker.dart` — multi-image picker, reorder, set main, delete.
- Client-side watermark utility: composes the AlNujom logo (semi-transparent) onto each image before upload.
- Image downscaling (max 1920px on long edge) to control storage cost.
- Video: external-link field + optional small-file upload (capped 30 MB).

**Acceptance criteria**:
- An uploaded image in `listing-images` bucket has the watermark visible.
- Uploading an 11th image is rejected client-side and server-side.
- Image order persists; main image is highlighted on listing card.

**Verification**:
- Manual: upload + visual check of watermark.
- SQL: `SELECT COUNT(*) FROM listing_media WHERE listing_id = '...' AND kind = 'image'` ≤ 10.

---

### Phase 12 — Listing approval workflow
**Spec**: `specs/012-listing-approval/`
**Principles**: I, III, VII, VIII, X

**Goal**: Admins with `listings.approve` review pending listings, approve or reject with reason; approved listings become public.

**Backend deliverables**:
- Edge Functions `approve_listing`, `reject_listing` (permission check + transition + audit + status_history + optional notification stub).
- RLS update: public read where `status = 'approved'`.

**Frontend deliverables**:
- `lib/features/admin/listing_review/` — pending queue, listing preview (full-fidelity render), approve / reject buttons, reject-reason dialog (with localized reason presets + free text).
- Publisher dashboard shows rejection reason on rejected cards with a "Resubmit" button.

**Acceptance criteria**:
- Admin approves a pending listing → it appears in any anonymous client's home feed.
- Admin rejects with reason → publisher sees reason in My Listings.
- Both transitions write audit logs.

**Verification**:
- Manual: full publish loop on emulator.
- SQL: `SELECT * FROM audit_logs WHERE action IN ('listing.approved','listing.rejected')`.

---

### Phase 13 — Public home & listing details
**Spec**: `specs/013-home-and-details/`
**Principles**: I, IV, V, VI

**Goal**: Anonymous and authenticated users browse approved listings and view full details.

**Backend deliverables**:
- Index migration `0022_listings_indexes.sql` — indexes on `(status, created_at DESC)`, `(governorate_id, status)`, `(property_type, status)`.

**Frontend deliverables**:
- `lib/features/home/` — `HomePage` with hero search + property-type shortcuts + latest listings (paginated).
- `lib/features/listing_details/` — gallery, price block, location block, contact-CTA stubs (Phase 16 wires them), favorite + share + report stubs.
- Pagination via cursor-based query (created_at + id tiebreaker).

**Acceptance criteria**:
- Home loads 20 listings; pull-to-refresh and infinite scroll work.
- Tapping a listing opens details; image gallery swipes.
- Anonymous viewing works (no login required).

**Verification**:
- Manual: scroll, refresh, open details.
- SQL `EXPLAIN` confirms index usage for the home query.

---

### Phase 14 — Search & filters
**Spec**: `specs/014-search-filters/`
**Principles**: I, V

**Goal**: Combined text + facet filtering with sort.

**Backend deliverables**:
- Migration `0023_listings_search.sql` — `tsvector` column + GIN index covering `title`, `address_text`, `description` (Arabic-aware via `simple` config since Postgres lacks an Arabic dictionary; supplemented with `ILIKE` for Latin).
- View `v_listings_public` exposing only public-readable columns.

**Frontend deliverables**:
- `lib/features/search/` — search bar, filter sheet (purpose, type, governorate/city/area, price range with currency, rooms, baths, area size), sort (newest / price low→high / price high→low).
- Filter state persisted across navigation.

**Acceptance criteria**:
- Combined filters narrow correctly (verified against fixture data).
- Arabic search "شقة" returns Arabic-titled apartment listings.
- Sort options reorder visibly.

**Verification**:
- SQL fixture set + canned query runs.
- Manual: filter combinations.

---

### Phase 15 — Map view
**Spec**: `specs/015-map-view/`
**Principles**: I, III, V, VIII, XII

**Goal**: `flutter_map` view with OSM tiles, marker pins for approved listings, location-visibility honored.

**Backend deliverables**:
- View `v_listings_map` exposing only `(id, latitude, longitude, location_visibility, governorate_id)` filtered to `status = approved` and visibility ∈ (`approximate`, `exact`).
- For `approximate` listings, the view emits a coordinate jittered within the area centroid (so leaks are server-side, not client-side).

**Frontend deliverables**:
- `lib/features/map/` — `MapPage` with `flutter_map`, OSM tile layer, attribution widget, marker clustering, listing-preview popover.
- "Hidden" and "admin_only" listings never appear on the public map.

**Acceptance criteria**:
- Approved listings with `exact` visibility show at exact coords.
- Approved listings with `approximate` visibility show within their area centroid (jittered server-side).
- Tile attribution to OpenStreetMap is visible.
- No Google / Mapbox dependency in `pubspec.lock`.

**Verification**:
- `grep -RE "google_maps|mapbox" pubspec.yaml` returns no matches.
- Manual: change a listing's visibility from exact to hidden → it disappears from map without a code change.

---

### Phase 16 — Contact, inquiries & lead events
**Spec**: `specs/016-contact-inquiries/`
**Principles**: I, III, X
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md) — `inquiries.inquirer_phone` is stored via Supabase Vault; only the receiving publisher and admins can decrypt it.

**Goal**: Users can call, WhatsApp, or send an inquiry to a publisher; every action is tracked as a lead event.

**Backend deliverables**:
- Migrations `0024_create_inquiries.sql` (with Vault-backed `inquirer_phone` per ADR-0001), `0025_create_lead_events.sql`.
- Edge Function `record_lead_event` (validates + inserts).
- Policies.

**Frontend deliverables**:
- Listing details: `Contact` block with three buttons (call / WhatsApp / inquiry form).
- Inquiry form (name, phone, message). Anonymous submissions allowed (sender_user_id null).
- Publisher inbox at `lib/features/inquiries/` with status updates (new → seen → responded → closed).
- Phone reveal triggers `phone_revealed` event; WhatsApp click triggers `whatsapp_clicked`; inquiry submit triggers `inquiry_sent`.

**Acceptance criteria**:
- Submitting an inquiry inserts both an `inquiries` row and an `inquiry_sent` `lead_events` row.
- Publisher sees the inquiry in their inbox; updating status persists.
- Cross-publisher access blocked by RLS.

**Verification**:
- SQL: counts per `event_type` after a manual session.
- RLS smoke: another publisher cannot read the inbox.

---

### Phase 17 — Favorites
**Spec**: `specs/017-favorites/`
**Principles**: I, III

**Goal**: Authenticated users save listings; favorites are private.

**Backend deliverables**:
- Migration `0026_create_favorites.sql`.
- Policies: self-only.

**Frontend deliverables**:
- Heart toggle on listing cards and details.
- `FavoritesPage` with the user's saved listings.

**Acceptance criteria**:
- Adding/removing a favorite persists across sessions.
- User A cannot see User B's favorites.
- Lead event `favorite_added` recorded.

**Verification**:
- SQL: `SELECT * FROM favorites WHERE user_id = '<other>'` from session A returns 0 rows.

---

### Phase 18 — Reports & moderation
**Spec**: `specs/018-reports-moderation/`
**Principles**: I, III, VII

**Goal**: Users report listings; admins resolve reports with an action (approve / hide / mark duplicate / delete) and a moderation-action audit row.

**Backend deliverables**:
- Migrations `0027_create_reports.sql`, `0028_create_moderation_actions.sql`.
- Edge Function `resolve_report` (atomic resolve + linked moderation action + audit log).
- Policies.

**Frontend deliverables**:
- `Report` button on listing details with reason dropdown + optional note.
- `lib/features/admin/reports/` — reports queue with filter and resolve flow.

**Acceptance criteria**:
- A report inserts a `reports` row with status `new`.
- Resolving a report creates a `moderation_actions` row and an `audit_logs` row, and updates the listing if the action requires (e.g., `hide`).
- Reporters see the resolution status on their report.

**Verification**:
- Manual: full report → resolve loop.
- SQL audit-log entry exists.

---

### Phase 19 — Agencies
**Spec**: `specs/019-agencies/`
**Principles**: I, III, IV, VII, VIII
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md) — `agency_verification_requests.id_document_number` and any other private agency-identity fields are stored via Supabase Vault; verification document files remain in Storage with admin-only RLS.

**Goal**: Agencies as multi-user publishing entities with their own profile, members, and verification.

**Backend deliverables**:
- Migrations `0029_create_agencies.sql`, `0030_create_agency_members.sql`, `0031_create_agency_verification_requests.sql` (Vault-backed ID fields per ADR-0001).
- `listings.agency_id` foreign key (already on the column from Phase 10; the FK becomes enforced here).
- Policies: owner / member / admin tiers.
- Audit triggers.

**Frontend deliverables**:
- `lib/features/agency/` — `AgencyProfilePage`, `AgencyMembersPage` (invite by phone, set member role), `AgencyListingsPage`, `AgencyAnalyticsPage` (counters), `AgencyVerificationFlow`.
- Listing form gains an "Publish under agency" switch when the user has an agency-admin role.

**Acceptance criteria**:
- Agency owner submits agency for verification; admin approves → agency profile is public.
- Agency admin invites a member; member can publish under the agency.
- Listing's agency badge appears on cards and details when `agency_id` is set.

**Verification**:
- Manual: create agency, invite, publish.
- SQL: `SELECT a.name, COUNT(l.*) FROM agencies a LEFT JOIN listings l ON l.agency_id = a.id GROUP BY a.id`.

---

### Phase 20 — Admin dashboard
**Spec**: `specs/020-admin-dashboard/`
**Principles**: I, V, VI, VII

**Goal**: A unified admin home consolidating counters, queues, and quick actions.

**Backend deliverables**:
- Materialized view or RPC `admin_dashboard_counts()` returning pending users / pending listings / open reports / new inquiries (last 24h) / active listings.

**Frontend deliverables**:
- `lib/features/admin/dashboard/` with permission-gated tiles (each tile only renders if the user has the relevant permission).
- Sections list: Users, Listings, Locations, Currencies, Reports, Ads, Roles, Permissions, Settings, Audit logs.

**Acceptance criteria**:
- An admin sees only the tiles they have permissions for.
- Counters refresh on pull-to-refresh and on Realtime signals (Phase 22 wires Realtime; Phase 20 uses polling).

**Verification**:
- Manual: log in as admins with different roles, observe tile differences.

---

### Phase 21 — Ads & banners admin module
**Spec**: `specs/021-ads-banners/`
**Principles**: I, III, VII
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md) — if/when this phase introduces third-party ad-network integrations (e.g., Google AdMob server-side keys), those API keys are stored as Supabase Vault secrets and read by Edge Functions. Phase 21 itself ships first-party banners only; external-network keys land only when an explicitly-approved later spec opens them.

**Goal**: Admins create banner ads with placement, schedule, and link target.

**Backend deliverables**:
- Migrations `0032_create_ads.sql`, `0033_create_ad_placements.sql`, `0034_create_ad_impressions.sql`.
- Storage bucket `ads`.
- Edge Function `record_ad_event` (impression / click).
- Policies.

**Frontend deliverables**:
- `lib/features/ads/admin/` — CRUD for ads, placement mapping, schedule pickers.
- `lib/features/ads/widgets/AdSlot.dart` — placement-aware slot widget used on home, search results, listing details.
- Tap on banner records click + opens link.

**Acceptance criteria**:
- Active ad in `home_top_banner` appears at the top of home for non-admin users.
- Schedule end-date hides the ad automatically.
- Impressions logged (sampling allowed for cost reasons).

**Verification**:
- Manual: create ad → see on home.
- SQL: `SELECT COUNT(*) FROM ad_impressions WHERE ad_id = '...' AND kind = 'click'`.

---

### Phase 22 — Push notifications + Supabase Realtime signals
**Spec**: `specs/022-notifications-realtime/`
**Principles**: I, III, XI
**Cross-cutting decisions**: [ADR-0001 — Secrets & PII storage](decisions/0001-secrets-and-pii-storage.md) — the FCM service-account JSON consumed by the fan-out Edge Function is stored as a single Supabase Vault secret (`fcm_service_account`). The Edge Function reads it via the `app_vault_secret()` helper from Phase 4. The service-account JSON MUST NOT be committed to the repository or shipped to the Flutter client.

**Goal**: FCM push for status changes; Supabase Realtime for admin counters.

**Backend deliverables**:
- Migration `0035_create_notification_tokens.sql`.
- Vault secret `fcm_service_account` registered via a migration that calls `vault.create_secret(...)` reading from a CI/local environment variable (per ADR-0001); no plaintext key material in the migration file.
- Edge Functions add a notification fan-out call after key transitions (account approval, listing approval, new inquiry); the FCM-sending function reads the service-account from Vault, not from environment variables baked into the function image.
- Realtime: enable on `listings` (status changes) and `reports` (new + resolved) for admin clients.

**Frontend deliverables**:
- `lib/features/notifications/` — FCM token registration on login, foreground/background handlers, deep links to the relevant page.
- Admin dashboard subscribes to Realtime and re-fetches counts on relevant change events.
- In-app notification center (history of received notifications).

**Acceptance criteria**:
- Approving a user sends them a push "Account approved"; tapping opens the home screen.
- Approving a listing sends the publisher "Listing approved"; opens listing details.
- Admin sees pending-listing counter increment in real time when a publisher submits.
- Sanction risk: confirm Firebase project setup is acceptable; if blocked, document fallback (in-app polling only) in the spec.

**Verification**:
- Manual: two devices — submit on A, observe Realtime counter bump on B (admin).
- Manual: approve on B → push received on A.

---

### Phase 23 — App settings
**Spec**: `specs/023-app-settings/`
**Principles**: I, VII, XII

**Goal**: Admin-tunable defaults: default language, default currency, supported currencies, public-publisher-name default, exact-location default, maintenance mode, support contact, terms/privacy links.

**Backend deliverables**:
- Migration `0036_create_app_settings.sql` + seed defaults.
- Policies: public read for non-sensitive keys; `settings.manage` write.
- Audit triggers.

**Frontend deliverables**:
- `lib/features/settings/admin/` — typed settings editor.
- App-load fetches public settings; `MaintenanceMode` route guard shows a maintenance screen when enabled.

**Acceptance criteria**:
- Toggling maintenance mode in admin shows the maintenance screen on all clients within 1 minute (next app foreground).
- Changing default display currency affects new users only (existing users keep their preference).

**Verification**:
- Manual: toggle maintenance, observe second device.
- SQL: `SELECT * FROM app_settings`.

---

### Phase 24 — Release polish, distribution, QA pass
**Spec**: `specs/024-release-polish/`
**Principles**: V, VI, X, XI

**Goal**: Production-grade build, distribution channels live, golden-path QA pass complete.

**Deliverables**:
- App icon + splash for both light/dark.
- Crash-reporting tool decision recorded in spec (Sentry self-hosted candidate). Wired in `lib/core/logging/`.
- Versioning bump to `1.0.0`.
- Direct-APK distribution: signed release APK uploaded to project website + Telegram channel, with a manual update prompt in-app (version-check on cold start).
- Play Store internal testing track configured.
- Full QA pass against the golden-path checklist:
  1. Register → admin approves → publish → admin approves → public view → inquiry.
  2. Anonymous browse + filter + map.
  3. Admin reports queue resolution.
  4. Super-admin role create + assign + revoke.
  5. Currency switch + exchange-rate update.
  6. Maintenance mode + recovery.
- Release notes in `docs/release/v1.0.0.md`.

**Acceptance criteria**:
- Signed APK boots on a fresh Android device.
- Crash-reporting captures a forced exception in dev build.
- All six golden paths pass.

**Verification**:
- Install signed APK on a fresh device; run through checklist.
- Inspect crash dashboard for the forced test crash.

---

## 11. Definition of Done (per phase)

A phase is "done" only when:

1. `specs/<###-name>/` contains `spec.md`, `plan.md`, `data-model.md` (if data introduced), `contracts/` (if APIs introduced), and `tasks.md` (Principle I).
2. All Supabase changes are checked-in migration / policy / function files (Principle II).
3. Domain layer of every touched feature has zero `package:supabase_flutter` imports; no widget calls Supabase directly (Principles IV, IX).
4. New user-visible strings exist in both `app_ar.arb` and `app_en.arb`; widgets render correctly in RTL + LTR + light + dark (Principles V, VI).
5. Sensitive admin actions write `audit_logs` rows (Principle VII).
6. RLS enabled on every new table with policies in `supabase/policies/`; an RLS smoke test exists (Principle III).
7. Acceptance criteria in `tasks.md` are demonstrably met — verification steps executed and recorded (Principle X).
8. No iOS or Web-only code added; `pubspec.yaml` carries no non-Android-only plugins (Principle XI).
9. Every assumption made (default behavior chosen for an ambiguous requirement) is recorded in the spec's `## Assumptions` section (Principle XII).
10. Hooks `before_<phase>` and `after_<phase>` from `.specify/extensions.yml` were honored (auto-commit checkpoints).
11. PR description references the phase number and the constitution principles enforced.
12. Reviewer (human or `/review`) signed off on principle compliance, not just code correctness.
13. Localization gate passed: no untranslated literals, RTL rendering verified.
14. Theme gate passed: no hardcoded colors / sizes / paddings in feature code.
15. The `before_implement` hook was run on a clean tree; the `after_implement` hook committed the result.

---

## 12. Testing posture

**Mandatory** for every relevant phase:

- Unit tests for domain use cases that hold meaningful logic: currency conversion (Phase 9), permission checks (Phase 6, 7), listing validation (Phase 10), location-visibility logic (Phases 8, 15), money formatting (Phase 9).
- RLS smoke tests for every new permission-gated table (Phases 4, 5, 6, 10–24 as applicable).
- Integration tests for the four golden paths after Phase 12: register → approve → publish → admin-approve → public view → inquiry. Re-run after Phases 19, 21, 22.
- Widget tests for cross-locale + cross-direction rendering of `ListingCard` (Phase 2/3) and listing form (Phase 10).

**Recommended** but not blocking:

- Widget tests for login form, admin approval buttons, filter sheet.
- Edge Function tests via `supabase functions serve` + test harness.

**Not required for v1**:

- Full E2E suite across all routes.
- Performance benchmarks (defer to release polish if user reports).
- Accessibility audit (deferred to release-polish phase).

Test files live under `test/` (unit + widget) and `integration_test/` (Flutter integration tests). Supabase RLS smoke tests live under `supabase/tests/` and run via `supabase test db`.

---

## 13. AI-agent workflow

The project uses three classes of AI assistants. Each has a defined responsibility surface; spec files note which agent is best for each task type.

**Claude Code** (this assistant):
- Architecture, repository structure, Supabase migrations, RLS policies, Edge Functions.
- Flutter `domain/` and `data/` layers.
- Security-sensitive code (auth flow, permission checks, audit logging).
- Refactoring and cross-cutting cleanups.

**GLM 4.7**:
- Review of Claude's work — RLS audits, edge-case discovery, naming and Arabic-copy quality.
- SQL review for index plans and constraint correctness.
- Architecture-consistency review across features.

**AntiGravity / Gemini 3 Pro**:
- UI implementation, widget polish, Figma-to-Flutter conversion, RTL/LTR visual checks, dark/light theme polish.
- Not authorized to make schema or RLS decisions unsupervised.

**Discipline rules (constitution Principle X)**:

- Every agent reads `.specify/memory/constitution.md`, `docs/IMPLEMENTATION_PLAN.md`, and the relevant `specs/<###>/` folder before writing code.
- Every backend change is a checked-in migration file, regardless of which agent wrote it. Studio-only changes are reverted.
- When implementation reveals that real behavior diverges from the spec, the agent updates the spec/plan/data-model/contracts in the same PR — drift is a defect.
- All agents respect the `before_*` / `after_*` hooks declared in `.specify/extensions.yml` (mandatory git initialize / feature branch creation, optional auto-commits).

---

## 14. Distribution & release

**Channel A — Direct APK** (primary for Syrian users):
- Signed release APK uploaded to project website (when available) and to a Telegram channel.
- App performs a version check on cold start; if a newer version is available on the manifest URL, prompts the user to download.
- The manifest URL is itself a JSON file on a CDN / origin server; if Cloudflare / Google CDNs are inaccessible from Syria, the host must be a directly reachable origin (verified during Phase 24).

**Channel B — Play Store internal testing track** (QA only):
- Used for QA team and stakeholder review.
- Not advertised to end users.

**Versioning**:
- `1.<phase>.<patch>` — e.g., after Phase 10 ships, the build is `1.10.0`. Patch revs within a phase are `1.10.1`, `1.10.2`, etc.
- v1.0.0 is reserved for the Phase 24 final release.

**Crash reporting**:
- Decision deferred to Phase 24 spec. Sentry (self-hosted or EU instance) is the leading candidate. Firebase Crashlytics flagged as sanctions-risky; do not adopt without legal review.

---

## 15. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **RLS complexity** — wrong policy leaks private data | RLS-first per table: write policy + smoke test before exposing the table to clients. Reviewer signs off on Principle III for every PR. |
| **Map privacy leak** — listings with `approximate` visibility expose true coords | Server-side jitter in the `v_listings_map` view; client never sees true coords for non-`exact` listings. |
| **Multi-currency confusion** — converted price overwrites entered price | Schema invariant: `listing_prices` rows are immutable on amount + currency; conversion is display-only. Linter / code-review check on any UPDATE of `listing_prices.amount`. |
| **Agent backend drift** — AI changes Supabase via Studio without a migration | PR review compares `supabase/migrations/` against the live DB schema (manual or via `supabase db diff`). Drift is rejected. |
| **Distribution risk** — Syrian users can't reach Play Store | Direct APK + manual update prompt + Telegram fallback. Verified in Phase 24. |
| **Image storage cost** — large listings + 10 images each | Client-side downscale to 1920px, JPEG quality 80; 10-image cap enforced server-side. |
| **Sanction / region blockers** — Google Maps / Mapbox / Twilio / Crashlytics inaccessible or risky | None of these adopted: `flutter_map` + OSM, no SMS in v1, Sentry instead of Crashlytics. Decisions logged here. |
| **Performance on cheap Android devices** — cold start, list scroll | Cold-start budget < 3s; image-list pagination; cached_network_image with downscaling; no eager Supabase realtime subscriptions on home. |
| **Arabic search quality** — Postgres lacks Arabic full-text dictionary | v1 uses `simple` config tsvector + `ILIKE` fallback; revisit with `arabic_lemmatizer` extension if quality is poor. |
| **Account-recovery dead end** — user without email forgets password | Admin can issue a temporary password via super-admin UI; documented support flow in Phase 24 release notes. |

---

## 16. Open questions

These are intentionally deferred to the spec that resolves them:

| Question | Resolved by |
|---|---|
| Which Figma direction (Luxury vs Modern Tech) wins? | Phase 2 spec (decision recorded in `docs/design/decision.md`). |
| Watermark style, opacity, and corner placement? | Phase 11 spec. |
| Final permission catalog (refinement to §9.1)? | Phase 6 spec. |
| Crash reporting tool (Sentry self-hosted vs EU vs alternative)? | Phase 24 spec. |
| Notification channel taxonomy (importance levels, sound, vibration)? | Phase 22 spec. |
| Agency verification evidence requirements (which documents)? | Phase 19 spec. |
| Maintenance-mode bypass for super-admin? | Phase 23 spec. |

---

## 17. Key revisions vs the ChatGPT draft

For traceability — this plan deliberately diverges from the ChatGPT draft on the following points:

1. **Auth** — switched from email+password to **phone+password with synthetic email**, with admin approval as the phone-verification gate. Reason: most Syrian users don't have or know an email; SMS-OTP is unreliable from international SMS providers serving Syria.
2. **Map** — locked to **`flutter_map` + OpenStreetMap**. ChatGPT left it open ("Google Maps or Mapbox"); both have billing / sanctions risk for a Syria-based project.
3. **Routing / DI / Localization** — locked to **`go_router` + `get_it`/`injectable` + ARB/intl**. ChatGPT left "or" alternatives. ARB explicitly overrides ChatGPT's `assets/translations/*.json` suggestion (Flutter's native ARB tooling is better).
4. **Project framing** — removed the MVP-cut framing; this is **full v1, phased**. All four borderline modules (Agencies, Super-admin role UI, Ads/banners, Push+Realtime) are IN v1, sequenced into Phases 19, 7, 21, 22 respectively.
5. **Build order** — moved super-admin role UI to Phase 7 (right after permissions) so dynamic admin behavior is real before any approval flow ships. Agencies moved to Phase 19 (after individual-publisher flows are stable). Ads, notifications, settings sequenced into Phases 21–23 before release polish.
6. **Supabase folder** — aligned with **Supabase CLI conventions** (`supabase/migrations/`, `supabase/functions/`, `supabase/seed.sql`) plus mandated subfolders (`policies/`, `storage/`, `docs/`). ChatGPT proposed a different layout that doesn't match `supabase` CLI.
7. **Constitution cross-reference** — every phase cites the principles it enforces (§3 + per-phase headers).
8. **Distribution realism** — APK-first for Syria + Play Store internal track. ChatGPT plan didn't address distribution.
9. **Region-sensitive choices flagged** — Crashlytics, Mapbox, Twilio explicitly called out as sanctions-risky with alternatives proposed.
10. **Watermark & video** — locked to **client-side watermark, image cap 10, video via external link primarily, small uploads up to 30 MB**. ChatGPT proposed similar but ambiguously; numbers pinned here.

---

`Plan version: 1.0 | Aligned with constitution v1.0.0 | Ratified: 2026-04-27`
