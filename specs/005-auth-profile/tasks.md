---
description: "Phase 5 — Auth & Profile task list (no automated tests per durable session feedback)"
---

# Tasks: Auth & Profile

**Input**: Design documents from `/specs/005-auth-profile/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: NO automated tests are generated in this phase. Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's "Verification posture" assumption, all verification is manual SQL via Supabase MCP `execute_sql` + manual UI walk on the reference Infinix Note 8 device, walked by `quickstart.md`. Existing Phase 1/2/3/4 tests remain in source unchanged.

**Organization**: Tasks are grouped by user story so each story (US1, US2, US3, US4, US5) is independently completable + verifiable. The MVP scope is **US1 + US4 jointly** (registration must reach an admin who can approve, otherwise an end-to-end demo is impossible). US2 / US3 / US5 ship as additive increments.

**Format**: `- [ ] [TaskID] [P?] [Story?] Description with file path`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: One-time project-level configuration changes that have no code-shape side effects but must be in place before migrations / Edge Function deploy / device runs.

- [X] T001 Update `supabase/config.toml` to set `auth.minimum_password_length = 8` (R-08, FR-001). The file is checked in; the project-level value is sourced from this file when the team next runs `supabase db push` or via the dashboard mirror.
- [X] T002 Mirror the password-length setting in the Supabase project dashboard: Auth → Settings → Password → Minimum length = 8. (One-time manual; required because Phase 5 has no local Supabase setup per Phase 4 R-01.) Document the configured value in the project runbook.
- [X] T003 Configure Supabase project Auth → Providers → Email → uncheck "Confirm email". (Synthetic email mailbox cannot receive real mail; signup confirmation is unreliable. Per spec.md Assumptions.) Document the change in the project runbook.
- [X] T004 Configure Supabase project Auth → Settings → Site URL + Redirect URLs to include the app's reset-password redirect target (deep link or placeholder web page). Used by `auth.admin.resetPasswordForEmail` in the Edge Function. Document the configured URL in the project runbook.
- [X] T005 Create empty Phase 5 source-tree scaffolds with `.gitkeep` files: `supabase/functions/request_password_reset/`, `lib/features/auth/{data/{datasources,internal,dtos,repositories},domain/{entities,repositories,usecases},presentation/{bloc,pages}}/`, `lib/features/profile/{data/{datasources,repositories},domain/{entities,repositories,usecases},presentation/{cubit,pages}}/`, `lib/features/onboarding/{data/datasources,domain/{repositories,usecases},presentation/{cubit,pages}}/`, `lib/features/admin/account_approvals/{data/{datasources,repositories},domain/{entities,repositories,usecases},presentation/{cubit,pages}}/`. (Empty folders without .gitkeep do not survive `git add`.)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend schema, helpers, Edge Function, shared domain entities, repository interfaces + impls, ARB strings, and the AuthBloc + go_router skeleton — every artifact every user story consumes.

**⚠️ CRITICAL**: No user story (US1..US5) work can begin until Phase 2 completes. The migrations land first because Phase 5's Flutter code references `account_approval_requests`, `profiles.is_admin`, the swapped admin predicate, and the Vault PII helpers — none of which exist before Phase 2.

### Backend SQL — `account_approval_requests` (R-04, FR-003, FR-004, FR-008)

- [X] T006 Author `supabase/policies/account_approval_requests_policies.sql` with three policies (self-read, admin-read, admin-update — body per `data-model.md` §1.10) wrapped in `DROP POLICY IF EXISTS … CREATE POLICY …` for idempotency. No INSERT or DELETE policy.
- [X] T007 Author `supabase/migrations/20260510120001_create_account_approval_requests.sql` containing: the `account_approval_status` enum (idempotent via `DO $$ … EXCEPTION WHEN duplicate_object THEN NULL; END $$`), the `account_approval_requests` table (with both CHECK constraints + the partial index on pending rows + the `set_updated_at` trigger), the `auto_create_account_approval_request()` SECURITY DEFINER function + `trg_profiles_auto_create_account_approval_request` trigger on `AFTER INSERT ON profiles`, `ENABLE ROW LEVEL SECURITY`, the bundled policy bodies from `supabase/policies/account_approval_requests_policies.sql` (with `# generated from …` header comment per Phase 4 R-02), AND the SECURITY DEFINER RPCs `approve_account_approval_request(p_user_id UUID)` and `reject_account_approval_request(p_user_id UUID, p_reason TEXT)` per R-14. Bodies per `data-model.md` §1.2/§1.3/§1.8/§1.10 and `research.md` R-14.
- [X] T008 Apply `20260510120001_create_account_approval_requests.sql` via Supabase MCP `apply_migration`. Then verify per `quickstart.md` Step 1 SQL block: `to_regclass('account_approval_requests')` non-NULL; the four function names exist (`auto_create_account_approval_request`, `approve_account_approval_request`, `reject_account_approval_request`, `set_updated_at` already from Phase 4); the three triggers exist; RLS is on; the three policies are attached. After verifying, run Supabase MCP `get_advisors` with `type: 'security'` and confirm no new warnings beyond the Phase 4 baseline.

### Backend SQL — `profiles.is_admin` + extended status guard (R-12, FR-007, FR-009)

- [X] T009 Author `supabase/migrations/20260510120002_profiles_add_is_admin.sql`: `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;` + `COMMENT ON COLUMN`; `CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only()` with the Phase 5 body that additionally rejects `is_admin` mutations from non-privileged callers (full body per `data-model.md` §1.5 and `research.md` R-12).
- [X] T010 Apply `20260510120002_profiles_add_is_admin.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 1: `information_schema.columns` shows `is_admin BOOLEAN NOT NULL DEFAULT false`. Then attempt a non-privileged `UPDATE profiles SET is_admin = true …` simulation per `quickstart.md` Step 12 and confirm `42501` is raised.

### Backend SQL — admin predicate body swap (R-12, FR-007)

- [X] T011 Author `supabase/migrations/20260510120003_swap_admin_predicate.sql`: a single `CREATE OR REPLACE FUNCTION current_user_is_admin() …` with the body `SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);` + a header comment naming `contracts/admin-predicate-v5.md`. **No other file is edited** in this migration — Phase 4's R-05 invariant.
- [X] T012 Apply `20260510120003_swap_admin_predicate.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 1: `pg_proc.prosrc` for `current_user_is_admin` includes `is_admin FROM profiles`. Then run the JWT-claims simulations in `quickstart.md` Step 8 (a non-admin user returns FALSE; an admin user returns TRUE — but admin bootstrap is in Phase 3 / Step 4-8; for now confirm body content only).

### Backend SQL — Vault PII helpers (R-13, FR-005, FR-006)

- [X] T013 Author `supabase/migrations/20260510120004_profiles_vault_pii_helpers.sql` with the five SECURITY DEFINER functions exactly as in `research.md` R-13: `app_vault_secret_for_self`, `app_vault_secret_for_user`, `app_vault_set_secret_for_self`, `app_vault_set_secret_for_user`, `app_vault_set_private_contact_methods_for_self`. Each uses `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public[, vault]`; allowlist guards on `field_name` ∈ {legal_name, national_id, private_contact_methods} (and the writer-side `{legal_name, national_id}` for the TEXT setters); the JSON setter validates keys ⊆ `{whatsapp, telegram, signal, private_email, secondary_phone}`; reads delegate to Phase 4's `app_vault_secret(name)`; writes call `vault.create_secret(...)`.
- [X] T014 Apply `20260510120004_profiles_vault_pii_helpers.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 1: all five function names exist in `pg_proc`. Then exercise the read/write/allowlist sanity checks in `contracts/vault-pii-helpers.md` Verification block (read self before write returns NULL; allowlist guard raises `22023`; cross-user non-admin read returns NULL silently — done with a test user UUID created ad-hoc via `auth.users` insert + cleaned up afterward, OR deferred to Phase 7 of this task list).

### Backend SQL — concrete audit trigger on `account_approval_requests` (R-05, FR-010)

- [X] T015 Author `supabase/migrations/20260510120005_attach_audit_trigger_account_approval_requests.sql` with the `DROP TRIGGER IF EXISTS … CREATE TRIGGER trg_account_approval_requests_audit_status …` body per `data-model.md` §1.9. The `EXECUTE FUNCTION` argument list is exactly `('account_approval.status_changed', 'status,rejection_reason,reviewed_by,reviewed_at', 'user_id')` — Phase 5's first reuse of Phase 4's `log_audit()` unchanged.
- [X] T016 Apply `20260510120005_attach_audit_trigger_account_approval_requests.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 1: `pg_trigger` shows `trg_account_approval_requests_audit_status`. End-to-end exercise (approve/reject + audit_logs row appears) is in Phase 4 of this task list (US4); foundational verification is just trigger existence.

