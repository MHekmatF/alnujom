# Phase 0 Research — Supabase Foundation

This document locks the technical decisions Phase 4 makes (or inherits), with the alternatives considered. Every decision below is stable enough that `/speckit-tasks` can rely on it without re-asking the user.

---

## R-01 — Migration application mechanism

**Decision**: Apply every Phase 4 migration to the **remote** Supabase project via the Supabase MCP `apply_migration` tool. There is no local Supabase setup; no `supabase start`, no `supabase db reset`, no `supabase db push` from a local CLI. The repo's `supabase/migrations/` tree is the source of truth (Constitution II); the remote is one applied instance.

**Rationale**: Locked by the Session 2026-05-06 Q5 clarification. The user's Windows host avoids Docker; the remote Supabase project is the only environment the schema actually runs against. Supabase MCP's `apply_migration` records each applied filename in `supabase_migrations.schema_migrations` (the same tracker the official CLI uses), so re-application of an already-applied migration is automatically a no-op. Inspection is done via Supabase MCP `execute_sql`, `list_tables`, `list_migrations`, and `get_advisors` (the last for catching common security misconfigurations after each migration applies).

**Alternatives considered**:
- Local Supabase via Docker — rejected per Q5; adds a Docker dependency on a Windows host the user is explicitly avoiding, and adds a third environment (local + remote dev + remote prod) where the project today operates with one (remote dev = remote prod, manually promoted later).
- `supabase db push` from the CLI without local stack — viable, but duplicates what Supabase MCP `apply_migration` already does, and requires CLI auth setup. The MCP server is already authenticated to the project the user is working in, so it is the lower-friction path.
- Apply migrations directly via Studio's SQL editor — rejected; bypasses the migration tracker, loses the file-level audit trail, and violates Constitution II's "every change applied to the live project MUST be checked in as a migration" by inviting Studio-only edits.

---

## R-02 — Migration filenames, ordering, and policy bundling

**Decision**: Six migration files under `supabase/migrations/`, named with Supabase's standard 14-digit-timestamp prefix `<YYYYMMDDhhmmss>_<title>.sql`. Phase 4 uses synthetic-monotonic timestamps `20260506120001` through `20260506120006` so the files sort after Phase 1's epoch-prefixed `00000000000000_init_extensions.sql` and before any future spec's migrations (which will use real wall-clock timestamps). Pre-implementation analysis (A4) confirmed that Supabase MCP's `apply_migration` and `list_migrations` use the timestamped name as the migration identifier in `supabase_migrations.schema_migrations`, so the verify queries throughout `tasks.md` and `quickstart.md` reference the full timestamped names.

| # | Filename | Purpose |
|---|---|---|
| 1 | `20260506120001_init_enums.sql` | All §6.3 enums (FR-011, Q3) |
| 2 | `20260506120002_create_profiles.sql` | `profiles` table + auto-provision trigger on `auth.users` (FR-001, FR-004, FR-020, Q1, Q4) |
| 3 | `20260506120003_create_user_preferences.sql` | `user_preferences` table + FR-019 defaults (Q2) |
| 4 | `20260506120004_create_audit_logs.sql` | `audit_logs` table + `log_audit()` reusable trigger function + concrete trigger on `profiles` status fields (FR-003, FR-009, FR-010) |
| 5 | `20260506120005_enable_rls_default.sql` | `ENABLE ROW LEVEL SECURITY` on the three new tables + the `current_user_is_admin()` placeholder helper + the policy bodies from `supabase/policies/*.sql` inlined into this migration so the apply step is atomic with RLS-enable (FR-005, FR-006, FR-007, FR-008) |
| 6 | `20260506120006_enable_vault.sql` | `pgsodium` + Supabase Vault scaffolding + `app_vault_secret(name)` helper (FR-012, FR-013) |

The policy SQL files in `supabase/policies/` are the **authoring** copy: each policy is reviewable in its own file, scoped to the table it governs, and is the file Phase 5 / Phase 6 / later phases edit when they swap the admin predicate or add new policies for the same tables. The migration `20260506120005_enable_rls_default.sql` **inlines** the contents of those three policy files at apply-time so the remote receives RLS-enable + policy-create as a single atomic migration. A short `# generated from supabase/policies/<file>` comment at the top of each inlined block makes the source obvious.

**Rationale**: Two competing interests resolved by bundling-with-source-comments:

1. The implementation plan's deliverables list (§5.4 of `IMPLEMENTATION_PLAN.md`) treats `supabase/policies/` and `supabase/migrations/` as parallel trees, which suggests separate authoring. Reviewers find policy SQL faster when it lives next to the table it governs, not buried in a numbered migration file.
2. Constitution II's "every change applied to the live project MUST be checked in as a migration" means the migrations are the canonical apply unit — policies that exist only in `supabase/policies/` would never be applied to the remote without a migration that references them.

