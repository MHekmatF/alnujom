# Phase 5 Implementation Handoff

**Stopped at**: 2026-05-10 (this session)
**State**: `flutter analyze` reports **0 issues**. Codebase compiles. Backend fully deployed to remote Supabase project `hczsgceagommznjaohyk` (AlNujom).

---

## What's done (you can rely on this)

### Phase 1 Setup

- ✅ **T001** `supabase/config.toml` — `minimum_password_length = 8` with Phase 5 comment.
- ✅ **T005** All 30 Phase 5 source-tree folders created with `.gitkeep` files.
- ⏳ **T002, T003, T004** — three Supabase dashboard toggles (your action; see below).

### Phase 2 Backend (fully shipped to remote project)

- ✅ **T006** `supabase/policies/account_approval_requests_policies.sql`.
- ✅ **T007–T016** Five SQL migrations applied via Supabase MCP `apply_migration`:
  - `20260510120001_create_account_approval_requests.sql` (table + enum + auto-trigger + RLS + 3 policies + approve/reject RPCs)
  - `20260510120002_profiles_add_is_admin.sql` (`is_admin` column + extended status guard)
  - `20260510120003_swap_admin_predicate.sql` (`current_user_is_admin()` body swap)
  - `20260510120004_profiles_vault_pii_helpers.sql` (5 SECURITY DEFINER PII helpers)
  - `20260510120005_attach_audit_trigger_account_approval_requests.sql` (audit trigger reusing `log_audit()`)
- ✅ **`20260510120006_phase5_advisor_hardening.sql`** (added during implementation — `current_user_is_admin` search_path + REVOKE EXECUTE on anon/authenticated for trigger-only and admin-gated functions). Closes the security advisor warnings my Phase 5 changes introduced.
- ✅ **T017–T019** Edge Function `request_password_reset` deployed (id `fa206424-…`, status ACTIVE, version 1, `verify_jwt: false`). Verified via cURL: malformed body → 400, unknown phone → 200 `{ok:true}`.
- ✅ **T020–T022** Three doc files: `account_approval_requests.md` (new), `profiles.md` (updated for `is_admin` + Vault PII RPCs), `audit_logs.md` (updated for Phase 5 trigger).

### Phase 2 Flutter foundation (PARTIAL — see "What's left")

**Shipped and analyze-clean**:

- ✅ **T024** `lib/shared/domain/value_objects/phone_number.dart` (E.164 validator, hand-rolled, no third-party dependency).
- ✅ **T023** `lib/shared/domain/entities/profile.dart` — added `isAdmin` field (default `false`).
- ✅ **T025** Skipped — used existing `Result<T>` / `FailureResult<T>` from `lib/core/errors/` instead of inventing `Either<L, R>`. **Side-effect**: `lib/core/errors/failure.dart` was loosened from `sealed class Failure` to `abstract class Failure` so feature folders can subclass it. The four existing `final class` failures (NetworkFailure, CacheFailure, ConfigFailure, UnknownFailure) are unchanged. Phase 4 call sites are not affected.
- ✅ **T026** `lib/features/auth/domain/entities/credentials.dart`.
- ✅ **T027** `lib/features/auth/domain/entities/session.dart`.
- ✅ **T028** `lib/features/auth/domain/entities/auth_failure.dart` — `InvalidPhoneOrPassword`, `AccountAlreadyExists`, `PasswordTooShort`, `UnknownAuthError`. (No `RealEmailRequiredForReset` per analysis L2.)
- ✅ **T029** `lib/features/auth/domain/repositories/auth_repository.dart` (interface).
- ✅ **T030** `lib/features/auth/data/internal/synthetic_email.dart` (package-private; format `<E.164>@alnujom.local`).
- ✅ **T031** `lib/features/auth/data/dtos/session_dto.dart` (Supabase Session → domain Session mapper).
- ✅ **T032** `lib/features/auth/data/datasources/supabase_auth_datasource.dart` (signUp / signInWithPassword / signOut / authStateChanges / functions.invoke + error mapping).
- ✅ **T033** `lib/features/auth/data/repositories/auth_repository_impl.dart` (composes auth datasource + profile repo; locale handoff R-11 in register flow).
- ✅ **T034** `lib/features/profile/domain/entities/private_contact_methods.dart` (typed-key allowlist).
- ✅ **T035** `lib/features/profile/domain/repositories/profile_repository.dart` — interface + `PiiBundle` + `ProfileFailure` sealed hierarchy. **Note**: `updateProfile` includes a `phone` parameter (FR-002 registration flow); the profile-edit page in T078 must NOT include phone in the edit payload.
- ✅ **T036** `lib/features/profile/data/datasources/supabase_profile_datasource.dart` (Postgrest + 3 Vault PII RPC wrappers).
- ✅ **T037** `lib/features/profile/data/repositories/profile_repository_impl.dart` (full `ProfileRepository` impl).
- ✅ **T046** `lib/features/onboarding/data/datasources/onboarding_seen_storage.dart` (key `com.alnujom.onboarding.seen_v1`).
- ✅ **T047** `lib/features/onboarding/domain/repositories/onboarding_repository.dart`.
- ✅ **T048** `lib/features/onboarding/data/repositories/onboarding_repository_impl.dart`.

