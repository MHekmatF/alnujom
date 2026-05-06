---
description: "Tasks list for Phase 4 — Supabase Foundation (specs/004-supabase-foundation)"
---

# Tasks: Supabase Foundation

**Input**: Design documents from `/specs/004-supabase-foundation/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: NOT included — durable no-new-tests rule (`feedback_no_new_tests.md`). Verification is manual SQL inspection against the **remote** Supabase project via Supabase MCP (`execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) plus a regression-only Flutter launch on the Infinix Note 8 reference device. There is no local Supabase setup in Phase 4 (Q5 clarification).

**Organization**: Tasks are grouped by user story. Note that Phase 4's stories are inherently coupled through shared migrations — every Phase 4 table must exist before `<timestamp>_enable_rls_default.sql` can apply, which is the migration that proves several US2 and US3 acceptance scenarios. The recommended execution order is **US2 → US3 → US4 → US1** (US1 is the meta source-of-truth verification + docs and is naturally a wrap-up). Each story carries a `**Verify**:` line on every task per Constitution Principle X.

---

## Required reading before starting

A less-capable implementing model MUST internalize the following protocol before authoring any SQL or Dart:

1. **Migration filename convention**: Phase 4 uses synthetic-monotonic timestamps `20260506120001` through `20260506120006`. Files MUST be named exactly `<timestamp>_<title>.sql` (e.g., `20260506120001_init_enums.sql`). The Supabase MCP `apply_migration` tool's `name` argument MUST be the full timestamped name without the `.sql` extension (e.g., `name: "20260506120001_init_enums"`). The same value appears in `list_migrations` output and in the verify queries below.

2. **Header comment template** for every Phase 4 migration file (replace `<N>` and `<TITLE>` per file):
   ```sql
   -- Migration <N>: <TITLE>
   -- Phase 4 — Supabase Foundation (specs/004-supabase-foundation)
   -- See: spec.md, plan.md, research.md
   -- Apply via: Supabase MCP apply_migration(name='<timestamp>_<title>', query='<file body>')
   ```

3. **Multi-statement MCP wrap pattern** for every cross-user RLS / role-simulation verification: Supabase MCP `execute_sql` runs each call as a fresh session, so `SET LOCAL ROLE` and `set_config(..., true)` (transaction-scoped) do NOT persist between MCP calls. Every cross-user verify MUST wrap its statements in a single `execute_sql` call shaped as:
   ```sql
   BEGIN;
   SELECT set_config('request.jwt.claims',
     json_build_object('sub','<UUID>','role','authenticated')::text, true);
   SET LOCAL ROLE authenticated;
   <verification SQL — usually one or two SELECT/UPDATE/INSERT statements>;
   ROLLBACK;
   ```
   Use `ROLLBACK` (not `COMMIT`) so the test data isn't mutated by the verify. For anon-role tests, omit the `set_config` and use `SET LOCAL ROLE anon;`. For privileged-session tests, just call MCP without any role override (the default role is privileged).

4. **`$TEST_ID` and `$OTHER_ID` placeholders**: After T013 inserts the test user, capture the returned UUID and store it as `$TEST_ID` in your scratch context. T015a captures `$OTHER_ID` similarly. Reuse both verbatim in T014, T015, T015a, T025-T033, and T046. **If you lose them between tasks, re-run T013/T015a to capture fresh UUIDs and continue from the next verification task** — T014's idempotency check still works on a fresh UUID.

5. **Privileged-session bypass on `enforce_profile_status_admin_only()`**: The R-12 BEFORE-UPDATE trigger blocks status changes for non-privileged, non-admin sessions. Privileged sessions (`postgres`, `supabase_admin`, `service_role`, `supabase_auth_admin`) bypass the check. Supabase MCP `execute_sql` connects as `postgres`, so quickstart Step 9 (privileged UPDATE of account_status) succeeds and fires the AFTER audit trigger. This is the intended behavior; do NOT remove the bypass.

## Format: `[ID] [P?] [Story?] Description`

- **[P]** = different files, no dependency on incomplete tasks → can run in parallel
- **[USx]** = task belongs to user story x (only on Phase 3+ tasks)
- Each task carries a `**Verify**:` line with the concrete acceptance check.

## Path Conventions