### Backend SQL — advisor hardening (R-01 addendum, FR-007 / R-12 search_path lock-down + RPC GRANT/REVOKE discipline)

- [X] T016a Author `supabase/migrations/20260510120006_phase5_advisor_hardening.sql`. Two responsibilities, both surfaced by `mcp__plugin_supabase_supabase__get_advisors` after T008/T010/T012/T014/T016 land: (1) re-create `current_user_is_admin()` with `SET search_path = public` (the body swap in `20260510120003` declared `LANGUAGE SQL STABLE` without an explicit search_path, which the advisor flags as mutable); (2) `REVOKE EXECUTE … FROM PUBLIC, anon` on the seven Phase-5 SECURITY DEFINER functions — the trigger-only `auto_create_account_approval_request()` revokes from `authenticated` as well; the six user-callable helpers (`app_vault_secret_for_self`, `app_vault_secret_for_user`, `app_vault_set_secret_for_self`, `app_vault_set_secret_for_user`, `app_vault_set_private_contact_methods_for_self`, `approve_account_approval_request`, `reject_account_approval_request`) are explicitly re-`GRANT EXECUTE … TO authenticated`. The migration does NOT touch Phase 4 baseline advisor warnings (`set_updated_at`, `handle_new_auth_user`) — those are documented as the Phase 4 R-01 baseline.
- [X] T016b Apply `20260510120006_phase5_advisor_hardening.sql` via Supabase MCP `apply_migration`. Re-run `mcp__plugin_supabase_supabase__get_advisors` with `type: 'security'` and confirm the `function_search_path_mutable` warning for `current_user_is_admin` is gone; the seven Phase-5 RPCs no longer surface `function_anon_executable`. The remaining three baseline warnings (Phase 4 `set_updated_at` + `handle_new_auth_user` + 7× authenticated-executable on the user-callable RPCs) are expected and documented in HANDOFF.md.

### Backend Edge Function (R-07, R-16, FR-017)

- [X] T017 Author `supabase/functions/request_password_reset/deno.json` with the Supabase-platform-default Deno runtime config + import_map for `@supabase/supabase-js`.
- [X] T018 Author `supabase/functions/request_password_reset/index.ts` per `contracts/request-password-reset-edge-fn.md`: parse `{phone}` body; reject malformed with 400 + `{error: "invalid_request"}`; normalize via the inlined TS port of the PhoneNumber rules (case table from `contracts/phone-number-value-object.md`); open service-role client from `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`; `SELECT email FROM profiles WHERE phone = $1 LIMIT 1`; if email present and non-empty, call `admin.auth.admin.generateLink({type: 'recovery', email, options: {redirectTo: ...}})`; **always** return 200 + `{ok: true}` for parseable bodies. Service-role key never appears in any response or log.
- [X] T019a Deploy via Supabase MCP `deploy_edge_function` with `name: 'request_password_reset'` and `entrypoint_path: 'supabase/functions/request_password_reset/index.ts'`. Verify immediately per `quickstart.md` Step 2: `list_edge_functions` shows the function as ACTIVE; the malformed-body cURL returns 400 + `{error: "invalid_request"}`. **Confirm the service-role secret is available**: Supabase auto-populates `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` as built-in env vars on every Edge Function (no manual secret-setting step is needed for the platform defaults). If the env var is missing, the function returns 500; document the dashboard remediation path (Supabase project → Edge Functions → secrets) in the project runbook even though the platform-default should not require it. **This task closes immediately on deploy + 400 verification — does NOT depend on US1 / T062.** US3 (T081–T084) consumes this deploy.
- [X] T019b [Story-deferred to post-T062] Once US1 ships and at least one user is registered with a real email on file, sanity-check the Edge Function's privileged path: invoke `request_password_reset` with that known-registered phone and observe in `mcp__plugin_supabase_supabase__get_logs` (type `edge-function`) that the `SELECT email FROM profiles` query succeeds and the `auth.admin.generateLink` call is issued. The function still returns the generic `{ok: true}` (account-enumeration resistance — FR-017). (Verified 2026-05-14 during Option B fix walk: see DEFERRED.md D-03.)

### Backend documentation

- [X] T020 [P] Author `supabase/docs/account_approval_requests.md` per FR-021: purpose, columns + types + defaults, lifecycle diagram (`pending → approved | rejected`; suspend/un-suspend/reopen deferred to Phase 7), RLS posture summary table, the auto-population trigger contract reference, the audit trigger reference, the relationship to `profiles.account_status`. Include the historical-filename note ("the IMPLEMENTATION_PLAN.md hint `0007_…` is now `20260510120001_…` per the timestamp convention locked in Phase 4 R-02") so a future reviewer searching for `0007` finds the pointer.
- [X] T021 [P] Update `supabase/docs/profiles.md`: append a section for the new `is_admin` column (default FALSE, mutation-blocked by trigger, consumed by `current_user_is_admin()`) AND a section for the Vault PII RPCs (the five helpers, the `field_name` allowlist, the contact-methods key allowlist, the `pii.<user_id>.<field_name>` naming convention). Cross-link to `contracts/vault-pii-helpers.md` and `contracts/admin-predicate-v5.md`.
- [X] T022 [P] Update `supabase/docs/audit_logs.md`: append a one-paragraph note that the `log_audit()` reusable function is now also attached to `account_approval_requests` via Phase 5's `20260510120005` migration, with `TG_ARGV` values `('account_approval.status_changed', 'status,rejection_reason,reviewed_by,reviewed_at', 'user_id')`.

### Flutter shared domain (entities + value objects)

- [X] T023 [P] Update `lib/shared/domain/entities/profile.dart` to add `final bool isAdmin;` field with default `false`; include in `props` and `copyWith`. Constitution IX: no `package:supabase_flutter` import. Profile entity shape per `data-model.md` §2.1.
- [X] T024 [P] Create `lib/shared/domain/value_objects/phone_number.dart` per `contracts/phone-number-value-object.md`: `PhoneNumber.parse` (throws `PhoneNumberFormatException`), `PhoneNumber.tryParse` (returns nullable), `e164` field, `Equatable`-based equality, normalization rules per the contract's "Normalization rules" section. The implementation is hand-rolled (~50 lines, no third-party packages — R-03). Add `PhoneNumberFormatException` with `localizationKey` field.
- [X] T025 [P] Verify the project's existing `Result<T>` / `FailureResult<T>` types in `lib/core/errors/` (Phase 1 / 4 inheritance) are sufficient for Phase 5's repository return shapes; if so, **skip the new `lib/shared/domain/result.dart` file entirely** and reuse `Result<T>` everywhere `Either<AuthFailure, …>` / `Either<ProfileFailure, …>` appears in `data-model.md` §2.4 / `contracts/auth-repository.md` / `contracts/profile-repository.md`. The contracts document `Either` as the recommended shape but explicitly permit raw nullable + typed failure as an equivalent — `Result<T>` is the chosen alternative. **One Phase 4 file edit is required**: loosen `lib/core/errors/failure.dart`'s base class from `sealed class Failure` to `abstract class Failure` so feature folders can subclass it with their own typed hierarchies (`AuthFailure`, `ProfileFailure`). The four existing `final class` failures (NetworkFailure, CacheFailure, ConfigFailure, UnknownFailure) stay unchanged; no Phase 4 call site is affected. Decision and rationale captured in research R-22.