**State**: `flutter analyze --no-pub` reports **No issues found!**.

---

## What's left (your work)

These tasks from `tasks.md` are NOT yet done. Numbered in execution order:

### Pre-flight (still needed before device demo)

═══════════════════════════════════════════
  🔴 ACTION REQUIRED — 3 Supabase dashboard toggles
═══════════════════════════════════════════

Open https://supabase.com/dashboard/project/hczsgceagommznjaohyk:

- **T002** Authentication → Sign In/Providers → **Password Settings** → Minimum length: change `6` → `8` → Save.
- **T003** Authentication → Sign In/Providers → **Email** → toggle **"Confirm email" OFF** → Save.
- **T004** Authentication → **URL Configuration** → Redirect URLs → Add `https://alnujom.local/reset-password-confirm` → Save.

### Phase 2 Flutter foundation — remaining

- **T038, T039** Add ARB keys for auth/profile/admin/onboarding/home to BOTH `lib/l10n/app_en.arb` AND `lib/l10n/app_ar.arb`. After editing run `flutter gen-l10n`. **Gotcha**: the project's `_DebugAppLocalizations` proxy in `lib/core/localization/app_strings.dart` requires every getter to be overridden; in DEBUG mode an un-overridden new key crashes at runtime. Add an `@override` getter for each new key (see existing patterns in that file).
- **T040, T041, T042** Update `lib/app.dart` and `lib/core/routing/app_router.dart`:
  - Register the `AuthBloc` as a top-level `BlocProvider` in `app.dart`.
  - Add routes `/onboarding`, `/login`, `/register`, `/pending`, `/rejected`, `/suspended`, `/home`, `/admin`, `/admin/approvals`, `/reset-password`, plus a Splash route at `/`.
  - **Important**: T041 also creates `lib/features/home/presentation/pages/home_page.dart` (the redirect destination for `AuthState.Authenticated`).
  - Implement the go_router redirect helper: exhaustive switch on `AuthState` to compute destination.
- **T043, T044, T045** AuthBloc + state + event:
  - `lib/features/auth/presentation/bloc/auth_event.dart` (sealed: RegisterRequested, LoginRequested, LogoutRequested, ResetPasswordRequested, SessionRefreshed, ProfileRefreshed, AppResumedRefresh).
  - `lib/features/auth/presentation/bloc/auth_state.dart` (sealed: Unauthenticated, Authenticating, Authenticated(Profile), PendingApproval(Profile), Rejected(Profile, reason), Suspended(Profile), AuthError(AuthFailure)).
  - `lib/features/auth/presentation/bloc/auth_bloc.dart` (subscribe to AuthRepository.sessionStream + ProfileRepository.currentProfileStream; compute destination state from cross-product).

### Phase 3 US1 (T046–T062)

- **T049–T052** Onboarding use case + cubit + splash page + onboarding page.
- **T053–T055** Register / Login / Logout use cases.
- **T056–T060** Register / Login / Pending / Rejected / Suspended pages.
- **T061** AuthBloc event wiring sanity check.
- **T062** **Manual verification on the device** — walks `quickstart.md` Steps 5, 6, 7.

### Phase 4 US4 — Admin queue (T063–T074)

Account-approvals feature (entity, repo interface + impl + datasource, 3 use cases, cubit, page, admin tile wiring on home, route guard, manual verification Steps 8–12).

### Phase 5 US2 — Profile (T075–T080)

Profile use cases + cubit + view + edit pages + nav wiring + manual verification Step 13.

### Phase 6 US3 — Reset password (T081–T084)

Reset use case + page + AuthBloc wiring + manual verification Steps 15–17.

### Phase 7 US5 — Vault PII (T085–T089)

`load_pii` / `update_pii` use cases + ProfileCubit PII state + private profile page + manual verification Step 14.

### Phase 8 — Polish (T090–T098)

