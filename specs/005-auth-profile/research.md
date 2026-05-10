# Phase 0 Research — Auth & Profile

This document locks the technical decisions Phase 5 makes (or inherits), with the alternatives considered. Every decision below is stable enough that `/speckit-tasks` can rely on it without re-asking the user. Decisions are numbered R-01..R-21 and referenced from `plan.md` and the `contracts/` folder.

---

## R-01 — Migration filenames, ordering, and the divergence from IMPLEMENTATION_PLAN.md's `0007_…` / `0008_…` hints

**Decision**: Six migration files under `supabase/migrations/` named with Supabase's standard 14-digit-timestamp prefix `<YYYYMMDDhhmmss>_<title>.sql`. Phase 5 uses synthetic-monotonic timestamps `20260510120001` through `20260510120006`, which sort after Phase 4's `20260506120006_enable_vault.sql` and before any future phase's migrations. Migrations 1–5 implement the FR deliverables; migration 6 was added during implementation to close `mcp__supabase__get_advisors` warnings introduced by the SECURITY DEFINER helpers in 1–5 (search_path + anon-executable hardening).

| # | Filename | Purpose |
|---|---|---|
| 1 | `20260510120001_create_account_approval_requests.sql` | `account_approval_status` enum + `account_approval_requests` table + auto-population trigger on `profiles` insert + RLS-enable + bundled policies (FR-003, FR-004, FR-008) |
| 2 | `20260510120002_profiles_add_is_admin.sql` | `profiles.is_admin` BOOLEAN column + extended `enforce_profile_status_admin_only()` to also reject `is_admin` mutations from non-privileged callers (FR-007, FR-009) |
| 3 | `20260510120003_swap_admin_predicate.sql` | `CREATE OR REPLACE FUNCTION current_user_is_admin()` body swap to read `profiles.is_admin` (FR-007, R-12) |
| 4 | `20260510120004_profiles_vault_pii_helpers.sql` | The five SECURITY DEFINER Vault PII helpers (FR-005, FR-006, R-13) |
| 5 | `20260510120005_attach_audit_trigger_account_approval_requests.sql` | Concrete audit trigger on `account_approval_requests` reusing `log_audit()` (FR-010, R-05 reusability invariant) |
| 6 | `20260510120006_phase5_advisor_hardening.sql` | Re-create `current_user_is_admin()` with explicit `SET search_path = public`; `REVOKE EXECUTE … FROM PUBLIC, anon` on the seven Phase-5 SECURITY DEFINER functions; explicit `GRANT EXECUTE … TO authenticated` for the user-callable subset. Closes the `function_search_path_mutable` and `function_anon_executable` advisor warnings introduced by 3/4/5 (Constitution III defense-in-depth; preserves the R-12 central-helper invariant — only the function definition is touched, not any policy file). |

**Rationale**: `docs/IMPLEMENTATION_PLAN.md` Phase 5 names the deliverables `0007_create_account_approval_requests.sql` and `0008_profiles_vault_columns.sql` — those filenames are historical (they predate Phase 4's R-02 lock-in of the 14-digit-timestamp convention) and Phase 4 did not edit them in the implementation plan. Phase 5 uses the timestamp convention so every migration filename in the repository (Phase 1's `00000000000000_init_extensions.sql`, the six Phase 4 migrations, the five Phase 5 migrations) follows one consistent shape and the migration tracker orders them deterministically. Pre-implementation analysis confirmed Supabase MCP's `apply_migration` and `list_migrations` use the timestamped name as the migration identifier in `supabase_migrations.schema_migrations`, so the verify queries in `tasks.md` and `quickstart.md` reference the full timestamped names.

The historical phase-counter names (`0007_…`, `0008_…`) are noted in the `## Notes` section of the per-table doc files (`supabase/docs/account_approval_requests.md`) with a one-liner explaining the convention shift, so a future reviewer searching for `0007` finds the pointer.

The deliberate divergence from the implementation plan's filename hints is recorded here per Constitution XII (No Hidden Product Decisions). Reviewers can still match each Phase 5 migration to its implementation-plan deliverable via the `## Purpose` column above.

**Alternatives considered**:
- Use `0007_…` and `0008_…` to match the implementation plan literally — rejected. Mixing two filename conventions in `supabase/migrations/` is exactly what Constitution XII warns about: it creates a hidden invariant ("when you see a `0NNN_` prefix, it's pre-Phase-4; when you see a 14-digit timestamp, it's Phase-4-or-later") that future agents have to learn from absence-of-documentation. One convention, locked once, is simpler.
- Use real wall-clock timestamps (e.g., `20260510143022_…`) — rejected for the same reason Phase 4 rejected it: synthetic monotonic timestamps are reproducible across reviewers and let the spec name the exact filenames so the `tasks.md` verify queries can be written precisely.

---

## R-02 — Migration application mechanism (inherited from Phase 4 R-01)

**Decision**: Apply every Phase 5 migration to the **remote** Supabase project via Supabase MCP `apply_migration`. There is no local Supabase setup; no `supabase start`, no `supabase db reset`, no `supabase db push` from a local CLI. The repo's `supabase/migrations/` tree is the source of truth (Constitution II). Inspection is done via Supabase MCP `execute_sql`, `list_tables`, `list_migrations`, and `get_advisors`. The Edge Function is deployed via Supabase MCP `deploy_edge_function` and inspected via `get_edge_function` / `list_edge_functions`.

**Rationale**: Phase 4's R-01 locked this. Phase 5 inherits it unchanged — no compelling reason to revisit, and Phase 5 explicitly extends the same remote project Phase 4 already populated. After each `apply_migration` call, the implementer SHOULD run `mcp__plugin_supabase_supabase__get_advisors` with `type: 'security'` to surface any new RLS misconfigurations introduced by that migration; this is a belt-and-suspenders check on top of the policy-bundling discipline.

**Alternatives considered**: Same as Phase 4 R-01 — local Supabase via Docker (rejected per Q5), CLI without local stack (rejected — duplicates MCP), Studio SQL editor (rejected — bypasses the migration tracker).

---