Inlining the policy bodies into `20260506120005_enable_rls_default.sql` (with a header comment naming the source file in `supabase/policies/`) gives both: the authoring tree is policy-file-centric for review; the apply tree is migration-centric for source-control invariants. Later phases (Phase 5 onwards) extend `supabase/policies/<file>.sql` and ship a small migration that re-applies just that file via `DROP POLICY IF EXISTS … CREATE POLICY …`.

**Alternatives considered**:
- Author policies directly inside the migration files; delete `supabase/policies/`. Rejected — the implementation plan explicitly names `supabase/policies/profiles_policies.sql` etc. as deliverables, and reviewers benefit from per-table grouping.
- Keep `supabase/policies/` and have a build step concatenate them into a generated migration. Rejected — adds a generation step and a "generated" file the developer has to keep in sync; in Phase 4's small footprint, hand-inlining with a source comment is the simpler solution and survives review unaltered.
- Apply policies via a `supabase migration repair` style flow, separate from the table-creation migration. Rejected — Supabase MCP's `apply_migration` is the only application path, and bundling guarantees atomicity (RLS enabled and policies attached at the same instant; no window where RLS is on but no policies exist).

---

## R-03 — Enum representation: native Postgres enum types vs CHECK constraints

**Decision**: Native Postgres `CREATE TYPE … AS ENUM (...)` for every §6.3 status enum. One enum type per status set. Columns referencing them are typed as the enum (e.g., `account_status account_status_enum NOT NULL DEFAULT 'pending'`).

**Rationale**: Native enums give the database the strongest possible enforcement (an attempt to insert an unknown value is rejected at the type level, not at a constraint level), are introspectable via `pg_enum` and `pg_type`, and round-trip cleanly through `supabase_flutter`'s typed query results. The Dart enum mirror in `lib/shared/domain/value_objects/` (Phase 4 ships `account_status.dart` and `publisher_status.dart`; later phases ship `listing_status.dart` etc. as their tables land) maps 1:1 to the SQL enum's value set, making domain code free of magic strings.

