# Implementation Plan: Supabase Foundation

**Branch**: `004-supabase-foundation` | **Date**: 2026-05-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-supabase-foundation/spec.md`

## Summary

Stand up the source-controlled backend skeleton that every later phase depends on: ship six SQL migrations under `supabase/migrations/` plus three policy files under `supabase/policies/` that together define (a) every §6.3 status enum, (b) the `profiles` table with the `current_user_is_admin()` placeholder helper, the `enforce_profile_status_admin_only()` BEFORE-UPDATE trigger that delivers FR-006's column-level enforcement, and the `set_updated_at()` helper, (c) the `user_preferences` self-only table plus the auto-provision trigger that creates one `profiles` row AND one `user_preferences` row atomically per `auth.users` insert, (d) the `audit_logs` table plus the reusable `log_audit()` trigger function (`TG_ARGV[0]`=action, `TG_ARGV[1]`=column-list, `TG_ARGV[2]`=PK column name defaulting to `'id'`) plus a concrete trigger on `profiles` status fields with `'user_id'` as the PK arg, (e) RLS-enabled-by-default with self-only and admin-gated policies, and (f) the `pgsodium` + Supabase Vault scaffolding with the `app_vault_secret(name)` helper as forward-prep for Phases 5/16/19/21/22 per ADR-0001 — without storing any actual secret. Apply every migration directly to the **remote** Supabase project via the Supabase MCP `apply_migration` tool (per Session 2026-05-06 Q5 clarification: there is no local Supabase setup in Phase 4). Migration filenames follow Supabase's standard `<14-digit-timestamp>_<name>.sql` convention. Ship a tiny Flutter data-layer footprint: domain entities `Profile` and `UserPreferences` under `lib/shared/domain/entities/`, Dart enum mirrors for the account/publisher statuses under `lib/shared/domain/value_objects/`, and the real `authStateChanges()` subscription in `SupabaseClientWrapper` (replacing the existing UnimplementedError stub) using `StreamTransformer.fromHandlers` for proper error propagation.

**Technical approach**: Phase 1 already vendored `supabase_flutter` and declared `SupabaseClientWrapper.authStateChanges()` in the interface, but the impl currently `throw`s `UnimplementedError('wired up in Phase 5')`. Phase 4's FR-016 reassigns that wiring **forward** to this phase: the impl's `authStateChanges()` becomes a real subscription that maps `supabase.AuthChangeEvent` values to the in-house `AuthState` enum (`signedIn`, `signedOut`, `error`) using `StreamTransformer.fromHandlers` for the error mapping (NOT `Stream.handleError`, whose callback is fire-and-forget and would silently swallow errors). The impl also bumps the `selectRows()` UnimplementedError comment from "Phase 4" to "Phase 5" — the spec does not require real reads in this phase, so the stub stays but its label is corrected. The bulk of the new work is SQL: six migrations checked into `supabase/migrations/`, named `<timestamp>_<title>.sql` per Supabase's 14-digit-timestamp convention, applied in numeric order via Supabase MCP `apply_migration`. Tasks prescribe specific synthetic timestamps (`20260506120001` through `20260506120006`) so the implementer's filenames match the verify queries. Each migration uses idempotent constructs (DO/EXCEPTION wrappers around `CREATE TYPE`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS … CREATE TRIGGER …`) so re-application is safe. The auto-provision trigger fires on `AFTER INSERT` to `auth.users` and inserts into both `profiles` and `user_preferences` in a single function body with `ON CONFLICT (user_id) DO NOTHING` on each target — covering the signup-race edge case. The `log_audit()` function is **fully table-agnostic**: it reads `TG_OP`, `OLD`, `NEW`, plus three `TG_ARGV` strings (`[0]` action key, `[1]` column list or `'*'`, `[2]` PK column name defaulting to `'id'`); the body extracts target_id via `to_jsonb(NEW or OLD) ->> COALESCE(TG_ARGV[2], 'id')` and computes before/after JSONB without referencing any column by name in the function body. Phase 4's profiles trigger passes `'user_id'` as the third arg. The "admin" predicate is `current_user_is_admin()` — a SQL function that returns `FALSE` in Phase 4 and is replaced (one definition, not many policy files) by Phase 5 (interim `is_admin` flag) and Phase 6 (role/permission system); ships in `20260506120002_create_profiles.sql` (moved from the original `0005` plan because the `enforce_profile_status_admin_only()` trigger in `0002` calls it). The R-12 enforce-status trigger raises `42501 insufficient_privilege` if a non-privileged, non-admin session attempts to change status fields; Supabase MCP `execute_sql` (running as `postgres`) bypasses the check via the privileged-role list, so quickstart Step 9 can fire the AFTER audit trigger. The Vault scaffolding migration enables `pgsodium` (the existing Phase-1 `00000000000000_init_extensions.sql` enables `pgcrypto` and `uuid-ossp`; Phase 4 builds on top) and creates `app_vault_secret(name TEXT) RETURNS TEXT` that wraps the Supabase Vault API and returns `NULL` on missing-name without raising. Per the durable session feedback, **no new automated tests are added in this phase**; verification is manual SQL inspection against the remote project via Supabase MCP `execute_sql`, executed against the recipe in `quickstart.md`. Cross-user RLS verifications use multi-statement blocks wrapped in a single `execute_sql` call (BEGIN; set_config; SET LOCAL ROLE; verify; ROLLBACK) because Supabase MCP runs each call in a fresh session — `SET LOCAL` does not persist across calls.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the data-layer additions; PostgreSQL (Supabase remote, current platform default — Postgres 15+) for the SQL migrations. Same Flutter + Dart base as Phases 1–3.

