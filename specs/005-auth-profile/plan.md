# Implementation Plan: Auth & Profile

**Branch**: `005-auth-profile` | **Date**: 2026-05-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/005-auth-profile/spec.md`

## Summary

Build the entire authentication + profile + admin-approval slice on top of Phase 4's source-controlled Supabase backend. Concretely: ship five SQL migrations under `supabase/migrations/` (account_approval_requests + auto-population trigger; `profiles.is_admin` column + extended status-mutation guard; admin-predicate body swap; Vault PII helper functions; concrete audit trigger on `account_approval_requests`), one new policy file (`supabase/policies/account_approval_requests_policies.sql`), one new Edge Function (`supabase/functions/request_password_reset/index.ts`), one supabase doc file (`supabase/docs/account_approval_requests.md`), three new Flutter feature folders (`lib/features/auth/`, `lib/features/profile/`, `lib/features/onboarding/`) plus the first admin-feature folder (`lib/features/admin/account_approvals/`), and one shared value object (`lib/shared/domain/value_objects/phone_number.dart`). Apply every migration to the **remote** Supabase project via Supabase MCP `apply_migration` (per Phase 4's R-01 — there is no local Supabase setup); deploy the Edge Function via Supabase MCP `deploy_edge_function`. Verification is manual SQL inspection via Supabase MCP `execute_sql` plus end-to-end manual UI verification on the reference Infinix Note 8 device, both walked by `quickstart.md`.

**Technical approach**: The five clarifications closed in the Session 2026-05-10 clarify pass (Vault mechanism = `vault.secrets` per-user-per-field; `private_contact_methods` shape = JSON object with allowlisted typed keys; password policy = 8 chars no-complexity; admin-queue scope = pending-only with approve/reject; locale source after first sign-in = server wins) collapse the entire solution space onto one concrete design with no remaining "implementer's choice" hedges. The auth flow uses Supabase Auth's email/password primitives — the synthetic email `<E.164>@alnujom.local` is constructed in a single helper inside the auth feature's data layer (`lib/features/auth/data/internal/synthetic_email.dart`, package-private) and the same helper is used by registration, login, and the reset-password Edge Function. Phase 4's `SupabaseClientWrapper.authStateChanges()` subscription is consumed by `AuthRepository` which exposes a domain-shaped `Stream<Session?>` to the BLoC. `current_user_is_admin()`'s body is swapped from `SELECT FALSE` to `SELECT (SELECT is_admin FROM profiles WHERE user_id = auth.uid())` in a single `CREATE OR REPLACE FUNCTION` migration (no policy files edited — Phase 4's R-05 invariant is preserved). The Vault PII path is two SECURITY DEFINER SQL functions called via Postgrest RPC — `app_vault_set_secret_for_self(field_name, value)` and `app_vault_secret_for_self(field_name)` plus admin-gated siblings — wrapping the existing `app_vault_secret(name)` helper from Phase 4. The reset-password account-enumeration resistance requirement (FR-017) is the only deliverable that requires an Edge Function: `request_password_reset` takes the phone, looks up `profiles.email`, conditionally calls `auth.admin.resetPasswordForEmail`, and always returns a generic 200 — the client cannot distinguish "phone known with email" from "phone unknown" or "phone known without email". This is a deliberate divergence from `docs/IMPLEMENTATION_PLAN.md`'s "first Edge Function lands in Phase 7"; the divergence is recorded in research R-16 with rejected alternatives. The locale handoff is implemented inside the registration use case itself — at the moment the user submits the registration form, the device-side `flutter_secure_storage` locale value is written through to `user_preferences.locale` as part of the post-signup profile-update step. On every subsequent authenticated sign-in, server wins (per the Session 2026-05-10 locale-source clarification). No client-side "first-sign-in" sentinel flag is needed. **No new automated tests** are added in this phase per the durable session-feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + manual device walk-through against the reference Infinix Note 8 + Supabase MCP `get_advisors` after each migration.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migrations; TypeScript on Deno for the single Edge Function. Same Flutter + Dart base as Phases 1–4.

**Primary Dependencies**: `supabase_flutter` (already in `pubspec.yaml` from Phase 1), `equatable` (already in `pubspec.yaml`), `flutter_bloc` (already in `pubspec.yaml`), `flutter_secure_storage` (already in `pubspec.yaml` per Phase 1's secure-storage wrapper), `go_router` (already in `pubspec.yaml`). **No new runtime packages, no new dev packages.** The phone-number value object is hand-rolled (Syria-focused with a generic E.164 fallback) — adding `libphonenumber_plugin` or `phone_number` is rejected (R-03). **Tooling**: Supabase MCP server (`mcp__plugin_supabase_supabase__apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`, `deploy_edge_function`, `get_edge_function`, `list_edge_functions`) is the canonical migration-apply / function-deploy / inspection mechanism.

**Storage**: Remote Supabase Postgres project (the same one Phase 4 already populated). Phase 5 adds: one new table (`account_approval_requests`); one new column on `profiles` (`is_admin BOOLEAN NOT NULL DEFAULT FALSE`); one new enum type (`account_approval_status` with values `pending`, `approved`, `rejected` — note: Phase 4's `account_status` enum is reused as-is for `profiles.account_status`; this new enum is a narrower lifecycle for the request row only); five new SQL helper functions (`app_vault_secret_for_self`, `app_vault_secret_for_user`, `app_vault_set_secret_for_self`, `app_vault_set_secret_for_user`, `app_vault_set_private_contact_methods_for_self`); one updated SQL helper (`current_user_is_admin()` body swap); one updated trigger function (`enforce_profile_status_admin_only` extended to also block `is_admin` mutation); one new auto-population trigger on `profiles` insert (creating the `account_approval_requests` row); one concrete audit trigger on `account_approval_requests` reusing `log_audit()`; one Edge Function (`request_password_reset`). Per-user-per-field PII secrets land in `vault.secrets` keyed `pii.<user_id>.<legal_name|national_id|private_contact_methods>` once users save them — the schema does not pre-populate these.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + manual UI verification on the reference Infinix Note 8 device.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, this phase introduces NO new automated tests of any kind — no unit, widget, integration, golden, runtime, or `supabase test db` tests, and no new CI step that runs tests. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors; Deno's TypeScript checker validates the Edge Function at `deploy_edge_function` time. Existing Phase 1/2/3/4 tests remain in source unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter app side (Constitution XI); Supabase remote Postgres + Edge Functions runtime for the backend side. iOS, Web, desktop NOT a target.

**Project Type**: Mobile app + backend. Phase 5 is the first phase that adds real `lib/features/` folders (auth, profile, onboarding, admin) on top of the Phase 1 shell + Phase 4's domain layer.

**Performance Goals**:

- Cold app launch to onboarding/login screen on the reference Infinix Note 8 device: under 3 seconds (Constitution baseline).
- Registration form submit → "pending approval" screen displayed: under 10 seconds end-to-end against the remote project (matches SC-001).
- Login form submit → home/pending/rejected/suspended screen displayed: under 5 seconds end-to-end.
- Admin queue page load with up to 50 pending rows: under 2 seconds.
- No latency targets on the SQL helpers or the Edge Function — at MVP scale (tens of users, low concurrency) the overhead of Vault `create_secret`/`update_secret` (a single AEAD encrypt) and the SECURITY DEFINER call overhead are negligible. Concrete server-side perf targets land with the Phase 24 release-polish performance pass per the implementation plan.

**Constraints**:

- Constitution II (Source-Controlled Backend) is the binding rule: every backend artifact lives as a checked-in `.sql` file or a checked-in `supabase/functions/<name>/index.ts`. No Studio-only edits (FR-020).
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): RLS enabled on every Phase 5 table; the new `account_approval_requests` policies are self-read + admin-read-and-write; no client write to `audit_logs`; service-role keys never shipped to the Flutter client; the Edge Function consumes the service role only inside the function runtime.
- Constitution VIII (Approval Workflow & Publisher Identity): every publisher-relevant action is gated by `profiles.account_status = 'approved'`. PII is admin-only by default per ADR-0001.
- Constitution IX (Future Backend Portability): the `lib/features/auth/`, `lib/features/profile/`, `lib/features/onboarding/`, and `lib/features/admin/` folders' `domain/` subfolders MUST NOT import from `package:supabase_flutter`. Only `data/` files (data sources, repository implementations, DTOs) reference Supabase types.
- Migrations are applied to the **remote** Supabase project via Supabase MCP `apply_migration`; the Edge Function is deployed via Supabase MCP `deploy_edge_function`. There is no local Supabase setup (per Phase 4's Q5 / R-01).
- Migrations MUST be safe to re-apply (Supabase migration tracker + idempotent constructs in the migration bodies).
- Phase 4's `current_user_is_admin()` central-helper invariant is preserved: Phase 5's body swap touches one function definition, NOT the policy files Phase 4 wrote (FR-007).
- The `log_audit()` reusable trigger function is invoked unchanged for the new audit trigger on `account_approval_requests` (FR-010 — Phase 4's reusability invariant is preserved).
- Account-enumeration resistance on login + reset-password is binding (FR-017). The reset-password path requires server-side coordination, hence the Edge Function (R-16).
- Password policy is 8 chars min, no complexity (per the Session 2026-05-10 password-policy clarification). Both the app validator and the Supabase project's `auth.minimum_password_length` setting MUST be set to 8.
- The PII fields `legal_name`, `national_id`, `private_contact_methods` are stored in `vault.secrets`, keyed `pii.<user_id>.<field_name>`; no plaintext or pgsodium-encrypted column on `profiles` for these fields (per the Session 2026-05-10 Vault-mechanism clarification).
- `private_contact_methods` is a JSON object whose keys are drawn from a server-side allowlist (`whatsapp`, `telegram`, `signal`, `private_email`, `secondary_phone`); unknown keys are rejected at the SQL function boundary (per the Session 2026-05-10 contact-shape clarification).
- The admin queue is pending-only — approve/reject only (per the Session 2026-05-10 queue-scope clarification). Suspend/un-suspend/reopen are deferred to Phase 7's super-admin UI.
- The admin-bootstrap path is privileged SQL only (Supabase MCP `execute_sql`) — no in-app affordance to flip `is_admin` in Phase 5 (R-19).

**Scale/Scope**:

- **5 new SQL migration files** under `supabase/migrations/` named with synthetic-monotonic 14-digit timestamps `20260510120001` through `20260510120005`, ordered after Phase 4's `20260506120006_enable_vault.sql` (R-01).
- **1 new policy file** under `supabase/policies/`: `account_approval_requests_policies.sql` (R-04).
- **1 new Edge Function** under `supabase/functions/request_password_reset/`: `index.ts` + `deno.json` per the Supabase Deno runtime convention (R-16).
- **1 new doc file** under `supabase/docs/`: `account_approval_requests.md` (FR-021). `supabase/docs/profiles.md` is amended for the new `is_admin` column and the Vault PII RPCs.
- **1 new value object** under `lib/shared/domain/value_objects/`: `phone_number.dart` (FR-014).
- **5 new feature folders** under `lib/features/`: `auth/`, `profile/`, `onboarding/`, `admin/account_approvals/`, and a minimal `home/presentation/pages/home_page.dart` placeholder (the post-approval redirect destination required by `AuthState.Authenticated` per the redirect helper R-18; the placeholder is extended by US2's profile tile + US4's admin tile). Each `auth/`, `profile/`, `onboarding/`, `admin/` folder follows the Clean Architecture trio `data/`, `domain/`, `presentation/` (FR-011, FR-012, FR-013, FR-019); `home/` ships only `presentation/pages/home_page.dart` because it has no domain or data of its own — every value it displays is consumed from the AuthBloc.
- **0 new packages** in `pubspec.yaml`.
- **0 new tests** (durable no-new-tests rule).
- **0 changes** to `.github/workflows/ci.yml` (no new tooling needs CI; SQL is validated at `apply_migration` time on the remote; the Edge Function is type-checked at `deploy_edge_function` time).

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-clarify` Session 2026-05-10 closed five high-impact ambiguities (Vault mechanism, contact-methods shape, password policy, queue scope, locale source). No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 5 backend artifact lives as a checked-in file: 5 migrations under `supabase/migrations/`, 1 policy file under `supabase/policies/`, 1 Edge Function under `supabase/functions/`, 1 doc file under `supabase/docs/`. The remote Supabase project is one applied instance of the repo. The first-admin bootstrap (privileged SQL via Supabase MCP `execute_sql`) is documented in `quickstart.md` Step N — it is a one-time operational action, not a schema artifact, so it does not need a checked-in migration. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS enabled on `account_approval_requests` (FR-008): self-read + admin-read-all + admin-update-only + no INSERT (the auto-trigger from FR-004 is the only writer) + no DELETE. The new column `profiles.is_admin` is non-NULL, default FALSE, and the existing column-mutation enforcement trigger from Phase 4 is extended (FR-009) to reject any client-initiated `UPDATE` that mutates `is_admin`. The `current_user_is_admin()` helper body swap (R-12) is the single line of admin gating across every dependent policy. The Edge Function `request_password_reset` consumes the service-role key only inside the function runtime; the Flutter client invokes the function and never sees the key. PII is stored encrypted in `vault.secrets` (per the Session 2026-05-10 clarification); reads gated by SECURITY DEFINER helpers that resolve `auth.uid()` server-side. |
| IV. Clean Architecture Flutter | **Pass** | Each Phase 5 feature folder ships the full trio (`data/`, `domain/`, `presentation/`). Use cases live in `domain/usecases/`. State management uses BLoC for `auth/` (multiple discrete events and states warranting an event-shaped store) and Cubit for `profile/`, `onboarding/`, and `admin/account_approvals/` (simpler load → mutate flows) — matching Constitution IV's "default to BLoC/Cubit; Cubit for simpler state" guidance. Locked in research R-09. |
| V. Arabic-First Localization | **Pass** | Every user-visible string in the four new feature folders ships through Phase 3's localization runtime (`AppLocalizations`). The Phase 3 lint guard (which rejects literal user-visible strings in `lib/features/`) catches violations at lint time. RTL/LTR is preserved by using `EdgeInsetsDirectional` and `Directionality`-aware widgets exclusively. The bilingual font stack from Phase 2 is consumed via `Theme.of(context)`. New ARB keys for register / login / pending / rejected / suspended / profile-edit / admin-queue / Vault-PII screens are added to both `intl_ar.arb` and `intl_en.arb` in lockstep. |
| VI. Theme System & Design Tokens | **Pass** | Every visual property in the new Phase 5 widgets reads from `Theme.of(context)` or Phase 2's design-token module. No hardcoded hex colors, raw font sizes, or ad-hoc paddings. The pending/rejected/suspended status badges reuse the Phase 2 status-badge component (or a thin wrapper if a new variant is needed; that wrapper is added as a new design-token consumer, not as a hardcoded style). |
| VII. Dynamic Roles & Permissions | **Pass — explicitly forward-prepped to Phase 6.** | Phase 5 uses the interim `profiles.is_admin` BOOLEAN as the single admin signal. Every admin-gated policy and every admin-gated SQL helper goes through `current_user_is_admin()` — Phase 6 swaps the helper's body to call `current_user_has_permission(...)` and drops the `is_admin` column without touching any Phase 5 policy file. The audit invariant from Constitution VII is honored — every admin action on `account_approval_requests` writes one `audit_logs` row via Phase 4's `log_audit()` reusable trigger, and the Vault PII write helpers also emit audit-log rows for admin-write paths. |
| VIII. Approval Workflow & Publisher Identity | **Pass — this is the principle this phase realizes.** | Registration sets `account_status = 'pending'` (via Phase 4's auto-provision trigger). Publishing-gated actions check `account_status = 'approved'` at both the route-guard layer and the database RLS layer (the latter when later phases add the publisher-side tables). The PII fields `legal_name`, `national_id`, `private_contact_methods` are admin-only by default per ADR-0001 — they live in `vault.secrets` and are read only via `app_vault_secret_for_self(...)` for the user themselves and `app_vault_secret_for_user(...)` for admins. The "publisher's settings explicitly opt in to public display" path from Constitution VIII is NOT implemented in Phase 5 — that opt-in toggle and its public-read surface land with the listing-publisher-view phase (Phase 11+); Phase 5's PII fields default to admin-only with no opt-in surface, which is a strict subset of Constitution VIII's specification. |
| IX. Future Backend Portability | **Pass** | The `domain/` subfolder of every Phase 5 feature is Supabase-free — verified by `grep` over `lib/features/auth/domain/`, `lib/features/profile/domain/`, `lib/features/onboarding/domain/`, `lib/features/admin/account_approvals/domain/`, and `lib/shared/domain/value_objects/`. The `data/` subfolders are the only place Supabase types appear; the synthetic-email helper (`lib/features/auth/data/internal/synthetic_email.dart`) is package-private to the auth feature so other features cannot accidentally import it. The `request_password_reset` Edge Function is invoked through `AuthRepository.resetPassword(phone)` — the BLoC and use case never see the function name or call shape. |
| X. Testable AI Workflow | **Pass — Justified.** | Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql`/`list_tables`/`get_advisors` calls OR via a manual UI walk on the reference device. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. `quickstart.md` lists the per-FR + per-SC verifications as runnable Supabase MCP calls and device-walk steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only; no platform-conditional code. The remote Supabase backend is platform-neutral. The Edge Function uses Supabase's Deno runtime — server-side, no platform target. |
| XII. No Hidden Product Decisions | **Pass** | All five Session 2026-05-10 clarifications are captured in `spec.md` `## Clarifications`. The deliberate divergence from `docs/IMPLEMENTATION_PLAN.md`'s "first Edge Function lands in Phase 7" — Phase 5 ships `request_password_reset` to satisfy FR-017's account-enumeration resistance — is recorded here in `## Constraints` and in research R-16 with rejected alternatives. The deliberate divergence from the implementation plan's filename hints `0007_create_account_approval_requests.sql` and `0008_profiles_vault_columns.sql` (they used a phase-counter convention; Phase 4 locked the timestamp convention; Phase 5 uses the timestamp convention) is recorded in research R-01. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/005-auth-profile/
├── plan.md                 # This file
├── research.md             # Phase 0 — locked tech decisions (R-01..R-21)
├── data-model.md           # Phase 1 — account_approval_requests, profiles.is_admin column, vault.secrets naming convention, domain entities, AuthBloc state machine, RLS posture
├── quickstart.md           # Phase 1 — end-to-end manual verification recipe via Supabase MCP execute_sql + Flutter device walk on Infinix Note 8
├── contracts/              # Phase 1 — interface contracts later phases consume
│   ├── account-approval-trigger.md      # auto-population trigger on profiles insert
│   ├── account-approval-audit-trigger.md # concrete audit trigger on account_approval_requests using log_audit()
│   ├── admin-predicate-v5.md            # the body-swap of current_user_is_admin() (Phase 4 contract upgraded)
│   ├── vault-pii-helpers.md             # the four/five SECURITY DEFINER helpers (read self, read admin, write self, write admin, write contact-methods JSON)
│   ├── auth-repository.md               # the domain-layer auth interface (register/login/logout/resetPassword/sessionStream)
│   ├── profile-repository.md            # the domain-layer profile interface (load/update/loadPii/updatePii)
│   ├── phone-number-value-object.md     # E.164 normalization contract
│   └── request-password-reset-edge-fn.md # the request_password_reset Edge Function HTTP contract
├── checklists/
│   └── requirements.md     # From /speckit-specify (validated)
├── spec.md                 # From /speckit-specify (clarified Session 2026-05-10)
└── tasks.md                # Created by /speckit-tasks (NOT by /speckit-plan)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                          # (existing) Update auth.minimum_password_length to 8 (R-08).
├── seed.sql                                             # (existing) NO CHANGE in Phase 5.
├── migrations/
│   ├── 00000000000000_init_extensions.sql               # (existing — Phase 1) NO CHANGE.
│   ├── 20260506120001_init_enums.sql                    # (existing — Phase 4) NO CHANGE.
│   ├── 20260506120002_create_profiles.sql               # (existing — Phase 4) NO CHANGE.
│   ├── 20260506120003_create_user_preferences.sql       # (existing — Phase 4) NO CHANGE.
│   ├── 20260506120004_create_audit_logs.sql             # (existing — Phase 4) NO CHANGE.
│   ├── 20260506120005_enable_rls_default.sql            # (existing — Phase 4) NO CHANGE — Phase 4's policy files are NOT edited (R-05 invariant).
│   ├── 20260506120006_enable_vault.sql                  # (existing — Phase 4) NO CHANGE.
│   ├── 20260510120001_create_account_approval_requests.sql  # NEW — account_approval_status enum (pending|approved|rejected); account_approval_requests table (id UUID PK DEFAULT gen_random_uuid(), user_id UUID UNIQUE FK auth.users(id) ON DELETE CASCADE, status account_approval_status NOT NULL DEFAULT 'pending', rejection_reason TEXT NULL, reviewed_by UUID NULL FK auth.users(id) ON DELETE SET NULL, reviewed_at TIMESTAMPTZ NULL, created_at + updated_at NOT NULL DEFAULT now()); set_updated_at trigger; auto_create_account_approval_request() function + trigger on AFTER INSERT ON profiles (idempotent ON CONFLICT (user_id) DO NOTHING); ENABLE RLS; bundled policies from supabase/policies/account_approval_requests_policies.sql via DROP POLICY IF EXISTS … CREATE POLICY … (R-02 bundling preserved from Phase 4).
│   ├── 20260510120002_profiles_add_is_admin.sql         # NEW — ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE (FR-007); CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only() to also reject NEW.is_admin <> OLD.is_admin from non-privileged callers (FR-009); idempotent — uses ALTER TABLE … ADD COLUMN IF NOT EXISTS.
│   ├── 20260510120003_swap_admin_predicate.sql          # NEW — CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN LANGUAGE SQL STABLE AS $$ SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE); $$ (R-12, FR-007). Single-statement body swap; no policy files edited.
│   ├── 20260510120004_profiles_vault_pii_helpers.sql    # NEW — five SECURITY DEFINER SQL functions (R-13, FR-005, FR-006): app_vault_secret_for_self(field_name TEXT) RETURNS TEXT; app_vault_secret_for_user(p_user_id UUID, field_name TEXT) RETURNS TEXT; app_vault_set_secret_for_self(field_name TEXT, p_value TEXT) RETURNS VOID; app_vault_set_secret_for_user(p_user_id UUID, field_name TEXT, p_value TEXT) RETURNS VOID; app_vault_set_private_contact_methods_for_self(p_methods JSONB) RETURNS VOID. All five validate field_name against the allowlist {legal_name, national_id, private_contact_methods}. The contact-methods setter additionally validates the JSON keys against {whatsapp, telegram, signal, private_email, secondary_phone}. All five wrap the existing app_vault_secret(name) helper from Phase 4 for reads; writes call vault.create_secret() / vault.update_secret() (or the Supabase-platform-equivalent secrets RPC).
│   └── 20260510120005_attach_audit_trigger_account_approval_requests.sql  # NEW — DROP TRIGGER IF EXISTS … CREATE TRIGGER trg_account_approval_requests_audit_status AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at ON account_approval_requests FOR EACH ROW EXECUTE FUNCTION log_audit('account_approval.status_changed', 'status,rejection_reason,reviewed_by,reviewed_at', 'user_id'). Reuses Phase 4's log_audit() unchanged (FR-010, R-05 reusability invariant).
├── policies/                                            # (existing dir from Phase 4)
│   ├── README.md                                        # (existing) NO CHANGE.
│   ├── profiles_policies.sql                            # (existing — Phase 4) NO CHANGE — the body-swap of current_user_is_admin() in 20260510120003 is what makes the existing admin-gated policies actually filter correctly. Constitution-IX-style "central helper, no policy edits" invariant preserved (FR-007).
│   ├── user_preferences_policies.sql                    # (existing — Phase 4) NO CHANGE.
│   ├── audit_logs_policies.sql                          # (existing — Phase 4) NO CHANGE — the body-swap is what now lets admins read audit_logs.
│   └── account_approval_requests_policies.sql          # NEW — self-read (auth.uid() = user_id); admin-read-all (current_user_is_admin()); admin-update (current_user_is_admin() — same predicate gates UPDATE because Phase 5 is approve/reject-only); no INSERT (the auto_create_account_approval_request trigger is the only writer); no DELETE policy (rows are kept for audit) (FR-008).
├── functions/                                           # NEW directory (Phase 5 introduces the first Edge Function — divergence from IMPLEMENTATION_PLAN.md, locked R-16).
│   └── request_password_reset/
│       ├── deno.json                                    # NEW — Deno config + import_map for the function.
│       └── index.ts                                     # NEW — Edge Function: takes {phone}, normalizes E.164, looks up profiles.email via service-role client, calls supabase.auth.admin.resetPasswordForEmail(real_email) if email exists, ALWAYS returns generic 200 JSON {ok: true} regardless of whether the phone exists or has an email on file (FR-017 account-enumeration resistance). Service-role key consumed only inside the function runtime via `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`.
└── docs/                                                # (existing dir from Phase 4)
    ├── profiles.md                                      # UPDATE — append section for the new is_admin column (default FALSE, mutation-blocked by trigger, swapped predicate body in current_user_is_admin) and a section for the Vault PII RPCs (the five helpers, the field allowlist, the contact-methods key allowlist).
    ├── audit_logs.md                                    # UPDATE — append note that the audit trigger is now also attached to account_approval_requests via the Phase 5 migration.
    └── account_approval_requests.md                     # NEW — purpose, columns, default values, lifecycle (pending → approved | rejected — no suspended/un-suspend in Phase 5), RLS posture, audit trigger, the auto-population trigger, the relationship to profiles.account_status (the request row tracks the lifecycle of admin approval; profiles.account_status is the broader user-state field) (FR-021).

lib/
├── main.dart                                            # (existing) NO CHANGE.
├── app.dart                                             # UPDATE — wire the AuthBloc as a top-level provider, register the new go_router routes (/onboarding, /login, /register, /pending, /rejected, /suspended, /profile, /profile/edit, /profile/private, /admin, /admin/approvals), keep the splash/redirect logic that reads AuthBloc state to choose the initial route (Constitution V Arabic-first preserved by go_router's locale propagation).
├── core/                                                # (existing)
│   ├── config/                                          # (existing) NO CHANGE.
│   └── network/                                         # (existing — Phase 4 already wired authStateChanges())
│       ├── supabase_client_wrapper.dart                 # (existing) NO CHANGE.
│       ├── supabase_client_wrapper_impl.dart            # (existing — Phase 4 wired the real authStateChanges()) NO CHANGE.
│       └── types/                                       # (existing) NO CHANGE.
└── shared/                                              # (existing)
    ├── presentation/                                    # (existing — Phase 2 widgets) NO CHANGE.
    └── domain/                                          # (existing — Phase 4 added entities/, value_objects/)
        ├── entities/
        │   ├── profile.dart                             # (existing — Phase 4) UPDATE — add `final bool isAdmin;` field (default false), wire into copyWith / props (Constitution IX preserved — no Supabase imports). Phase 5 reads is_admin via the existing profiles select; the data-layer mapper picks up the new column automatically.
        │   └── user_preferences.dart                    # (existing — Phase 4) NO CHANGE.
        └── value_objects/
            ├── account_status.dart                      # (existing — Phase 4) NO CHANGE.
            ├── publisher_status.dart                    # (existing — Phase 4) NO CHANGE.
            └── phone_number.dart                        # NEW — E.164 normalization value object (R-03, FR-014). Hand-rolled, Syria-focused (default country code +963; strips leading 0; validates total digit count 7–15). Equatable. NO third-party packages, NO Supabase imports.

lib/features/                                            # NEW top-level directory under lib/.
├── auth/                                                # NEW — feature folder for register/login/logout/reset-password (FR-011).
│   ├── data/
│   │   ├── datasources/
│   │   │   └── supabase_auth_datasource.dart           # NEW — the only file in this feature that imports `package:supabase_flutter`. Wraps supabase.auth.signUp, signInWithPassword, signOut, the authStateChanges stream from the Phase 4 wrapper, and the request_password_reset Edge Function invocation. Uses the synthetic-email helper for register/login.
│   │   ├── internal/
│   │   │   └── synthetic_email.dart                    # NEW — package-private (no `export` from the feature's barrel file) helper: String syntheticEmailFor(PhoneNumber phone) => '${phone.e164}@alnujom.local'. Single source of the synthetic-email format (FR-015).
│   │   ├── dtos/
│   │   │   └── session_dto.dart                        # NEW — Supabase-shape DTO; mapped to domain Session entity by the repository impl.
│   │   └── repositories/
│   │       └── auth_repository_impl.dart               # NEW — domain-shaped repository implementation. Translates Supabase errors into domain AuthFailure types.
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── credentials.dart                        # NEW — value object {phone: PhoneNumber, password: String}. NO Supabase imports.
│   │   │   ├── session.dart                            # NEW — domain Session entity (user_id, accessTokenIsActive). NO Supabase imports.
│   │   │   └── auth_failure.dart                       # NEW — sealed Failure types: InvalidPhoneOrPassword, AccountAlreadyExists, PasswordTooShort, NetworkError, UnknownAuthError. (Reset-password emits no specific failure — the Edge Function is account-enumeration-resistant; only transport-level NetworkError surfaces.)
│   │   ├── repositories/
│   │   │   └── auth_repository.dart                    # NEW — abstract interface. Stream<Session?> sessionStream; Future<Result> register(PhoneNumber, String password, String? realEmail, Locale deviceLocale); Future<Result> login(PhoneNumber, String password); Future<void> logout(); Future<Result> requestPasswordReset(PhoneNumber).
│   │   └── usecases/
│   │       ├── register.dart                           # NEW — takes RegisterParams, calls auth_repo.register, on success also writes the device-side locale to user_preferences via ProfileRepository.updateLocale (R-11 locale handoff implementation).
│   │       ├── login.dart                              # NEW.
│   │       ├── logout.dart                             # NEW.
│   │       └── request_password_reset.dart             # NEW.
│   └── presentation/
│       ├── bloc/
│       │   ├── auth_bloc.dart                          # NEW — BLoC with events RegisterRequested / LoginRequested / LogoutRequested / ResetPasswordRequested / SessionRefreshed and states Unauthenticated / Authenticating / Authenticated(Profile) / PendingApproval(Profile) / Rejected(Profile, reason) / Suspended(Profile) / AuthError(message). Subscribes to AuthRepository.sessionStream + listens for Profile changes; emits the right "post-login destination" state.
│       │   ├── auth_event.dart                         # NEW.
│       │   └── auth_state.dart                         # NEW.
│       └── pages/
│           ├── login_page.dart                         # NEW — phone + password + "forgot password?" link. Uses Phase 2 design tokens; Phase 3 ARB strings.
│           ├── register_page.dart                      # NEW — phone (default +963) + password (8-char min validator) + optional real email + submit. Locale picker NOT here — picked at onboarding.
│           ├── pending_approval_page.dart              # NEW — localized "Account pending approval" copy + sign-out affordance.
│           ├── rejected_page.dart                      # NEW — localized "Account rejected" copy + the reviewer-supplied reason from account_approval_requests.rejection_reason + sign-out affordance.
│           ├── suspended_page.dart                     # NEW — localized "Account suspended" copy + sign-out affordance.
│           └── reset_password_page.dart                # NEW — phone-only form + generic "if an account exists for this phone, a reset link has been sent" message after submit (FR-017 account-enumeration resistance).
├── profile/                                             # NEW — feature folder for profile view + edit (FR-012).
│   ├── data/
│   │   ├── datasources/
│   │   │   └── supabase_profile_datasource.dart        # NEW — wraps supabase.from('profiles').select/update + the Vault PII RPCs.
│   │   └── repositories/
│   │       └── profile_repository_impl.dart            # NEW.
│   ├── domain/
│   │   ├── entities/
│   │   │   └── private_contact_methods.dart            # NEW — domain value object for the typed-keys JSON (whatsapp, telegram, signal, private_email, secondary_phone). Validates keys at construction; rejects unknown keys.
│   │   ├── repositories/
│   │   │   └── profile_repository.dart                 # NEW — abstract interface. Future<Profile> getCurrentProfile(); Future<Result> updateProfile({fullName, username, email, avatarUrl}); Future<PiiBundle> loadPii(); Future<Result> updateLegalName(String); Future<Result> updateNationalId(String); Future<Result> updatePrivateContactMethods(PrivateContactMethods); Future<Result> updateLocale(Locale).
│   │   └── usecases/
│   │       ├── load_profile.dart                       # NEW.
│   │       ├── update_profile.dart                     # NEW — validates username uniqueness via Postgres unique-violation → domain UsernameTakenFailure mapping.
│   │       └── update_pii.dart                         # NEW — fans out to the Vault helpers based on which field changed.
│   └── presentation/
│       ├── cubit/
│       │   ├── profile_cubit.dart                      # NEW.
│       │   └── profile_state.dart                      # NEW.
│       └── pages/
│           ├── profile_page.dart                       # NEW — read-only view of the user's own profile (full name, username, phone, email, status badges, avatar).
│           ├── profile_edit_page.dart                  # NEW — edit form for non-status fields.
│           └── profile_private_page.dart               # NEW — separate page (route /profile/private) for the Vault PII fields. Uses load_pii + update_pii.
├── onboarding/                                          # NEW — feature folder for splash + onboarding (FR-013).
│   ├── data/
│   │   └── datasources/
│   │       └── onboarding_seen_storage.dart            # NEW — wraps the existing flutter_secure_storage wrapper from Phase 1 with key 'onboarding_seen_v1' (R-10).
│   ├── domain/
│   │   ├── repositories/
│   │   │   └── onboarding_repository.dart              # NEW — abstract: Future<bool> hasSeenOnboarding(); Future<void> markSeen().
│   │   └── usecases/
│   │       └── mark_onboarding_seen.dart               # NEW.
│   └── presentation/
│       ├── cubit/
│       │   ├── onboarding_cubit.dart                   # NEW.
│       │   └── onboarding_state.dart                   # NEW.
│       └── pages/
│           ├── splash_page.dart                        # NEW — branded splash; reads AuthBloc state + onboarding-seen flag and routes to /onboarding | /login | /home | /pending | /rejected | /suspended.
│           └── onboarding_page.dart                    # NEW — N-step value-prop carousel + "Get started" button that marks seen and navigates to /register (or /login).
├── home/                                                # NEW — minimal post-approval landing page (the destination for AuthState.Authenticated per the redirect helper R-18). No domain or data layer — consumes AuthBloc state directly.
│   └── presentation/
│       └── pages/
│           └── home_page.dart                          # NEW — Scaffold with full-name display + sign-out + an empty tile region. US2's T079 adds the Profile tile; US4's T072 adds the Admin tile (gated on profile.isAdmin). Constitution V/VI: ARB strings (home_title, home_signed_in_as, home_tile_profile) + Theme tokens.
└── admin/                                               # NEW top-level admin namespace (Phase 5 introduces the first admin feature; Phase 6+ extend it).
    └── account_approvals/                              # NEW — pending-only queue (FR-019, per the Session 2026-05-10 queue-scope clarification).
        ├── data/
        │   ├── datasources/
        │   │   └── supabase_account_approvals_datasource.dart  # NEW — wraps supabase.from('account_approval_requests').select('*, profiles(...)') and update.
        │   └── repositories/
        │       └── account_approvals_repository_impl.dart      # NEW.
        ├── domain/
        │   ├── entities/
        │   │   └── account_approval_request.dart       # NEW — domain entity (user_id, status, rejection_reason, reviewed_by, reviewed_at, created_at, plus a denormalized snippet of the registrant's phone/email/full_name for the queue display).
        │   ├── repositories/
        │   │   └── account_approvals_repository.dart   # NEW.
        │   └── usecases/
        │       ├── load_pending_queue.dart             # NEW.
        │       ├── approve_account.dart                # NEW — atomic: UPDATE account_approval_requests SET status='approved', reviewed_by=auth.uid(), reviewed_at=now() WHERE user_id=$1 AND status='pending' AND profiles.account_status='pending'; UPDATE profiles SET account_status='approved' WHERE user_id=$1. Both UPDATEs in a single Postgrest batch / RPC so the audit trigger fires once per affected table and a partial failure rolls back. (R-14)
        │       └── reject_account.dart                 # NEW — same shape, with rejection_reason TEXT NOT NULL parameter.
        └── presentation/
            ├── cubit/
            │   ├── account_approvals_cubit.dart        # NEW.
            │   └── account_approvals_state.dart        # NEW.
            └── pages/
                └── account_approvals_page.dart         # NEW — list of pending approvals, newest first; per-row Approve / Reject(reason) actions; pull-to-refresh; route-guarded against non-admins via go_router redirect that reads AuthBloc.state.profile.isAdmin.

# Out of scope — explicitly NOT created in this phase:
# - lib/features/listings/**             — Phase 11+ owns listings.
# - lib/features/inquiries/**            — Phase 16+ owns inquiries (Phase 16 will use the same Vault PII pattern Phase 5 establishes).
# - lib/features/admin/users/**          — managing users (suspend / un-suspend / promote-to-admin) lands in Phase 7's super-admin UI, NOT Phase 5.
# - lib/features/admin/listings/**       — Phase 11+ owns listing-approval admin surface.
# - SMS-OTP                              — post-v1 per IMPLEMENTATION_PLAN.md §6.6.
# - test/**                              — durable no-new-tests rule. Existing Phase 1/2/3/4 tests remain unchanged.
# - .github/workflows/ci.yml             — no new CI step.
# - new packages in pubspec.yaml         — none.
# - profiles.last_seen_at / last_login_at — not needed in Phase 5; the auth-state listener + the Edge Function handle session liveness.
# - publisher_status transitions          — Phase 5 leaves publisher_status at the auto-provisioned 'pending'; the publisher-application surface lands with the listing-publisher phase (Phase 11+).
```

**Structure Decision**: Phase 5's footprint is split between (a) a small backend extension on top of Phase 4 (5 new migrations, 1 new policy file, 1 new Edge Function, 1 new doc file, 2 doc-file updates) and (b) the first real `lib/features/` folders on the Flutter side (4 feature folders — auth, profile, onboarding, admin/account_approvals — each with the full Clean Architecture trio). No Phase 4 file is rewritten; the only "edits to existing Phase 4 artifacts" are the appends to `supabase/docs/profiles.md` + `supabase/docs/audit_logs.md` (text-only), the addition of the `isAdmin` field to the existing Phase 4 `Profile` entity (additive — does not break Phase 4's contract), and the `app.dart` wiring that registers the new top-level providers and routes. Constitution IX is enforced by the directory layout: every `domain/` subfolder is Supabase-free; the only files importing `package:supabase_flutter` are the four `data/datasources/*.dart` files plus the existing `supabase_client_wrapper_impl.dart`. Migrations are applied to the **remote** Supabase project via Supabase MCP `apply_migration`; the Edge Function is deployed via Supabase MCP `deploy_edge_function`. There is no local Supabase setup in this phase (per Phase 4's R-01).

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