## R-03 — Phone-number value object: hand-rolled Syria-focused validator vs. third-party package

**Decision**: Hand-rolled Syria-focused phone-number value object in `lib/shared/domain/value_objects/phone_number.dart`. Validates and normalizes:

1. Strips whitespace, dashes, parentheses.
2. If input begins with `+963` (Syria explicit) — accept; the remaining digits MUST be 9 digits long (mobile) or match other Syrian formats per `IMPLEMENTATION_PLAN.md` §6.6.
3. If input begins with `0` (Syrian national-format leading-zero) — strip the 0 and prepend `+963`; same length check as (2).
4. If input begins with another country code prefix (`+<digits>`) — accept structurally if the total length is 8–16 digits including the `+`. No country-specific validation for non-Syrian numbers in v1.
5. Otherwise reject with a `PhoneNumberFormatException` whose message is a localization key the UI translates.

The class extends `Equatable`; equality is by the canonical `+963XXXXXXXXX` (or `+CCXXXXXXXXX`) string. No third-party packages are added; the validator is ~50 lines of Dart with no dependencies beyond `package:equatable` (already in `pubspec.yaml`).

**Rationale**: The MVP target is Syrian users (Constitution and `IMPLEMENTATION_PLAN.md` §11) — every v1 phone is `+963…`. Adding `libphonenumber_plugin` (~3 MB native binary per platform) or `phone_number` (which depends on `libphonenumber_plugin` on mobile) for a 50-line Syria-specific validator is excess weight. The value object's API is small enough that Phase 19 (when agencies might enroll non-Syrian phones) can revisit and either extend the hand-rolled validator or swap in a package without touching consumers — the value-object boundary is the swap point.