**Primary Dependencies**: `supabase_flutter` (already in `pubspec.yaml` from Phase 1), `equatable` (already in `pubspec.yaml` — value-equality for the new domain entities; the project does NOT use Freezed). No new runtime packages, no new dev dependencies. **Tooling**: Supabase MCP server (`mcp__plugin_supabase_supabase__apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) is the canonical migration-application and inspection mechanism. `pgsodium` and Supabase Vault are Postgres-side dependencies enabled via migration; no client-side Vault dependency in Phase 4.

**Storage**: Remote Supabase Postgres project. Three new tables (`profiles`, `user_preferences`, `audit_logs`); eight `CREATE TYPE` statements (every §6.3 enum); one trigger function (`log_audit()`); one helper function (`current_user_is_admin()`); one helper function (`app_vault_secret()`); one auto-provision trigger on `auth.users`; one concrete audit trigger on `profiles`. The `pgsodium` extension and the Supabase Vault `vault` schema are enabled but contain zero application-level secrets at end of Phase 4. There is no local Supabase setup in this phase (Q5 clarification, Session 2026-05-06).

**Testing**: **Manual SQL inspection against the remote Supabase project only.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, this phase introduces NO new automated tests of any kind — no unit, widget, integration, golden, runtime, or `supabase test db` tests, and no new CI step that runs tests. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors. The `quickstart.md` recipe walks every FR + every SC verification step as Supabase MCP `execute_sql` calls reviewers can re-run on the remote project. Existing Phase 1/2/3 tests remain in source unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter app side (Constitution XI); Supabase remote Postgres for the backend side. iOS, Web, desktop NOT a target.

**Project Type**: Mobile app + backend. Phase 4 is the first phase that adds backend SQL artifacts to the source-controlled tree; the Flutter footprint is intentionally tiny because Phase 1 already shipped the auth-state listener and the Supabase client wrapper, and Phase 5 owns the actual auth flow.

**Performance Goals**:
- No latency or throughput targets in Phase 4. RLS overhead, trigger overhead, and Vault helper overhead are negligible at MVP scale (tens of users); concrete performance targets land with the Phase 24 release-polish performance pass per the implementation plan and per the spec's coverage-summary deferred note.
- The auto-provision trigger MUST complete in a single round-trip — no synchronous external calls, no `pg_notify`, no chained side-effects beyond the two table inserts.

**Constraints**:
- Constitution II (Source-Controlled Backend) is the binding rule: every backend artifact lives as a checked-in `.sql` file. No Studio-only edits (FR-014).
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): RLS enabled on every Phase 4 table; no public-read column; no client write to `audit_logs`; service-role keys never shipped to the Flutter client.
- Migrations are applied to the **remote** Supabase project via Supabase MCP `apply_migration`; there is no local Supabase setup (Q5 clarification).
- Migrations MUST be safe to re-apply (Supabase migration tracker handles this for normal flows; migration bodies use idempotent constructs as a belt-and-suspenders defense).
- The `log_audit()` function MUST be reusable by later phases without modification (FR-009).
- The "admin" predicate MUST be a single helper Phase 5 / Phase 6 swap implementations of — touching policy files in those phases is forbidden.
- Phase 4 stores **zero** application-level Vault secrets (FR-013); the cabinet is empty by design.
- The Flutter `domain/` layer MUST NOT import `package:supabase_flutter` (Constitution IX, FR-017).
- All §6.3 enums are pre-declared in `20260506120001_init_enums.sql` even when their owning tables land in later phases (Q3 clarification).
- `profiles` does NOT carry `preferred_language` or `preferred_currency` columns; `user_preferences.locale` and `user_preferences.display_currency` are canonical (Q2 clarification).
- A signed-up user has BOTH a `profiles` row AND a `user_preferences` row at first read — the auto-provision trigger creates them atomically (Q1 clarification).
- `profiles.username` and `profiles.phone` use plain `UNIQUE` semantics with NULL-distinct (Postgres default); no partial index, no `NULLS NOT DISTINCT` (Q4 clarification).

**Scale/Scope**:
- 6 new SQL migration files under `supabase/migrations/` named with synthetic timestamps `20260506120001_init_enums.sql` through `20260506120006_enable_vault.sql` (Supabase's standard `<14-digit-timestamp>_<name>.sql` convention; the timestamps are synthetic-monotonic so the migration tracker orders them after Phase 1's `00000000000000_init_extensions.sql`).
- 3 new policy files under `supabase/policies/` (`profiles_policies.sql`, `user_preferences_policies.sql`, `audit_logs_policies.sql`). The choice to keep policies in a separate tree from the table-creation migrations matches the implementation plan's deliverables list (§5.4 of `IMPLEMENTATION_PLAN.md`); the Phase 4 task list bundles each policy file's content into the same `apply_migration` call as the corresponding table's RLS-enable migration so the remote project sees `ENABLE RLS` and the matching policies in one atomic step. (Locking the bundling shape is research item R-02.)
- 2 new doc files: `supabase/docs/profiles.md`, `supabase/docs/audit_logs.md` (FR-018).
- 8 `CREATE TYPE … AS ENUM` statements covering account/publisher, listing, inquiry, report, listing-purpose, property-type, location-visibility, and report-reason value sets (FR-011).
- 3 new Flutter domain files under `lib/shared/domain/entities/` and `lib/shared/domain/value_objects/`: `profile.dart`, `user_preferences.dart`, and the Dart enum mirrors `account_status.dart` + `publisher_status.dart`.
- 0 new packages in `pubspec.yaml`.
- 0 new `lib/features/` folders (Phase 4 is shared infrastructure only).
- 0 new tests (durable no-new-tests rule).
- 0 changes to `.github/workflows/ci.yml` (no new tooling needs CI; SQL is validated at `apply_migration` time on the remote).

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-clarify` Session 2026-05-06 closed five high-impact ambiguities (preferences provisioning timing, profiles-vs-user_preferences locus, full §6.3 enum scope, NULL+UNIQUE semantics, deployment scope). No implementation has begun. |
| II. Source-Controlled Backend | **Pass — this is the principle this phase realizes.** | Every Phase 4 backend artifact lives as a checked-in `.sql` file under `supabase/migrations/`, `supabase/policies/`, or `supabase/docs/`. The remote Supabase project is one applied instance of the repo; FR-014 forbids Studio-only edits and treats them as defects. The Q5 clarification explicitly preserves the source-of-truth invariant even though there is no local Supabase setup — re-applying the same migrations to a different Supabase project reproduces the schema exactly (US 1 acceptance scenario 5). |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS enabled on `profiles`, `user_preferences`, `audit_logs` (FR-005). Self-only on `user_preferences` (FR-007). No client writes on `audit_logs` (FR-008). Admin reads gated by the placeholder predicate that evaluates to `false` for every caller in Phase 4 (Assumptions). Service-role keys never enter the Flutter client (existing Phase 1 invariant — `lib/core/config/` reads only the anon key). Vault scaffolding lays the groundwork for ADR-0001's encrypted-PII strategy without storing any secret yet (FR-012, FR-013). |
| IV. Clean Architecture Flutter | **Pass** | Phase 4's Flutter additions live in `lib/shared/domain/entities/` and `lib/shared/domain/value_objects/` — pure domain, no widgets, no data-source coupling. The `Profile` and `UserPreferences` entities are provider-agnostic (FR-017). The auth-state listener (`SupabaseClientWrapper.authStateChanges()`) is already in `lib/core/network/` from Phase 1 and exposes a domain-shaped `Stream<AuthState>` — Phase 5 consumes it without ever importing `package:supabase_flutter`. |
| V. Arabic-First Localization | **Pass (N/A in scope)** | Phase 4 introduces no user-visible strings. The `user_preferences.locale` default is `'ar'` (FR-019) — preserving Phase 3's Arabic-first runtime — but no UI lives in this phase. Any future admin tooling that surfaces audit-log content (Phase 7+) carries its own translation work. |
| VI. Theme System & Design Tokens | **Pass (N/A)** | No widgets, no tokens. Phase 2's design-system layer is untouched. |
| VII. Dynamic Roles & Permissions | **Pass — explicitly forward-prepped.** | Phase 4 ships the `current_user_is_admin()` placeholder helper (Assumptions) that Phase 5 (interim flag) and Phase 6 (role/permission system) replace. The `log_audit()` reusable trigger function (FR-009) is the audit infrastructure every sensitive action across later phases will reuse — Constitution VII's "audit-log entry capturing actor, action, target, timestamp, before/after state" invariant is established here, generically, before any specific admin action is implemented. |
| VIII. Approval Workflow & Publisher Identity | **Pass — explicitly forward-prepped.** | Account/publisher statuses default to `pending` in the auto-provision trigger (FR-020). The Vault-backed columns for `legal_name`, `national_id`, `private_contact_methods` per ADR-0001 are NOT introduced here — Phase 5 adds them on top of the Vault scaffolding Phase 4 lays down. |
| IX. Future Backend Portability | **Pass** | The `Profile` and `UserPreferences` domain entities introduced in this phase MUST NOT import `package:supabase_flutter`. The `data/`-layer mapping from Supabase rows to domain entities is Phase 5's concern; Phase 4 ships only the domain shapes. The `SupabaseClientWrapper.authStateChanges()` interface is already provider-agnostic — its return type is the in-house `Stream<AuthState>` enum, not Supabase's `AuthState`. |
| X. Testable AI Workflow | **Pass — Justified.** | Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql`/`list_tables`/`list_migrations` calls — both of which satisfy Principle X's "command an agent can run" letter. The constitution explicitly permits "a SQL query with expected output" as an acceptance step. `quickstart.md` lists the per-FR verifications as runnable Supabase MCP calls. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only; no platform-conditional code. The remote Supabase backend is platform-neutral. |
| XII. No Hidden Product Decisions | **Pass** | All five clarifications captured in `spec.md` `## Clarifications`. The deliberate divergence from §6.3's `profiles.preferred_language`/`preferred_currency` columns (Q2) is recorded in both `spec.md` Assumptions and this plan's Constraints. The deliberate "no local Supabase" choice (Q5) is recorded in both `spec.md` Assumptions and this plan's Technical Context, with the trade-off explicitly noted. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-supabase-foundation/
├── plan.md                # This file
├── research.md            # Phase 0 — locked tech decisions (migration filenames + ordering, enum-vs-CHECK, log_audit signature, admin-predicate helper, pgsodium baseline, auto-provision trigger shape, Vault helper signature, RLS bundling)
├── data-model.md          # Phase 1 — Profile, UserPreferences, AuditLog, the 8 §6.3 enums, log_audit() function, current_user_is_admin() helper, app_vault_secret() helper, auto-provision trigger
├── quickstart.md          # Phase 1 — reviewer/AI agent end-to-end manual verification recipe via Supabase MCP execute_sql + Flutter device launch
├── contracts/             # Phase 1 — interface contracts later phases consume
│   ├── auto-provision-trigger.md
│   ├── log-audit-trigger-fn.md
│   ├── admin-predicate.md
│   ├── vault-helper.md
│   ├── profile-entity.md
│   └── user-preferences-entity.md
├── checklists/
│   └── requirements.md    # From /speckit-specify (validated)
├── spec.md                # From /speckit-specify (clarified Session 2026-05-06)
└── tasks.md               # Created by /speckit-tasks (NOT by /speckit-plan)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                           # (existing) NO CHANGE.
├── seed.sql                                              # (existing) NO CHANGE in Phase 4.
├── migrations/
│   ├── 00000000000000_init_extensions.sql                # (existing — Phase 1) Enables pgcrypto + uuid-ossp. NO CHANGE; Phase 4 builds on top.
│   ├── 20260506120001_init_enums.sql                     # NEW — every §6.3 status enum as CREATE TYPE … AS ENUM (account/publisher, listing, inquiry, report, listing-purpose, property-type, location-visibility, report-reason). Idempotent via DO/EXCEPTION block guards per R-03.
│   ├── 20260506120002_create_profiles.sql                # NEW — profiles table (PK = user_id FK auth.users(id) ON DELETE CASCADE; full_name, username UNIQUE, phone UNIQUE, email, avatar_url, account_status, publisher_status, created_at NOT NULL DEFAULT now(), updated_at NOT NULL DEFAULT now()). NO preferred_language / preferred_currency (Q2). Plus: set_updated_at() helper, trg_profiles_set_updated_at trigger, current_user_is_admin() placeholder helper (R-05; moved here from 0005), enforce_profile_status_admin_only() function and trg_profiles_enforce_status_admin_only trigger (R-12, FR-006 column-level enforcement).
│   ├── 20260506120003_create_user_preferences.sql        # NEW — user_preferences table (user_id PK + FK to auth.users; locale CHECK ('ar','en') DEFAULT 'ar', theme_mode CHECK ('system','light','dark') DEFAULT 'system', display_currency DEFAULT 'SYP', notifications_enabled DEFAULT TRUE, timestamps NOT NULL DEFAULT now()). Plus: trg_user_preferences_set_updated_at trigger (reuses set_updated_at), handle_new_auth_user() function (R-07), trg_auth_users_handle_new trigger on auth.users (FR-004, Q1).
│   ├── 20260506120004_create_audit_logs.sql              # NEW — audit_logs table (id UUID PK DEFAULT gen_random_uuid() per R-11, actor_user_id NULL FK auth.users(id) ON DELETE SET NULL, action TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT, before_state JSONB, after_state JSONB, ip INET, user_agent TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()). Plus: log_audit() reusable trigger function with TG_ARGV[0]/[1]/[2] convention (R-04, FR-009), trg_profiles_audit_status concrete trigger calling log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id') (FR-010).
│   ├── 20260506120005_enable_rls_default.sql             # NEW — ALTER TABLE … ENABLE ROW LEVEL SECURITY on all three tables (FR-005) + apply policies inline from supabase/policies/*.sql each wrapped with DROP POLICY IF EXISTS … CREATE POLICY … (R-02 bundling). Note: current_user_is_admin() is NOT created here (it shipped in 0002).
│   └── 20260506120006_enable_vault.sql                   # NEW — CREATE EXTENSION IF NOT EXISTS pgsodium (R-08); CREATE OR REPLACE FUNCTION app_vault_secret(p_name TEXT) RETURNS TEXT (R-06, FR-012). Header comment documents forward-prep intent for Phases 5/16/19/21/22 (FR-013, ADR-0001).
├── policies/                                             # NEW directory (sibling of migrations/, source-of-truth for policy SQL).
│   ├── profiles_policies.sql                             # NEW — self read/write on non-status fields; admin (placeholder) read/write on status fields (FR-006).
│   ├── user_preferences_policies.sql                     # NEW — self-only read/write (FR-007).
│   └── audit_logs_policies.sql                           # NEW — admin (placeholder) read; no client write (FR-008).
└── docs/                                                 # NEW directory (FR-018).
    ├── profiles.md                                       # NEW — purpose, columns, defaults, RLS, audit fields covered, the deliberate omission of preferred_language/preferred_currency.
    └── audit_logs.md                                     # NEW — purpose, columns, the log_audit() function contract, how later phases attach it to new tables.

lib/
├── main.dart                                             # (existing) NO CHANGE.
├── app.dart                                              # (existing) NO CHANGE.
├── core/
│   ├── config/                                           # (existing) NO CHANGE — already reads SUPABASE_URL + SUPABASE_ANON_KEY from --dart-define.
│   └── network/
│       ├── supabase_client_wrapper.dart                  # (existing — Phase 1) Interface already declares authStateChanges() returning Stream<AuthState>. NO CHANGE; Phase 4 only changes the impl.
│       ├── supabase_client_wrapper_impl.dart             # UPDATE — replace the `authStateChanges()` UnimplementedError with a real `supabase.Supabase.instance.client.auth.onAuthStateChange.map(...)` subscription that emits the in-house `AuthState` enum (Phase 1 → `signedIn` / `signedOut` / `error`). Also fix the stale `selectRows()` UnimplementedError comment from 'Phase 4' to 'Phase 5'. Locked in research R-09.
│       └── types/
│           ├── auth_state.dart                           # (existing) Already enum AuthState { signedOut, signedIn, error }. NO CHANGE.
│           └── realtime_channel.dart                     # (existing) NO CHANGE.
└── shared/
    ├── presentation/                                     # (existing — Phase 2 widgets) NO CHANGE.
    └── domain/                                           # NEW directory (Phase 4 introduces the shared domain layer).
        ├── entities/
        │   ├── profile.dart                              # NEW — Equatable-based Profile entity mirroring the profiles columns relevant to consumers (user_id, full_name, username, phone, email, avatar_url, account_status, publisher_status, created_at, updated_at). Hand-written copyWith + props. NO Supabase imports, NO Freezed (FR-017, Constitution IX).
        │   └── user_preferences.dart                     # NEW — Equatable-based UserPreferences entity (user_id, locale, theme_mode, display_currency, notifications_enabled). Hand-written copyWith + props. NO Supabase imports.
        └── value_objects/
            ├── account_status.dart                       # NEW — Dart enum mirror of the SQL account-status enum. Values: pending, approved, rejected, suspended, deleted.
            └── publisher_status.dart                     # NEW — Dart enum mirror of the SQL publisher-status enum (same values as account-status per §6.3).

# Out of scope — explicitly NOT created in this phase:
# - lib/features/auth/**            — Phase 5 owns the auth flow + auth_repository/datasource.
# - lib/features/profile/**         — Phase 5 owns the profile view/edit pages.
# - lib/data/**                     — Phase 4 introduces no data-source code; Phase 5 introduces SupabaseAuthDataSource.
# - test/**                         — durable no-new-tests rule. Existing Phase 1/2/3 tests remain unchanged.
# - .github/workflows/ci.yml        — no new CI step. Supabase MCP apply_migration validates SQL on the remote at application time; the existing Phase 3 lint steps remain.
# - supabase/functions/**           — no Edge Functions in Phase 4. Phase 7 ships the first one (mutate_role).
# - supabase/storage/**             — no Storage buckets in Phase 4.
# - profiles.legal_name / national_id / private_contact_methods — Phase 5's 0008_profiles_vault_columns.sql adds these on top of Phase 4's Vault scaffolding (ADR-0001).
# - account_approval_requests       — Phase 5's 0007 migration, not Phase 4.
# - roles / permissions / role_permissions / user_roles — Phase 6.
```

**Structure Decision**: The Phase 4 footprint is split between a new SQL tree under `supabase/` (six migrations, three policy files, two doc files) and a small addition under `lib/shared/domain/` (two entities + two value-object enums) plus one targeted edit to the existing `lib/core/network/supabase_client_wrapper_impl.dart` (replacing the `authStateChanges()` UnimplementedError with a real subscription). No `lib/features/` folder is touched — Phase 4 is shared infrastructure. Constitution IX is enforced by the directory layout: domain entities live under `lib/shared/domain/`, the Supabase types stay confined to `lib/core/network/types/` (already Supabase-free) and to the impl file under `lib/core/network/`, which is the only file in Phase 4 that imports `package:supabase_flutter`. Migrations are applied to the **remote** Supabase project via Supabase MCP `apply_migration` (per Q5 clarification); there is no local Supabase setup in this phase.

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