The accepted cost is that adding a new enum value later requires `ALTER TYPE … ADD VALUE`, which Postgres allows but disallows inside a transaction in some scenarios — Supabase platform handles this via per-statement migrations, and Phase 4's enum sets are stable enough at the spec level that no value addition is anticipated within the v1 lifecycle. If a future phase needs to add a value, that phase's spec calls it out (per FR-011's "no later migration adds a new top-level enum unless its spec explicitly extends §6.3").

**Idempotency wrinkle**: `CREATE TYPE` has no `IF NOT EXISTS` clause in Postgres. The migration uses a `DO $$ BEGIN … EXCEPTION WHEN duplicate_object THEN NULL; END $$;` block per enum to make re-application safe. This pattern is standard in Supabase migrations and is documented inline in the migration file's header comment.

**Alternatives considered**:
- `CHECK (status IN ('pending', 'approved', …))` constraints on a TEXT column — rejected. CHECK constraints are easier to add/remove (no ALTER TYPE dance) but lose the introspectability of `pg_enum`, are harder to keep in sync with the Dart mirror, and put the enforcement burden on the DDL author each time the column is referenced. The Phase 4 spec explicitly allows either (FR-011: "native enum types or `CHECK` constraints"), but the project benefits from one consistent choice — native enums.
- Lookup tables (e.g., `account_statuses (key, label)` joined via FK) — rejected; over-engineering for stable, small, never-localized status sets. Lookup tables are the right tool for user-managed taxonomies (locations, currencies — Phases 8/9), not for hard-coded operational states.

---

## R-04 — `log_audit()` trigger function signature

**Decision**: A single PL/pgSQL function `log_audit() RETURNS TRIGGER` that reads its configuration from the trigger's `TG_ARGV`:

- `TG_ARGV[0]` — the action key string (e.g., `'profile.status_changed'`). Required.
- `TG_ARGV[1]` — a comma-separated list of column names to capture in `before_state` / `after_state` (e.g., `'account_status,publisher_status'`). Required for `UPDATE`. For `INSERT` and `DELETE` triggers (not used in Phase 4 but supported for later phases), `TG_ARGV[1]` may be empty/`*` meaning "capture all columns from `NEW`/`OLD` respectively."
- `TG_ARGV[2]` — the **primary-key column name** of the target table (e.g., `'user_id'` for `profiles`, `'id'` for `listings`). Optional; defaults to `'id'` when omitted. This is the column whose value populates `audit_logs.target_id`.

The function body (full PL/pgSQL):

```sql
CREATE OR REPLACE FUNCTION log_audit() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_action      TEXT := TG_ARGV[0];
  v_columns     TEXT := COALESCE(TG_ARGV[1], '');
  v_pk_col      TEXT := COALESCE(TG_ARGV[2], 'id');
  v_before      JSONB := 'null'::jsonb;
  v_after       JSONB := 'null'::jsonb;
  v_target_id   TEXT;
  v_col_array   TEXT[];
  v_changed     BOOLEAN := FALSE;
  v_col         TEXT;
BEGIN
  -- Resolve target_id from PK column name (works for any PK name).
  IF TG_OP = 'DELETE' THEN
    v_target_id := to_jsonb(OLD) ->> v_pk_col;
  ELSE
    v_target_id := to_jsonb(NEW) ->> v_pk_col;
  END IF;

  -- Build before/after JSONB filtered to the configured column list.
  IF v_columns = '*' OR v_columns = '' THEN
    IF TG_OP <> 'INSERT' THEN v_before := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN v_after  := to_jsonb(NEW); END IF;
  ELSE
    v_col_array := string_to_array(v_columns, ',');
    IF TG_OP <> 'INSERT' THEN
      v_before := '{}'::jsonb;
      FOREACH v_col IN ARRAY v_col_array LOOP
        v_before := v_before || jsonb_build_object(v_col, to_jsonb(OLD) -> v_col);
      END LOOP;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      v_after := '{}'::jsonb;
      FOREACH v_col IN ARRAY v_col_array LOOP
        v_after := v_after || jsonb_build_object(v_col, to_jsonb(NEW) -> v_col);
      END LOOP;
    END IF;
  END IF;

  -- Audit-noise filter: for UPDATE with a column list, skip the INSERT
  -- if NONE of the listed columns actually changed.
  IF TG_OP = 'UPDATE' AND v_columns <> '*' AND v_columns <> '' THEN
    FOREACH v_col IN ARRAY v_col_array LOOP
      IF (to_jsonb(OLD) -> v_col) IS DISTINCT FROM (to_jsonb(NEW) -> v_col) THEN
        v_changed := TRUE;
        EXIT;
      END IF;
    END LOOP;
    IF NOT v_changed THEN
      RETURN COALESCE(NEW, OLD);
    END IF;
  END IF;

  INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, before_state, after_state)
    VALUES (auth.uid(), v_action, TG_TABLE_NAME, v_target_id, v_before, v_after);

  RETURN COALESCE(NEW, OLD);
END;
$$;
```

Phase 4's concrete trigger declaration (note the third arg `'user_id'`, since `profiles.user_id` is the PK):

```sql
CREATE TRIGGER trg_profiles_audit_status
  AFTER UPDATE OF account_status, publisher_status ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
```

Later-phase examples:

```sql
-- Phase 5 (account_approval_requests, PK = id)
EXECUTE FUNCTION log_audit('account_approval.decision', 'status,reason', 'id')
-- equivalent to omitting TG_ARGV[2]:
EXECUTE FUNCTION log_audit('account_approval.decision', 'status,reason')

-- Phase 12 (listings, PK = id)
EXECUTE FUNCTION log_audit('listing.status_changed', 'status', 'id')
```

**Rationale**: Putting the action key, captured-column list, AND PK column name in `TG_ARGV` makes the function table-agnostic. The body uses `to_jsonb(NEW) -> col` to read column values without referencing column names at compile time, so the function compiles once and reuses across every audit-worthy table — exactly what FR-009's "reusable by later phases without modification" requires. The `IS DISTINCT FROM` audit-noise filter prevents Phase 5+'s admin tools from writing duplicate audit logs when re-PATCHing whole rows.

The `RETURN COALESCE(NEW, OLD)` is correct for AFTER triggers: AFTER triggers ignore the return value, but PL/pgSQL requires a return statement; returning the surviving row keeps the function defensible if accidentally attached as BEFORE (it would behave as a passthrough rather than blocking the row).

**Alternatives considered**:
- Per-table dedicated trigger functions (`log_profile_audit`, `log_listing_audit`, …) — rejected; massive duplication, and Constitution VII's "audit-log entry capturing actor, action, target, timestamp, before/after state where applicable" is identical across tables.
- Hard-coded `NEW.id::TEXT` for `target_id` — rejected (was the original Phase-4 sketch, fixed during pre-implementation analysis). Hard-coding works only for tables whose PK is named `id`; `profiles` uses `user_id`. Without `TG_ARGV[2]`, every later phase whose audit-worthy table uses a non-`id` PK would have to redefine the function, violating FR-009.
- A single trigger function that captures *every* column (no `TG_ARGV[1]` filter) — rejected; spam-prone for tables with many columns, and exposes columns that may be admin-only or Vault-decrypted unnecessarily. The `*` wildcard in `TG_ARGV[1]` is the opt-in for that case.
- Edge-Function-only audit emission (no DB triggers; every mutation goes through an Edge Function that audits and then writes) — rejected for Phase 4. The Edge Function path is in scope for actions that are inherently routed through one (Phases 7's `mutate_role`, Phase 12's `approve_listing`, etc.), but for direct `UPDATE`s by an admin SQL session or an admin tool, the trigger is the only line of defense. Phase 4 ships both: a generic trigger function any phase can attach, and the convention that Edge Functions also call out to it (or directly write to `audit_logs`) for actions they own.

---

## R-05 — Admin-predicate placeholder helper

**Decision**: A SQL function `current_user_is_admin() RETURNS BOOLEAN` with body `SELECT FALSE;` in Phase 4. **Defined in `20260506120002_create_profiles.sql`** (moved from the original 0005 plan during pre-implementation analysis: the `enforce_profile_status_admin_only()` trigger introduced by R-12 calls this helper from a `BEFORE UPDATE` trigger on `profiles`, so the helper must exist at the time `0002` runs — not at `0005`). Every admin-gated policy in Phase 4 (the `profiles` admin-read-status, the `audit_logs` admin-read) calls this function; no policy hardcodes a per-table admin check.

**Phase-by-phase replacement plan**:

- **Phase 4**: `SELECT FALSE;` (no admin exists yet; admin-gated rows are read-blocked for every caller — this is the correct behavior per the spec's "Admin-readable does not mean readable in Phase 4" assumption).
- **Phase 5**: redefined to `SELECT (SELECT is_admin FROM profiles WHERE user_id = auth.uid());` after Phase 5 introduces the interim `is_admin` boolean column on `profiles`.
- **Phase 6**: redefined to `SELECT current_user_has_permission('users.view');` (or a similarly broad anchor permission) after Phase 6 ships the role/permission system. The Phase 6 spec backfills existing `is_admin` users to the `admin` role and drops the column in the same migration.

In every case, the **function body** changes; the **function signature** stays `current_user_is_admin() RETURNS BOOLEAN`. Policy files never change.

**Rationale**: Centralizing the predicate behind a single function realizes the spec's binding constraint ("Replacing the placeholder MUST NOT require touching every Phase 4 policy file" — edge case). It also future-proofs the project: when Phase 6 swaps to a permission-based model, the swap is a one-line `CREATE OR REPLACE FUNCTION` migration, not a hunt-and-replace across every policy.

**`SECURITY DEFINER` vs `SECURITY INVOKER`**: The function is declared `SECURITY INVOKER` (the default). This means the function runs with the calling session's privileges. In Phase 4 the body is a constant `SELECT FALSE;` so it doesn't matter; from Phase 5 onward, `SECURITY INVOKER` is correct because the function reads `profiles` (and Phase 6 reads `user_roles`/`role_permissions`) using the caller's permissions, which is exactly what RLS expects. `SECURITY DEFINER` would let the function bypass RLS, which is the wrong default for an admin check.

**Alternatives considered**:
- Inline the admin check in each policy (`USING (auth.uid() IN (SELECT user_id FROM profiles WHERE is_admin))`) — rejected; violates the spec's centralization invariant and would force Phase 5 / Phase 6 to touch every policy file.
- Use a Postgres role (`CREATE ROLE app_admin`) and check via `current_user`/`current_setting('role')` — rejected; Supabase auth doesn't surface DB-level roles to the policy layer in a way that aligns with our RLS posture (the auth layer hands the database the `authenticated` role + the JWT claims; per-user role grants would require a custom JWT-claim → DB-role mapping that's more infrastructure than warranted).
- A view (`v_admin_users`) that policies join against — rejected; a function call is simpler, more cacheable per-statement, and produces clearer error messages when something goes wrong.

---

## R-06 — `app_vault_secret()` helper signature and missing-name semantics

**Decision**: `CREATE FUNCTION app_vault_secret(p_name TEXT) RETURNS TEXT LANGUAGE SQL STABLE SECURITY DEFINER AS $$ SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name LIMIT 1; $$;`. Returns the decrypted secret value if a row exists in `vault.decrypted_secrets` with that name; returns `NULL` (the SQL `LIMIT 1` on an empty result set is a single NULL, propagated through the SELECT) when no such secret exists. Never raises an exception for a missing name.

**Rationale**: The spec's edge case ("Vault helper failure isolation") is binding: callers MUST be able to treat a missing secret as an empty result. A `SELECT … WHERE … LIMIT 1` against an empty result naturally returns NULL with no exception, satisfying the contract without any explicit `EXCEPTION` block.

`SECURITY DEFINER` is correct here because the function needs to read `vault.decrypted_secrets`, which is admin-only by Supabase platform default. Without `SECURITY DEFINER`, a Phase 22 Edge Function calling this helper would hit a permission error before it even got to the missing-secret case. Importantly, the function body itself doesn't take user input that could be used to escape the WHERE clause (the `LIMIT 1` and the typed parameter prevent SQL injection), so the `SECURITY DEFINER` privilege escalation is bounded.

`STABLE` is the right volatility class: same input ⇒ same output within a statement, but the underlying table can change between statements (a later phase that updates a Vault secret would see the new value on the next call).

**Alternatives considered**:
- `RETURNS TEXT` with explicit `EXCEPTION WHEN no_data_found THEN RETURN NULL;` block — rejected; unnecessary because `SELECT … LIMIT 1` doesn't raise when empty; the explicit handler is dead code that confuses readers.
- `RETURNS JSONB` for callers that want richer payloads (Phase 22's FCM service-account JSON is itself a JSON document) — rejected for Phase 4. The Vault stores secrets as text; callers that need to parse JSON do `app_vault_secret(name)::jsonb` at the call site. Keeping the helper signature minimal in Phase 4 leaves the door open for later phases to add typed wrappers if patterns emerge.
- A view (`vault_secrets` rename) that maps `name` to `decrypted_secret` — rejected; views require explicit grants and complicate the Phase 5+ "Edge Functions read this" pattern. A function with `SECURITY DEFINER` is the canonical Supabase pattern.
- Use Supabase's built-in `vault.read_secret(name)` directly — rejected; this binds every Edge Function to the platform-specific name, and the wrapper is a small abstraction layer that lets us swap implementation later (e.g., when the v2 backend swap eventually replaces Vault with a different secret store).

---

## R-07 — Auto-provision trigger shape (atomic profile + user_preferences)

**Decision**: A single `AFTER INSERT` trigger on `auth.users` calling a function `handle_new_auth_user() RETURNS TRIGGER` whose body inserts into both `profiles` and `user_preferences` with `ON CONFLICT (user_id) DO NOTHING` on each:

```sql
CREATE OR REPLACE FUNCTION handle_new_auth_user() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (user_id, account_status, publisher_status)
    VALUES (NEW.id, 'pending', 'pending')
    ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO user_preferences (user_id, locale, theme_mode, display_currency, notifications_enabled)
    VALUES (NEW.id, 'ar', 'system', 'SYP', TRUE)
    ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auth_users_handle_new
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_auth_user();
```

**Rationale**: Single trigger ⇒ single function ⇒ atomicity (both inserts succeed or both roll back with the surrounding statement), which is exactly what the Q1 clarification requires ("downstream code can assume that for any `auth.users.id` either both rows exist or neither does"). `ON CONFLICT DO NOTHING` on each target table covers the signup-race edge case from the spec without requiring a separate idempotency mechanism.

`SECURITY DEFINER` is required: triggers on `auth.users` execute in a context where the writing role does not have direct insert privileges on `public.profiles` and `public.user_preferences` under default RLS. `SECURITY DEFINER` lets the trigger function run as the function's owner (set by Supabase migrations to the privileged `postgres` role) so the inserts succeed regardless of the JWT claims of whoever triggered the auth.users insert.

`SET search_path = public` is a defense-in-depth measure that prevents an attacker from creating a same-named relation in another schema and tricking the function into writing there. Standard hardening for `SECURITY DEFINER` functions.

**Alternatives considered**:
- Two separate triggers (one for `profiles`, one for `user_preferences`) — rejected. Triggers on the same event fire in alphabetical order by trigger name, but a transactional rollback between them is awkward; one-function-per-event is the cleaner pattern and produces the atomicity guarantee for free.
- Insert via a Supabase Edge Function called from the auth signup hook — rejected for Phase 4. The Edge Function path adds a network hop and a deployment step on top of every signup; a SQL trigger runs in-process and is the canonical Supabase pattern (see Supabase's official "user profile" example).
- `LATERAL INSERT` or chained CTE — rejected; not idiomatic for trigger functions and harder to read.
- Insert via an `auth.users` `BEFORE INSERT` trigger so the new rows are committed in the same statement as the auth user — rejected; `BEFORE` would require referencing `NEW.id` (which exists at BEFORE time) but writes to a separate table during a `BEFORE` trigger are unusual; `AFTER` is the canonical pattern and works fine for our atomicity requirement.

---

## R-08 — `pgsodium` and Vault baseline migration

**Decision**: `20260506120006_enable_vault.sql` runs `CREATE EXTENSION IF NOT EXISTS pgsodium;`. The Supabase Vault scaffolding (the `vault` schema, the `vault.secrets` table, the `vault.decrypted_secrets` view, and the supporting machinery) is created by Supabase's platform migrations on every project; Phase 4's migration does NOT redefine any of those objects. The migration's only purpose is (a) confirming `pgsodium` is enabled, (b) defining `app_vault_secret(name)` per R-06, and (c) carrying a header comment that documents the forward-prep intent for Phases 5/16/19/21/22 per ADR-0001. The migration body is intentionally short.

**Rationale**: Supabase manages the Vault infrastructure (schema, tables, encryption-key rotation) at the platform level — application migrations should not redefine it. `CREATE EXTENSION IF NOT EXISTS pgsodium` is the canonical Supabase pattern for ensuring the Vault dependency is present even on projects where Supabase hasn't pre-enabled it. (On most Supabase plans `pgsodium` is enabled by default; the explicit `CREATE EXTENSION` is a guard.)

**Alternatives considered**:
- Define our own encrypted-column scheme using `pgcrypto`'s `pgp_sym_encrypt`/`pgp_sym_decrypt` — rejected by ADR-0001 (alternatives section). Vault's managed root-key rotation and decrypted-view abstraction are the value; reinventing them is exactly what the ADR rejected.
- Defer `pgsodium` enable to Phase 5 (since Phase 5 is the first phase that *uses* a Vault column) — rejected. ADR-0001's verification clause specifically requires Phase 4 to ship the extension and the helper as forward-prep so Phase 5 can consume them without touching extensions. Bundling it in Phase 5 would re-invent Phase 5's migration ordering.

**Verification**: `SELECT * FROM pg_extension WHERE extname = 'pgsodium'` returns one row after `20260506120006_enable_vault.sql` is applied. `SELECT app_vault_secret('does_not_exist')` returns NULL without raising.

---

## R-09 — Flutter `SupabaseClientWrapper.authStateChanges()` real wiring

**Decision**: Replace the `UnimplementedError('wired up in Phase 5')` body in `lib/core/network/supabase_client_wrapper_impl.dart` with a real subscription that uses `StreamTransformer.fromHandlers` for the error mapping (so error events actually propagate as `AuthState.error` — `Stream.handleError`'s callback is fire-and-forget and would silently swallow errors):

```dart
@override
Stream<AuthState> authStateChanges() {
  if (!_isInitialized) {
    return Stream<AuthState>.value(AuthState.signedOut);
  }
  return supabase.Supabase.instance.client.auth.onAuthStateChange
      .map(_mapAuthChangeEvent)
      .transform(
        StreamTransformer<AuthState, AuthState>.fromHandlers(
          handleError: (Object error, StackTrace stackTrace, EventSink<AuthState> sink) {
            _logger.warning(
              'Auth state subscription error.',
              error: error,
              stackTrace: stackTrace,
              tag: _tag,
            );
            sink.add(AuthState.error);
          },
        ),
      );
}

AuthState _mapAuthChangeEvent(supabase.AuthState data) {
  switch (data.event) {
    case supabase.AuthChangeEvent.signedIn:
    case supabase.AuthChangeEvent.tokenRefreshed:
    case supabase.AuthChangeEvent.userUpdated:
    case supabase.AuthChangeEvent.initialSession:
      return data.session != null ? AuthState.signedIn : AuthState.signedOut;
    case supabase.AuthChangeEvent.signedOut:
    case supabase.AuthChangeEvent.userDeleted:
      return AuthState.signedOut;
    case supabase.AuthChangeEvent.passwordRecovery:
    case supabase.AuthChangeEvent.mfaChallengeVerified:
      return AuthState.signedIn;
  }
}
```

**Required imports** (add to the top of `supabase_client_wrapper_impl.dart` if not already present):

```dart
import 'dart:async' show EventSink, StreamTransformer;
```

The stale `UnimplementedError('wired up in Phase 4')` comment on `selectRows()` is updated to `'wired up in Phase 5'` — the spec does not require real reads in Phase 4, and Phase 5's auth flow is the first caller that actually needs `selectRows()`. (`rpc()`, `uploadObject()`, and `realtimeChannel()` already say `'wired up in Phase 5'`, `'wired up in Phase 11'`, and `'wired up in Phase 22'` respectively — verify these match the current implementation plan; do not change them in Phase 4.)

**Rationale**: FR-016 binds the listener to Phase 4. `supabase_flutter`'s `auth.onAuthStateChange` returns `Stream<supabase.AuthState>` (Supabase's namespaced type — note the `supabase.` prefix is essential to disambiguate from our in-house `AuthState`); the wrapper maps each event to our in-house `AuthState` enum (`signedIn`, `signedOut`, `error`) so the domain layer never imports `package:supabase_flutter` (Constitution IX). The mapping collapses Supabase's six event types to two (`signedIn`/`signedOut`) because the in-house enum doesn't yet distinguish them; Phase 5 can extend the enum if needed.

The `StreamTransformer.fromHandlers(handleError: ...)` approach is the canonical Dart pattern for translating stream errors into typed events. **Do not use `Stream.handleError`** — its callback returns void; any value returned is ignored, and errors would be silently swallowed without `AuthState.error` ever reaching subscribers. The `EventSink.add` call inside the handler is what actually emits the typed error event downstream.

The early `Stream<AuthState>.value(AuthState.signedOut)` when `_isInitialized == false` covers the boot path where `Supabase.initialize()` hasn't completed yet — `Supabase.instance` would throw on access. Returning a one-shot signed-out stream lets consumers subscribe without errors and re-subscribe after initialize.

**Alternatives considered**:
- `Stream.handleError` — rejected; the callback is fire-and-forget and any returned value is ignored. Errors would be logged but no `AuthState.error` event would reach the stream's subscribers, which is the entire point of having an `error` value in the in-house enum.
- Wrap each event in a `try/catch` inside `_mapAuthChangeEvent` — rejected; the mapper itself doesn't throw; the error path is upstream `onAuthStateChange` itself emitting an error (e.g., network failure during token refresh), which `StreamTransformer.fromHandlers` is the right hook to intercept.
- Defer the wiring to Phase 5 — rejected; FR-016 is explicit, and Phase 5 has plenty of work without re-doing Phase 4 data-layer wiring.
- Expose Supabase's `Stream<AuthState>` directly via the wrapper interface — rejected; violates Constitution IX. The whole point of the wrapper is to hide the Supabase types.
- Map `tokenRefreshed` to a separate in-house state — rejected for Phase 4; consumers don't yet need this distinction. Phase 5 can extend the enum if needed.

---

## R-10 — Domain entity shape and serialization

**Decision**: `Profile` and `UserPreferences` are plain immutable Dart classes that extend `Equatable` (the value-equality library already in `pubspec.yaml: equatable: 2.0.8`). Field types are pure Dart (no Supabase types). `created_at`/`updated_at` columns in `profiles` map to `DateTime` in the entity; parsing happens in the data-layer mapper Phase 5 will introduce. The Dart enum mirrors `AccountStatus` and `PublisherStatus` are plain enums.

```dart
// lib/shared/domain/entities/profile.dart
import 'package:equatable/equatable.dart';
import '../value_objects/account_status.dart';
import '../value_objects/publisher_status.dart';

class Profile extends Equatable {
  const Profile({
    required this.userId,
    this.fullName,
    this.username,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.accountStatus,
    required this.publisherStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? fullName;
  final String? username;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final AccountStatus accountStatus;
  final PublisherStatus publisherStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile copyWith({
    String? userId,
    String? fullName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
    AccountStatus? accountStatus,
    PublisherStatus? publisherStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Profile(
    userId: userId ?? this.userId,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    accountStatus: accountStatus ?? this.accountStatus,
    publisherStatus: publisherStatus ?? this.publisherStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    userId, fullName, username, phone, email, avatarUrl,
    accountStatus, publisherStatus, createdAt, updatedAt,
  ];
}

// lib/shared/domain/entities/user_preferences.dart
import 'dart:ui' show Locale;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

class UserPreferences extends Equatable {
  const UserPreferences({
    required this.userId,
    required this.locale,
    required this.themeMode,
    required this.displayCurrency,
    required this.notificationsEnabled,
  });

  final String userId;
  final Locale locale;
  final ThemeMode themeMode;
  final String displayCurrency;        // Phase 9 will narrow to a Currency value object
  final bool notificationsEnabled;

  UserPreferences copyWith({
    String? userId,
    Locale? locale,
    ThemeMode? themeMode,
    String? displayCurrency,
    bool? notificationsEnabled,
  }) => UserPreferences(
    userId: userId ?? this.userId,
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    displayCurrency: displayCurrency ?? this.displayCurrency,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
  );

  @override
  List<Object?> get props => [
    userId, locale, themeMode, displayCurrency, notificationsEnabled,
  ];
}
```

**Rationale**: `equatable` is the existing value-equality library in `pubspec.yaml`; Freezed is NOT a project dependency, and adding it for two entities would introduce build-time code generation that the rest of the codebase doesn't use (Phase 2's `ColorPalette` is a sealed class, Phase 1's other shared types are plain classes). Using `equatable` keeps Phase 4's footprint consistent with the codebase. The hand-written `copyWith` is ~12 lines per entity — small enough to maintain. `props` provides value-equality and `hashCode` automatically.

Mirror the database column names in the entity field names (in camelCase) so the data-layer mapper Phase 5 introduces is a one-line `Profile(userId: row['user_id'], …)`. Reusing Phase 3's `Locale` (from `dart:ui`) and Phase 2's `ThemeMode` (from `package:flutter/material.dart`, also used by Phase 2's theme-mode tokens) keeps the domain layer cohesive.

`displayCurrency` is left as `String` in Phase 4 because the `Currency` value object lands in Phase 9 with the currencies & exchange-rates feature. Pre-typing it to a Phase-9 type would either require Phase 9's value object to land in Phase 4 (scope creep) or leave a forward reference that can't compile.

**Alternatives considered**:
- Add `freezed` + `freezed_annotation` to `pubspec.yaml` — rejected; mixes value-class conventions across the codebase. The other shared types use plain classes or sealed classes; adding Freezed for Phase 4 alone increases the cognitive load on every future contributor.
- Map fields to-and-from JSON inside the entity (e.g., a `fromJson` factory inside `Profile`) — rejected; that pulls JSON-shape concerns into the domain layer. The data layer (Phase 5) owns the row → entity mapping.
- Use `dart:ui`'s `Locale` directly without an `import` alias — fine but `import 'dart:ui' show Locale;` keeps the import surface narrow and avoids confusion with Flutter's `Locale` (they're the same type but the explicit `show` makes that obvious).

---

## R-11 — `audit_logs.id` primary-key type

**Decision**: `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`. UUID, not `bigint`/`bigserial`.

**Rationale**: UUID matches Supabase's broader convention for primary keys (`auth.users.id` is `UUID`, and every later table introduced by the implementation plan uses UUID PKs unless explicitly noted). Audit logs are append-only and admin-readable only — there is no value in a sequential numeric ID for users, and UUIDs avoid the "guess the next ID" reconnaissance vector. `gen_random_uuid()` is provided by the `pgcrypto` extension already enabled in Phase 1's `00000000000000_init_extensions.sql` — no new extension required.

**Alternatives considered**:
- `bigserial` — rejected; sequential IDs leak insert ordering, and the audit-log volume isn't large enough that the ~10 byte savings per row matter.
- `id BIGINT GENERATED ALWAYS AS IDENTITY` — same objection.
- Composite key `(target_type, target_id, created_at)` — rejected; not unique (an admin can change the same field twice in the same millisecond), and reads are harder when you need a single key to reference one audit row.

---

## R-12 — Column-level enforcement of admin-only status changes (FR-006)

**Decision**: A `BEFORE UPDATE` trigger function `enforce_profile_status_admin_only() RETURNS TRIGGER` that raises an exception when a non-privileged, non-admin caller attempts to change `account_status` or `publisher_status`. The function and trigger ship in `20260506120002_create_profiles.sql`. Together with the row-level RLS policies, this gives Phase 4 the column-aware enforcement FR-006 requires.

**Rationale**: Postgres RLS UPDATE policies are **row-level**, not column-level. A policy `USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)` lets an authenticated user update **any column** of their own row — including `account_status` and `publisher_status`, which would let users self-elevate from `pending` to `approved` and bypass Constitution VIII's approval workflow. RLS policies cannot reference `OLD.col` to compare against `NEW.col`; the only standard Postgres mechanisms for column-level write enforcement are (a) column-level GRANT/REVOKE or (b) a BEFORE trigger. A trigger is more flexible because it can call `current_user_is_admin()` (which Phase 5/6 swap implementations of), whereas column-level GRANTs are role-based and can't easily delegate to a function.

**Function body**:

```sql
CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  -- Privileged-session bypass: Supabase MCP execute_sql, Edge Functions running
  -- with service_role JWT, and direct postgres connections (e.g., admin tooling)
  -- need to be able to change status fields. The check below applies only to
  -- non-privileged sessions (authenticated/anon roles).
  IF current_user IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin') THEN
    RETURN NEW;
  END IF;

  IF (OLD.account_status IS DISTINCT FROM NEW.account_status
      OR OLD.publisher_status IS DISTINCT FROM NEW.publisher_status)
     AND NOT current_user_is_admin() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',  -- insufficient_privilege
      MESSAGE = 'Only admins can change account_status or publisher_status',
      HINT    = 'Status fields are admin-only per FR-006; current_user_is_admin() returned FALSE.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_enforce_status_admin_only ON profiles;
CREATE TRIGGER trg_profiles_enforce_status_admin_only
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION enforce_profile_status_admin_only();
```

**Why the privileged-session bypass is correct**: In Phase 4, `current_user_is_admin()` returns FALSE for every caller (including the privileged session, since the body is a constant `SELECT FALSE;`). Without the bypass, quickstart Step 9 — which runs `UPDATE profiles SET account_status = 'approved'` from Supabase MCP `execute_sql` (which connects as `postgres`) — would be blocked by the trigger, and the audit-emission verification (R-04 / FR-010) could not be tested. The bypass list (`postgres`, `supabase_admin`, `service_role`, `supabase_auth_admin`) is the standard Supabase set of privileged DB roles; an authenticated user's role is `authenticated`, which is NOT in the list and therefore IS subject to the check.

**Phase-by-phase evolution**:

- **Phase 4**: Privileged-session bypass + `current_user_is_admin()` returns FALSE → in practice, only privileged sessions can change status. Authenticated users are blocked. Quickstart adds Step 8a verifying the block.
- **Phase 5**: `current_user_is_admin()` body becomes the `is_admin` lookup → users with `is_admin = TRUE` can also change status. Privileged-session bypass remains. The trigger's signature/name does NOT change.
- **Phase 6**: `current_user_is_admin()` body becomes `current_user_has_permission('users.approve')` (or whatever Phase 6 chooses). Same bypass, same trigger.

**Alternatives considered**:
- Column-level `REVOKE UPDATE (account_status, publisher_status) ON profiles FROM authenticated; GRANT UPDATE (account_status, publisher_status) ON profiles TO admin_role;` — rejected. Supabase doesn't define a Postgres-level `admin_role` distinct from `authenticated`; the admin distinction is at the application level (the JWT claim drives an `is_admin` lookup or a `current_user_has_permission` call). Column GRANTs can't dynamically delegate to a function.
- A second RLS policy that blocks UPDATE when status fields differ — rejected because RLS WITH CHECK clauses can't compare OLD vs NEW.
- Application-layer enforcement (rely on Phase 5+ to never SEND status updates from non-admin clients) — rejected. Constitution III is "non-negotiable"; the database, not the application, is the line of defense for sensitive marketplace data.
- Skip the trigger in Phase 4 (Phase 5 will add it when the admin flag exists) — rejected. The trigger function and its body don't depend on a real admin existing; they depend on the `current_user_is_admin()` helper, which Phase 4 already ships. Deferring leaves Phase 4's RLS posture incomplete and forces Phase 5 to revisit profiles' triggers.

**Verification (Phase 4 quickstart Step 8a)**:

```sql
-- From a simulated authenticated session for $TEST_ID:
BEGIN;
SELECT set_config('request.jwt.claims', json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Attempt self-elevation: must fail with 42501 'Only admins can change ...'
UPDATE profiles SET account_status = 'approved' WHERE user_id = '$TEST_ID';
-- Expect: ERROR: insufficient_privilege

ROLLBACK;
```

---