**Alternatives considered**:
- `libphonenumber_plugin` (Google's port) — rejected. Adds platform-channel weight, requires native code on Android, and the v1 use case is one country.
- `phone_number` Dart package — rejected for the same reason; it's a thin wrapper over `libphonenumber_plugin`.
- Pure-regex validation embedded inline in the auth/profile widgets — rejected. Constitution IX requires phone parsing to be a domain primitive (so future use cases — Phase 16 inquiries' inquirer phone, Phase 19 agency phones — can reuse it without re-implementing).

---

## R-04 — `account_approval_requests` schema and the lifecycle question

**Decision**: One row per user (UNIQUE on `user_id`), narrower lifecycle than `profiles.account_status`. Schema:

```sql
CREATE TYPE account_approval_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE account_approval_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  status          account_approval_status NOT NULL DEFAULT 'pending',
  rejection_reason TEXT NULL,
  reviewed_by     UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at     TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

The auto-population trigger fires on `AFTER INSERT ON profiles` (NOT on `auth.users`) — because Phase 4's auto-provision trigger creates `profiles` from `auth.users`, the request-row creation runs after the profile exists, which means the FK to `profiles.user_id` (transitively to `auth.users.id`) is guaranteed populated. The trigger uses `INSERT … ON CONFLICT (user_id) DO NOTHING` for idempotency under concurrent retries.

The `account_approval_status` enum is **narrower** than `profiles.account_status` (which has `pending`, `approved`, `rejected`, `suspended`, `deleted`) — by design, per the Session 2026-05-10 queue-scope clarification. Suspending an approved user does NOT change `account_approval_requests.status`; the request row stays at `approved` while `profiles.account_status` flips to `suspended` (out-of-band via privileged SQL in Phase 5; via Phase 7's super-admin UI in v1.x). Rejecting a previously-approved user is also out of scope for Phase 5 — rejections only apply on first review.

**Rationale**: A single canonical lifecycle field per concern. `profiles.account_status` tracks "what is this user's overall account state" (which can flip many ways — suspend/un-suspend/delete); `account_approval_requests.status` tracks "what was the outcome of the admin's first-time review of this user's registration" (immutable after the first decision in Phase 5; Phase 7's super-admin UI may add a "reopen rejection" path later).

The narrower enum forces the implementation to keep the two concerns distinct — code that reads the queue cannot accidentally short-circuit to "this user is currently approved" by looking only at the request row, because `account_status` may have moved on independently.

**Alternatives considered**:
- Reuse `profiles.account_status` enum (the wider one) on the request table — rejected. Conflates first-review-outcome with current-state. The first-review record is historical; the current state is mutable. Two different concerns deserve two different enums.
- Separate table per status (e.g., `pending_requests`, `approved_users`, `rejected_users`) — rejected as Constitution-XII level over-engineering for the one-row-per-user case.
- Trigger fires on `auth.users` insert (skipping the `profiles` indirection) — rejected. Phase 4's auto-provision trigger already runs on `auth.users` insert; piggybacking another side-effect on the same trigger function would couple two concerns. Firing on `profiles` insert keeps the auto-provision trigger Phase-4-frozen and makes the request-row creation a Phase-5-owned trigger that Phase 7 can later evolve without touching Phase 4 code.

---

## R-05 — Audit trigger reuses Phase 4's `log_audit()` unchanged

**Decision**: The concrete audit trigger on `account_approval_requests` is created via:

```sql
DROP TRIGGER IF EXISTS trg_account_approval_requests_audit_status ON account_approval_requests;
CREATE TRIGGER trg_account_approval_requests_audit_status
  AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at
  ON account_approval_requests
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    OR OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason
    OR OLD.reviewed_by IS DISTINCT FROM NEW.reviewed_by
    OR OLD.reviewed_at IS DISTINCT FROM NEW.reviewed_at
  )
  EXECUTE FUNCTION log_audit(
    'account_approval.status_changed',
    'status,rejection_reason,reviewed_by,reviewed_at',
    'user_id'
  );
```

The function `log_audit()` is Phase 4's reusable trigger function — Phase 5 does NOT modify it (Phase 4 contract `contracts/log-audit-trigger-fn.md` declares the function v1-stable). Phase 5's third `TG_ARGV` arg is `'user_id'`, matching the table's PK-equivalent column for audit-target purposes (the row's `id` is a synthetic UUID; `user_id` is the meaningful target a reviewer cares about).

**Rationale**: Phase 4's reusability invariant is the bedrock of the audit infrastructure. Every later phase that adds an audit-worthy table reuses `log_audit()` unchanged — Phase 5 is the first such reuse and validates the design. The `WHEN` clause prevents no-op `UPDATE` statements (e.g., a re-touch that doesn't change the watched columns) from emitting spurious audit rows.

**Alternatives considered**:
- Write a Phase-5-specific audit function — rejected. Phase 4's contract is binding and the function was designed for exactly this case.
- Skip the `WHEN` clause — rejected. Without it, every `UPDATE … SET updated_at = now()` would emit an audit row, polluting the log. The `WHEN` clause is a Postgres-native feature (not a workaround) that aligns the audit emission with the actual semantic change.

---

## R-06 — Synthetic-email helper location and visibility

**Decision**: The synthetic-email helper is a package-private Dart function in the auth feature's data layer:

```dart
// lib/features/auth/data/internal/synthetic_email.dart
// Package-private — NOT exported from lib/features/auth/auth.dart
String syntheticEmailFor(PhoneNumber phone) => '${phone.e164}@alnujom.local';
```

The file lives under `data/internal/` (a sibling of `data/datasources/` and `data/repositories/`) and is intentionally not re-exported from any barrel file. Only the auth feature's data-layer files (`supabase_auth_datasource.dart`, the Edge Function's TypeScript counterpart) construct synthetic emails. The domain layer takes a `PhoneNumber` value object and never sees the synthetic email.

**Rationale**: The synthetic email is a Supabase-Auth-imposed identifier shape — it is concretely a workaround for Supabase Auth requiring a unique email per user. Constitution IX (Future Backend Portability) requires Supabase-specific shapes to live in `data/`; a domain-layer synthetic-email helper would leak the Supabase coupling to the use cases. Putting it in `data/internal/` (not `data/datasources/`) signals it is even narrower than a data source — it is private machinery used by the data source and the Edge Function only.

The Edge Function (TypeScript) defines its own equivalent helper inline (or imports a shared TS file under `supabase/functions/_shared/synthetic_email.ts` if a future Edge Function also needs it; Phase 5 has only one Edge Function so the TS helper is inlined in `index.ts` for now). The Dart and TS helpers MUST agree on the format string `<E.164>@alnujom.local` — both are documented in `contracts/auth-repository.md`.

**Alternatives considered**:
- Helper lives in domain (`lib/features/auth/domain/usecases/synthetic_email.dart`) — rejected. The synthetic email is a leaked-from-data concept; domain shouldn't know about email shape at all.
- Helper lives in `lib/shared/` (cross-feature) — rejected. Only the auth feature constructs synthetic emails; sharing it widens the surface unnecessarily.
- Inline the helper in `supabase_auth_datasource.dart` directly (no separate file) — rejected. Three call sites (signUp, signInWithPassword, the Edge Function's TS equivalent) want one source-of-truth definition. The separate file makes the format string a single named constant.

---

## R-07 — `request_password_reset` Edge Function: necessity and divergence from the implementation plan

**Decision**: Phase 5 ships **one** Edge Function — `supabase/functions/request_password_reset/index.ts` — to satisfy FR-017's account-enumeration resistance on the reset-password flow.

Function shape:

- **Trigger**: HTTP POST `request_password_reset` with `{phone: string}` body.
- **Auth**: anonymous (the reset flow runs before the user is signed in).
- **Body**:
  1. Normalize the phone via the same E.164 logic as the Dart `PhoneNumber` value object (TS port; small enough to inline).
  2. Open a service-role-key Supabase client (`Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`).
  3. `SELECT email FROM profiles WHERE phone = $1` — bypassing RLS via the service role.
  4. If the row exists AND `email IS NOT NULL` AND non-empty: call `supabase.auth.admin.resetPasswordForEmail(email)`.
  5. **Always** return `200 OK` with body `{ok: true}` regardless of whether step 4 actually fired. No timing-side-channel mitigation in v1 (the latency difference between "RPC fired" and "RPC not fired" is small in practice; if Phase 24's release-polish pass identifies it as a real concern, that pass adds a fixed-delay).

**Rationale — necessity**: FR-017 explicitly requires the reset-password user-facing copy to be identical for "phone known with email", "phone known without email", and "phone unknown". A pure-client implementation cannot achieve this without leaking via either (a) an RPC return-value side channel ("does this phone have an email?") or (b) a network-observable difference in whether the Supabase Auth reset-email API is invoked. An Edge Function is the simplest place to encapsulate the lookup-then-conditional-reset on the server side, making the response uniform.

**Rationale — divergence**: `docs/IMPLEMENTATION_PLAN.md` says Phase 7 ships the first Edge Function (`mutate_role`). Phase 5 ships an earlier one. The divergence is recorded in `plan.md` Constraints + Constitution Check VII / XII, in this research document, and in `quickstart.md`'s deployment step. The implementation plan's intent was that Phase 5 has no Edge Function need — that intent is invalidated by FR-017's clarified account-enumeration resistance posture, which the implementation plan did not yet account for. Per Constitution XII, the divergence must be (a) chosen, (b) justified, (c) recorded — done in this R-07.

**Alternatives considered**:
- Pure-client lookup via a public RPC `lookup_reset_target(phone) RETURNS BOOLEAN` — rejected. Even returning a boolean leaks information; the network observer learns "phone known with email" vs. "anything else", which is a partial enumeration leak.
- Always call `resetPasswordForEmail(synthetic_email)` — rejected. The synthetic mailbox doesn't exist; the reset email is undeliverable; users with a real email on file (FR-017's happy path) wouldn't receive their reset link.
- Defer the reset-password feature to Phase 7 — rejected. FR-017 + FR-001's "optional real email field" require a working reset path in v1; users who lock themselves out of their account on day 1 cannot wait for Phase 7.
- Use Supabase's built-in `pgsodium`-protected admin RPC pattern — rejected. The pattern doesn't compose with `auth.admin.resetPasswordForEmail` cleanly; the Edge Function is the canonical Supabase pattern for "client makes an authentic-looking request, server does privileged work then returns a uniform response".

---

## R-08 — Password policy and Supabase Auth project setting

**Decision**: 8-character minimum, no complexity requirements (no mandatory letter/digit/symbol mix), no maximum below the platform's hard limit. Two enforcement layers:

1. **App-side validator**: in `lib/features/auth/presentation/pages/register_page.dart` and `reset_password_page.dart`, the password input rejects values with fewer than 8 characters and surfaces a localized error "Password must be at least 8 characters" (Arabic + English ARB keys).
2. **Project-side setting**: Supabase project `auth.minimum_password_length` is configured to `8`. This is set via `supabase/config.toml` if the local CLI is used (Phase 5 does not use the local CLI per R-02), or via the Supabase project's Auth settings dashboard / Supabase MCP (the platform exposes this via project-level config, not a SQL migration). The setting's location is documented in `quickstart.md` Step "Pre-flight Auth config".

**Rationale**: Per the Session 2026-05-10 password-policy clarification. Defense-in-depth: app-side validator gives instant feedback; project-side setting catches client bypass attempts.

**Alternatives considered**: See the Session 2026-05-10 clarification options A/B/C/D in `spec.md` `## Clarifications` — option A (8 min, no complexity) was chosen.

---

## R-09 — BLoC vs Cubit per feature

**Decision**: Per Constitution IV's "default to BLoC/Cubit; Cubit for simpler local state":

| Feature | Choice | Reason |
|---|---|---|
| `lib/features/auth/` | **BLoC** | Multiple discrete events (RegisterRequested, LoginRequested, LogoutRequested, ResetPasswordRequested, SessionRefreshed, ProfileRefreshed) and a multi-state state machine (Unauthenticated, Authenticating, Authenticated, PendingApproval, Rejected, Suspended, AuthError). Events warrant an event-shaped store. |
| `lib/features/profile/` | **Cubit** | Linear flow: load → display → edit → save. No event-shaped behavior. |
| `lib/features/onboarding/` | **Cubit** | Trivial: step counter + a "mark seen" emission. |
| `lib/features/admin/account_approvals/` | **Cubit** | Load-list, mutate-row, reload-list. Two methods (`approve`, `reject`); state transitions are local. |

**Rationale**: BLoC's event-driven shape pays off when discrete user/system events drive non-trivial state transitions. Cubit's method-driven shape is simpler when the state is computed from a small set of inputs and the transitions are local.

**Alternatives considered**:
- Use BLoC everywhere — rejected. Constitution IV explicitly permits Cubit for simpler state; using BLoC for `onboarding/` (one state, one method) is over-engineered.
- Use Cubit everywhere — rejected. The auth state machine has enough event-driven branching that a BLoC reads more clearly.

---

## R-10 — Onboarding-seen flag location

**Decision**: Persisted in `flutter_secure_storage` (via Phase 1's existing wrapper) under key `onboarding_seen_v1`. The key is namespaced with the `_v1` suffix so a future onboarding redesign (Phase 24+ release polish, or a v2 product change) can use a different key and re-show onboarding without colliding with old installs.

**Rationale**: The flag is per-device-install, not per-account. Storing it on the server-side `user_preferences` row would require either showing onboarding on every fresh install regardless of prior accounts, or storing onboarding-seen in a per-device row keyed by some device id (which Phase 5 doesn't have). Local secure storage is simpler.

**Alternatives considered**:
- Store on `user_preferences` — rejected per the analysis above.
- Store in `SharedPreferences` (non-secure) — rejected. Constitution III's security baseline favors `flutter_secure_storage` for any persisted client state when the wrapper already exists; the marginal performance cost is irrelevant for one boolean read on app start.

---

## R-11 — Locale handoff implementation: where the device-side value crosses to the server

**Decision**: The device-side locale crosses to the server **inside the registration use case itself**, as a single-shot post-signup write. There is no client-side "first-sign-in" sentinel flag. The flow:

1. User completes onboarding, picks a locale (or accepts `'ar'` default). The choice is persisted in `flutter_secure_storage` via Phase 3's existing `LocaleCubit`.
2. User opens the registration form (locale is whatever the LocaleCubit currently resolves to).
3. User submits. The `Register` use case in `lib/features/auth/domain/usecases/register.dart`:
   1. Calls `auth_repository.register(phone, password, optionalRealEmail)` → triggers Supabase Auth's `signUp` → triggers Phase 4's auto-provision trigger → creates `profiles` + `user_preferences` (with default `locale='ar'`) + the Phase 5 auto-population trigger creates `account_approval_requests` (status `pending`).
   2. Reads the device-side locale from the LocaleCubit (or directly from secure_storage if the cubit hasn't propagated yet).
   3. Calls `profile_repository.updateLocale(deviceLocale)` → `UPDATE user_preferences SET locale = $1 WHERE user_id = auth.uid()` → server now reflects the user's choice.
4. On every subsequent authenticated sign-in, the auth bloc reads `user_preferences.locale` and pushes it to both `flutter_secure_storage` and the LocaleCubit. **Server wins.**
5. The in-app locale picker (Phase 3's LocaleCubit, now wired through to a use case in `profile_repository.updateLocale`) writes to **both** `user_preferences` (durable) AND `flutter_secure_storage` (offline cache). Both stores stay coherent.

The "first sign-in wins device-side" invariant from the Session 2026-05-10 clarification is realized by step 3 above — the registration use case IS the first authenticated sign-in moment, so the device's locale is durably written then.

**Rationale — why no sentinel flag**: A client-side flag like `locale_synced_to_server` would have to handle:
- Sign-in on a second device (user A's flag is unset on the new device → device-side push wins → overwrites their actual prior choice). Bad.
- Account switching on the same device (user B signs in after user A signs out → flag is set from user A's session → server wins for user B → ignores B's onboarding choice). Bad.
- Re-install on the same device (flag wiped → device-side push wins → may overwrite the user's prior choice). Bad.

Putting the device-side push at the registration moment avoids all three: it fires exactly once per user creation, not per sign-in, so no per-device flag is needed.

**Alternatives considered**:
- Per-device sentinel flag in secure_storage — rejected per the analysis above.
- Per-account-per-device flag (key like `locale_synced_to_server.<user_id>`) — rejected as kludge with no real-world advantage over the registration-time push.
- Always-server-wins-on-login (skip the registration push) — rejected. A user who picked English on onboarding and then registered would land on Arabic post-signup because `user_preferences.locale` defaults to `'ar'`. The Session 2026-05-10 clarification explicitly preserves the "device wins on first sign-in" invariant.

---

## R-12 — `current_user_is_admin()` body swap is a single statement

**Decision**: The body swap migration is one statement:

```sql
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
$$;
```

The migration `20260510120003_swap_admin_predicate.sql` contains only this `CREATE OR REPLACE FUNCTION` plus a header comment naming the contract (`contracts/admin-predicate-v5.md`). No policy file is edited (Phase 4's R-05 invariant is preserved).

**Rationale**: The `COALESCE(…, FALSE)` handles the case where a user has no `profiles` row (impossible in normal operation — Phase 4's auto-provision trigger guarantees one — but defense-in-depth costs nothing). `LANGUAGE SQL STABLE` matches the Phase 4 placeholder's language and volatility, so the swap is purely body-level and call-site behavior changes from "always false" to "true iff is_admin".

The body deliberately does NOT use `SECURITY DEFINER`. Reason: every caller of `current_user_is_admin()` is itself a SECURITY INVOKER policy (or a SECURITY DEFINER function whose owner has the same `auth.uid()` semantics). Adding SECURITY DEFINER would change the `auth.uid()` resolution context inside the helper and is unnecessary because the only thing the helper reads is `profiles.is_admin` for the calling user — RLS on `profiles` already permits the user to read their own row.

**Alternatives considered**:
- Use `SECURITY DEFINER` — rejected per the analysis above.
- Inline the body into every policy that needs it — rejected. That's exactly the policy-rewrite pattern Phase 4's R-05 invariant forbids.
- Use a triggered cached column on `profiles` (e.g., `cached_is_admin`) — rejected. Adds complexity for no perf benefit at MVP scale.

---

## R-13 — Vault PII helper signatures and the SECURITY DEFINER pattern

**Decision**: Five SECURITY DEFINER SQL functions in `20260510120004_profiles_vault_pii_helpers.sql`. All five validate `field_name` against the allowlist `{legal_name, national_id, private_contact_methods}`; the contact-methods setter additionally validates the JSON keys against `{whatsapp, telegram, signal, private_email, secondary_phone}`.

```sql
-- Read self
CREATE OR REPLACE FUNCTION app_vault_secret_for_self(field_name TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN NULL; END IF;
  IF field_name NOT IN ('legal_name', 'national_id', 'private_contact_methods') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN app_vault_secret(format('pii.%s.%s', uid, field_name));
END;
$$;

-- Read admin
CREATE OR REPLACE FUNCTION app_vault_secret_for_user(p_user_id UUID, field_name TEXT)
  RETURNS TEXT
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  IF NOT current_user_is_admin() THEN RETURN NULL; END IF;
  IF field_name NOT IN ('legal_name', 'national_id', 'private_contact_methods') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  RETURN app_vault_secret(format('pii.%s.%s', p_user_id, field_name));
END;
$$;

-- Write self (TEXT-typed fields: legal_name, national_id)
CREATE OR REPLACE FUNCTION app_vault_set_secret_for_self(field_name TEXT, p_value TEXT)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  uid UUID := auth.uid();
  secret_name TEXT;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501'; END IF;
  IF field_name NOT IN ('legal_name', 'national_id') THEN
    RAISE EXCEPTION 'use app_vault_set_private_contact_methods_for_self for private_contact_methods, or invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.%s.%s', uid, field_name);
  -- vault.create_secret is idempotent on (name): inserts or updates per Supabase platform.
  PERFORM vault.create_secret(p_value, secret_name, 'AlNujom PII per-user-per-field');
END;
$$;

-- Write admin (TEXT-typed fields)
CREATE OR REPLACE FUNCTION app_vault_set_secret_for_user(p_user_id UUID, field_name TEXT, p_value TEXT)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  secret_name TEXT;
BEGIN
  IF NOT current_user_is_admin() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501'; END IF;
  IF field_name NOT IN ('legal_name', 'national_id') THEN
    RAISE EXCEPTION 'invalid field_name: %', field_name USING ERRCODE = '22023';
  END IF;
  secret_name := format('pii.%s.%s', p_user_id, field_name);
  PERFORM vault.create_secret(p_value, secret_name, 'AlNujom PII per-user-per-field (admin write)');
END;
$$;

-- Write self for private_contact_methods (JSON-typed; keys allowlisted)
CREATE OR REPLACE FUNCTION app_vault_set_private_contact_methods_for_self(p_methods JSONB)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public, vault
AS $$
DECLARE
  uid UUID := auth.uid();
  secret_name TEXT;
  k TEXT;
  ALLOWED CONSTANT TEXT[] := ARRAY['whatsapp','telegram','signal','private_email','secondary_phone'];
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501'; END IF;
  IF jsonb_typeof(p_methods) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'private_contact_methods must be a JSON object' USING ERRCODE = '22023';
  END IF;
  FOR k IN SELECT jsonb_object_keys(p_methods) LOOP
    IF k <> ALL(ALLOWED) THEN
      RAISE EXCEPTION 'unknown channel key: %', k USING ERRCODE = '22023';
    END IF;
  END LOOP;
  secret_name := format('pii.%s.private_contact_methods', uid);
  PERFORM vault.create_secret(p_methods::TEXT, secret_name, 'AlNujom PII private_contact_methods JSON');
END;
$$;
```

**Rationale**:
- SECURITY DEFINER lets the functions read/write `vault.secrets` (which the calling user's role typically cannot) while preserving `auth.uid()` resolution for the caller — exactly the "authenticated user can manage their own PII" pattern.
- Validating `field_name` against an allowlist inside the function ensures a malicious caller cannot construct arbitrary secret names like `pii.<other_user>.legal_name` (the calling user is forced to be `auth.uid()` for self-helpers; admins go through the explicit `for_user` variant which gates on `current_user_is_admin()`).
- The contact-methods setter is a separate function (not a flag on the generic setter) because its value type is JSONB and its validation logic (key allowlisting) is different. Keeping it separate makes the contract clearer for the data-layer caller.
- `vault.create_secret(value, name, description)` is idempotent on `name` per the Supabase Vault docs — second calls update the value. So the same function handles both create and update cases without an explicit `update_secret` branch.
- The SQL `format('pii.%s.%s', uid, field_name)` is safe (UUID + allowlisted field name; no user input concatenation that could escape the format string).

**Alternatives considered**:
- One generic setter with a discriminator argument — rejected. The signature would be `set_secret_for_self(field_name TEXT, value JSONB)` which forces TEXT callers to JSON-encode the string. Adds a marshaling layer for no clarity benefit.
- Bypass `app_vault_secret` (Phase 4's read helper) and call `vault.decrypted_secrets` directly — rejected. The Phase 4 contract is a stable read interface; using it preserves a single read path that future phases can monitor.
- Edge Function for the write path (consume service role from the function runtime) — rejected. SECURITY DEFINER SQL is the simpler, faster, and lower-attack-surface mechanism for "user manages their own PII" — no service role in the data path, no extra Deno deploy step. The reset-password Edge Function (R-07) is justified by FR-017's enumeration-resistance requirement; the Vault PII path has no such requirement.

---

## R-14 — Approve / reject atomic update path

**Decision**: Two Postgrest `update` calls wrapped in a single Supabase RPC (a SECURITY DEFINER SQL function `approve_account_approval_request(p_user_id UUID)` and `reject_account_approval_request(p_user_id UUID, p_reason TEXT)`).

Approve:

```sql
CREATE OR REPLACE FUNCTION approve_account_approval_request(p_user_id UUID)
  RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  IF NOT current_user_is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  UPDATE account_approval_requests
  SET status = 'approved',
      rejection_reason = NULL,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  WHERE user_id = p_user_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no pending request for user_id %', p_user_id USING ERRCODE = '02000';
  END IF;

  UPDATE profiles
  SET account_status = 'approved',
      updated_at = now()
  WHERE user_id = p_user_id AND account_status = 'pending';

  -- profile UPDATE may match 0 rows if the user was already approved out-of-band; that's not an error.
END;
$$;
```

Reject is structurally similar with `status = 'rejected'` and `rejection_reason = p_reason` (NOT NULL CHECK at the SQL level).

**Rationale**:
- Both UPDATEs in one transaction: a partial failure (e.g., the profile UPDATE fails for some constraint reason) rolls the request UPDATE back automatically. The audit trigger fires once per affected table per the standard PG semantics.
- SECURITY DEFINER + `current_user_is_admin()` check inside the function: the policy on `account_approval_requests` for UPDATE could also enforce admin-gating, but routing through the RPC gives one auditable boundary and lets the function fail-fast with a clear error message instead of an empty WHERE result.
- The `IF NOT FOUND` raises a recognizable Postgres `'02000'` (no_data) error code — the data layer maps this to a domain `RequestAlreadyResolved` failure type so the Cubit can refresh the queue without a generic error.
- The `account_status = 'pending'` guard on the profile UPDATE: prevents an out-of-band admin action (e.g., a Phase-7 super-admin UI that flips an approved user back to pending and back to approved while we're processing a stale queue row) from being silently overwritten.

**Alternatives considered**:
- Two separate Postgrest `update` calls from the client — rejected. Not atomic; a network hiccup between them leaves the system in a half-state.
- Edge Function for the approve/reject path — rejected. SECURITY DEFINER SQL with admin-gating is the lighter pattern; no service role needed; matches Phase 7's planned `mutate_role` Edge-Function shape but cheaper for the same problem class.

---

## R-15 — Synthetic-email collision = phone uniqueness

**Decision**: Phase 5 does not add an explicit duplicate-phone check at registration time. Two enforcement layers absorb collisions:

1. **Supabase Auth `auth.users.email` UNIQUE**: at `signUp` time, two clients submitting the same E.164 phone construct the same synthetic email. The first signUp succeeds; the second fails with Supabase's "user already registered" error. The data source maps this to a domain `AccountAlreadyExists` failure.
2. **`profiles.phone` UNIQUE** (Phase 4): belt-and-suspenders. If somehow two rows reach `profiles` with the same phone (e.g., a test fixture skips Auth), the second hits the unique-violation.

**Rationale**: The synthetic-email-derives-from-phone design makes Supabase Auth's existing email-uniqueness check do double duty as phone-uniqueness enforcement. No extra Phase 5 code. The Phase 4 `profiles.phone UNIQUE` is preserved for the fixture/non-Auth path.

**Alternatives considered**:
- Pre-check `profiles` for the phone before calling `signUp` — rejected. Race-prone (two near-simultaneous registrations could both pass the pre-check) and adds a network round-trip. Auth's unique check is atomic.
- Drop `profiles.phone UNIQUE` because Auth covers it — rejected. The Phase 4 contract guarantees the unique constraint; removing it would invalidate Phase 4's spec and create drift.

---

## R-16 — Reset-password account-enumeration resistance: the Edge Function justification

**(See R-07 above.)** Logged here as a separate research line item because it is the most consequential Phase 5 deliverable that diverges from the implementation plan, and downstream phases (Phase 7 `mutate_role`, Phase 22 push-notification fan-out) will consume the Edge Function deployment pattern Phase 5 establishes (`supabase/functions/<name>/{deno.json,index.ts}` checked into the repo + deployed via Supabase MCP `deploy_edge_function`).

---

## R-17 — Profile-edit input validation rules

**Decision**: Validation lives in the domain layer (`lib/features/profile/domain/usecases/update_profile.dart`). Rules:

| Field | Rule | On violation |
|---|---|---|
| `full_name` | Trimmed length 1–100 chars (UTF-8 char count, not bytes) | Domain `InvalidFullName` failure |
| `username` | Lowercase only; `[a-z0-9_]` charset; length 3–30 | Domain `InvalidUsername` failure |
| `username` (uniqueness) | Postgres unique-violation `'23505'` on `profiles_username_key` | Maps to domain `UsernameTaken` failure |
| `email` | Optional. If provided, basic RFC-5322-shape regex (`^[^@\s]+@[^@\s]+\.[^@\s]+$`); trimmed; lowercase | Domain `InvalidEmail` failure |
| `avatar_url` | Optional. Must be a valid `Uri.parse`-able HTTPS URL or NULL | Domain `InvalidAvatarUrl` failure |

`account_status` and `publisher_status` are NOT in the edit form — they are not exposed to the client at all; the database trigger is the second line of defense (FR-009).

**Rationale**: Domain-layer validation keeps UI consistent (the same rules apply whether the value comes from the edit page, a deep link, or a future use case) and makes the rules testable as data — `tasks.md` doesn't add new tests, but the validation rules are self-evident from the use-case file.

**Alternatives considered**:
- Server-side regex constraints on `profiles.username` — rejected for now. Adds DDL surface area for marginal benefit; the client validator is the primary gate and the unique index is the only DB-level invariant Phase 5 relies on for correctness.
- Allow uppercase usernames — rejected. Case-sensitive uniqueness produces the "is `Hekmat` the same as `hekmat`?" UX confusion. Lowercase-only is simpler and matches modern social conventions.

---

## R-18 — `AuthBloc` state machine

**Decision**:

```dart
sealed class AuthState extends Equatable {
  const AuthState();
}

class Unauthenticated extends AuthState { ... }
class Authenticating extends AuthState { ... }
class Authenticated extends AuthState { final Profile profile; ... }       // profile.account_status == 'approved'
class PendingApproval extends AuthState { final Profile profile; ... }     // profile.account_status == 'pending'
class Rejected extends AuthState { final Profile profile; final String reason; ... }
class Suspended extends AuthState { final Profile profile; ... }
class AuthError extends AuthState { final AuthFailure failure; ... }
```

Events:

```dart
sealed class AuthEvent { ... }
class RegisterRequested(...);
class LoginRequested(...);
class LogoutRequested();
class ResetPasswordRequested(...);
class SessionRefreshed(Session? session);  // emitted by the Phase 4 authStateChanges() subscription
class ProfileRefreshed(Profile profile);   // emitted on app foreground or after profile mutations
```

The bloc subscribes to:
1. `AuthRepository.sessionStream` — feeds `SessionRefreshed` events.
2. `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` — feeds a "re-load profile" command (the bloc dispatches `ProfileRefreshed` after a `profile_repo.getCurrentProfile()` call). This handles the "Suspended user mid-session" edge case from `spec.md` — when the user returns to the app, the bloc re-reads `account_status` and routes them to the suspension screen if the admin flipped them while they were away.

**Rationale**: The state machine maps 1:1 to the post-login destination screens (US 1 acceptance scenarios). Sealed-class state means exhaustive `switch` in the go_router redirect helper, making "where should this user be?" decisions a compile-time check.

**Alternatives considered**:
- Single `AuthState` class with nullable fields (`session?`, `profile?`, `failure?`) — rejected. Sealed classes are the Constitution-IV-aligned shape and remove the "unwrap nullable" branching.
- Separate `SessionBloc` + `ProfileBloc` — rejected. The auth flow's destination screen depends on BOTH session and profile.account_status, so coupling them into one bloc avoids cross-bloc orchestration.

---

## R-19 — First-admin bootstrap process

**Decision**: Manual one-time SQL action via Supabase MCP `execute_sql`:

```sql
UPDATE profiles SET is_admin = true WHERE phone = '+9639XXXXXXXX';
```

Documented in `quickstart.md` Step "Bootstrap the first admin". No in-app affordance to flip `is_admin` in Phase 5 — the row is mutable only by the privileged-role bypass (Phase 4 R-12 trigger lists `postgres` as bypassable).

**Rationale**: The first admin must exist before the queue page is reachable for testing. Phase 7 ships the super-admin UI for managing admins (assign / revoke); Phase 5's bootstrap is one row, one time.

**Alternatives considered**:
- Hardcode an `is_admin = true` row in `supabase/seed.sql` — rejected. The seed file is applied to every fresh project; pre-seeding admin rights to a real user account ID requires knowing the UUID at seed-write time, which is fragile.
- Add an environment-variable-driven seeding step — rejected. Adds tooling for a one-time action.

---

## R-20 — `account_approval_requests.id` PK is UUID

**Decision**: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`. Matches Phase 4's R-11 convention for `audit_logs.id`. The natural-key alternative (`user_id` as PK) is also UNIQUE-constrained on the table (so it works as an identity for queries), but the synthetic UUID PK leaves room for the (post-v1) "re-application history" pattern where one user might have multiple historical request rows.

**Rationale**: Consistency with Phase 4's table convention. UUID PKs let later phases (Phase 7 super-admin UI's "reopen a rejection" path) add new rows for the same user without violating a `user_id PRIMARY KEY` constraint. The current `UNIQUE (user_id)` constraint is the v1 invariant; Phase 7 may relax it to a partial unique index `WHERE status = 'pending'`.

**Alternatives considered**:
- `user_id` as PK — rejected per the analysis above.
- `BIGSERIAL` / `BIGINT GENERATED ALWAYS AS IDENTITY` — rejected. UUIDs are `pg_dump`-friendly across environments and avoid the merge-collision pain that surfaces when two environments both autoincrement.

---

## R-21 — Stale-session detection on suspension

**Decision**: Phase 5 detects out-of-band suspension on app foreground only — not real-time. The `AuthBloc` subscribes to `WidgetsBindingObserver.didChangeAppLifecycleState`; on `resumed` (app brought back to foreground), the bloc dispatches a `ProfileRefreshed` request that re-reads `profiles` via `ProfileRepository.getCurrentProfile()`. If `account_status` has changed (most likely from `approved` → `suspended` by an out-of-band admin action), the bloc re-emits the appropriate state and the go_router redirect routes the user to the suspension screen.

Real-time suspension push (Supabase Realtime channel on `profiles` for the user's own row) is **out of scope for Phase 5** — it lands with Phase 22's push-notification realtime infrastructure. The trade-off is that a user actively using the app between admin-suspends and next-foreground does not see the suspension screen until they next leave and return; their database actions, however, are still gated by RLS policies that downstream phases will tie to `account_status` so any publishing-relevant action will fail at the database.

**Rationale**: Foreground-refresh covers 95% of the realistic scenarios (an admin suspends a user, the user opens the app some time later) without the complexity of a realtime subscription. Phase 22 introduces the realtime channels project-wide; bundling Phase 5's suspension push into that phase preserves the "one phase introduces the realtime infrastructure" property.

**Alternatives considered**:
- Subscribe to `profiles` realtime channel for the user's own row — rejected for Phase 5; deferred to Phase 22.
- Poll `profiles.account_status` every N seconds — rejected. Wasteful; foreground-refresh is sufficient.
- Tie suspension to a session-revocation step (admin sets suspended → background job revokes Supabase Auth session) — rejected for v1. Adds a moving piece that has to coordinate with the auto-refresh token flow; not worth the Phase 5 complexity budget.

---

## R-22 — Reuse `Result<T>` instead of introducing `Either<L, R>`; loosen `Failure` base class

**Decision**: Phase 5 reuses the project's existing `Result<T>` / `FailureResult<T>` types from `lib/core/errors/` (introduced by earlier phases) as the repository return shape. The new file `lib/shared/domain/result.dart` originally proposed by tasks.md T025 is **not created**. Wherever `data-model.md` §2.4 and the auth/profile repository contracts use `Either<AuthFailure, T>` / `Either<ProfileFailure, T>`, the actual implementation uses `Result<T>` with the typed failure subclass surfaced via `FailureResult<T>(failure: AuthFailure | ProfileFailure)`. The contract documents (`contracts/auth-repository.md` L58, `contracts/profile-repository.md`) explicitly permit this swap ("raw nullable + typed failure is equivalent — keep the explicit `Either` to avoid sentinel-value ambiguity, but `Result<T>` is acceptable").

To make `Result<T>` carry feature-typed failures, `lib/core/errors/failure.dart`'s base class is loosened from `sealed class Failure` to `abstract class Failure`. This is the **only Phase 4 file Phase 5 edits**. The four existing `final class` failures (`NetworkFailure`, `CacheFailure`, `ConfigFailure`, `UnknownFailure`) keep their `final` modifier and their bodies are unchanged; no Phase 4 call site references the `sealed` modifier (verified by `grep`). `AuthFailure` and `ProfileFailure` then `extends Failure` so they slot into `Result<T>` natively.

**Rationale**: Adding a parallel `Either<L, R>` hierarchy when a working `Result<T>` already exists is duplicate plumbing — the two types model the same domain shape (success + typed failure). Phase 5 chose the simpler path during implementation. The `sealed` → `abstract` loosening is a single-keyword edit with zero behavioral side-effects (Dart's `sealed` keyword only restricts where subclasses can be declared, not how the type behaves at runtime); the cost is that consumers of `Failure` can no longer rely on exhaustive `switch` over the four built-in subclasses. In practice none do — `Failure` is consumed via `is`-checks at the presentation layer.

**How this affects spec/plan/contracts**: `data-model.md` §2.4 + the two repository contracts' `Either<L, R>` examples are read as illustrative of the shape, not literal — see this R-22 decision for the actual chosen type. The footer note in `auth-repository.md` L58 is now load-bearing, not optional.

**Alternatives considered**:
- Add `dartz` as a dependency for `Either<L, R>` — rejected. New runtime package for one type, when the project already has an equivalent. `pubspec.yaml` is locked at zero new packages for Phase 5.
- Hand-roll `lib/shared/domain/result.dart` with `Either` + `Unit` aliases (the original T025 plan) — rejected during implementation. Would have required mapping `Result<T>` ↔ `Either<L, R>` at data-source boundaries; pointless duplication.
- Keep `Failure` as `sealed` and have `AuthFailure` / `ProfileFailure` NOT extend it (use a parallel hierarchy) — rejected. The presentation layer's error-display widgets are written against `Failure`; bypassing them for feature failures would require a parallel error-display path.

---

## Inherited decisions from prior phases (preserved unchanged)

- **Phase 4 R-01** (migration application via Supabase MCP `apply_migration` against the remote project) — see Phase 5 R-02.
- **Phase 4 R-03** (native Postgres enums for status types) — Phase 5 adds `account_approval_status` as a native enum following the same convention.
- **Phase 4 R-04** (`log_audit()` reusable trigger function with `TG_ARGV` convention) — Phase 5 invokes it unchanged for the new audit trigger (R-05).
- **Phase 4 R-05** (`current_user_is_admin()` placeholder helper, central-helper invariant) — Phase 5 swaps the body (R-12) without editing any policy file.
- **Phase 4 R-06** (`app_vault_secret(name)` helper signature) — Phase 5 wraps it via the five new PII helpers (R-13) without modifying the helper itself.
- **Phase 4 R-07** (atomic auto-provision trigger on `auth.users` insert) — Phase 5's auto-population trigger on `profiles` insert is structurally identical; ON CONFLICT DO NOTHING + same-transaction semantics.
- **Phase 4 R-08** (pgsodium baseline) — Phase 5 consumes the existing extension; no new extensions enabled.
- **Phase 4 R-09** (real `authStateChanges()` wiring in `SupabaseClientWrapper`) — Phase 5 consumes the existing implementation; no changes to the Supabase client wrapper.
- **Phase 4 R-10** (Equatable-based domain entities, no Freezed) — Phase 5's new `Credentials`, `Session`, `AuthFailure`, `AccountApprovalRequest`, `PrivateContactMethods` entities follow the same convention.
- **Phase 4 R-11** (UUID PKs with `gen_random_uuid()`) — Phase 5's `account_approval_requests.id` follows the convention (R-20).
- **Phase 4 R-12** (`enforce_profile_status_admin_only` BEFORE-UPDATE trigger; privileged-role bypass list) — Phase 5 extends the trigger to also block `is_admin` mutation; the bypass list is unchanged.