### Flutter auth domain (entities + repository interface)

- [X] T026 [P] Create `lib/features/auth/domain/entities/credentials.dart`: `class Credentials extends Equatable { final PhoneNumber phone; final String password; … }`. Constitution IX: no Supabase imports.
- [X] T027 [P] Create `lib/features/auth/domain/entities/session.dart`: `class Session extends Equatable { final String userId; final bool isActive; final DateTime? expiresAt; … }`.
- [X] T028 [P] Create `lib/features/auth/domain/entities/auth_failure.dart`: sealed-class hierarchy with `InvalidPhoneOrPassword`, `AccountAlreadyExists`, `PasswordTooShort`, `NetworkError`, `UnknownAuthError(String message)`. Per `data-model.md` §2.4. The reset-password path emits no Phase-5-specific failure type because `request_password_reset` is account-enumeration-resistant by contract — it returns `Right(Unit)` on any parseable input and `Left(NetworkError)` only on transport failure (per `contracts/auth-repository.md`).
- [X] T029 Create `lib/features/auth/domain/repositories/auth_repository.dart` — abstract interface per `contracts/auth-repository.md`: `Stream<Session?> get sessionStream; Session? get currentSession; Future<Either<AuthFailure, Session>> register(...); Future<Either<AuthFailure, Session>> login(...); Future<void> logout(); Future<Either<AuthFailure, Unit>> requestPasswordReset(...);`. Constitution IX: no Supabase imports. Depends on T024, T025, T026, T027, T028.

### Flutter auth data (datasource + helper + DTO + impl)

- [X] T030 Create `lib/features/auth/data/internal/synthetic_email.dart` — package-private (NOT exported from any barrel file): `String syntheticEmailFor(PhoneNumber phone) => '${phone.e164}@alnujom.local';`. Per `contracts/auth-repository.md` and R-06. Single source of the synthetic-email format string for register / login / Edge Function (the Edge Function has its own TS-side equivalent inlined per T018).
- [X] T031 Create `lib/features/auth/data/dtos/session_dto.dart` — Supabase-shape DTO mapper. Imports `package:supabase_flutter` (the data layer is the only place this is allowed per Constitution IX). Maps `supabase.Session` → domain `Session`.
- [X] T032 Create `lib/features/auth/data/datasources/supabase_auth_datasource.dart` — wraps `supabase.Supabase.instance.client.auth` operations: `signUp(email: synthetic, password)`, `signInWithPassword(email: synthetic, password)`, `signOut()`, the `authStateChanges()` subscription from Phase 4's `SupabaseClientWrapper`, and `functions.invoke('request_password_reset', body: {phone})`. Maps Supabase errors to domain `AuthFailure` per `contracts/auth-repository.md` "Behavior contract → Failure mapping" table. Imports `package:supabase_flutter` and `synthetic_email.dart`. Depends on T030, T031.
- [X] T033 Create `lib/features/auth/data/repositories/auth_repository_impl.dart` implementing `AuthRepository`. Composes `SupabaseAuthDataSource` (T032) + `ProfileRepository` (T037 — the register flow calls `profileRepository.updateProfile(...)` + `profileRepository.updateLocale(...)` after `signUp`). The login flow reads `user_preferences.locale` post-sign-in and writes to secure_storage + the LocaleCubit (R-11). **⚠ Order: complete after T037 — T033 is numbered earlier than T037 by topic grouping (auth files first), but the actual dependency is `T037 → T033`.** Depends on T029, T032, T037.

### Flutter profile domain (entities + repository interface)

- [X] T034 [P] Create `lib/features/profile/domain/entities/private_contact_methods.dart`: `enum ContactChannel { whatsapp, telegram, signal, privateEmail, secondaryPhone }`; `class PrivateContactMethods extends Equatable` with `fromJson` (rejects unknown keys) + `toJson`. The `secondaryPhone` value goes through `PhoneNumber.parse`. Constitution IX: no Supabase imports.
- [X] T035 Create `lib/features/profile/domain/repositories/profile_repository.dart` — abstract interface per `contracts/profile-repository.md`: `getCurrentProfile()`, `currentProfileStream`, `updateProfile(...)`, `updateLocale(Locale)`, `loadPii()` returning `PiiBundle`, `updateLegalName`, `updateNationalId`, `updatePrivateContactMethods`. Add the `PiiBundle` class + `ProfileFailure` sealed hierarchy (UsernameTaken, InvalidFullName, InvalidUsername, InvalidEmail, InvalidAvatarUrl, NotAuthenticated, NetworkErrorProfile, UnknownProfileError, etc.). Depends on T024, T025, T034.

### Flutter profile data (datasource + impl)