End-to-end quickstart walk, advisor sweep, lint, IX import audit, central-helper invariant audit, idempotent re-apply, suspended-mid-session, cleanup, CLAUDE.md drift check.

---

## Notes / gotchas for whoever picks this up

1. **DI registration via `injectable`**: every `@LazySingleton` / `@injectable` annotation I added needs `injection.config.dart` to be regenerated. Run `flutter pub run build_runner build --delete-conflicting-outputs` (or `flutter pub run build_runner watch` while developing) before the app launches; otherwise `getIt<AuthRepository>()` will throw "not registered". The new singletons are: `SupabaseAuthDataSource`, `AuthRepositoryImpl` (as `AuthRepository`), `SupabaseProfileDataSource`, `ProfileRepositoryImpl` (as `ProfileRepository`), `OnboardingSeenStorage`, `OnboardingRepositoryImpl` (as `OnboardingRepository`).

2. **`Failure` loosened from `sealed` to `abstract`**: this is the only edit I made to a Phase 4 file (`lib/core/errors/failure.dart`). Reason: `AuthFailure` and `ProfileFailure` need to extend `Failure` so they slot into `Result<T>`, and Dart's `sealed` keyword requires same-library subclasses. The four existing failure subclasses are unchanged. No call site is affected.

3. **`profile_repository.updateProfile` takes `phone`**: data-model.md §2.1 didn't have it; I added it because the registration flow (FR-002) needs to write the phone after auto-provision creates a NULL phone. The profile-edit page (US2 / T078) MUST NOT pass `phone` in its update payload — phone is read-only there. The DB-level `UNIQUE(phone)` constraint is the second line of defense.

4. **PII RPC return types**: Postgrest returns the function's RETURNS TEXT result as a Dart `String?`. The `app_vault_secret_for_self('private_contact_methods')` returns the JSON-serialized string; the data layer parses it via `jsonDecode` + `PrivateContactMethods.fromJson` (already wired in `profile_repository_impl.dart`).

5. **AuthRepositoryImpl seeds the session controller eagerly**: it emits the current session immediately on construction so subscribers don't miss the initial state. The `@disposeMethod` cleans the subscription up.

6. **`SupabaseClientWrapper.selectRows()` and `.rpc()` are still UnimplementedError stubs**. Phase 5's data layer talks to `supabase.Supabase.instance.client` directly inside `data/datasources/`. That's still Constitution-IX compliant — only files in `data/datasources/` import `package:supabase_flutter`. The wrapper's `authStateChanges()` IS used (Phase 4 wired it).

7. **Edge Function deploy used `verify_jwt: false`**: the reset-password flow is anon-callable by design (the user is signed-out when they request a reset). The function uses the service-role key internally for the privileged `profiles` lookup. The Supabase platform auto-populates `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as env vars on every Edge Function — no manual secret-setting step was needed.

8. **`tasks.md` task IDs have a known ordering wart**: T033 is numerically before T037 but its body depends on T037. Comments in T033 flag this. Read the `**Order:**` line.

9. **Advisor warnings remaining (all expected)**: `set_updated_at` mutable search_path (Phase 4 baseline), `handle_new_auth_user` anon-executable (Phase 4 baseline), 7× authenticated-executable on the user-callable RPCs (intentional — they ARE meant to be callable by authenticated users; admin/self gating is internal).

---

## Quick verification commands you can run

```bash
# Lint (should be clean)
flutter analyze --no-pub

# Once you start running the app:
flutter pub run build_runner build --delete-conflicting-outputs
flutter run

# To check Phase 5 backend health any time:
# (use Supabase MCP via Claude Code)
mcp list_migrations    # expect 12 migrations including 6 Phase 5
mcp get_advisors security
mcp list_edge_functions  # expect request_password_reset ACTIVE
```

---

## Reference docs you'll want open

- `specs/005-auth-profile/spec.md` — FRs, SCs, acceptance scenarios.
- `specs/005-auth-profile/plan.md` — architecture, source-tree layout.
- `specs/005-auth-profile/research.md` — 21 locked decisions (R-01..R-21).
- `specs/005-auth-profile/data-model.md` — concrete SQL + Dart shapes.
- `specs/005-auth-profile/contracts/` — 8 interface contracts.
- `specs/005-auth-profile/quickstart.md` — 20-step end-to-end manual verification recipe.
- `specs/005-auth-profile/tasks.md` — 98-task breakdown (T001–T098).

Good luck. The foundation is solid — analyze passes, the backend is verified live, and every interface is documented. The remaining work is mostly UI scaffolding + DI regen + manual on-device verification.