This project is a Flutter Android app with a remote Supabase backend. Paths are relative to repo root `H:\alnujom-project\`.

- Backend SQL: `supabase/migrations/`, `supabase/policies/`, `supabase/docs/`
- Flutter source: `lib/`
- Shared domain layer: `lib/shared/domain/`
- Supabase client wrapper: `lib/core/network/`
- The remote Supabase project is reached via Supabase MCP — there is no local DB to start.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the new directory structure and confirm Supabase MCP can reach the remote project before any migration is authored.

- [X] T001 [P] Create the new policy authoring directory `supabase/policies/` (sibling of `supabase/migrations/`). Add a `README.md` inside it with this exact body:
  ```markdown
  # supabase/policies/

  Source-of-truth RLS policy SQL files for review. Each `*.sql` file in this
  directory is the authoring copy of the policies for one table.

  Policy bodies are inlined into `<timestamp>_enable_rls_default.sql` at apply
  time per research [R-02](../../specs/004-supabase-foundation/research.md#r-02--migration-filenames-ordering-and-policy-bundling).
  Later phases that change a policy do so by editing the file here AND shipping
  a new migration that re-applies it via `DROP POLICY IF EXISTS … CREATE POLICY …`.
  ```
  - **Verify**: `Test-Path supabase/policies/` returns True; `supabase/policies/README.md` exists with the above content.

- [X] T002 [P] Create the new docs directory `supabase/docs/` (sibling of `supabase/migrations/`). Empty for now — content lands in T037 / T038 under US1.
  - **Verify**: `Test-Path supabase/docs/` returns True; the directory is initially empty.

- [X] T003 Verify Supabase MCP connectivity to the project: call `mcp__plugin_supabase_supabase__list_tables` (with `schemas: ["public", "auth"]`) and confirm the response returns the existing `auth.users` table. Call `mcp__plugin_supabase_supabase__list_migrations` and confirm the existing Phase-1 migration `00000000000000_init_extensions` is present. If either call fails, do NOT proceed to authoring migrations — fix MCP authentication / project linkage first.
  - **Verify**: `list_tables` returns at least the `auth.users` row; `list_migrations` returns at least the row whose `name` is `00000000000000_init_extensions`; both calls return without error.

**Checkpoint**: Directories in place; Supabase MCP confirmed reaching the right remote project.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Author and apply the §6.3 status enums migration plus the three RLS policy SQL skeletons. Every later user-story task references these. **No user story can begin until this phase is complete.**

> Contracts: [`contracts/log-audit-trigger-fn.md`](contracts/log-audit-trigger-fn.md), [`contracts/admin-predicate.md`](contracts/admin-predicate.md). Decisions: research [R-02](research.md#r-02--migration-filenames-ordering-and-policy-bundling), [R-03](research.md#r-03--enum-representation-native-postgres-enum-types-vs-check-constraints).

### Enum migration

- [X] T004 Author `supabase/migrations/20260506120001_init_enums.sql` containing nine `CREATE TYPE … AS ENUM (...)` statements per [data-model.md](data-model.md#status-enums-63-of-the-implementation-plan). Each `CREATE TYPE` MUST be wrapped in a `DO`/`EXCEPTION` block per research [R-03](research.md#r-03--enum-representation-native-postgres-enum-types-vs-check-constraints) so re-application is safe. Use this exact pattern (worked example for the first enum; repeat for all nine):
  ```sql
  -- Migration 1: Init Enums
  -- Phase 4 — Supabase Foundation (specs/004-supabase-foundation)
  -- See: spec.md FR-011 (Q3 clarification — pre-declare every §6.3 enum); research.md R-03.

  DO $$ BEGIN
    CREATE TYPE account_status_enum AS ENUM ('pending','approved','rejected','suspended','deleted');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE publisher_status_enum AS ENUM ('pending','approved','rejected','suspended','deleted');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE listing_status_enum AS ENUM ('draft','pending_review','approved','rejected','paused','sold','rented','expired','deleted');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE inquiry_status_enum AS ENUM ('new','seen','responded','closed','spam');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE report_status_enum AS ENUM ('new','reviewing','resolved','dismissed');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE listing_purpose_enum AS ENUM ('sale','rent','daily_rent','investment');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE property_type_enum AS ENUM ('apartment','villa','land','shop','office','farm','warehouse','other');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE location_visibility_enum AS ENUM ('hidden','approximate','exact','admin_only');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;

  DO $$ BEGIN
    CREATE TYPE report_reason_enum AS ENUM ('fake_listing','wrong_price','already_sold_or_rented','duplicate','spam','wrong_location','inappropriate_content','other');
  EXCEPTION WHEN duplicate_object THEN NULL; END $$;
  ```
  - **Verify**: File exists at the path; the file contains exactly 9 `DO $$ BEGIN CREATE TYPE … EXCEPTION` blocks; the value lists match data-model.md exactly; the header comment is present.

- [X] T005 Apply `20260506120001_init_enums.sql` to the remote project via Supabase MCP `apply_migration` with `name: "20260506120001_init_enums"` and `query` set to the file's full content. Then via Supabase MCP `execute_sql`, run:
  ```sql
  SELECT typname FROM pg_type
   WHERE typname IN ('account_status_enum','publisher_status_enum',
                     'listing_status_enum','inquiry_status_enum','report_status_enum',
                     'listing_purpose_enum','property_type_enum',
                     'location_visibility_enum','report_reason_enum')
   ORDER BY typname;
  ```
  Depends on T004.
  - **Verify**: `apply_migration` returns success; the `execute_sql` query returns 9 rows; `list_migrations` shows `20260506120001_init_enums` appended after `00000000000000_init_extensions`.

### Policy SQL skeletons (authored now, applied via 0005 in T024)

- [X] T006 [P] Author `supabase/policies/profiles_policies.sql` with this exact content. Header comment + 4 named policies. Note the `TO authenticated` clause on every policy so anon explicitly cannot match (defense in depth — `auth.uid() = user_id` would already fail for anon, but explicit role binding is clearer):
  ```sql
  -- Source-of-truth policies for profiles
  -- Phase 4 — Supabase Foundation (FR-006)
  -- Inlined into 20260506120005_enable_rls_default.sql per R-02.
  -- Column-level enforcement of "self can't change status" lives in the R-12
  -- BEFORE UPDATE trigger enforce_profile_status_admin_only() (in 0002), NOT here.

  CREATE POLICY profiles_select_self ON profiles
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

  CREATE POLICY profiles_select_admin ON profiles
    FOR SELECT TO authenticated
    USING (current_user_is_admin());

  CREATE POLICY profiles_update_self ON profiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY profiles_update_admin ON profiles
    FOR UPDATE TO authenticated
    USING (current_user_is_admin())
    WITH CHECK (current_user_is_admin());
  ```
  - **Verify**: File exists with exactly 4 named policies (`profiles_select_self`, `profiles_select_admin`, `profiles_update_self`, `profiles_update_admin`); each carries `TO authenticated`; admin policies reference `current_user_is_admin()`. There is intentionally NO `profiles_insert_self` (rows are created by the auto-provision trigger as SECURITY DEFINER; no self-INSERT path) and NO `profiles_delete_self` (deletion happens via auth.users CASCADE).

- [X] T007 [P] Author `supabase/policies/user_preferences_policies.sql` with this exact content (4 named policies, all self-only, all `TO authenticated`):
  ```sql
  -- Source-of-truth policies for user_preferences
  -- Phase 4 — Supabase Foundation (FR-007)
  -- Self-only — no admin policy in Phase 4.
  -- Inlined into 20260506120005_enable_rls_default.sql per R-02.

  CREATE POLICY user_preferences_select_self ON user_preferences
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

  CREATE POLICY user_preferences_insert_self ON user_preferences
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY user_preferences_update_self ON user_preferences
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY user_preferences_delete_self ON user_preferences
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
  ```
  - **Verify**: File exists with exactly 4 named policies; no policy references `current_user_is_admin()`; all four policies are `TO authenticated` and self-scoped.

- [X] T008 [P] Author `supabase/policies/audit_logs_policies.sql` with this exact content (1 named policy — admin-only SELECT; no INSERT/UPDATE/DELETE policies, which means non-superuser writes are blocked entirely):
  ```sql
  -- Source-of-truth policies for audit_logs
  -- Phase 4 — Supabase Foundation (FR-008)
  -- Admin-read only; client INSERT/UPDATE/DELETE forbidden by absence of policies
  -- (writes happen ONLY via the SECURITY DEFINER log_audit() trigger).
  -- Inlined into 20260506120005_enable_rls_default.sql per R-02.

  CREATE POLICY audit_logs_select_admin ON audit_logs
    FOR SELECT TO authenticated
    USING (current_user_is_admin());
  ```
  - **Verify**: File exists with exactly 1 named policy (`audit_logs_select_admin`); the file contains NO `CREATE POLICY` statements for INSERT/UPDATE/DELETE; the header comment explicitly notes the absence is intentional.

**Checkpoint**: Enums applied; the three policy SQL skeletons are authored.

---

## Phase 3: User Story 2 — A signed-up user has a server-side profile and isolated data by default (Priority: P1) 🎯 MVP

**Goal**: A new auth user atomically receives a `profiles` row AND a `user_preferences` row populated with FR-019/FR-020 defaults; an anonymous client and any other authenticated client cannot read or write that user's data; the user's own session can read/write non-status columns; the user CANNOT self-elevate `account_status`/`publisher_status` (R-12). The Flutter `data/` layer exposes the auth-state listener Phase 5 will consume, and ships the `Profile`/`UserPreferences` domain entities (Constitution IX).

**Independent Test**: Insert a synthetic `auth.users` row via Supabase MCP `execute_sql`, confirm both downstream rows exist with expected defaults; from anon and a second authenticated session, confirm cross-user reads return zero rows; from the user's own session, confirm self-elevation of status fails with `42501`. Quickstart [Steps 4, 5, 6, 7, 8, 8a, 16](quickstart.md).

> Contracts: [`contracts/auto-provision-trigger.md`](contracts/auto-provision-trigger.md), [`contracts/profile-entity.md`](contracts/profile-entity.md), [`contracts/user-preferences-entity.md`](contracts/user-preferences-entity.md), [`contracts/admin-predicate.md`](contracts/admin-predicate.md). Decisions: research [R-05](research.md#r-05--admin-predicate-placeholder-helper), [R-07](research.md#r-07--auto-provision-trigger-shape-atomic-profile--user_preferences), [R-09](research.md#r-09--flutter-supabaseclientwrapperauthstatechanges-real-wiring), [R-10](research.md#r-10--domain-entity-shape-and-serialization), [R-12](research.md#r-12--column-level-enforcement-of-admin-only-status-changes-fr-006).

### Backend — profiles table + helpers + enforce trigger

- [ ] T009 [US2] Author `supabase/migrations/20260506120002_create_profiles.sql` containing the seven sections below in this order. Use `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, and `DROP TRIGGER IF EXISTS … CREATE TRIGGER …` for idempotency. Do NOT include the auto-provision trigger or the `handle_new_auth_user()` function — those land in `0003` after `user_preferences` exists.
  ```sql
  -- Migration 2: Create Profiles + admin helper + status-enforcement trigger
  -- Phase 4 — Supabase Foundation (FR-001, FR-006, FR-020, Q2, Q4)
  -- See: research.md R-05 (admin predicate moved here from 0005), R-12 (enforce_status trigger).

  -- (a) profiles table
  CREATE TABLE IF NOT EXISTS profiles (
    user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name        TEXT,
    username         TEXT UNIQUE,
    phone            TEXT UNIQUE,
    email            TEXT,
    avatar_url       TEXT,
    account_status   account_status_enum   NOT NULL DEFAULT 'pending',
    publisher_status publisher_status_enum NOT NULL DEFAULT 'pending',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- (b) set_updated_at() helper — reused by user_preferences in 0003
  CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER
  LANGUAGE plpgsql AS $$
  BEGIN
    NEW.updated_at := now();
    RETURN NEW;
  END;
  $$;

  -- (c) updated_at trigger on profiles
  DROP TRIGGER IF EXISTS trg_profiles_set_updated_at ON profiles;
  CREATE TRIGGER trg_profiles_set_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  -- (d) current_user_is_admin() placeholder helper (R-05)
  -- Phase 4 body returns FALSE; Phase 5 swaps to `is_admin` lookup; Phase 6 swaps to permission check.
  CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
  LANGUAGE SQL STABLE AS $$
    SELECT FALSE;
  $$;

  -- (e) enforce_profile_status_admin_only() function (R-12)
  -- Privileged-session bypass list per R-12 rationale.
  CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only() RETURNS TRIGGER
  LANGUAGE plpgsql AS $$
  BEGIN
    IF current_user IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin') THEN
      RETURN NEW;
    END IF;
    IF (OLD.account_status IS DISTINCT FROM NEW.account_status
        OR OLD.publisher_status IS DISTINCT FROM NEW.publisher_status)
       AND NOT current_user_is_admin() THEN
      RAISE EXCEPTION USING
        ERRCODE = '42501',
        MESSAGE = 'Only admins can change account_status or publisher_status',
        HINT    = 'Status fields are admin-only per FR-006; current_user_is_admin() returned FALSE.';
    END IF;
    RETURN NEW;
  END;
  $$;

  -- (f) enforce_status trigger
  DROP TRIGGER IF EXISTS trg_profiles_enforce_status_admin_only ON profiles;
  CREATE TRIGGER trg_profiles_enforce_status_admin_only
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION enforce_profile_status_admin_only();

  -- (g) header comment is at the top; nothing else here.
  ```
  Note: NULL-distinct `UNIQUE` semantics on `username` and `phone` are Postgres's default — multiple NULLs coexist (Q4). The file does NOT reference `user_preferences` (deferred to 0003).
  - **Verify**: File exists; reading it confirms all seven sections (table, set_updated_at, updated_at trigger, current_user_is_admin, enforce_status function, enforce_status trigger, header); columns match data-model.md exactly (no `preferred_language`/`preferred_currency` per Q2); `created_at` and `updated_at` are `NOT NULL DEFAULT now()`.

- [ ] T010 [US2] Apply `20260506120002_create_profiles.sql` via Supabase MCP `apply_migration` with `name: "20260506120002_create_profiles"`. Then verify via `execute_sql`:
  ```sql
  -- (1) columns
  SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'profiles'
   ORDER BY ordinal_position;
  -- (2) helpers
  SELECT proname FROM pg_proc
   WHERE proname IN ('set_updated_at','current_user_is_admin','enforce_profile_status_admin_only')
   ORDER BY proname;
  -- (3) triggers
  SELECT tgname FROM pg_trigger
   WHERE tgname IN ('trg_profiles_set_updated_at','trg_profiles_enforce_status_admin_only')
     AND NOT tgisinternal
   ORDER BY tgname;
  ```
  Depends on T009 + T005.
  - **Verify**: `apply_migration` succeeds; query 1 returns exactly 10 columns (user_id, full_name, username, phone, email, avatar_url, account_status, publisher_status, created_at, updated_at) — created_at and updated_at have `is_nullable = 'NO'`; query 2 returns 3 rows; query 3 returns 2 rows; `list_migrations` shows `20260506120002_create_profiles`.

### Backend — user_preferences table + auto-provision trigger

- [ ] T011 [US2] Author `supabase/migrations/20260506120003_create_user_preferences.sql` containing the four sections below. The auto-provision function references both `profiles` and `user_preferences` — Postgres PL/pgSQL late-binds table references, so the function definition succeeds. The function actually executes only when `auth.users` receives an INSERT; by that time both tables exist (this migration creates `user_preferences` BEFORE creating the function). **Do NOT move the function or trigger to 0002** — they live here, after `user_preferences` exists, by design.
  ```sql
  -- Migration 3: Create User Preferences + auto-provision trigger
  -- Phase 4 — Supabase Foundation (FR-002, FR-004, FR-019, Q1)
  -- See: research.md R-07 (atomic profile + user_preferences provisioning).

  -- (a) user_preferences table
  CREATE TABLE IF NOT EXISTS user_preferences (
    user_id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    locale                TEXT NOT NULL DEFAULT 'ar'
                          CHECK (locale IN ('ar','en')),
    theme_mode            TEXT NOT NULL DEFAULT 'system'
                          CHECK (theme_mode IN ('system','light','dark')),
    display_currency      TEXT NOT NULL DEFAULT 'SYP',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- (b) updated_at trigger reusing the helper from 0002
  DROP TRIGGER IF EXISTS trg_user_preferences_set_updated_at ON user_preferences;
  CREATE TRIGGER trg_user_preferences_set_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  -- (c) handle_new_auth_user() — atomic profile + user_preferences provisioning
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

  -- (d) auto-provision trigger on auth.users
  DROP TRIGGER IF EXISTS trg_auth_users_handle_new ON auth.users;
  CREATE TRIGGER trg_auth_users_handle_new
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();
  ```
  - **Verify**: File exists; reading it confirms all four sections; the function is `SECURITY DEFINER` with `SET search_path = public`; both INSERT statements use the FR-019/FR-020 defaults; the trigger fires `AFTER INSERT ON auth.users`.

- [ ] T012 [US2] Apply `20260506120003_create_user_preferences.sql` via Supabase MCP `apply_migration` with `name: "20260506120003_create_user_preferences"`. Then verify:
  ```sql
  -- (1) columns
  SELECT column_name, is_nullable, column_default
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'user_preferences'
   ORDER BY ordinal_position;
  -- (2) auto-provision function
  SELECT proname, prosecdef FROM pg_proc WHERE proname = 'handle_new_auth_user';
  -- (3) auto-provision trigger
  SELECT tgname FROM pg_trigger WHERE tgname = 'trg_auth_users_handle_new' AND NOT tgisinternal;
  ```
  Depends on T011 + T010.
  - **Verify**: `apply_migration` succeeds; query 1 returns 7 columns with the documented defaults (locale='ar', theme_mode='system', display_currency='SYP', notifications_enabled=true); query 2 returns one row with `prosecdef = true`; query 3 returns one row; `list_migrations` shows `20260506120003_create_user_preferences`.

### Backend — verification of auto-provision (works without RLS)

- [ ] T013 [US2] Quickstart [Step 4](quickstart.md#step-4--confirm-the-auto-provision-trigger-creates-both-rows). Note: this insert IS the spec's "manually-inserted auth user" edge case — passing it confirms the auto-provision trigger fires regardless of insert source. Via Supabase MCP `execute_sql`, run this exact SQL and capture the returned UUID as `$TEST_ID`:
  ```sql
  INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
    VALUES (gen_random_uuid(),
            'phase4-quickstart@example.com',
            crypt('test', gen_salt('bf')),
            'authenticated',
            'authenticated',
            '00000000-0000-0000-0000-000000000000'::uuid)
    RETURNING id;
  ```
  Note the returned UUID. Then verify both downstream rows exist:
  ```sql
  SELECT user_id, account_status, publisher_status
    FROM profiles WHERE user_id = '<paste $TEST_ID here>';
  SELECT user_id, locale, theme_mode, display_currency, notifications_enabled
    FROM user_preferences WHERE user_id = '<paste $TEST_ID here>';
  ```
  Depends on T012. **Save the returned UUID as `$TEST_ID`** for use in T014, T015, T015a, T025-T033, T046.
  - **Verify**: profiles row exists with `account_status='pending'`, `publisher_status='pending'`; user_preferences row exists with `locale='ar'`, `theme_mode='system'`, `display_currency='SYP'`, `notifications_enabled=true`.

- [ ] T014 [US2] Quickstart [Step 5](quickstart.md#step-5--confirm-the-auto-provision-trigger-is-idempotent-under-retry): test the trigger's idempotency directly (NOT through `auth.users` PK uniqueness — see Step 5 note about why). Via privileged `execute_sql`, manually invoke the trigger function with the same NEW.id twice in one call:
  ```sql
  -- Direct trigger invocation, simulating two near-simultaneous fires:
  -- The function uses ON CONFLICT (user_id) DO NOTHING on each target,
  -- so the second invocation must not duplicate either row.
  SELECT handle_new_auth_user_simulate('<paste $TEST_ID here>'::uuid);
  -- ^ if a simulator function isn't available, equivalently retry by
  --   inserting the SAME auth.users.id with ON CONFLICT (id) DO NOTHING:
  INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
    VALUES ('<paste $TEST_ID here>'::uuid,
            'phase4-retry@example.com',
            crypt('test', gen_salt('bf')),
            'authenticated',
            'authenticated',
            '00000000-0000-0000-0000-000000000000'::uuid)
    ON CONFLICT (id) DO NOTHING;
  -- Then count downstream rows:
  SELECT COUNT(*) FROM profiles WHERE user_id = '<paste $TEST_ID here>';
  SELECT COUNT(*) FROM user_preferences WHERE user_id = '<paste $TEST_ID here>';
  ```
  Depends on T013.
  - **Verify**: Both COUNTs return exactly 1 (the trigger's `ON CONFLICT DO NOTHING` absorbs the retry; no duplicate rows). If the simulator function doesn't exist (it's not part of Phase 4's deliverables), the `auth.users` `ON CONFLICT` path is sufficient because it tests the same invariant: the auth.users PK rejects the duplicate before the trigger fires, so the system as a whole produces 1+1 rows.

- [ ] T015 [US2] Create a second test auth user via the auto-provision path. Capture the returned UUID as `$OTHER_ID`. Via privileged `execute_sql`:
  ```sql
  INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
    VALUES (gen_random_uuid(),
            'phase4-other@example.com',
            crypt('test', gen_salt('bf')),
            'authenticated',
            'authenticated',
            '00000000-0000-0000-0000-000000000000'::uuid)
    RETURNING id;
  ```
  **Save the returned UUID as `$OTHER_ID`** for use in T031-T033 and T046.
  Depends on T014.
  - **Verify**: After insertion, `SELECT COUNT(*) FROM profiles;` and `SELECT COUNT(*) FROM user_preferences;` each return at least 2 (your `$TEST_ID` and `$OTHER_ID` plus any pre-existing). Both counts are equal.

- [ ] T015a [US2] Quickstart [Step 16](quickstart.md#step-16--confirm-uniqueness-on-usernamephone-allows-multiple-nulls). Verify that NULL-distinct UNIQUE on `username` allows multiple NULLs (Q4) and rejects non-NULL duplicates:
  ```sql
  -- (1) Multiple NULLs allowed
  SELECT COUNT(*) FROM profiles WHERE username IS NULL;
  -- (2) Non-NULL uniqueness enforced — second UPDATE must fail
  UPDATE profiles SET username = 'shared_handle' WHERE user_id = '<$TEST_ID>';
  -- ... should succeed; then:
  UPDATE profiles SET username = 'shared_handle' WHERE user_id = '<$OTHER_ID>';
  -- ... should fail with "duplicate key value violates unique constraint"
  -- (3) Roll back
  UPDATE profiles SET username = NULL WHERE user_id IN ('<$TEST_ID>', '<$OTHER_ID>');
  ```
  Depends on T015.
  - **Verify**: Query 1 ≥ 2; query 2 succeeds for `$TEST_ID` then fails for `$OTHER_ID` with a unique-constraint error; query 3 restores both rows to `username = NULL`.

### Flutter — Supabase-free domain layer

- [ ] T016 [P] [US2] Author `lib/shared/domain/value_objects/account_status.dart` with this exact body:
  ```dart
  /// Mirror of the SQL `account_status_enum` from
  /// supabase/migrations/20260506120001_init_enums.sql.
  ///
  /// Phase 4 — Supabase Foundation (data-model.md).
  enum AccountStatus { pending, approved, rejected, suspended, deleted }
  ```
  - **Verify**: `flutter analyze lib/shared/domain/value_objects/account_status.dart` reports zero issues; the file's import list is empty.

- [ ] T017 [P] [US2] Author `lib/shared/domain/value_objects/publisher_status.dart` with this exact body:
  ```dart
  /// Mirror of the SQL `publisher_status_enum` from
  /// supabase/migrations/20260506120001_init_enums.sql.
  ///
  /// Phase 4 — Supabase Foundation (data-model.md).
  enum PublisherStatus { pending, approved, rejected, suspended, deleted }
  ```
  - **Verify**: `flutter analyze` reports zero issues; no imports.

- [ ] T018 [P] [US2] Author `lib/shared/domain/entities/profile.dart` per [`contracts/profile-entity.md`](contracts/profile-entity.md) and research [R-10](research.md#r-10--domain-entity-shape-and-serialization). Use the exact body from R-10 (plain Dart class extending `Equatable`; hand-written `copyWith` and `props`). Imports: ONLY `package:equatable/equatable.dart`, `../value_objects/account_status.dart`, `../value_objects/publisher_status.dart`. NO `supabase_flutter`, NO Freezed, NO data-layer imports.
  - **Verify**: File exists; `flutter analyze` reports zero issues; `Get-Content lib/shared/domain/entities/profile.dart | Select-String -Pattern 'supabase_flutter'` returns zero matches; instantiation `Profile(userId: 'x', accountStatus: AccountStatus.pending, publisherStatus: PublisherStatus.pending, createdAt: DateTime.now(), updatedAt: DateTime.now())` compiles in a temporary scratch file.

- [ ] T019 [P] [US2] Author `lib/shared/domain/entities/user_preferences.dart` per [`contracts/user-preferences-entity.md`](contracts/user-preferences-entity.md) and research [R-10](research.md#r-10--domain-entity-shape-and-serialization). Use the exact body from R-10. Imports: ONLY `package:equatable/equatable.dart`, `dart:ui` (with `show Locale`), `package:flutter/material.dart` (with `show ThemeMode`).
  - **Verify**: File exists; `flutter analyze` reports zero issues; `Select-String -Pattern 'supabase_flutter'` returns zero matches; the import list contains exactly the three documented imports with `show` clauses.

### Flutter — Supabase client wrapper

- [ ] T020 [US2] Edit `lib/core/network/supabase_client_wrapper_impl.dart` per research [R-09](research.md#r-09--flutter-supabaseclientwrapperauthstatechanges-real-wiring). Make the following changes:
  - **Add import** (if not present): `import 'dart:async' show EventSink, StreamTransformer;`
  - **Replace `authStateChanges()` body** with the full implementation from R-09 (uses `StreamTransformer.fromHandlers` for error mapping — NOT `Stream.handleError`, which would silently swallow errors and never emit `AuthState.error`).
  - **Add the `_mapAuthChangeEvent` helper method** below `authStateChanges()` per R-09.
  - **Update `selectRows()` UnimplementedError comment** from `'wired up in Phase 4'` to `'wired up in Phase 5'`.
  - **Verify the existing comments** on `rpc()` (`'wired up in Phase 5'`), `uploadObject()` (`'wired up in Phase 11'`), and `realtimeChannel()` (`'wired up in Phase 22'`) match the current implementation plan; if any is inconsistent (e.g., `rpc()` had said `Phase 4`), update it. Do NOT change the methods themselves — only the comment text.
  - **Verify**: `flutter analyze` reports zero issues; reading the file confirms `authStateChanges()` no longer throws and uses `StreamTransformer.fromHandlers`; `selectRows()` still throws but its comment now says `'Phase 5'`; `Select-String -Pattern 'wired up in Phase 4'` against the file returns zero matches; manual `flutter run --debug` on the device shows the app launches and `adb logcat` does not log any AuthState exceptions during the first 10 seconds of normal use.

**Checkpoint**: Auto-provision verified end-to-end via privileged session. Flutter domain layer is in place and compiles. RLS enforcement and self-elevation block (R-12) are NOT yet active — quickstart steps 6, 7, 8, 8a require `0005`'s RLS-enable AND the enforce_status trigger from T009. (The R-12 trigger function and its trigger landed in T010, but its full effect on authenticated sessions is verified after RLS lands in T024 — without RLS, there's no concept of "authenticated session that's NOT privileged" via JWT-claims simulation, since SET LOCAL ROLE alone doesn't activate the bypass-relevant role context.) Re-run those after T024 lands.

---

## Phase 4: User Story 3 — Sensitive changes leave an admin-readable audit trail (Priority: P2)

**Goal**: A `profiles` `account_status`/`publisher_status` UPDATE writes one `audit_logs` row capturing actor + before/after JSON; clients cannot write to `audit_logs`; non-admins cannot read it; the `log_audit()` function is reusable as-is by every later phase via `TG_ARGV[2]`. This story also ships `20260506120005_enable_rls_default.sql` (the RLS bundle migration) which closes US2's RLS verification.

**Independent Test**: Update a profile's `account_status` via privileged session; confirm one matching `audit_logs` row appears with the expected JSON; confirm normal-user `INSERT`/`UPDATE`/`DELETE` against `audit_logs` are rejected; confirm non-admin `SELECT` returns 0 rows. Quickstart [Steps 9, 10, 11, 12, 13](quickstart.md).

> Contracts: [`contracts/log-audit-trigger-fn.md`](contracts/log-audit-trigger-fn.md), [`contracts/admin-predicate.md`](contracts/admin-predicate.md). Decisions: research [R-04](research.md#r-04--log_audit-trigger-function-signature), [R-05](research.md#r-05--admin-predicate-placeholder-helper), [R-11](research.md#r-11--audit_logsid-primary-key-type).

### Backend — audit_logs table + log_audit + concrete trigger

- [ ] T021 [US3] Author `supabase/migrations/20260506120004_create_audit_logs.sql` containing the three sections below. The `log_audit()` function uses the **full table-agnostic body from research [R-04](research.md#r-04--log_audit-trigger-function-signature)** — copy it verbatim. The function reads PK column name from `TG_ARGV[2]` and uses `to_jsonb(NEW or OLD) ->> COALESCE(TG_ARGV[2], 'id')` to compute `target_id`, so the function body contains NO references to specific column names. The Phase 4 trigger declaration passes `'user_id'` as `TG_ARGV[2]` because `profiles.user_id` is the PK.
  ```sql
  -- Migration 4: Create Audit Logs + reusable log_audit() trigger function
  -- Phase 4 — Supabase Foundation (FR-003, FR-009, FR-010)
  -- See: research.md R-04 (log_audit signature), R-11 (UUID PK).

  -- (a) audit_logs table
  CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action          TEXT NOT NULL,
    target_type     TEXT NOT NULL,
    target_id       TEXT,
    before_state    JSONB,
    after_state     JSONB,
    ip              INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  -- (b) log_audit() reusable trigger function (PASTE THE FULL BODY FROM research.md R-04)
  -- The body is ~40 lines; do NOT abbreviate. The function MUST be table-agnostic
  -- (no profiles-specific column references) and MUST honor TG_ARGV[2] for the PK column name.
  -- ... copy from research.md R-04 verbatim ...

  -- (c) Phase 4 concrete trigger on profiles status changes
  -- Note the third arg 'user_id' — profiles.user_id is the PK, not 'id'.
  DROP TRIGGER IF EXISTS trg_profiles_audit_status ON profiles;
  CREATE TRIGGER trg_profiles_audit_status
    AFTER UPDATE OF account_status, publisher_status ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
  ```
  - **Verify**: File exists; the table DDL has 10 columns with `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` and `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`; the function body is the verbatim R-04 code (search for `to_jsonb(NEW) ->> v_pk_col` to confirm the PK-agnostic resolver is present); the trigger declaration passes three arguments to `log_audit()` and the third is `'user_id'`; `Get-Content` of the file shows zero references to `NEW.id` or `OLD.id` (the function uses `to_jsonb(NEW or OLD) ->> v_pk_col` instead).

- [ ] T022 [US3] Apply `20260506120004_create_audit_logs.sql` via Supabase MCP `apply_migration` with `name: "20260506120004_create_audit_logs"`. Then verify:
  ```sql
  -- (1) columns
  SELECT column_name FROM information_schema.columns
   WHERE table_schema='public' AND table_name='audit_logs'
   ORDER BY ordinal_position;
  -- (2) function
  SELECT proname, prosecdef FROM pg_proc WHERE proname='log_audit';
  -- (3) trigger
  SELECT tgname FROM pg_trigger
   WHERE tgname='trg_profiles_audit_status' AND NOT tgisinternal;
  ```
  Depends on T021 + T012.
  - **Verify**: Query 1 returns 10 columns; query 2 returns one row with `prosecdef = true`; query 3 returns one row; `list_migrations` shows `20260506120004_create_audit_logs`.

### Backend — RLS bundle migration (closes both US2 and US3 RLS posture)

- [ ] T023 [US3] Author `supabase/migrations/20260506120005_enable_rls_default.sql` per research [R-02](research.md#r-02--migration-filenames-ordering-and-policy-bundling). The migration has two sections: (1) ENABLE RLS on the three tables; (2) inline the bodies of the three `supabase/policies/*.sql` files (T006/T007/T008), each block prefixed with a `-- generated from supabase/policies/<filename>` comment, and each `CREATE POLICY` wrapped with a `DROP POLICY IF EXISTS <name> ON <table>;` line for idempotency. Use the policy names from T006/T007/T008 verbatim. Note: `current_user_is_admin()` is NOT created here — it shipped in 0002 (T009).
  ```sql
  -- Migration 5: Enable RLS by Default + apply policies
  -- Phase 4 — Supabase Foundation (FR-005, FR-006, FR-007, FR-008)
  -- Note: current_user_is_admin() ships in 0002, NOT here, because R-12's
  -- enforce_status trigger in 0002 calls it.

  -- (1) Enable RLS on every Phase 4 table
  ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
  ALTER TABLE user_preferences  ENABLE ROW LEVEL SECURITY;
  ALTER TABLE audit_logs        ENABLE ROW LEVEL SECURITY;

  -- (2a) -- generated from supabase/policies/profiles_policies.sql
  DROP POLICY IF EXISTS profiles_select_self      ON profiles;
  CREATE POLICY profiles_select_self ON profiles
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS profiles_select_admin     ON profiles;
  CREATE POLICY profiles_select_admin ON profiles
    FOR SELECT TO authenticated
    USING (current_user_is_admin());

  DROP POLICY IF EXISTS profiles_update_self      ON profiles;
  CREATE POLICY profiles_update_self ON profiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  DROP POLICY IF EXISTS profiles_update_admin     ON profiles;
  CREATE POLICY profiles_update_admin ON profiles
    FOR UPDATE TO authenticated
    USING (current_user_is_admin())
    WITH CHECK (current_user_is_admin());

  -- (2b) -- generated from supabase/policies/user_preferences_policies.sql
  DROP POLICY IF EXISTS user_preferences_select_self ON user_preferences;
  CREATE POLICY user_preferences_select_self ON user_preferences
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS user_preferences_insert_self ON user_preferences;
  CREATE POLICY user_preferences_insert_self ON user_preferences
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

  DROP POLICY IF EXISTS user_preferences_update_self ON user_preferences;
  CREATE POLICY user_preferences_update_self ON user_preferences
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  DROP POLICY IF EXISTS user_preferences_delete_self ON user_preferences;
  CREATE POLICY user_preferences_delete_self ON user_preferences
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

  -- (2c) -- generated from supabase/policies/audit_logs_policies.sql
  DROP POLICY IF EXISTS audit_logs_select_admin ON audit_logs;
  CREATE POLICY audit_logs_select_admin ON audit_logs
    FOR SELECT TO authenticated
    USING (current_user_is_admin());
  ```
  - **Verify**: File exists; reading it confirms three `ALTER TABLE … ENABLE ROW LEVEL SECURITY` lines and exactly 9 `CREATE POLICY` blocks (4 profiles + 4 user_preferences + 1 audit_logs), each preceded by a `DROP POLICY IF EXISTS` line; the inlined bodies are byte-equivalent (modulo the DROP wrappers and source comments) to the source `.sql` files in `supabase/policies/`; the file does NOT redefine `current_user_is_admin()`.

- [ ] T024 [US3] Apply `20260506120005_enable_rls_default.sql` via Supabase MCP `apply_migration` with `name: "20260506120005_enable_rls_default"`. Then verify:
  ```sql
  -- (1) RLS enabled
  SELECT relname, relrowsecurity FROM pg_class
   WHERE relname IN ('profiles','user_preferences','audit_logs')
     AND relnamespace = 'public'::regnamespace
   ORDER BY relname;
  -- (2) policy count + names
  SELECT tablename, policyname FROM pg_policies
   WHERE schemaname='public'
     AND tablename IN ('profiles','user_preferences','audit_logs')
   ORDER BY tablename, policyname;
  -- (3) admin predicate still returns FALSE
  SELECT current_user_is_admin();
  ```
  Then call Supabase MCP `get_advisors` and confirm no new SECURITY-class advisor warnings on Phase 4 tables. Depends on T023 + T022.
  - **Verify**: Query 1 returns three rows all `relrowsecurity = true`; query 2 returns 9 rows with the expected policy names per T006/T007/T008; query 3 returns `false`; `get_advisors` returns no new "RLS disabled on user-facing table" warnings on `profiles`, `user_preferences`, or `audit_logs`; `list_migrations` shows `20260506120005_enable_rls_default`.

### Backend — verification of audit emission and RLS isolation

- [ ] T025 [US3] Quickstart [Step 9](quickstart.md#step-9--confirm-the-audit-trigger-fires-on-account_status-changes). Via privileged `execute_sql` (the privileged-session bypass on the R-12 enforce_status trigger lets this UPDATE through):
  ```sql
  UPDATE profiles SET account_status = 'approved' WHERE user_id = '<$TEST_ID>';

  SELECT actor_user_id, action, target_type, target_id, before_state, after_state
    FROM audit_logs
   WHERE target_type='profiles' AND target_id='<$TEST_ID>'
   ORDER BY created_at DESC LIMIT 1;
  ```
  Depends on T024.
  - **Verify**: Exactly one audit_logs row with `action='profile.status_changed'`, `target_type='profiles'`, `target_id='<$TEST_ID>'` (note: TEXT, not UUID — the resolver casts via JSONB), `before_state` JSON contains `"account_status":"pending"`, `after_state` JSON contains `"account_status":"approved"`.

- [ ] T026 [US3] Quickstart [Step 10](quickstart.md#step-10--confirm-the-audit-trigger-does-not-fire-on-unrelated-changes): test the audit-noise filter via privileged `execute_sql`:
  ```sql
  UPDATE profiles SET full_name = 'Different Name' WHERE user_id = '<$TEST_ID>';
  SELECT COUNT(*) FROM audit_logs WHERE target_type='profiles' AND target_id='<$TEST_ID>';
  ```
  Depends on T025.
  - **Verify**: COUNT unchanged from T025 (still 1, not 2). The `IS DISTINCT FROM` filter inside `log_audit()` skipped the insert.

- [ ] T027 [US3] Quickstart [Step 11](quickstart.md#step-11--confirm-audit_logs-rejects-client-writes). Use the multi-statement MCP wrap pattern from "Required reading" §3 to simulate authenticated and anon roles. Issue this **single `execute_sql` call**:
  ```sql
  BEGIN;
  -- Try as authenticated user $TEST_ID
  SELECT set_config('request.jwt.claims',
    json_build_object('sub','<$TEST_ID>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  -- Each of these MUST fail or affect 0 rows:
  INSERT INTO audit_logs (action, target_type, target_id) VALUES ('hacker.try', 'profiles', '<$TEST_ID>');
  ROLLBACK;
  ```
  Repeat the pattern with `UPDATE audit_logs SET action='tampered' WHERE target_type='profiles';` and `DELETE FROM audit_logs WHERE target_type='profiles';`. Repeat the same three statements with `SET LOCAL ROLE anon;` (omit the set_config since anon has no JWT claims). Depends on T024.
  - **Verify**: Every attempt either errors with a permission/policy violation OR the `ROLLBACK` reports zero rows affected for the offending statement; `SELECT COUNT(*) FROM audit_logs WHERE target_type='profiles' AND target_id='<$TEST_ID>'` from a privileged session is unchanged from T025/T026 (= 1).

- [ ] T028 [US3] Quickstart [Step 12](quickstart.md#step-12--confirm-audit_logs-reads-are-blocked-for-normal-users). Single `execute_sql` call:
  ```sql
  BEGIN;
  SELECT set_config('request.jwt.claims',
    json_build_object('sub','<$TEST_ID>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT COUNT(*) FROM audit_logs WHERE target_id='<$TEST_ID>';
  ROLLBACK;
  ```
  Depends on T024.
  - **Verify**: COUNT = 0. The user whose status changed cannot read the audit row from their own session — `current_user_is_admin()` returns FALSE.

- [ ] T029 [US3] Quickstart [Step 13](quickstart.md#step-13--confirm-the-placeholder-admin-predicate-evaluates-to-false). Three separate `execute_sql` calls:
  ```sql
  -- Call 1 (privileged): SELECT current_user_is_admin();
  -- Call 2 (authenticated): wrap in BEGIN/SET LOCAL ROLE authenticated/SELECT/ROLLBACK
  -- Call 3 (anon): wrap in BEGIN/SET LOCAL ROLE anon/SELECT/ROLLBACK
  ```
  Depends on T024.
  - **Verify**: All three calls return `false`.

### US2 RLS-isolation follow-on (newly verifiable after T024)

- [ ] T030 [US2] Quickstart [Step 8a (NEW per R-12)](quickstart.md#step-8a--confirm-self-elevation-of-status-is-blocked-r-12-fr-006). Single `execute_sql` call simulating user `$TEST_ID` trying to self-elevate status:
  ```sql
  BEGIN;
  SELECT set_config('request.jwt.claims',
    json_build_object('sub','<$TEST_ID>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  -- This MUST fail with SQLSTATE 42501 — the R-12 enforce_status trigger
  -- bypass list excludes 'authenticated', and current_user_is_admin() returns FALSE.
  UPDATE profiles SET account_status = 'approved' WHERE user_id = '<$TEST_ID>';
  ROLLBACK;
  ```
  Depends on T024.
  - **Verify**: The UPDATE raises an exception; the error code is `42501 insufficient_privilege`; the message contains `'Only admins can change account_status or publisher_status'`. Confirm via privileged read after the rollback that `account_status` is unchanged from its previous value (`'approved'` from T025, since T025 was privileged and succeeded).

- [ ] T031 [US2] Quickstart [Step 6](quickstart.md#step-6--confirm-anonymous-reads-return-zero-rows). Single `execute_sql` call:
  ```sql
  BEGIN;
  SET LOCAL ROLE anon;
  SELECT
    (SELECT COUNT(*) FROM profiles)         AS profiles_count,
    (SELECT COUNT(*) FROM user_preferences) AS prefs_count,
    (SELECT COUNT(*) FROM audit_logs)       AS audit_count;
  ROLLBACK;
  ```
  Depends on T024.
  - **Verify**: All three counts return 0.

- [ ] T032 [US2] Quickstart [Step 7](quickstart.md#step-7--confirm-cross-user-reads-are-blocked). Two single-call `execute_sql` blocks (one per user):
  ```sql
  -- As $TEST_ID — own reads return 1, cross-user reads return 0:
  BEGIN;
  SELECT set_config('request.jwt.claims', json_build_object('sub','<$TEST_ID>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT
    (SELECT COUNT(*) FROM profiles WHERE user_id = '<$TEST_ID>')          AS own_profile,
    (SELECT COUNT(*) FROM user_preferences WHERE user_id = '<$TEST_ID>')  AS own_prefs,
    (SELECT COUNT(*) FROM profiles WHERE user_id = '<$OTHER_ID>')         AS other_profile,
    (SELECT COUNT(*) FROM user_preferences WHERE user_id = '<$OTHER_ID>') AS other_prefs;
  ROLLBACK;
  ```
  Depends on T024.
  - **Verify**: `own_profile` = 1, `own_prefs` = 1, `other_profile` = 0, `other_prefs` = 0.

- [ ] T033 [US2] Quickstart [Step 8](quickstart.md#step-8--confirm-self-write-works-cross-user-write-fails). Single `execute_sql`:
  ```sql
  BEGIN;
  SELECT set_config('request.jwt.claims', json_build_object('sub','<$TEST_ID>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  -- Self-update (non-status) must succeed:
  UPDATE profiles SET full_name = 'Test User A' WHERE user_id = '<$TEST_ID>' RETURNING user_id;
  -- Cross-user update must affect 0 rows (RLS blocks):
  UPDATE profiles SET full_name = 'Hacker' WHERE user_id = '<$OTHER_ID>' RETURNING user_id;
  ROLLBACK;
  ```
  Depends on T024.
  - **Verify**: First UPDATE returns one row; second UPDATE returns zero rows. (After ROLLBACK, neither change persists; this is fine — the test verifies policy behavior, not data state.)

**Checkpoint**: User Story 3 complete; User Story 2's RLS-related and column-level acceptance scenarios verified.

---

## Phase 5: User Story 4 — Vault scaffolding ready for later-phase secrets and PII (Priority: P2)

**Goal**: `pgsodium` extension is enabled; the Supabase Vault scaffolding is in place; the `app_vault_secret(name)` helper exists with NULL-on-miss semantics; no application-level secret is stored in Phase 4 (FR-013 — forward prep for Phases 5/16/19/21/22 per ADR-0001).

**Independent Test**: Inspect remote `pg_extension` for `pgsodium`; call `app_vault_secret('does_not_exist')` and confirm it returns NULL without error; inspect `vault.secrets` and confirm zero application-level entries. Quickstart [Steps 14, 15](quickstart.md).

> Contracts: [`contracts/vault-helper.md`](contracts/vault-helper.md). Decisions: research [R-06](research.md#r-06--app_vault_secret-helper-signature-and-missing-name-semantics), [R-08](research.md#r-08--pgsodium-and-vault-baseline-migration).

- [ ] T034 [US4] Author `supabase/migrations/20260506120006_enable_vault.sql` with this exact body:
  ```sql
  -- Migration 6: Enable Vault scaffolding (forward-prep, no secrets stored)
  -- Phase 4 — Supabase Foundation (FR-012, FR-013)
  -- See: research.md R-06 (app_vault_secret signature), R-08 (pgsodium baseline).
  -- ADR-0001: Vault is the canonical store for backend secrets and admin-only PII.
  -- Phase 4 ships ONLY the scaffolding — zero secrets are stored here.
  -- Phases 5/16/19/21/22 add their first real Vault entries on top.

  CREATE EXTENSION IF NOT EXISTS pgsodium;

  CREATE OR REPLACE FUNCTION app_vault_secret(p_name TEXT) RETURNS TEXT
  LANGUAGE SQL STABLE SECURITY DEFINER AS $$
    SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = p_name LIMIT 1;
  $$;
  ```
  - **Verify**: File exists with exactly the three logical sections (header comment, `CREATE EXTENSION`, `CREATE OR REPLACE FUNCTION`); the file contains NO `INSERT INTO vault.secrets` statement (FR-013); the function is `SECURITY DEFINER STABLE`.

- [ ] T035 [US4] Apply `20260506120006_enable_vault.sql` via Supabase MCP `apply_migration` with `name: "20260506120006_enable_vault"`. Then verify per quickstart [Steps 14, 15](quickstart.md#step-14--confirm-pgsodium-and-vault-scaffolding-are-in-place):
  ```sql
  -- (1) extension
  SELECT extname FROM pg_extension WHERE extname='pgsodium';
  -- (2) function — using pg_get_function_identity_arguments instead of proargtypes (A10 fix)
  SELECT proname,
         pg_get_function_identity_arguments(oid) AS args,
         prorettype::regtype AS return_type,
         prosecdef,
         provolatile
    FROM pg_proc WHERE proname='app_vault_secret';
  -- (3) missing-name returns NULL without error
  SELECT app_vault_secret('does_not_exist') AS result;
  -- (4) zero application-level secrets
  SELECT COUNT(*) FROM vault.secrets;
  ```
  Depends on T034 + T024.
  - **Verify**: Query 1 returns 1 row; query 2 returns one row with `args = 'p_name text'`, `return_type = 'text'`, `prosecdef = true`, `provolatile = 's'` (stable); query 3 returns NULL with no error; query 4 returns 0 (or matches the platform-managed baseline if Supabase pre-creates any — application-level count attributable to Phase 4 = 0); `list_migrations` shows `20260506120006_enable_vault`.

**Checkpoint**: User Story 4 complete.

---

## Phase 6: User Story 1 — Source-controlled backend invariant + documentation (Priority: P1)

**Goal**: Confirm that every Phase 4 backend artifact present on the remote project corresponds to a checked-in `.sql` file in the repo; the migrations apply idempotently; the schema is reproducible by re-applying the same files to a fresh project; and the two required documentation files exist and accurately describe the deployed schema.

**Independent Test**: Walk every artifact via `list_tables`/`list_migrations`/`pg_proc`/`pg_trigger` and confirm each maps to a checked-in `.sql` definition; read both docs files and confirm they describe the artifacts deployed in T010/T012/T022/T024/T035. Quickstart [Steps 1, 2, 3, 19](quickstart.md).

### Documentation

- [ ] T036 [P] [US1] Author `supabase/docs/profiles.md` per FR-018: human-readable description of the `profiles` table — its purpose, every column with type/default/nullable from data-model.md, the auto-provision trigger contract (cross-link `../../specs/004-supabase-foundation/contracts/auto-provision-trigger.md`), the RLS posture (self-read/write on non-status; admin-gated for status), the column-level enforcement trigger `enforce_profile_status_admin_only` (cross-link to R-12), the audit fields covered (`account_status`, `publisher_status` via `trg_profiles_audit_status`), and the deliberate omission of `preferred_language` / `preferred_currency` (Q2 — `user_preferences` is canonical).
  - **Verify**: File exists; reading it confirms seven sections (purpose, columns, auto-provision, RLS, R-12 trigger, audit, Q2 omission); column list matches `20260506120002_create_profiles.sql` exactly.

- [ ] T037 [P] [US1] Author `supabase/docs/audit_logs.md` per FR-018: human-readable description of the `audit_logs` table — its purpose, every column with type/default/nullable, the `log_audit()` trigger function contract (cross-link `../../specs/004-supabase-foundation/contracts/log-audit-trigger-fn.md`) with the `TG_ARGV[0]/[1]/[2]` convention and the `IS DISTINCT FROM` filter, the RLS posture (admin-only read; no client write), how later phases attach the function to new tables (Phase 5 `account_approval_requests`, Phase 6 roles, Phase 12 listings, Phase 18 reports, Phase 19 agencies, Phase 21 ads), and the convention that `ip`/`user_agent` are NULL in trigger-context writes and populated by Edge Functions from Phase 7+.
  - **Verify**: File exists; reading it confirms five sections; column list matches `20260506120004_create_audit_logs.sql`; the `TG_ARGV[2]` PK convention is described.

### Meta-verification of source-of-truth invariant

- [ ] T038 [US1] Quickstart [Step 1](quickstart.md#step-1--confirm-the-migrations-applied-cleanly): call Supabase MCP `list_migrations` and confirm exactly seven entries — `00000000000000_init_extensions` (pre-existing) plus the six Phase 4 filenames in order: `20260506120001_init_enums`, `20260506120002_create_profiles`, `20260506120003_create_user_preferences`, `20260506120004_create_audit_logs`, `20260506120005_enable_rls_default`, `20260506120006_enable_vault`. Depends on T035.
  - **Verify**: `list_migrations` returns the seven expected names in numeric (timestamp) order; no duplicates.

- [ ] T039 [US1] Quickstart [Step 2](quickstart.md#step-2--confirm-rls-is-enabled-on-every-phase-4-table): same query as T024 query 1 — confirm RLS is still enabled on all three tables. Depends on T024.
  - **Verify**: All three tables return `relrowsecurity = true`.

- [ ] T040 [US1] Quickstart [Step 3](quickstart.md#step-3--confirm-every-63-enum-exists): use the explicit IN-list (NOT `LIKE '%_enum'` — the IN-list rejects platform-managed enums that happen to end in `_enum`):
  ```sql
  SELECT typname FROM pg_type
   WHERE typname IN ('account_status_enum','publisher_status_enum',
                     'listing_status_enum','inquiry_status_enum','report_status_enum',
                     'listing_purpose_enum','property_type_enum',
                     'location_visibility_enum','report_reason_enum')
   ORDER BY typname;
  ```
  Depends on T005.
  - **Verify**: 9 rows.

- [ ] T041 [US1] Quickstart [Step 19](quickstart.md#step-19--confirm-every-backend-artifact-has-a-checked-in-sql-source): walk every Phase 4 artifact reported by the remote and confirm each has a matching `.sql` definition in `supabase/migrations/` or `supabase/policies/` at this commit:
  ```sql
  -- Tables
  SELECT tablename FROM pg_tables
   WHERE schemaname='public' AND tablename IN ('profiles','user_preferences','audit_logs');
  -- Functions
  SELECT proname FROM pg_proc
   WHERE proname IN ('handle_new_auth_user','log_audit','current_user_is_admin',
                     'app_vault_secret','set_updated_at','enforce_profile_status_admin_only')
   ORDER BY proname;
  -- Triggers
  SELECT tgname FROM pg_trigger
   WHERE tgname IN ('trg_auth_users_handle_new','trg_profiles_audit_status',
                    'trg_profiles_set_updated_at','trg_user_preferences_set_updated_at',
                    'trg_profiles_enforce_status_admin_only')
     AND NOT tgisinternal
   ORDER BY tgname;
  -- Extension
  SELECT extname FROM pg_extension WHERE extname='pgsodium';
  -- Policies (9 expected from T024 query 2)
  SELECT tablename, policyname FROM pg_policies WHERE schemaname='public'
     AND tablename IN ('profiles','user_preferences','audit_logs')
   ORDER BY tablename, policyname;
  -- Enums (9 expected from T040)
  ```
  For each artifact, locate the `.sql` source line in the repo. Depends on T035.
  - **Verify**: 3 tables, 6 functions, 5 triggers, 1 extension, 9 policies, 9 enums — each present on the remote AND with a matching definition in `supabase/migrations/` or `supabase/policies/`. Any artifact present on the remote with no repo source is a defect.

- [ ] T042 [US1] Confirm idempotent re-apply produces no schema drift. Capture a schema snapshot, attempt re-application, capture again, and diff:
  ```sql
  -- Snapshot 1 (before re-apply)
  SELECT proname, pg_get_functiondef(oid) FROM pg_proc
   WHERE proname IN ('handle_new_auth_user','log_audit','current_user_is_admin',
                     'app_vault_secret','set_updated_at','enforce_profile_status_admin_only');
  -- ... save the result
  ```
  Then attempt to apply `20260506120001_init_enums` again via `apply_migration` (with the same name). Snapshot again; diff. Behavior expected: Supabase MCP either rejects the duplicate name (no-op behavior) OR accepts and re-runs the body (idempotent constructs like `DO/EXCEPTION` and `CREATE OR REPLACE` make this safe). Depends on T035.
  - **Verify**: Either `apply_migration` returns an error message indicating the migration was already applied (no-op), OR it returns success and the second snapshot is byte-equivalent to the first. Either outcome satisfies SC-002.

**Checkpoint**: User Story 1 complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and the Flutter regression-launch verification.

- [ ] T043 Quickstart [Step 17](quickstart.md#step-17--confirm-the-flutter-app-builds-and-launches-on-the-reference-device): on the developer machine, `flutter clean`, `flutter pub get`, `flutter analyze` (zero issues), then deploy to the Infinix Note 8 (Helio G80, Android 10/11) via `flutter run --release -d <device-id>` or `flutter build apk --release` + `adb install -r`. Open the app; walk the existing Phase 1/2/3 surfaces (first launch in Arabic with RTL, theme toggle, locale toggle, Theme Gallery) and confirm everything still works. Depends on T020.
  - **Verify**: `flutter analyze` reports zero issues; APK installs cleanly; app launches without crash; Phase 1/2/3 surfaces behave identically to pre-Phase-4 state; `adb logcat | Select-String 'AuthState'` shows the auth-state listener emitting one initial event with no errors.

- [ ] T044 [P] Quickstart [Step 18](quickstart.md#step-18--confirm-domain-layer-entities-dont-import-supabase): Grep the four files for forbidden imports:
  ```text
  Get-ChildItem lib/shared/domain -Recurse -Filter *.dart |
    Select-String -Pattern 'package:supabase_flutter|lib/data|features/.*/data'
  ```
  Depends on T016, T017, T018, T019.
  - **Verify**: The Grep returns zero matches across `profile.dart`, `user_preferences.dart`, `account_status.dart`, `publisher_status.dart`.

- [ ] T045 [P] Confirm `CLAUDE.md` is current: open the file and verify the `<!-- SPECKIT START -->` block points at `specs/004-supabase-foundation/plan.md` and references the six Phase 4 contracts.
  - **Verify**: Reading `CLAUDE.md` confirms the block is correct.

- [ ] T046 [P] Quickstart [Step 20](quickstart.md#step-20--cleanup-the-test-data): via privileged Supabase MCP `execute_sql`:
  ```sql
  DELETE FROM auth.users WHERE id IN ('<$TEST_ID>', '<$OTHER_ID>');
  ```
  The `ON DELETE CASCADE` FK propagates to `profiles` and `user_preferences`; `audit_logs` rows persist (intentional — append-only; `actor_user_id` becomes NULL via `ON DELETE SET NULL`). Depends on T030/T032/T033 (after all verifications using the test users).
  - **Verify**: Subsequent `SELECT` from `profiles` / `user_preferences` for either id returns 0 rows; `SELECT COUNT(*) FROM audit_logs WHERE target_id IN ('<$TEST_ID>','<$OTHER_ID>')` returns the audit rows that were created in T025/T026 (still present).

- [ ] T047 Run Supabase MCP `get_advisors` against the remote project and confirm there are no NEW security-class advisors introduced by Phase 4. Depends on T035.
  - **Verify**: `get_advisors` returns no new RLS-disabled-on-user-facing-table warnings on `profiles`, `user_preferences`, `audit_logs`; no new "function with `SECURITY DEFINER` and unsafe search_path" warnings on `handle_new_auth_user` (sets `search_path = public`) or `log_audit` (sets `search_path = public`). The `app_vault_secret` and `enforce_profile_status_admin_only` functions are SECURITY DEFINER / INVOKER respectively per their R-06 / R-12 design.

**Checkpoint**: Phase 4 ready for the Git workflow squash-merge per `feedback_git_workflow.md`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001/T002 in parallel; T003 sequential.
- **Foundational (Phase 2)**: T004→T005 sequential. T006/T007/T008 in parallel after T003 (independent files; consumed by T023).
- **User Story 2 (Phase 3) — backend**: T009→T010 (apply 0002); T011→T012 (apply 0003, depends on T010 because 0003 references the auth.users trigger target); T013→T014→T015→T015a sequential verifications.
- **User Story 2 (Phase 3) — Flutter**: T016/T017/T019 parallel; T018 depends on T016+T017; T020 depends on no Flutter peers (different file). All independent of T013-T015a.
- **User Story 3 (Phase 4)**: T021→T022 (apply 0004, depends on T012); T023→T024 (apply 0005, depends on T022 + T006/T007/T008); T025-T029 sequential verifications all depend on T024.
- **US2 RLS follow-on**: T030/T031/T032/T033 all depend on T024.
- **User Story 4 (Phase 5)**: T034→T035 sequential (T035 depends on T024 for migration ordering).
- **User Story 1 (Phase 6)**: T036/T037 parallel docs; T038-T042 verification depends on T035.
- **Polish (Phase 7)**: T043 depends on T020. T044/T045/T046 parallel; T046 depends on T030/T032/T033 (test users no longer needed). T047 depends on T035.

### Parallel Opportunities

- Foundational policies (T006/T007/T008): three `[P]` files.
- US2 Flutter (T016/T017/T019): three `[P]` files; T018 depends on T016+T017.
- US1 docs (T036/T037): two `[P]` files.
- Polish pure-checks (T044/T045/T046): three `[P]` concerns.

### Within Each User Story

Backend SQL → Flutter domain → Flutter wrapper. SQL migrations apply sequentially via MCP regardless of `[P]` markers — the migration tracker enforces order.

---

## Implementation Strategy

### Recommended Full-Phase Delivery (solo developer)

1. Setup + Foundational (T001-T008).
2. US2 backend (T009-T015a) — auto-provision verified.
3. US2 Flutter (T016-T020) — domain entities + wrapper wiring; parallel-friendly.
4. US3 (T021-T029) — audit infrastructure + RLS bundle.
5. US2 RLS follow-on (T030-T033) — closes US2's RLS verification.
6. US4 (T034-T035) — Vault scaffolding.
7. US1 (T036-T042) — documentation + meta-verification.
8. Polish (T043-T047) — Flutter regression launch + cleanup.

Per the durable Git workflow contract (`feedback_git_workflow.md`), the entire spec ships as ONE PR with squash-merge — no per-phase PRs.

---

## Notes

- `[P]` tasks = different files, no dependencies → can run in parallel.
- `[Story]` label maps each task to a user story for traceability.
- Each task carries a `**Verify**:` line per Constitution Principle X.
- No automated tests (durable no-new-tests rule).
- Migration application is via Supabase MCP `apply_migration`; no local Supabase setup (Q5).
- The five Session 2026-05-06 clarifications are codified: Q1 (atomic preferences provisioning, T011), Q2 (no `preferred_language`/`preferred_currency` on profiles, T009), Q3 (all §6.3 enums in `0001`, T004), Q4 (NULL-distinct UNIQUE on username/phone, T009 + T015a), Q5 (remote-only deployment via MCP, every `apply_migration` task).
- The pre-implementation analysis findings are integrated: A1 (TG_ARGV[2] PK arg in T021), A2 (`enforce_profile_status_admin_only` trigger in T009 + T030), A3 (named policies in T006-T008), A4 (timestamp filenames throughout), A5 (multi-statement MCP wrap in T027-T033), A6 (StreamTransformer in T020), A7 (NOT NULL DEFAULT now() in T009/T011/T021), A8 (exact set_updated_at body in T009), A9 (exact INSERT INTO auth.users in T013), A10 (`pg_get_function_identity_arguments` in T035), A11 (worked DO/EXCEPTION example in T004), A12 (pinned idempotency check in T042), A13 (TO authenticated in T006-T008), A14 ($TEST_ID/$OTHER_ID protocol in Required Reading), A15 (direct trigger idempotency in T014), A16 (explicit enum names in T040), A17 (edge-case note in T013), A18 (verify other comments in T020), A19 (late-binding note in T011), A20 (header-comment template in Required Reading).