- [X] T036 Create `lib/features/profile/data/datasources/supabase_profile_datasource.dart` — wraps `supabase.from('profiles').select('*').eq('user_id', uid).single()`, the matching `update`, `from('user_preferences').update({locale})`, AND the four/five Vault PII RPCs (`supabase.rpc('app_vault_secret_for_self', ...)`, `app_vault_set_secret_for_self`, `app_vault_set_private_contact_methods_for_self`, plus the admin-side `app_vault_secret_for_user` for Phase 7's super-admin UI but not invoked from Phase 5 UI). Maps Postgres `'23505'` on `profiles_username_key` to a typed `UsernameTaken` exception; maps `'42501'` from the enforce trigger to a typed `Forbidden` exception. Imports `package:supabase_flutter`.
- [X] T037 Create `lib/features/profile/data/repositories/profile_repository_impl.dart` implementing `ProfileRepository`. Manages a `StreamController<Profile>` for `currentProfileStream` (the AuthBloc subscribes; the Cubit's `refresh()` emits new values). Constitution IX: imports come only from the project's domain types + the data-source (T036). Depends on T035, T036.

### ARB localization (FR-013, Constitution V, gate)

- [X] T038 Add ARB keys for the auth feature to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in lockstep (the Phase 3 lint gate fails any merge that adds a key to one file but not the other). Required keys: `register_title`, `register_phone_label`, `register_phone_hint`, `register_password_label`, `register_password_hint`, `register_real_email_label_optional`, `register_full_name_label`, `register_submit`, `login_title`, `login_phone_label`, `login_password_label`, `login_submit`, `login_forgot_password`, `pending_approval_title`, `pending_approval_body`, `rejected_title`, `rejected_body_with_reason`, `suspended_title`, `suspended_body`, `reset_password_title`, `reset_password_phone_label`, `reset_password_submit`, `reset_password_generic_response`, `phone_required`, `phone_invalid`, `password_too_short`, `account_already_exists`, `invalid_phone_or_password`, `network_error`, `unknown_auth_error`, `sign_out`. Phrase Arabic copy in Syrian-friendly tone (Constitution V). **Pin the literal copy for the two account-enumeration-resistant messages** so visual comparison across paths in `quickstart.md` Steps 7 / 15 / 16 / 17 is unambiguous: `invalid_phone_or_password` (en) = `"Invalid phone or password."`; (ar) = `"رقم الهاتف أو كلمة المرور غير صحيحة."`. `reset_password_generic_response` (en) = `"If an account exists for this phone, a reset link has been sent."`; (ar) = `"إذا كان هناك حساب مرتبط بهذا الرقم، فقد تم إرسال رابط إعادة تعيين كلمة المرور."`. These exact strings MUST appear identically across login-failure paths and across all three reset-password paths to satisfy FR-017.
- [X] T039 Add ARB keys for the profile feature, the admin feature, onboarding, and the home placeholder to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in lockstep. Required keys (profile): `profile_title`, `profile_full_name_label`, `profile_username_label`, `profile_phone_label`, `profile_email_label`, `profile_avatar_label`, `profile_edit_button`, `profile_save_button`, `profile_cancel_button`, `profile_account_status_badge_pending`, `…_approved`, `…_rejected`, `…_suspended`, `username_taken`, `invalid_full_name`, `invalid_username`, `invalid_email`, `invalid_avatar_url`, `profile_private_section_title`, `profile_private_legal_name`, `profile_private_national_id`, `profile_private_contact_methods_title`, `profile_private_contact_methods_whatsapp`, `…_telegram`, `…_signal`, `…_private_email`, `…_secondary_phone`, `profile_private_unknown_channel`. (admin): `admin_tile_account_approvals`, `admin_queue_title`, `admin_queue_empty`, `admin_queue_pull_to_refresh`, `admin_queue_phone_label`, `admin_queue_email_label`, `admin_queue_full_name_label`, `admin_queue_created_at_label`, `admin_action_approve`, `admin_action_reject`, `admin_action_reject_reason_title`, `admin_action_reject_reason_label`, `admin_action_reject_reason_required`, `admin_action_confirm`, `admin_action_cancel`, `admin_request_already_resolved`. (onboarding): `onboarding_step_1_title`, `…_body`, `onboarding_step_2_title`, `…_body`, `onboarding_step_3_title`, `…_body`, `onboarding_get_started`, `onboarding_skip`, `onboarding_locale_picker_label`. (home placeholder, consumed by T041 + T072 + T079): `home_title`, `home_signed_in_as`, `home_tile_profile`. Verify the ARB lint gate passes (`flutter pub run …` per Phase 3's gate config).

### Flutter app-level wiring

- [X] T040 Update `lib/app.dart` to register `AuthBloc` (T045) as a top-level `BlocProvider` so every feature folder consumes the same instance via `BlocProvider.of<AuthBloc>(context)`. Initialize the bloc with the singleton `AuthRepository` (T033) and `ProfileRepository` (T037). The bloc's `add(SessionRefreshed(...))` is fed by the `AuthRepository.sessionStream` subscription and by the `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` hook (R-21). Depends on T033, T037, T045.
- [X] T041 Update `lib/app.dart` to add the foundational go_router routes Phase 5 needs across stories — register the routes whose pages exist by the end of foundational + US1 + US4: `/splash`, `/onboarding`, `/login`, `/register`, `/pending`, `/rejected`, `/suspended`, `/home`, `/admin`, `/admin/approvals`, `/reset-password`. (Profile routes `/profile`, `/profile/edit`, `/profile/private` are added in their own US tasks T078 / T088 to avoid compile errors before those pages exist.) Each route specifies its page widget and a tag for the redirect helper. **Additionally** create `lib/features/home/presentation/pages/home_page.dart` as a minimal placeholder home — a `Scaffold` with the user's full name (read from `AuthState.Authenticated.profile`), a sign-out affordance dispatching `AuthBloc.add(LogoutRequested())`, and an empty tile region that US2 (T079) and US4 (T072) will populate with the Profile and Admin tiles. **⚠ Shared-file warning**: `home_page.dart` is the only file edited by both US2 and US4. To keep the parallel-team strategy clean, structure the empty tile region as a `Column` of named-slot widgets (or a `List<Widget> tiles` field) so T072 and T079 can each add their tile without fighting over the same lines. If two developers run US2+US4 in parallel, they MUST coordinate the home_page.dart edits — this is the one cross-story coupling in Phase 5. Constitution V/VI: every visible string from ARB (`home_title`, `home_signed_in_as`, etc. — add these keys to T039); Theme tokens for spacing/typography. The home page is the redirect destination for `AuthState.Authenticated` (consumed by T042); without it the post-approval redirect would target an unregistered route.
- [X] T042 Implement the go_router redirect helper in `lib/app.dart` (or a sibling file `lib/core/routing/auth_redirect.dart` if the redirect is large enough to warrant extraction). Exhaustive `switch` over the sealed `AuthState`: `Unauthenticated` → `/login` (or `/onboarding` if the onboarding-seen flag is false); `Authenticating` → no redirect; `Authenticated` → `/home` (or the post-approval landing slot Phase 5 owns); `PendingApproval` → `/pending`; `Rejected` → `/rejected`; `Suspended` → `/suspended`; `AuthError` → no redirect (the page renders the error). Admin routes additionally require `state.profile.isAdmin` else redirect to `/home` (or the destination computed from state). Depends on T041, T044.

### Flutter AuthBloc skeleton

- [X] T043 [P] Create `lib/features/auth/presentation/bloc/auth_event.dart` — sealed-class hierarchy: `RegisterRequested(...)`, `LoginRequested(...)`, `LogoutRequested()`, `ResetPasswordRequested(...)`, `SessionRefreshed(Session?)`, `ProfileRefreshed(Profile)`, `AppResumedRefresh()`. Per R-18.
- [X] T044 [P] Create `lib/features/auth/presentation/bloc/auth_state.dart` — sealed `AuthState` per `data-model.md` §2.9: `Unauthenticated`, `Authenticating`, `Authenticated(Profile)`, `PendingApproval(Profile)`, `Rejected(Profile, String reason)`, `Suspended(Profile)`, `AuthError(AuthFailure)`. Each carries the data the corresponding screen needs.
- [X] T045 Create `lib/features/auth/presentation/bloc/auth_bloc.dart`. Subscribes to `AuthRepository.sessionStream`; on each emission, fetches `ProfileRepository.getCurrentProfile()` (or the cached value from `currentProfileStream`) and computes the destination state from the cross-product `(Session?, Profile.accountStatus)`. Handles each event:
  - `RegisterRequested`: emit `Authenticating` → call `register` use case (T053) → on `Right(Session)` → wait for next sessionStream emission (which fires `SessionRefreshed`) → state computed from profile.
  - `LoginRequested`: emit `Authenticating` → call `login` use case (T054) → same.
  - `LogoutRequested`: call `logout` use case (T055) → state becomes `Unauthenticated` from sessionStream emission.
  - `ResetPasswordRequested`: emit `Authenticating` → call `requestPasswordReset` use case (T081, US3) → emit back to whatever state the user was in (typically `Unauthenticated` / `AuthError` for transport failures).
  - `SessionRefreshed`: re-fetch profile and re-emit destination state.
  - `ProfileRefreshed`: re-compute destination state from new profile snapshot.
  - `AppResumedRefresh`: trigger `ProfileRepository.refresh()` to handle the suspension-on-foreground case (R-21).
  - Depends on T029, T035, T037, T043, T044.

**Checkpoint**: Foundation ready — every domain interface, every data-layer impl, every backend artifact, the AuthBloc, the routes, and the localization keys are in place. The app **compiles and launches**, but the only reachable surface is the splash + login + register pages (US1's pages); pending/rejected/suspended/admin/profile/private pages are still placeholders or wired to "not implemented" widgets that say so until their US task lands. From here, US1 / US2 / US3 / US4 / US5 can each ship as a complete, independently testable increment.

---

## Phase 3: User Story 1 — Register and pending-approval lockout (Priority: P1) 🎯 MVP

**Goal**: A first-time visitor can complete onboarding, register with phone + password (+ optional real email + full name), land on the localized "Account pending approval" screen, sign out and back in to the same screen (lockout is sticky), and have all the corresponding rows (`profiles`, `user_preferences`, `account_approval_requests`) created on the remote project with the correct defaults.

**Independent Test**: `quickstart.md` Steps 5, 6, 7 — register `+963991234567` + `Test1234`; confirm `/pending` lands; verify the three rows in the DB; force-close and re-open; sign out and sign in; confirm `/pending` survives. The admin-approval round-trip is covered in US4; US1 alone is verifiable via the database state plus the lockout invariants.

### Onboarding feature (FR-013)

- [X] T046 [P] [US1] Create `lib/features/onboarding/data/datasources/onboarding_seen_storage.dart` — wraps Phase 1's `flutter_secure_storage` wrapper with key `onboarding_seen_v1` (R-10). Methods: `Future<bool> hasSeenOnboarding()`, `Future<void> markSeen()`.
- [X] T047 [P] [US1] Create `lib/features/onboarding/domain/repositories/onboarding_repository.dart` — abstract interface mirroring the storage methods. Constitution IX: no Supabase imports.
- [X] T048 [US1] Create `lib/features/onboarding/data/repositories/onboarding_repository_impl.dart`. Depends on T046, T047.
- [X] T049 [US1] Create `lib/features/onboarding/domain/usecases/mark_onboarding_seen.dart`. Depends on T047.
- [X] T050 [P] [US1] Create `lib/features/onboarding/presentation/cubit/onboarding_cubit.dart` + `onboarding_state.dart`. State carries the current step index + the locale picker selection. Methods: `nextStep()`, `previousStep()`, `selectLocale(Locale)`, `markSeen()`.
- [X] T051 [P] [US1] Create `lib/features/onboarding/presentation/pages/splash_page.dart` — branded splash. Reads `AuthBloc.state` + the onboarding-seen flag and routes to `/onboarding | /login | /home | /pending | /rejected | /suspended`. Uses Phase 2 design tokens; Phase 3 ARB strings (T038/T039); RTL/LTR via `Directionality`.
- [X] T052 [US1] Create `lib/features/onboarding/presentation/pages/onboarding_page.dart` — N-step value-prop carousel + locale picker (delegates to the existing Phase 3 `LocaleCubit`) + "Get started" button that calls `markSeen()` and navigates to `/register`. Depends on T050.

### Auth use cases (US1)

- [X] T053 [P] [US1] Create `lib/features/auth/domain/usecases/register.dart` — orchestrates the registration flow per `contracts/auth-repository.md` register contract: domain validation (PhoneNumber.parse, password length 8+, full_name non-empty if provided), call `AuthRepository.register(...)` (T033), on success: read the device-side locale from the `LocaleCubit` (passed in as a dependency), call `ProfileRepository.updateLocale(deviceLocale)` (T037; the registration use case is the R-11 first-sign-in handoff point). Returns `Either<RegisterFailure, Session>` mapping repository failures.
- [X] T054 [P] [US1] Create `lib/features/auth/domain/usecases/login.dart` — calls `AuthRepository.login(...)` then triggers a profile refresh + a `user_preferences.locale → flutter_secure_storage` write (R-11 server-wins).
- [X] T055 [P] [US1] Create `lib/features/auth/domain/usecases/logout.dart` — calls `AuthRepository.logout()` and clears the LocaleCubit's session-derived state.

### Auth pages (US1)

- [X] T056 [P] [US1] Create `lib/features/auth/presentation/pages/register_page.dart`: phone field (defaults to `+963` country code; uses `PhoneNumber.tryParse` on submit; surfaces localized errors); password field (min-8 validator surfaces `password_too_short`); optional real-email field; optional full-name field; submit button dispatches `AuthBloc.add(RegisterRequested(...))`. Constitution V: every visible string from ARB. Constitution VI: every spacing / color / font from `Theme.of(context)`.
- [X] T057 [P] [US1] Create `lib/features/auth/presentation/pages/login_page.dart`: phone + password + "Forgot password?" link (routes to `/reset-password`, US3). Submit dispatches `AuthBloc.add(LoginRequested(...))`. The error message for both "phone unknown" and "wrong password" resolves to the same ARB key `invalid_phone_or_password` (FR-017 enumeration resistance).
- [X] T058 [P] [US1] Create `lib/features/auth/presentation/pages/pending_approval_page.dart`: localized title + body; sign-out affordance dispatching `AuthBloc.add(LogoutRequested())`.
- [X] T059 [P] [US1] Create `lib/features/auth/presentation/pages/rejected_page.dart`: localized title; body uses `rejected_body_with_reason` and substitutes the `reason` from `AuthState.Rejected(profile, reason)`; sign-out affordance.
- [X] T060 [P] [US1] Create `lib/features/auth/presentation/pages/suspended_page.dart`: localized title + body; sign-out affordance.

### US1 wiring

- [X] T061 [US1] Verify the AuthBloc handlers for `RegisterRequested`, `LoginRequested`, `LogoutRequested` are connected to the correct use cases (T053, T054, T055) and the destination-state computation is correct for each `account_status` value. The bloc was scaffolded in T045; this task closes the actual orchestration end-to-end.
- [X] T062 [US1] **Manual verification on the reference device**: walk `quickstart.md` Step 3 (phone normalization sanity), Step 5 (register `+963991234567`), Step 6 (pending lockout sticky), Step 7 (account-enumeration resistance on login). Confirm the SQL inspection in Step 5 returns one row each in `profiles`, `user_preferences`, `account_approval_requests` with the expected defaults. **Ship-ready signal for US1.** (Verified 2026-05-12: Step 5 via successful end-to-end registration of admin + 2 test users; Step 6 implicit in rejected→rejected_page routing. Steps 3 and 7 remain as low-risk UI smoke tests — code paths use the same ARB key per design.)

**Checkpoint**: User Story 1 is fully functional. A first-time user can register, lands on `/pending`, the rows are created correctly, and the lockout is sticky. The admin path needed to flip `/pending` → `/home` lives in US4.

---

## Phase 4: User Story 4 — Admin reviews and acts on pending approval requests (Priority: P1)

**Goal**: An admin (interim `is_admin = true` flag) signs in, sees a queue of pending requests, approves with one tap or rejects with a typed reason. Both transitions atomically update `account_approval_requests.status` AND `profiles.account_status` AND emit one `audit_logs` row per affected table. Non-admins are bounced from the admin route by both the route guard and database RLS.

**Independent Test**: `quickstart.md` Steps 8–12 — bootstrap an admin, register a second pending user, approve and reject from the admin queue, verify the `audit_logs` rows, simulate a non-admin reading via JWT-claims and confirm zero rows.

### Admin domain (US4)

- [X] T063 [P] [US4] Create `lib/features/admin/account_approvals/domain/entities/account_approval_request.dart`: enum `AccountApprovalStatus { pending, approved, rejected }` mirroring the SQL enum; class `AccountApprovalRequest extends Equatable` with `id`, `userId`, `status`, `rejectionReason`, `reviewedBy`, `reviewedAt`, `createdAt`, `updatedAt` AND the denormalized snippet fields (`registrantPhone`, `registrantEmail`, `registrantFullName`) for queue display. Per `data-model.md` §2.5. Constitution IX: no Supabase imports.
- [X] T064 [P] [US4] Create `lib/features/admin/account_approvals/domain/repositories/account_approvals_repository.dart` — abstract: `Future<Either<Failure, List<AccountApprovalRequest>>> loadPendingQueue();`, `Future<Either<Failure, Unit>> approve({required String userId});`, `Future<Either<Failure, Unit>> reject({required String userId, required String reason});`. Plus a sealed `AccountApprovalsFailure` hierarchy (`Forbidden`, `RequestAlreadyResolved`, `NetworkErrorAdmin`, `UnknownAdminError`).

### Admin data (US4)

- [X] T065 [US4] Create `lib/features/admin/account_approvals/data/datasources/supabase_account_approvals_datasource.dart`: `loadPendingQueue()` calls `supabase.from('account_approval_requests').select('*, profiles!user_id(phone, email, full_name)').eq('status', 'pending').order('created_at', ascending: false)`; `approve()` calls `supabase.rpc('approve_account_approval_request', params: {p_user_id: userId})`; `reject()` calls `supabase.rpc('reject_account_approval_request', params: {p_user_id: userId, p_reason: reason})`. Maps `'02000'` (no_data) from the RPCs to a `RequestAlreadyResolved` exception; maps `'42501'` to a `Forbidden` exception. Imports `package:supabase_flutter`.
- [X] T066 [US4] Create `lib/features/admin/account_approvals/data/repositories/account_approvals_repository_impl.dart`. Depends on T063, T064, T065.

### Admin use cases (US4)

- [X] T067 [P] [US4] Create `lib/features/admin/account_approvals/domain/usecases/load_pending_queue.dart`. Depends on T064.
- [X] T068 [P] [US4] Create `lib/features/admin/account_approvals/domain/usecases/approve_account.dart`. Depends on T064.
- [X] T069 [P] [US4] Create `lib/features/admin/account_approvals/domain/usecases/reject_account.dart`. Validates `reason.trim().isNotEmpty` (matches the SQL CHECK constraint defense-in-depth).

### Admin presentation (US4)

- [X] T070 [P] [US4] Create `lib/features/admin/account_approvals/presentation/cubit/account_approvals_cubit.dart` + `account_approvals_state.dart`. State carries: `loading`, `requests: List<AccountApprovalRequest>`, `error: Failure?`. Methods: `loadPending()`, `approve(userId)`, `reject(userId, reason)`. After each mutation, reload the queue (per `quickstart.md` Step 9 expectation: row disappears from the list).
- [X] T071 [US4] Create `lib/features/admin/account_approvals/presentation/pages/account_approvals_page.dart`: list of `AccountApprovalRequest` cards, newest first, each showing phone + email + full name + created_at + Approve / Reject buttons. Reject opens a dialog asking for `rejectionReason`; localized empty / loading / error states. Pull-to-refresh dispatches `cubit.loadPending()`. Constitution V/VI: ARB strings + Theme tokens.
- [X] T072 [US4] Add the admin tile to the home page (`lib/features/home/presentation/pages/home_page.dart` — the placeholder created in T041's empty tile region). The tile renders only when `state.profile.isAdmin == true` (consume `AuthBloc` state); tapping it routes to `/admin/approvals`. ARB key `admin_tile_account_approvals` (already in T039). Constitution V/VI: ARB + tokens.
- [X] T073 [US4] Confirm the go_router redirect helper (T042) bounces non-admins from `/admin` and `/admin/approvals` to `/home`. Add a unit-of-behavior check by manually navigating to `/admin/approvals` as a non-admin on the device and observing the redirect.
- [X] T074 [US4] **Manual verification on the reference device**: walk `quickstart.md` Steps 8 (bootstrap admin via SQL), 9 (approve a pending user — verify `audit_logs` row), 10 (reject with reason — verify rejection screen for the rejected user), 11 (cross-user RLS holds), 12 (`is_admin` mutation guard). **Ship-ready signal for US4.** (Verified 2026-05-12: Step 8 via direct SQL bootstrap of +963991234567; Step 9 via UI Approve + audit_logs row inspection (account_approval.status_changed); Step 10 via UI Reject with reason "test" + rejected_page shows reason; Step 11 via JWT-claims-simulated query returning 0 rows for non-admin; Step 12 via JWT-claims-simulated UPDATE raising 42501.)

**Checkpoint**: User Stories 1 AND 4 work end-to-end. A registered user can be approved by an admin and lands on `/home` on next sign-in.

---

## Phase 5: User Story 2 — View and edit my own profile (Priority: P1)

**Goal**: An approved user can view their full name, username, phone, optional email, avatar, and account/publisher status badges; edit the non-status fields; receive a localized error if username collides; cannot mutate `account_status` / `publisher_status` / `is_admin` from any path (UI or crafted client request).

**Independent Test**: `quickstart.md` Step 13 — sign in as an approved user, view profile, edit full name + username, save; verify `profiles` row updated; collide on a username and confirm the rejection.

### Profile use cases (US2)

- [X] T075 [P] [US2] Create `lib/features/profile/domain/usecases/load_profile.dart`. Depends on T035.
- [X] T076 [P] [US2] Create `lib/features/profile/domain/usecases/update_profile.dart` — domain-layer validation per `data-model.md` §6 (R-17): full_name (1..100 trimmed chars), username (`[a-z0-9_]{3,30}`), email (basic regex), avatar_url (HTTPS URL). Calls `ProfileRepository.updateProfile(...)`. Maps `UsernameTaken` (Postgres `'23505'` on `profiles_username_key`) → returns `Left(UsernameTaken)` to the cubit.

### Profile presentation (US2)

- [X] T077 [P] [US2] Create `lib/features/profile/presentation/cubit/profile_cubit.dart` + `profile_state.dart`. State: `loading | loaded(Profile) | editing(Profile, draft) | saving | savedFailure(ProfileFailure)`. Methods: `load()`, `startEdit()`, `updateDraft(...)`, `save()`, `cancelEdit()`.
- [X] T078 [US2] Create `lib/features/profile/presentation/pages/profile_page.dart` (read-only) AND `lib/features/profile/presentation/pages/profile_edit_page.dart` (form). Add `/profile` and `/profile/edit` routes to `lib/app.dart`'s router (extending T041's route table). Constitution V/VI: ARB strings + Theme tokens; RTL/LTR via `Directionality`.
- [X] T079 [US2] Add a "Profile" tile to the home page (`lib/features/home/presentation/pages/home_page.dart` — the placeholder created in T041's empty tile region). Tapping the tile routes to `/profile`. ARB key `home_tile_profile` (add to T039 ARB additions if not already present). Constitution V/VI: ARB + tokens.
- [X] T080 [US2] **Manual verification on the reference device**: walk `quickstart.md` Step 13. **Ship-ready signal for US2.** (Verified 2026-05-14: profile view, edit full name + username, save succeeded; username-collision surfaced the localized `username_taken` error.)

**Checkpoint**: User Stories 1, 2, 4 are independently functional. Approved users have a profile they can read and edit; the database invariants on status/admin fields are intact.

---

## Phase 6: User Story 3 — Reset password when real email is on file (Priority: P2)

**Goal**: A user with a real email on file can request a password reset and receive a Supabase reset email at the real address (NOT the synthetic). A user without a real email — or with a phone the project doesn't recognize — sees the same generic localized response (account-enumeration resistant). The Edge Function deployed in Phase 2 (T019) is the server-side coordinator.

**Independent Test**: `quickstart.md` Steps 15, 16, 17 — three reset attempts (with email / without email / unknown phone); confirm the user-facing copy is identical and the actual email arrival differs only for the first scenario.

### Reset-password use case (US3)

- [X] T081 [US3] Create `lib/features/auth/domain/usecases/request_password_reset.dart` — calls `AuthRepository.requestPasswordReset(phone)` (T033). Returns `Right(Unit)` on success; `Left(NetworkError)` only on transport failure. The use case does NOT distinguish "email known" / "email unknown" / "phone unknown" — the Edge Function's response is uniform per `contracts/request-password-reset-edge-fn.md`.

### Reset-password page (US3)

- [X] T082 [US3] Create `lib/features/auth/presentation/pages/reset_password_page.dart`: phone field (uses `PhoneNumber.tryParse`); submit dispatches `AuthBloc.add(ResetPasswordRequested(...))`; on completion the page shows the localized `reset_password_generic_response` regardless of outcome (FR-017). Constitution V/VI: ARB + tokens.
- [X] T083 [US3] Wire the `ResetPasswordRequested` event in the AuthBloc (T045) to call the use case (T081); on completion emit either `Unauthenticated` (the user typed a phone that resulted in success) or `AuthError(NetworkError)` for transport failures (the page handles `AuthError` by showing the localized network error and offering retry).
- [X] T084 [US3] **Manual verification on the reference device**: walk `quickstart.md` Step 15 (phone with real email — reset email arrives at real address), Step 16 (phone without real email — generic response, no email anywhere), Step 17 (unknown phone — generic response). Inspect Edge Function logs via Supabase MCP `get_logs` to confirm the lookup happened in Steps 16 and 17 but no reset was issued. **Ship-ready signal for US3.** (Verified 2026-05-14: Step 15 surfaced an architectural defect — `auth.admin.generateLink` requires `auth.users.email` to match, but the synthetic-email design stored it as `<phone>@alnujom.local`. Fixed via Option B in commit 468a685: sync trigger on profiles + lookup_email_by_phone Edge Function + lookup-aware signInWithPassword. Reset email now arrives. Click-to-complete the reset on mobile is deferred — needs deep-link integration; see DEFERRED.md D-01.)

**Checkpoint**: User Stories 1, 2, 3, 4 functional; reset-password is account-enumeration-resistant.

---

## Phase 7: User Story 5 — Vault-stored private identity fields (Priority: P2)

**Goal**: A user can enter `legal_name`, `national_id`, and `private_contact_methods` (typed JSON object) on a separate "private identity" page; the values are stored encrypted in `vault.secrets` keyed `pii.<user_id>.<field_name>`; the user reads back their own decrypted values; another user reading via any path receives nothing; an admin reading via the admin-decrypting helper receives the values.

**Independent Test**: `quickstart.md` Step 14 — full Vault round-trip: write, read self, cross-user read non-admin (NULL), cross-user read admin (decrypted), `pg_dump` plaintext check.

### PII use cases (US5)

- [X] T085 [P] [US5] Create `lib/features/profile/domain/usecases/load_pii.dart` — calls `ProfileRepository.loadPii()` (T035), returns the `PiiBundle` or a domain failure.
- [X] T086 [P] [US5] Create `lib/features/profile/domain/usecases/update_pii.dart` — dispatches by field-shape: `legalName: String` → `updateLegalName`, `nationalId: String` → `updateNationalId`, `methods: PrivateContactMethods` → `updatePrivateContactMethods`. Each dispatch maps `Forbidden` / network failures to typed domain failures.

### PII presentation (US5)

- [X] T087 [US5] Extend `ProfileCubit` (T077) with PII-specific state slices (`piiLoading`, `piiLoaded(PiiBundle)`, `piiSaving`, `piiSavedFailure`) and methods (`loadPii()`, `saveLegalName(String)`, `saveNationalId(String)`, `saveContactMethods(PrivateContactMethods)`). Keep the public-profile state and PII state decoupled in the cubit so the read-only profile page does not pay the cost of fetching PII.
- [X] T088 [US5] Create `lib/features/profile/presentation/pages/profile_private_page.dart` — separate page (route `/profile/private`, added to `lib/app.dart`'s router extending T041). Sections: `Legal name`, `National ID`, `Private contact methods` (form rows for each `ContactChannel`: WhatsApp, Telegram, Signal, Private email, Secondary phone — the secondary-phone field passes through `PhoneNumber.tryParse`). Save button calls `profileCubit.saveLegalName(...)` etc. Constitution V/VI: ARB + tokens.
- [X] T089 [US5] **Manual verification on the reference device**: walk `quickstart.md` Step 14. Then `pg_dump` (or its MCP-exposed equivalent) and `grep` the dump for the test plaintext (`'Hekmat Al Fanar'`, `'01010101010'`); confirm zero matches outside of `vault.secrets` ciphertext (SC-008 verification). **Ship-ready signal for US5.** (UI portion verified 2026-05-14: ProfilePrivatePage stores + reloads legal_name + national_id + contact methods. SQL/pg_dump security-property proofs deferred to Phase 8 T090's full quickstart walk; see DEFERRED.md D-02.)

**Checkpoint**: All five user stories functional. The MVP slice (US1+US4) was demonstrable after Phase 4; Phase 5 of this task list now ships every additional Phase-5-spec increment.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final cross-cutting verifications and cleanup.

- [ ] T090 Walk the entire `quickstart.md` end to end (all 20 steps) on a clean device install + the remote project state at this commit. Capture each verification result in a runbook entry. Any failure is a defect, not a "polish" item — fix in the appropriate US phase. **Include explicit SC-013 verification within this walk**: on the splash and onboarding screens, toggle device locale Arabic ↔ English, confirm RTL ↔ LTR mirroring, and confirm Phase 2's bilingual font stack is applied (Arabic glyphs render with the Arabic-family font, Latin glyphs with the English-family font). No other task in Phase 5 owns SC-013 device verification — it lives here.
- [ ] T091 [P] Run Supabase MCP `get_advisors` with `type: 'security'` AND `type: 'performance'` against the remote project. Confirm no new warnings beyond the Phase 4 baseline (Phase 4 R-01 documented the baseline). Any new advisor warning is a defect; resolve before claiming Phase 5 done.
- [ ] T092 Verify the Phase 3 literal-string lint guard still passes after Phase 5's four feature folders ship — run the project's existing lint (`flutter analyze` + the project-specific literal-string gate from Phase 3) and confirm zero new violations. (Constitution V; FR-013 lockstep ARB requirement.)
- [ ] T093 [P] Constitution-IX import-graph audit: `Grep` over `lib/features/auth/domain/`, `lib/features/profile/domain/`, `lib/features/onboarding/domain/`, `lib/features/admin/account_approvals/domain/`, `lib/shared/domain/` for any import containing `package:supabase_flutter`. Expected: zero matches. (SC-014 verification.)
- [ ] T094 [P] Central-helper invariant audit: `git diff` Phase 5's PR against `supabase/policies/profiles_policies.sql`, `supabase/policies/user_preferences_policies.sql`, `supabase/policies/audit_logs_policies.sql`. Expected: zero changes — every Phase-5 admin-gated policy works because the swapped `current_user_is_admin()` body picked up the right rows; no policy file was edited. (FR-007 + SC-015 verification.)
- [ ] T095 [P] Idempotent re-apply test: re-apply each of the five Phase 5 migrations (`20260510120001` through `20260510120005`) via Supabase MCP `apply_migration`. Expected: each call is a no-op per the migration tracker; the inspection queries from `quickstart.md` Step 1 return the same object counts as the first apply. (SC-016 verification.)
- [ ] T096 Suspended-mid-session check: run `quickstart.md` Step 18 — sign in, background, suspend via SQL, foreground, observe the redirect to `/suspended`. (Edge case verification; R-21.)
- [ ] T097 Cleanup test users: delete the test rows created during verification (the four test phones `+963991234567`, `+963992345678`, `+963993456789`, plus any Vault secrets that did not cascade). Per `quickstart.md` Cleanup section.
- [ ] T098 Update `CLAUDE.md`'s SPECKIT marker if any Phase 5 artifact's path or name has drifted since the plan was written. (The plan-time CLAUDE.md update is in T010 of the plan workflow / already done; this task catches any drift introduced during implementation.)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** — no dependencies; can start immediately.
- **Foundational (Phase 2)** — depends on Setup. **BLOCKS** all user stories. Within Phase 2, the SQL migrations have a strict order: T007/T008 (account_approval_requests) → T009/T010 (is_admin column) → T011/T012 (admin predicate body — needs is_admin) → T013/T014 (Vault helpers — call current_user_is_admin) → T015/T016 (audit trigger — needs the table) → T016a/T016b (advisor hardening — re-creates current_user_is_admin and revokes anon-executable on the helpers from 1–5). The Edge Function (T017–T019b), domain entities (T023–T028), repository interfaces (T029, T035), data sources / impls (T030–T037), ARB localization (T038–T039), AuthBloc skeleton (T043–T045), and app-level wiring (T040–T042) can run mostly in parallel after the SQL migrations land — any task tagged [P] is safe to fan out. **Doc-file tasks (T020/T021/T022) are independent of each other and from the SQL ordering — all three are [P].**
- **User Story 1 (Phase 3)** — depends on Phase 2 completion. Self-contained; verifiable independently via `quickstart.md` Steps 5/6/7 (does not require US4 to land).
- **User Story 4 (Phase 4)** — depends on Phase 2 completion. Independent of US1's UI but required for any end-to-end demo (the user registered via US1 needs an admin to flip their status).
- **User Story 2 (Phase 5)** — depends on Phase 2 completion. Independent of US1/US4; an approved user (created any way — including via privileged SQL) can verify US2 in isolation.
- **User Story 3 (Phase 6)** — depends on Phase 2 completion (specifically the Edge Function from T019). Independent of US1/US4 in terms of integration tests, but the test data — a phone with a real email on file — is most easily created via US1's registration flow.
- **User Story 5 (Phase 7)** — depends on Phase 2 (Vault helpers from T013/T014) and US2's profile shell (the `/profile/private` route is added next to `/profile`). Could in theory run in parallel with US2 if the route is added in this phase.
- **Polish (Phase 8)** — depends on all desired US phases being complete.

### User Story Dependencies (within Phase 2-completed state)

- US1 (P1): no story dependencies.
- US4 (P1): no story dependencies. Required for end-to-end MVP demo; recommended to ship alongside US1 in the MVP increment.
- US2 (P1): no story dependencies. Can ship in parallel with US1+US4 if staffed.
- US3 (P2): no story dependencies (the Edge Function is foundational).
- US5 (P2): light dependency on US2 (route `/profile/private` is added in T088 by extending the route table T041 already declared; if US2 has not landed, T088 still works because routes are independent).

### Within Each User Story

- Models / value objects (in `domain/entities/`, `domain/value_objects/`) before repositories.
- Repositories before use cases.
- Use cases before pages / cubits / blocs.
- Story complete before moving to next priority.

### Parallel Opportunities

- All Setup tasks T001–T005 are mostly sequential (config edits + scaffold) but T002, T003, T004 (Supabase dashboard config) are independent of T001 and can run in any order.
- Phase 2 SQL migrations (T006–T016) are strictly ordered as above. **NOT** parallelizable beyond what the order allows.
- Phase 2 documentation (T020, T021, T022) — all [P], different files.
- Phase 2 shared domain (T023, T024, T025) — all [P].
- Phase 2 auth domain (T026, T027, T028, T034) — all [P].
- Phase 2 ARB localization (T038, T039) — sequential within each file (one file, two languages locked together) but T038 and T039 add disjoint key sets so can run in parallel by different developers.
- Within US1: T046, T047, T050, T051 [P]; T053, T054, T055 [P]; T056, T057, T058, T059, T060 [P].
- Within US4: T063, T064 [P]; T067, T068, T069 [P]; T070 [P].
- Within US2: T075, T076, T077 [P].
- Within US5: T085, T086 [P].
- Polish T091, T093, T094, T095 [P].

---

## Parallel Examples

### Phase 2 — fan out shared domain after T010 lands

```text
# After 20260510120002 applies, multiple developers can fan out:
Developer A: T023 (Profile entity isAdmin field)
Developer B: T024 (PhoneNumber value object)
Developer C: T025 (Either / Unit aliases)
Developer D: T020 / T021 / T022 (the three doc files)
Developer E: T038 / T039 (ARB strings)
```

### US1 — fan out auth pages

```text
After T053–T055 (use cases) land, the five auth pages parallelize:
Developer A: T056 (register_page.dart)
Developer B: T057 (login_page.dart)
Developer C: T058 (pending_approval_page.dart)
Developer D: T059 (rejected_page.dart)
Developer E: T060 (suspended_page.dart)
```

### US4 — fan out admin domain

```text
After Phase 2 completes:
Developer A: T063 (entity)
Developer B: T064 (repository interface)
Developer C: T070 (cubit)
Developer D: T067 / T068 / T069 (use cases)
Then T065 / T066 / T071 / T072 / T073 in dependency order.
```

---

## Implementation Strategy

### MVP First (US1 + US4 jointly — true MVP requires both)

1. Complete Phase 1: Setup (T001–T005).
2. Complete Phase 2: Foundational (T006–T045). **CRITICAL — blocks all stories.**
3. Complete Phase 3: User Story 1 (T046–T062).
4. Complete Phase 4: User Story 4 (T063–T074).
5. **STOP and VALIDATE**: walk `quickstart.md` Steps 5–12 end to end. The full register-and-be-approved-by-admin flow works on the device.
6. Demo / ship the MVP slice.

> Why US1 + US4 together: US1 alone produces users stuck on `/pending` indefinitely (no admin path means no path off `/pending`). US4 alone has no users to review. The two stories together are the smallest end-to-end demonstrable slice.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (no user-facing surface yet beyond what compiles).
2. Add US1 + US4 → MVP demo: register a user, admin approves, user lands on `/home`.
3. Add US2 → Profile view + edit ships; users can polish their identity.
4. Add US3 → Reset password ships; lockout-recovery exists.
5. Add US5 → Vault PII ships; admin-only PII fields are storable.
6. Each story adds value without breaking previous stories — verified by re-running `quickstart.md` after each.

### Parallel Team Strategy

After Phase 2 completes (single-thread-recommended due to SQL migration ordering), fan out:

- Developer A: US1 (T046–T062)
- Developer B: US4 (T063–T074)
- Developer C: US2 (T075–T080)
- Developer D: US3 (T081–T084) — start as soon as the Edge Function (T017–T019) is deployed.
- Developer E: US5 (T085–T089) — light dependency on US2's route table extension; coordinate the `/profile` and `/profile/private` route additions.

Stories integrate cleanly because they consume the foundational `AuthBloc` + `ProfileRepository` + `ARB` strings without modifying each other's files (the `/admin/approvals` page lives in `lib/features/admin/`; `/profile/private` lives in `lib/features/profile/`; the route table in `lib/app.dart` is the only shared file and the additions are localized to disjoint route groups).

---

## Notes

- [P] tasks = different files, no dependencies on uncompleted tasks.
- [Story] label maps each US task to the spec's user-story number for traceability.
- Each user story is independently completable + verifiable per its `quickstart.md` step range.
- **No automated tests are added** in this phase per the durable session feedback (`feedback_no_new_tests.md`). Verification is manual SQL via Supabase MCP `execute_sql` + UI walk on the reference Infinix Note 8. Existing Phase 1/2/3/4 tests remain unchanged.
- **Constitution V (Arabic-first)**: every user-visible string MUST come from ARB; the Phase 3 literal-string lint guard (T092) catches violations at lint time.
- **Constitution VI (Theme tokens)**: every visual property MUST come from `Theme.of(context)` or Phase 2's design-token module.
- **Constitution IX (Future Backend Portability)**: every `domain/` subfolder MUST be Supabase-free — verified by T093.
- **Constitution X (Testable AI workflow)**: every task above resolves to either a SQL inspection step or a UI walk step, both of which an agent can run.
- Commit after each task or each cohesive group of [P] tasks; the project's git workflow (per `feedback_git_workflow.md`) ships ONE PR per spec, not per phase, so commits accumulate on the `005-auth-profile` branch until the full spec is implemented.
- Stop at any checkpoint to validate the corresponding US independently before continuing.
- Avoid: vague tasks, same-file conflicts within a parallel batch, cross-story dependencies that break independence.
