---

description: "Task list for Phase 10 — Listing Creation & Submit-for-Review. Each task is self-contained with exact absolute file paths and contract pointers so a cheaper LLM model can implement without context-switching. Tasks are dependency-ordered: Setup → Foundational backend migrations → Foundational Flutter shared/core (validators + PermissionChecker helper + routes) → US1 publisher creates draft (MVP) → US2 non-approved gate verification → US3 rejected resubmit → US4 MyListingsPage → US5/US6/US7 verifications → Polish."

---

# Tasks: Listing Creation & Submit-for-Review

**Input**: Design documents from `/specs/010-listing-creation/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md` (12 files), `quickstart.md` — all complete and locked at Session 2026-05-18.

**Tests**: **NONE.** Per durable session feedback (`feedback_no_new_tests.md`), Phase 10 introduces ZERO new automated tests. Verification is manual SQL via Supabase MCP `execute_sql` + manual UI walks on the reference Infinix Note 8 device. The validator goldens in `contracts/validators.md` are manually exercised on the device, not automated. Existing Phase 1–9 tests remain unchanged.

**Organization**: Tasks are grouped by user story (US1 P1 is the MVP). Each story's checkpoint is a self-contained increment that can be demo'd without subsequent stories. Phase 10's plan-time ordering prioritizes shared infrastructure (validators, PermissionChecker helper, route guards) in Foundational + the 7 backend migrations in Phase 2, so US1's UI work is unblocked.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P]-marked tasks in the same phase (different files, no dependency on incomplete tasks).
- **[Story]**: User story label (US1..US7). Setup / Foundational / Polish tasks have NO story label.
- Every task includes the exact absolute file path and a pointer to the relevant contract / data-model section.

## Path Conventions

- Repository root: `H:\alnujom-project\`
- Supabase artifacts: `H:\alnujom-project\supabase\`
- Flutter sources: `H:\alnujom-project\lib\`
- ARB files: `H:\alnujom-project\lib\l10n\`

## Implementer briefing (read once before T001)

Before starting, read in this order:

1. `H:\alnujom-project\specs\010-listing-creation\spec.md` — entire file (Clarifications Q1/Q2/Q3 resolutions, 7 user stories, 24 Success Criteria).
2. `H:\alnujom-project\specs\010-listing-creation\plan.md` — entire file (Project Structure tree lists every file you will touch; Constitution Check explains every plan-time choice).
3. `H:\alnujom-project\specs\010-listing-creation\data-model.md` — entire file (full CREATE TABLE bodies, trigger function bodies, RLS policy bodies, RPC body, BLoC + entity shapes, validator API shapes, ARB key inventory, per-FR / per-SC verification map). **This is your most-consulted reference.**
4. `H:\alnujom-project\specs\010-listing-creation\quickstart.md` — Steps 1–6 first; re-read individual steps when verification tasks reference them.
5. Skim the 12 contract files in `H:\alnujom-project\specs\010-listing-creation\contracts\` — these are the binding interface definitions. The most critical ones: `submit-listing-rpc.md`, `phase10-rls-policies.md`, `listing-form-pages.md`, `area-centroid-autofill.md`, `validators.md`.
6. `H:\alnujom-project\specs\009-currencies\tasks.md` — skim for format reference. Phase 10 follows the same pattern with more file paths because the surface is bigger.

When a task says "per `contracts/<X>.md` § Y" or "per `data-model.md` § Z", that section is your source of truth for the exact code/SQL — copy it verbatim and adjust only the table/column names called out in the task.

**Three carry-forward project memories matter most**:

- `feedback_no_new_tests.md` — **do not write any new automated test files**. Manual verification only.
- `feedback_git_workflow.md` — commit + push immediately after each phase / each checkpoint marker (`⚠️ Checkpoint:` lines below). One PR per spec, opened only at end-of-spec.
- `project_dart_defines.md` — `flutter run` MUST include `--dart-define-from-file=.env.json` or Supabase.initialize is skipped and the app red-screens.

### Project ground-truth references (probe-confirmed at plan time)

The cheaper LLM should treat these as authoritative. They were verified by reading the actual files during Phase 10 plan + analyze; they are not guesses.

- **`PermissionChecker` at `lib/core/security/permission_checker.dart`** caches a `Set<String>` of permission keys ONLY. It does NOT cache the user's profile. Do NOT add profile state to PermissionChecker. The publisher-status three-layer gate uses `AuthBloc` state instead (see R-19 in `research.md`).
- **`AuthBloc` at `lib/features/auth/presentation/bloc/auth_bloc.dart`** emits `AuthState` with these variants per `auth_state.dart`: `Unauthenticated`, `Authenticating`, `Authenticated(profile: Profile)`, `PendingApproval()`, `Rejected()`, `Suspended()`, `AuthError()`. Only `Authenticated` carries a Profile. Phase 5 publishes the AuthBloc as a global instance; consume via `BlocBuilder<AuthBloc, AuthState>` in widgets and via `authBloc.state` in router guards.
- **`Profile` entity at `lib/features/profile/domain/entities/`** carries fields including `publisherStatus: PublisherStatus` and `accountStatus: AccountStatus`. The two enums are defined in the same folder. `PublisherStatus.approved` and `AccountStatus.approved` are the values to check.
- **Router at `lib/core/routing/app_router.dart`** uses the `AppRoutes` + `AppRouteNames` abstract final classes for path/name constants, and `requireXxxRedirect` helpers in `auth_redirect.dart` for per-route guards. New routes must follow this pattern: add constants to `AppRoutes` / `AppRouteNames`, then attach a `redirect: requirePublisherStatusRedirect` callback on the `GoRoute`.
- **`auth_redirect.dart` at `lib/core/routing/auth_redirect.dart`** contains the redirect helpers. Phase 10 adds a new helper `requirePublisherStatusRedirect` mirroring `requireCurrenciesManageRedirect`'s shape (reads `authBloc.state`, casts to `Authenticated`, returns redirect path on cast-fail or wrong status).
- **`HomePage` at `lib/features/home/presentation/pages/home_page.dart`** is the post-login landing screen. It contains the existing Phase 5 + Phase 6/7/8/9 tiles (Profile, Admin, etc.). Phase 10 adds two new tiles ("Create listing", "My listings") to this page. There is NO `publisher_dashboard_page.dart` in the project — the "publisher dashboard" colloquial term refers to `HomePage`. The `lib/features/publisher_dashboard/` feature folder is new Phase-10 scaffolding for `MyListingsPage`; do NOT confuse it with the publisher's home surface.
- **`ListCurrencies` use case at `lib/features/currencies/domain/usecases/list_currencies.dart`** exposes `Future<List<Currency>> call({bool activeOnly = false})`. Phase 10's prices step calls it with `activeOnly: true` to populate the dropdown.

### RLS testing helper (READ BEFORE running any "RLS deny" verification)

The Supabase MCP `execute_sql` tool runs queries with the **project's service_role JWT**, which BYPASSES Row Level Security. A naive `INSERT INTO public.listings ...` via `execute_sql` will SUCCEED even when the RLS policy would deny it for a real user. To validate RLS behavior, every "expected: 0 rows affected / RLS deny" verification MUST use ONE of these two impersonation patterns:

**Pattern A — Set the role and JWT claims for the current transaction (preferred for MCP)**:

```sql
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"<USER_UUID>","role":"authenticated"}';
-- Now run the operation; RLS evaluates as if this user is the caller.
INSERT INTO public.listings (publisher_user_id, purpose, property_type, title, governorate_id)
VALUES ('<USER_UUID>', 'sale', 'apartment', 'test', '<GOV_UUID>');
-- Expected for a non-approved publisher: ERROR 42501 (new row violates row-level security policy)
ROLLBACK;
```

Use `ROLLBACK` always — these verifications must not leave state behind.

**Pattern B — Use the Supabase HTTP REST endpoint (no MCP)**:

```bash
curl -X POST 'https://<PROJECT>.supabase.co/rest/v1/listings' \
  -H "apikey: <ANON_KEY>" \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"publisher_user_id":"<USER_UUID>","purpose":"sale",...}'
# Expected for a non-approved publisher: HTTP 401/403 with code 42501.
```

Pattern A is preferred because the cheaper LLM has MCP `execute_sql` but typically no shell access. For every RLS-deny verification in this tasks file (T010, T022, T025, T083, T107), USE Pattern A — the `BEGIN ... SET LOCAL ROLE authenticated; SET LOCAL "request.jwt.claims" ... ; <op>; ROLLBACK;` block. The verification's expected outcome shifts from "0 rows affected" (which is misleading) to "ERROR 42501 new row violates row-level security policy" or equivalent.

The anonymous-deny verifications (T003, quickstart Step 3, T026, quickstart Step 12 anon read) use a different pattern: `SET LOCAL ROLE anon; SET LOCAL "request.jwt.claims" TO '{"role":"anon"}'`. This makes the query run as the `anon` role per Phase 4's role grants. Same wrapping in BEGIN/ROLLBACK.

If a verification can't be made to work via either pattern (rare), defer to a manual test on the device with a real user's JWT.

---

## Phase 1: Setup

**Purpose**: Confirm environment + warm the toolchain. NO production code authored yet.

- [ ] T001 Verify current git state. From `H:\alnujom-project`, run `git status` and `git branch --show-current`. Expected: branch `010-listing-creation`, working tree clean apart from the already-committed `specs/010-listing-creation/*` files. If branch differs, STOP and ask. If tree has unrelated dirty files, commit or stash before proceeding.

- [ ] T002 [P] Verify Phase 9 is shipped on the remote Supabase project. Run via Supabase MCP `execute_sql` five checks: (a) `SELECT count(*) FROM public.currencies` returns `2`; (b) `SELECT code FROM public.currencies WHERE is_system ORDER BY sort_order` returns `SYP` then `USD`; (c) `SELECT count(*) FROM pg_proc WHERE proname='current_user_has_permission'` returns `1`; (d) `SELECT count(*) FROM pg_proc WHERE proname='log_audit'` returns `1`; (e) `SELECT count(*) FROM pg_proc WHERE proname='set_updated_at'` returns `1`. If any check fails, STOP — Phase 10 cannot proceed without Phase 9's currencies catalog + Phase 4's reusable helpers.

- [ ] T003 [P] Verify Phase 8's `public.areas` table exists and has rows. Run via Supabase MCP `execute_sql`: `SELECT count(*) FROM public.areas` — record the count. Expected: between 30 and 100 area rows (the Phase 8 seed populated Syrian areas across 14 governorates). Also run: `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='areas' AND column_name IN ('centroid_lat','centroid_lng')` — expected: 0 rows (centroid columns do NOT yet exist; T009 will add them).

- [ ] T004 [P] Verify `H:\alnujom-project\.env.json` exists and contains valid Supabase credentials (URL + anon key + service_role key per project memory `project_dart_defines.md`). If missing, STOP and ask the user to provide the file. Do NOT commit `.env.json` (it is in `.gitignore`).

- [ ] T005 Capture pre-migration baseline to `H:\alnujom-project\specs\010-listing-creation\baseline-pre-migration.txt`. Concatenate the following sections (use the section headers shown verbatim) into the file: (A) Supabase MCP `list_tables` output for the `public` schema; (B) Supabase MCP `list_migrations` output (full ordered list — the last entry MUST be `20260518120005_phase9_advisor_hardening`); (C) `SELECT count(*) FROM public.listings` — expected: error `relation "public.listings" does not exist`; record the error verbatim; (D) `SELECT key FROM public.permissions WHERE key LIKE 'listings.%' ORDER BY key` — expected: 5 rows (`listings.approve`, `listings.delete_any`, `listings.edit_any`, `listings.reject`, `listings.view_all`); record verbatim; (E) **Analyzer baseline**: from `H:\alnujom-project`, run `flutter analyze --no-fatal-infos --no-fatal-warnings` and paste the full stdout/stderr verbatim under this section header. This snapshot is the rollback reference if Phase 10 needs to be reverted AND the analyzer-comparison reference for the final polish phase.

**⚠️ Checkpoint A — Setup complete**: Environment confirmed, Phase 9 verified shipped, Phase 8 `public.areas` present, `.env.json` present, baseline snapshot captured. Commit: `git add specs/010-listing-creation/baseline-pre-migration.txt && git commit -m "chore(010): capture pre-migration baseline" && git push`.

---

## Phase 2: Foundational — Backend Migrations (Blocking Prerequisites)

**Purpose**: Apply the 7 Phase 10 migrations + 5 new policy files + 6 new/updated doc files. The 5 new tables, 1 altered Phase 8 table, status-transition trigger, sync trigger, audit-trigger group, 5 RLS policy bundles, the `submit_listing` RPC all land here. EVERY downstream user story depends on this phase.

**⚠️ CRITICAL**: No user story task may begin until Phase 2 is complete and verified.

### Migration 1 — ALTER public.areas + centroid seed

- [ ] T006 **HUMAN-OPERATOR HAND-OFF TASK** — this task requires WebFetch / map-lookup tooling that a cheaper LLM may not have. If your environment lacks WebFetch, STOP and ask the human operator to provide the centroid inventory before continuing. The inventory is a list of `(area_id, name_en, centroid_lat, centroid_lng)` triples for every row in `public.areas`. Procedure: (1) run via Supabase MCP `execute_sql`: `SELECT id, name_en, name_ar, c.name_en AS city_name FROM public.areas a JOIN public.cities c ON a.city_id=c.id ORDER BY c.name_en, a.name_en` and save the output verbatim. **Record the exact `name_en` strings from the result — DO NOT invent names; the contracts' verification queries reference the actual seed values.** (2) For each row, look up the area's centroid on OpenStreetMap (search "<area name_en>, <city_name>, Syria" at https://nominatim.openstreetmap.org/ui/search.html OR https://www.openstreetmap.org/search; click the result; read the URL's lat/lon parameters or hover to get coordinates). Record 6 decimal places of precision. (3) Verify every coordinate satisfies `lat BETWEEN 32 AND 37 AND lng BETWEEN 35 AND 43` (Syria's bounding box). (4) Verify your inventory is complete — every row from step (1) has a coordinate pair. Save the final inventory as inline VALUES for the migration body in T007. **If no LLM tooling and no human operator can supply the centroids, the migration cannot proceed; you cannot fall back to `(0,0)` or guess.**

- [ ] T007 Author migration 1 file at `H:\alnujom-project\supabase\migrations\20260519120001_alter_areas_add_centroids.sql`. (FR-013a, R-07, SC-023.) Body MUST contain, in exactly this order: (1) leading SQL `-- COMMENT` block citing FR-013a, R-07 and Q2 resolution; (2) `ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS centroid_lat NUMERIC(9, 6); ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS centroid_lng NUMERIC(9, 6);` (columns initially NULL); (3) for each row in the T006 inventory, one `UPDATE public.areas SET centroid_lat=<lat>, centroid_lng=<lng> WHERE id='<id>';` statement (one statement per row, in the order from T006); (4) the verification block from `data-model.md § Altered Phase 8 table` (`DO $$ ... missing_count > 0 RAISE EXCEPTION ... END $$;`); (5) `ALTER TABLE public.areas ALTER COLUMN centroid_lat SET NOT NULL; ALTER TABLE public.areas ALTER COLUMN centroid_lng SET NOT NULL;`; (6) `ALTER TABLE public.areas ADD CONSTRAINT areas_centroid_syria_bounds CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43);`. Copy the full body from `data-model.md § Altered Phase 8 table` and replace the truncated example UPDATEs with your full T006 inventory.

- [ ] T008 Apply migration 1 via Supabase MCP `apply_migration` with name `20260519120001_alter_areas_add_centroids` and body from T007. Then verify via Supabase MCP `execute_sql`: (a) `SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='areas' AND column_name IN ('centroid_lat','centroid_lng') AND is_nullable='NO'` returns `2`; (b) `SELECT count(*) FROM public.areas WHERE centroid_lat IS NULL OR centroid_lng IS NULL` returns `0`; (c) `SELECT count(*) FROM public.areas WHERE centroid_lat NOT BETWEEN 32 AND 37 OR centroid_lng NOT BETWEEN 35 AND 43` returns `0`; (d) `SELECT constraint_name FROM information_schema.table_constraints WHERE table_name='areas' AND constraint_name='areas_centroid_syria_bounds'` returns `1` row.

### Migration 2 — public.listings table + RLS

- [ ] T009 Author migration 2 file at `H:\alnujom-project\supabase\migrations\20260519120002_create_listings.sql`. (FR-001, FR-002, FR-005, FR-006.) Body MUST contain, in exactly this order: (1) leading SQL `-- COMMENT` block citing FR-001/002/005/006, R-04 (no broad anon carve-out), R-17 (agency_id no FK), R-16 (public-read-when-approved shipped here); (2) the full `CREATE TABLE IF NOT EXISTS public.listings (...)` body from `data-model.md § Tables § public.listings` (all 25 columns, all CHECK constraints, all FK references); (3) `ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;`; (4) the `set_updated_at` trigger attach: `DROP TRIGGER IF EXISTS trg_listings_set_updated_at ON public.listings; CREATE TRIGGER trg_listings_set_updated_at BEFORE UPDATE ON public.listings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();`; (5) the three indexes from `data-model.md § Tables § public.listings` (`idx_listings_publisher_status`, `idx_listings_status_created`, `idx_listings_governorate`); (6) the 7 RLS policies from `data-model.md § RLS Policies § public.listings` (verbatim: `listings_select_public`, `listings_select_owner`, `listings_select_admin`, `listings_insert_owner`, `listings_update_owner`, `listings_update_admin`, `listings_delete_admin`). Each `CREATE POLICY` is preceded by `DROP POLICY IF EXISTS <name> ON public.listings;` for idempotency.

- [ ] T010 Apply migration 2 via Supabase MCP `apply_migration` with name `20260519120002_create_listings` and body from T009. Then verify via Supabase MCP `execute_sql` (all read-only — service_role context is FINE here, RLS deny is tested separately in T083 + T107 using Pattern A from the implementer briefing): (a) `SELECT relrowsecurity FROM pg_class WHERE relname='listings' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public')` returns `t`; (b) `SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='listings'` returns `25`; (c) `SELECT count(*) FROM pg_indexes WHERE tablename='listings' AND indexname LIKE 'idx_listings_%'` returns `3`; (d) `SELECT count(*) FROM pg_policies WHERE tablename='listings'` returns `7`; (e) `SELECT count(*) FROM information_schema.referential_constraints WHERE constraint_name LIKE '%listings%' AND constraint_name LIKE '%agency%'` returns `0` (R-17 / SC-017: no FK on agency_id in Phase 10).

- [ ] T011 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listings_policies.sql`. Body MUST be a verbatim copy of the 7 `DROP POLICY IF EXISTS ... CREATE POLICY ...` blocks from migration 2 step (6). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260519120002_create_listings.sql. R-02 dual-storage invariant — both files MUST be kept in sync at PR review.`

- [ ] T011a Anonymous SELECT smoke test (verifies SC-005). Via Supabase MCP `execute_sql` using Pattern A from the implementer briefing:

  ```sql
  BEGIN;
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" TO '{"role":"anon"}';
  SELECT count(*) FROM public.listings;
  -- Expected: 0 (no approved+publish-window-open listings exist yet — Phase 10 seeds no listings)
  -- The RLS policy listings_select_public limits anon SELECT to status='approved' rows in the publish window.
  ROLLBACK;
  ```

  Re-run later in T081/T082's verification window once a Phase-10-created listing exists in `status='pending_review'` — confirm anon still sees 0 rows (because pending_review is not approved). Once Phase 12 ships and flips a listing to `approved`, anon will see that one row.

### Migration 3 — public.listing_details + RLS

- [ ] T012 Author migration 3 file at `H:\alnujom-project\supabase\migrations\20260519120003_create_listing_details.sql`. (FR-003.) Body MUST contain, in order: (1) leading `-- COMMENT` block citing FR-003 + the child-derived-ownership pattern; (2) full `CREATE TABLE IF NOT EXISTS public.listing_details (...)` body from `data-model.md § Tables § public.listing_details`; (3) `ALTER TABLE public.listing_details ENABLE ROW LEVEL SECURITY;`; (4) `set_updated_at` trigger attach (mirror T009 step 4); (5) the 3 RLS policies (SELECT inherited from parent; ALL owner via parent ownership + status-in-(draft,rejected); ALL admin via listings.edit_any). Use the same shape as `data-model.md § RLS Policies § Child tables § listing_prices` but with `listing_details` substituted for the table name. Each `CREATE POLICY` preceded by `DROP POLICY IF EXISTS ...` for idempotency.

- [ ] T013 Apply migration 3 via Supabase MCP `apply_migration` with name `20260519120003_create_listing_details`. Verify: (a) `SELECT relrowsecurity FROM pg_class WHERE relname='listing_details' ...` returns `t`; (b) `SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='listing_details'` returns `8`; (c) `SELECT count(*) FROM pg_policies WHERE tablename='listing_details'` returns `3`; (d) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.listing_details'::regclass AND tgname='trg_listing_details_set_updated_at'` returns `1`.

- [ ] T014 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_details_policies.sql`. Mirror of T012 step (5) policies + leading R-02 comment.

### Migration 4 — public.listing_prices + RLS + partial unique index

- [ ] T015 Author migration 4 file at `H:\alnujom-project\supabase\migrations\20260519120004_create_listing_prices.sql`. (FR-003, SC-008, SC-009, SC-022.) Body MUST contain, in order: (1) leading `-- COMMENT` citing FR-003 + Phase 9 Q4 + R-10 + R-12 + Q3 single-row invariant; (2) full `CREATE TABLE IF NOT EXISTS public.listing_prices (...)` from `data-model.md § Tables § public.listing_prices` (includes `UNIQUE(listing_id, currency_code)` per Phase 9 Q4); (3) `CREATE UNIQUE INDEX IF NOT EXISTS listing_prices_one_primary_idx ON public.listing_prices (listing_id) WHERE is_primary = true;` (R-12); (4) `CREATE INDEX IF NOT EXISTS idx_listing_prices_listing_id ON public.listing_prices (listing_id);`; (5) `ALTER TABLE public.listing_prices ENABLE ROW LEVEL SECURITY;`; (6) the 3 RLS policies from `data-model.md § RLS Policies § Child tables § listing_prices` (verbatim).

- [ ] T016 Apply migration 4. Verify: (a) `SELECT count(*) FROM information_schema.table_constraints WHERE table_name='listing_prices' AND constraint_type='UNIQUE'` returns at least `1` (the listing_id+currency_code UNIQUE); (b) `SELECT count(*) FROM pg_indexes WHERE tablename='listing_prices' AND indexname='listing_prices_one_primary_idx'` returns `1`; (c) `SELECT count(*) FROM pg_policies WHERE tablename='listing_prices'` returns `3`; (d) `SELECT count(*) FROM information_schema.referential_constraints WHERE constraint_name LIKE '%listing_prices%currency_code%'` returns `1` (the FK to currencies(code) per Phase 9 forward-statement).

- [ ] T017 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_prices_policies.sql`. Mirror of T015 step (6) policies + leading R-02 comment.

### Migration 5 — public.listing_visibility + sync trigger + RLS

- [ ] T018 Author migration 5 file at `H:\alnujom-project\supabase\migrations\20260519120005_create_listing_visibility.sql`. (FR-003, R-11.) Body MUST contain, in order: (1) leading `-- COMMENT` citing FR-003 + R-11 parent-column-authoritative pattern; (2) full `CREATE TABLE IF NOT EXISTS public.listing_visibility (...)` from `data-model.md § Tables § public.listing_visibility`; (3) `ALTER TABLE public.listing_visibility ENABLE ROW LEVEL SECURITY;`; (4) `set_updated_at` trigger attach; (5) the 3 RLS policies (parent-derived shape, same as listing_details); (6) the `listing_visibility_sync_trigger` function + trigger from `data-model.md § Triggers § listing_visibility_sync_trigger` (verbatim — the trigger fires on the parent `public.listings`, NOT on the child table; this is by design so the parent column remains authoritative).

- [ ] T019 Apply migration 5. Verify: (a) `SELECT relrowsecurity FROM pg_class WHERE relname='listing_visibility' ...` returns `t`; (b) `SELECT count(*) FROM pg_proc WHERE proname='listing_visibility_sync_trigger_fn'` returns `1`; (c) `SELECT count(*) FROM pg_trigger WHERE tgname='listing_visibility_sync_trigger' AND tgrelid='public.listings'::regclass` returns `1`; (d) `SELECT count(*) FROM pg_policies WHERE tablename='listing_visibility'` returns `3`.

- [ ] T020 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_visibility_policies.sql`. Mirror of T018 step (5) policies + leading R-02 comment.

### Migration 6 — public.listing_status_history + status-transition trigger + audit-trigger group

- [ ] T021 Author migration 6 file at `H:\alnujom-project\supabase\migrations\20260519120006_create_listing_status_history.sql`. (FR-004, FR-004a, FR-007, R-09.) Body MUST contain, in order: (1) leading `-- COMMENT` citing FR-004/004a/007 + R-05 (log_audit reused 7th time) + R-09 (separate operational vs compliance triggers); (2) full `CREATE TABLE IF NOT EXISTS public.listing_status_history (...)` from `data-model.md § Tables § public.listing_status_history`; (3) `CREATE INDEX IF NOT EXISTS idx_listing_status_history_listing ON public.listing_status_history (listing_id, changed_at DESC);`; (4) `ALTER TABLE public.listing_status_history ENABLE ROW LEVEL SECURITY;`; (5) the 2 RLS policies from `data-model.md § RLS Policies § public.listing_status_history` (`listing_status_history_insert_trigger_only` with `pg_trigger_depth() > 0` predicate; `listing_status_history_select_owner` — NO UPDATE/DELETE policy); (6) the `listing_status_transition_trigger_fn` function + trigger from `data-model.md § Triggers § listing_status_transition_trigger` (verbatim); (7) the `listings_audit_trigger_fn` function + trigger from `data-model.md § Triggers § Audit trigger group on public.listings` (verbatim — note this function is the AUDIT trigger, separate from the status-transition trigger per R-09).

- [ ] T022 Apply migration 6. Verify: (a) `SELECT relrowsecurity FROM pg_class WHERE relname='listing_status_history' ...` returns `t`; (b) `SELECT count(*) FROM pg_policies WHERE tablename='listing_status_history'` returns exactly `2` (NO UPDATE, NO DELETE policies); (c) `SELECT polcmd FROM pg_policy p JOIN pg_class c ON p.polrelid=c.oid WHERE c.relname='listing_status_history'` returns only `r` (SELECT) and `a` (INSERT) — NO `w` (UPDATE) or `d` (DELETE); (d) `SELECT count(*) FROM pg_proc WHERE proname IN ('listing_status_transition_trigger_fn','listings_audit_trigger_fn')` returns `2`; (e) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.listings'::regclass AND tgname IN ('listing_status_transition_trigger','listings_audit_trigger')` returns `2`; (f) `SELECT prosrc FROM pg_proc WHERE proname='log_audit'` — copy the result and diff against the Phase 4 migration body to confirm `log_audit` is unchanged (R-05 invariant preserved 7th time).

- [ ] T023 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_status_history_policies.sql`. Mirror of T021 step (5) policies + leading R-02 comment + explicit note: `-- NO UPDATE POLICY. NO DELETE POLICY. Table is append-only per FR-007.`

### Migration 7 — submit_listing RPC

- [ ] T024 Author migration 7 file at `H:\alnujom-project\supabase\migrations\20260519120007_create_submit_listing_rpc.sql`. (FR-010, FR-010a, R-06.) Body MUST contain, in order: (1) leading `-- COMMENT` citing FR-010 + FR-010a + R-06 (RPC not Edge Function — Phase 7/9 carry-forward); (2) the full `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID) RETURNS JSONB ... $$;` body from `data-model.md § RPC: public.submit_listing(...)` verbatim (this includes the loadrow, ownership check, approved-pair check, status check, Q1 Full validation, status flip, return JSONB); (3) `REVOKE EXECUTE ON FUNCTION public.submit_listing(UUID) FROM PUBLIC, anon;`; (4) `GRANT EXECUTE ON FUNCTION public.submit_listing(UUID) TO authenticated;`. **Implementation note**: the function body's `auth.uid()` calls resolve correctly because the function carries `SET search_path = public, auth` — do NOT qualify further. The `RAISE EXCEPTION USING ERRCODE = '<sqlstate>', MESSAGE = '<msg>', DETAIL = <jsonb_text>` form is the standard PL/pgSQL pattern; the Flutter client will catch this as a `PostgrestException` with `.code = '<sqlstate>'` and `.details = <DETAIL string>` — the JSON-parseable `missing_fields` payload is in `.details`, which the client parses in T047.

- [ ] T025 Apply migration 7. Verify: (a) `SELECT proname, prosecdef FROM pg_proc WHERE proname='submit_listing'` returns 1 row with prosecdef=`t`; (b) `SELECT proconfig FROM pg_proc WHERE proname='submit_listing'` returns an array containing `search_path=public,auth`; (c) `SELECT grantee, privilege_type FROM information_schema.routine_privileges WHERE routine_name='submit_listing'` — verify `authenticated` has EXECUTE; verify `anon` and `PUBLIC` do NOT appear; (d) attempt as anonymous using Pattern A from the implementer briefing (SC-011 surface): `BEGIN; SET LOCAL ROLE anon; SET LOCAL "request.jwt.claims" TO '{"role":"anon"}'; SELECT public.submit_listing('00000000-0000-0000-0000-000000000000'::uuid); ROLLBACK;` — expected: ERROR 42501 permission denied for function submit_listing (anon has no EXECUTE per the REVOKE in migration 7).

### Migration 8 — v_publisher_listings view (most-recent history + primary price per listing)

- [ ] T025a Author migration 8 file at `H:\alnujom-project\supabase\migrations\20260519120008_create_v_publisher_listings.sql`. (Supports FR-015, SC-015; bound by `contracts/phase10-v-publisher-listings.md` — needed because Postgrest doesn't natively express "most-recent per group" joins; the view does it server-side and is then queried as a single relation by `MyListingsPage`'s data layer.) Body MUST contain: (1) leading `-- COMMENT` block citing FR-015 + `contracts/phase10-v-publisher-listings.md` + the rationale that the view is a query helper (RLS is inherited from underlying tables; the view is NOT a security boundary); (2) the full `CREATE OR REPLACE VIEW public.v_publisher_listings AS ...` body from `data-model.md § View: public.v_publisher_listings` (verbatim — uses `LEFT JOIN LATERAL (... ORDER BY changed_at DESC LIMIT 1) h ON true` for the most-recent history row + `LEFT JOIN public.listing_prices p ON p.listing_id=l.id AND p.is_primary=true` for the primary price; filters out `l.status='deleted'`); (3) `GRANT SELECT ON public.v_publisher_listings TO authenticated;`.

- [ ] T025b Apply migration 8 via Supabase MCP `apply_migration` with name `20260519120008_create_v_publisher_listings`. Then verify: (a) `SELECT count(*) FROM pg_views WHERE viewname='v_publisher_listings'` returns `1`; (b) `SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='v_publisher_listings'` returns a count matching the column list in `data-model.md § View` (about 30 columns: 24 from listings minus `id` (renamed listing_id) + 6 history columns + 3 primary-price columns = approx 30); (c) `SELECT grantee FROM information_schema.role_table_grants WHERE table_name='v_publisher_listings' AND privilege_type='SELECT'` includes `authenticated`; (d) the view is queryable from PostgREST — quick smoke test by selecting any approved listing as an authenticated user (will be exercised properly in T101).

### Run advisors after all migrations

- [ ] T026 Run Supabase MCP `get_advisors`. Expected: zero new warnings vs the T005 baseline. If new warnings appear, read them carefully — common cases: (a) "policies allow anon SELECT" — expected for the listings public-read policy (`status='approved'`); the advisor may flag this — annotate in `H:\alnujom-project\specs\010-listing-creation\baseline-pre-migration.txt` under a new section `(F) ADVISOR DELTA AFTER PHASE 10 MIGRATIONS` and explain the carve-out; (b) "function without search_path" — verify the RPC has `SET search_path=public,auth` (T024); (c) "trigger function without SECURITY DEFINER" — neither the status-transition nor the sync nor the audit trigger functions need SECURITY DEFINER (they run as the row owner); ignore. Phase 10 does NOT author a separate `phase10_advisor_hardening.sql` migration (unlike Phase 9 which had one) because the REVOKE/GRANT on the new RPC is bundled inline in T024. If `get_advisors` flags a NEW concern that requires SQL fixes, append a new migration `20260519120009_phase10_advisor_hardening.sql` with the targeted fix (mirror the Phase 9 advisor-hardening file's structure).

### Backend documentation

- [ ] T027 [P] Author `H:\alnujom-project\supabase\docs\listings.md`. Body: a short markdown doc describing the table — its 25 columns, the RLS posture (public-when-approved SELECT; owner+admin write; the approved-pair gate via `profiles.publisher_status`), the trigger attachments (`set_updated_at`, `listing_visibility_sync_trigger`, `listing_status_transition_trigger`, `listings_audit_trigger`), the FK-less `agency_id` (R-17 note that Phase 19 adds the FK). Cite `data-model.md § Tables § public.listings` and `contracts/phase10-tables.md` + `contracts/phase10-rls-policies.md`.

- [ ] T028 [P] Author `H:\alnujom-project\supabase\docs\listing_details.md`. Body: short doc — 1:1 child table, parent-derived policies, no special triggers beyond `set_updated_at`.

- [ ] T029 [P] Author `H:\alnujom-project\supabase\docs\listing_prices.md`. Body: short doc — Phase 9 forward-stated `UNIQUE(listing_id, currency_code)` + the FK to `currencies(code) ON DELETE RESTRICT`; R-12 partial unique on `(listing_id) WHERE is_primary=true`; the Q3 Phase-10 single-row-per-listing invariant.

- [ ] T030 [P] Author `H:\alnujom-project\supabase\docs\listing_visibility.md`. Body: short doc — R-11 parent-column-authoritative sync trigger; child row is a narrow projection used by Phase 15's `v_listings_map` per IMPLEMENTATION_PLAN §Phase 15.

- [ ] T031 [P] Author `H:\alnujom-project\supabase\docs\listing_status_history.md`. Body: short doc — FR-007 append-only invariant via INSERT-trigger-only RLS; FR-004 trigger writes from any UPDATE of status; FR-004a + R-09 the audit-log table is the parallel compliance trail (separate from this operational history).

- [ ] T032 Update `H:\alnujom-project\supabase\docs\audit_logs.md` to enumerate the 10 new action keys: `listing.created`, `listing.updated`, `listing.deleted`, `listing.submitted`, `listing.approved`, `listing.rejected`, `listing.paused`, `listing.expired`, `listing.sold`, `listing.rented`. Use the existing file's table format; add the rows in the listings section.

**⚠️ Checkpoint B — Backend migrations complete**: 8 migrations applied (7 table/RPC + 1 view), 5 policy files mirrored, 6 docs authored/updated, advisors clean. Verify: `SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename IN ('listings','listing_details','listing_prices','listing_visibility','listing_status_history')` returns `5`; `SELECT count(*) FROM pg_views WHERE viewname='v_publisher_listings'` returns `1`; `SELECT count(*) FROM pg_proc WHERE proname='submit_listing'` returns `1`. Commit: `git add supabase/ && git commit -m "feat(010): backend migrations + policies + docs (8 migrations, 5 policies, 6 docs, 1 RPC, 1 view)" && git push`.

---

## Phase 3: Foundational — Flutter Core (Validators + Permission Helper + Routes)

**Purpose**: Land the three validators (FR-018), the `ListingFormMode` enum stub (T038), and the four new go_router routes wired through `requirePublisherStatusRedirect` (R-19 revised / FR-009). The publisher-status gate is AuthBloc-driven; PermissionChecker is NOT modified. These are consumed by US1's form widgets, so they must ship before any feature folder.

### Validators

- [ ] T033 [P] Author `H:\alnujom-project\lib\core\validators\area_size_validator.dart`. Per `contracts/validators.md § AreaSizeValidator`. The file MUST export a class `AreaSizeValidator` with one static method `static String? validate(num? value, AppLocalizations l10n)`. Logic per the rules table in the contract. Imports: only `package:flutter_gen/gen_l10n/app_localizations.dart` (for the `AppLocalizations` type). No `package:supabase_flutter`. No `package:decimal` (the validator accepts `num`, not `Decimal` — that's the `PriceValidator`'s domain). No Supabase imports. Re-run `dart analyze lib/core/validators/area_size_validator.dart` and confirm 0 errors.

- [ ] T034 [P] Author `H:\alnujom-project\lib\core\validators\price_validator.dart`. Per `contracts/validators.md § PriceValidator`. The file MUST export a class `PriceValidator` with one static method `static String? validate(Decimal? value, Currency currency, AppLocalizations l10n)`. Imports: `package:decimal/decimal.dart`, `package:flutter_gen/gen_l10n/app_localizations.dart`, and the existing Phase 9 `Currency` entity at `package:alnujom/features/currencies/domain/entities/currency.dart` (verify path matches actual Phase 9 layout). Logic per the rules table in the contract: reject null/non-positive; reject precision > NUMERIC(14,2); round-or-pass for currency.displayDecimals overage. No Supabase imports.

- [ ] T035 [P] Author `H:\alnujom-project\lib\core\validators\phone_validator.dart`. Per `contracts/validators.md § PhoneValidator`. The file MUST export a class `PhoneValidator` with one static method `static ({String? error, String? normalized}) validateAndNormalize(String? value, AppLocalizations l10n)`. Reuse Phase 5's `PhoneNumber` value object E.164 normalization logic — find the value object at `H:\alnujom-project\lib\shared\domain\value_objects\phone_number.dart` (or wherever Phase 5 placed it; grep `phone_number.dart` if path is uncertain) and call its normalization function. Do NOT reimplement E.164 logic in the validator. Output shape per contract.

### Publisher-status checker (uses AuthBloc — NOT PermissionChecker)

**Important context** (per R-19 revised + implementer briefing § Project ground-truth references): `PermissionChecker` is permission-keys-only and intentionally does NOT cache the user's profile. The publisher-status gate consumes the existing `AuthBloc` state, which already carries `Authenticated(profile: Profile)`. Do NOT modify `PermissionChecker`.

- [ ] T036 Confirm the existing `Authenticated` AuthState shape. Open `H:\alnujom-project\lib\features\auth\presentation\bloc\auth_state.dart` and verify the `Authenticated` case carries a `final Profile profile` field. Open `H:\alnujom-project\lib\features\profile\domain\entities\profile.dart` and verify it carries `publisherStatus: PublisherStatus` AND `accountStatus: AccountStatus`. Open the same directory's enum files to confirm `PublisherStatus.approved` and `AccountStatus.approved` exist. If any of these are different in this project, STOP and check with the human operator — the entire R-19 design rests on this shape. (Probed at plan time; almost certainly intact.)

- [ ] T037 No PermissionChecker edit required. Instead, the publisher-status gate is implemented in two places added by subsequent tasks: (a) the router guard `requirePublisherStatusRedirect` in `auth_redirect.dart` (T041), and (b) the UX tile wrap via `BlocBuilder<AuthBloc, AuthState>` on `HomePage` (T080). No new file is needed in `lib/core/security/`. **Verification (this task's verifiable outcome)**: from `H:\alnujom-project` run `grep -c "userIsApprovedPublisher" lib/core/security/permission_checker.dart` and confirm the result is `0`. Run `git diff lib/core/security/permission_checker.dart` and confirm there is no diff (the file is unchanged from main). This confirms R-19 revised is honored: PermissionChecker is permission-keys-only.

### Routes + redirect guard

The go_router config lives at `H:\alnujom-project\lib\core\routing\app_router.dart` (probe-confirmed at plan time). The file uses `AppRoutes` + `AppRouteNames` abstract final classes for path/name constants and `requireXxxRedirect` per-route helpers in `auth_redirect.dart`. Mirror this pattern exactly for Phase 10.

- [ ] T038 Define `ListingFormMode` enum (referenced by the route registrations T039 + page constructor T066). **Always create a stub file at this point**: `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_form_mode.dart` containing exactly:

  ```dart
  /// Listing-form mode passed from the router to ListingFormPage.
  /// Stub created in T038 (Phase 3 foundational); merged into listing_form_state.dart by T055 (Phase 4 US1).
  enum ListingFormMode { create, edit }
  ```

  T055 (Phase 4) will later absorb this enum into `listing_form_state.dart` and delete this stub file — the two-file dance is intentional because T039 needs the enum to compile in Phase 3 before T055 runs. Confirm `dart analyze lib/features/listing_form/domain/entities/listing_form_mode.dart` passes.

- [ ] T039 Edit `H:\alnujom-project\lib\core\routing\app_router.dart` to register three new routes per `contracts/listings-routing.md § Obligations`. Concretely: (a) add four new constants to `AppRoutes`: `publisherListingsCreate = '/publisher/listings/create'`, `publisherListingsEdit = '/publisher/listings/:id/edit'`, `publisherMyListings = '/publisher/dashboard/my-listings'`, `publisherApprovalPending = '/publisher/pending-approval'`. Add four matching `AppRouteNames` constants (kebab-case names: `publisher-listings-create`, `publisher-listings-edit`, `publisher-my-listings`, `publisher-pending-approval`). (b) Inside the top-level `routes:` list of `buildAppRouter(...)`, add four new `GoRoute(...)` entries — three of them attach `redirect: requirePublisherStatusRedirect` (added in T041); the `publisher-pending-approval` route has NO redirect guard (it's the destination the guard redirects TO). Each `GoRoute.builder` returns the appropriate page widget. The widgets `ListingFormPage` and `MyListingsPage` do not yet exist — for compilation, import a temporary `_TodoPhase10Placeholder` widget (defined as `class _TodoPhase10Placeholder extends StatelessWidget { const _TodoPhase10Placeholder(this.label); final String label; @override Widget build(BuildContext c) => Scaffold(body: Center(child: Text('TODO Phase 10 page: $label'))); }` at the bottom of the router file) and use that for the three routes. The placeholder is replaced when T066 (ListingFormPage) and T092 (MyListingsPage) land. The fourth route (`publisher-pending-approval`) gets a thin `PublisherApprovalPendingPage` widget — create it in this task at `H:\alnujom-project\lib\features\auth\presentation\pages\publisher_approval_pending_page.dart` as a Scaffold rendering the localized `publisherApprovalPendingTitle` + `publisherApprovalPendingMessage` ARB keys (the ARB keys are added in T112). Construct the route table entries per the existing Phase 5 pattern (look at the `pending` / `rejected` / `suspended` routes for the shape). Run `flutter analyze` and confirm 0 new errors.

- [ ] T040 Confirm `H:\alnujom-project\lib\core\routing\auth_redirect.dart` structure. The file (probe-confirmed at plan time) exports `authRedirect(AuthBloc, BuildContext, GoRouterState)` as the top-level redirect plus per-permission helper functions `requireSuperAdminRedirect`, `requireLocationsManageRedirect`, `requireCurrenciesManageRedirect` — each accepts `(BuildContext, GoRouterState)` and returns `String?` (a redirect path or null). Each helper reads `getIt<PermissionChecker>()` and checks the required key. Phase 10 will follow this pattern but reads `AuthBloc` state instead (because publisher_status is profile state, not a permission key).

- [ ] T041 Edit `H:\alnujom-project\lib\core\routing\auth_redirect.dart` to add a new helper `requirePublisherStatusRedirect(BuildContext context, GoRouterState state)`. The body MUST read `getIt<AuthBloc>().state` (NOT PermissionChecker — see R-19 revised). Implementation: `final s = getIt<AuthBloc>().state; if (s is! Authenticated) return AppRoutes.login; if (s.profile.accountStatus != AccountStatus.approved) { return switch (s.profile.accountStatus) { AccountStatus.pending => AppRoutes.pending, AccountStatus.rejected => AppRoutes.rejected, AccountStatus.suspended => AppRoutes.suspended, _ => AppRoutes.home }; } if (s.profile.publisherStatus != PublisherStatus.approved) { return AppRoutes.publisherApprovalPending; } return null;`. Add the matching imports: `Authenticated` from `auth_state.dart`, `AccountStatus`/`PublisherStatus` from `lib/features/profile/domain/entities/`, `AppRoutes` from `app_router.dart`, and `AuthBloc` (already imported via the file's existing AuthBloc import for `authRedirect`). The existing `authRedirect()` top-level function does NOT need modification — the new helper is consumed via the per-route `redirect:` parameter added in T039. Run `flutter analyze` and confirm 0 new errors.

**⚠️ Checkpoint C — Flutter foundational complete**: 3 validators authored, `ListingFormMode` enum stub created, 4 new routes registered (3 publisher-listing routes + 1 publisher-approval-pending), `requirePublisherStatusRedirect` helper wired into `auth_redirect.dart` consuming `AuthBloc` state (NO PermissionChecker edits per R-19 revised). Commit: `git add lib/core/ lib/features/auth/presentation/pages/publisher_approval_pending_page.dart lib/features/listing_form/domain/entities/listing_form_mode.dart && git commit -m "feat(010): core validators + ListingFormMode enum + listing-form routes + AuthBloc-driven publisher-status redirect" && git push`.

---

## Phase 4: User Story 1 — Approved publisher creates a draft (Priority: P1) 🎯 MVP

**Goal**: An approved publisher walks through the seven-step form and submits to `pending_review`. (US1 + US5 single-currency + US2 implicit gate.)

**Independent Test**: After Phase 3 + this phase, a publisher with `profiles.publisher_status='approved' AND account_status='approved'` can open the dashboard, tap "Create listing", walk through all 7 steps with valid data, tap Submit on Review, and observe the listing land at `status='pending_review'` in the database with the correct `listing_status_history` rows + audit-log rows. Verified per `quickstart.md` Steps 5–7.

### Data layer — DTOs + datasource + repository impl

- [ ] T042 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\listing_dto.dart`. A class `ListingDto` with one field per column of `public.listings` (25 columns per `data-model.md § Tables § public.listings`). Include `Listing toEntity()` and `static ListingDto fromMap(Map<String, dynamic> row)` methods. Convert SQL types to Dart: `UUID` → `String`, `TEXT` → `String`/`String?`, `NUMERIC` → `Decimal` (use `package:decimal`), `BOOLEAN` → `bool`/`bool?`, `SMALLINT` → `int`/`int?`, `TIMESTAMPTZ` → `DateTime`. Each enum (purpose, property_type, status, location_visibility, contact_name_visibility) → its Dart enum from the entity layer (T048).

- [ ] T043 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\listing_details_dto.dart` per the same pattern. 8 fields per `data-model.md § Tables § public.listing_details`. `amenities JSONB` → `List<String>` in Dart (parse from `List<dynamic>` via `.cast<String>()`).

- [ ] T044 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\listing_price_dto.dart`. 6 fields per `data-model.md § Tables § public.listing_prices`. `amount NUMERIC(14,2)` → `Decimal`.

- [ ] T045 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\listing_visibility_dto.dart`. 6 fields per `data-model.md § Tables § public.listing_visibility`.

- [ ] T046 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\submit_listing_request_dto.dart`. A class with one field `final String listingId`. Provides `Map<String, dynamic> toRpcParams() => {'p_listing_id': listingId}`.

- [ ] T047 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\submit_listing_response_dto.dart`. Per `contracts/submit-listing-rpc.md § Obligations § step 7`. Two variants: success carries `(listingId, status, submittedAt)`; failure (when SQLSTATE=22023 with `missing_fields`) carries `(missingFields: List<String>, sqlState: String)`. Implement as a sealed class with `SubmitListingSuccess` and `SubmitListingFailure` subtypes, OR as a single class with nullable fields — pick one per Phase 9's DTO conventions (read `lib/features/currencies/data/dtos/update_exchange_rate_response_dto.dart` for the established pattern). Include factory constructors that parse the RPC's JSONB output OR Supabase's `PostgrestException` (the latter for the failure path — `e.code=='22023'` AND `e.details` contains the `missing_fields` JSON).

### Domain entities + enums

- [ ] T048 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing.dart`. Per `data-model.md § Flutter entity shapes § listing.dart`. A Dart class `Listing extends Equatable` with the 25 fields shown. Also in this same file (or a sibling file `listing_enums.dart` — your choice), define the five enums: `ListingPurpose { sale, rent, dailyRent, investment }`; `PropertyType { apartment, villa, land, shop, office, farm, warehouse, other }`; `ListingStatus { draft, pendingReview, approved, rejected, paused, sold, rented, expired, deleted }`; `LocationVisibility { hidden, approximate, exact, adminOnly }`; `ContactNameVisibility { public, adminOnly }`. Each enum gains a `.toDbValue()` method returning the snake_case string used in the database (`pendingReview → 'pending_review'`, `dailyRent → 'daily_rent'`, etc.) and a `static <Enum> fromDbValue(String)` factory.

- [ ] T049 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_details.dart`. Per `data-model.md § Flutter entity shapes § listing_details.dart`. `extends Equatable`.

- [ ] T050 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_price.dart`. Per `data-model.md § Flutter entity shapes § listing_price.dart`. `extends Equatable`. Uses `Decimal` for `amount`.

- [ ] T051 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_visibility.dart`. Per `data-model.md § Flutter entity shapes § listing_visibility.dart`.

- [ ] T052 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_status_history_entry.dart`. Per `data-model.md § Flutter entity shapes § listing_status_history_entry.dart`.

- [ ] T053 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\submit_listing_result.dart`. Per `data-model.md § Flutter entity shapes § submit_listing_result.dart`.

- [ ] T054 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\submit_failure.dart`. Per `data-model.md § Flutter entity shapes § submit_failure.dart`. `final List<String> missingFields; final String? rawSqlState; final String? userFacingMessage;`.

- [ ] T055 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_form_state.dart`. Per `data-model.md § Flutter entity shapes § listing_form_state.dart`. Define TWO enums in this file (or move `ListingFormMode` to the existing stub `listing_form_mode.dart` from T038 — pick one and remove duplication): `enum ListingFormStep { basics, location, details, prices, visibility, media, review }` and `enum ListingFormMode { create, edit }`. The class `ListingFormState extends Equatable` holds all in-progress form data plus per-step validation errors plus submit-in-progress + last-submit-failure. If T038 created the standalone `listing_form_mode.dart` stub, REMOVE that file at the end of this task and import `ListingFormMode` from this file in the router (update T039's imports accordingly).

### Domain repository + use cases

- [ ] T056 [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\repositories\listings_repository.dart`. An abstract class `ListingsRepository` exposing 6 methods that mirror the 6 use cases (T057–T062). Method signatures per `data-model.md § lib/features/listing_form/domain/usecases/`. No Supabase imports.

- [ ] T057 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\load_or_create_draft.dart`. Class `LoadOrCreateDraft` with constructor injecting `ListingsRepository`. Method `Future<Listing> call(String publisherUserId)`. Behavior: ask the repository for the publisher's most-recent draft (status='draft'); if found return it; if not, ask the repository to INSERT a new `listings` row with all fields except `publisher_user_id` left at defaults / null. Returns the new or existing `Listing`. No Supabase imports.

- [ ] T058 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\save_form_step.dart`. Class `SaveFormStep` with method `Future<void> call(ListingFormState state, ListingFormStep step)`. Behavior: based on `step`, the use case calls the repository to UPSERT the relevant rows. The exact column/table mapping per step is normative:

  | Step | Table | Operation | Columns written |
  |---|---|---|---|
  | `basics` | `public.listings` | UPDATE by `id` | `title`, `purpose`, `property_type` |
  | `location` | `public.listings` | UPDATE by `id` | `governorate_id`, `city_id`, `area_id`, `address_text`, `latitude`, `longitude` (the lat/lng pair comes from the `DeriveAreaCentroid` use case's result — the BLoC calls `DeriveAreaCentroid(area_id)` before calling `SaveFormStep`, sets `latitude`/`longitude` into the state, then SaveFormStep persists them) |
  | `details` | TWO operations in one transaction or sequential: UPDATE `public.listings` SET `area_size`, `rooms`, `bathrooms`, `floor`; UPSERT `public.listing_details` row with `(listing_id, description, amenities, year_built, furnished, parking)` (use `ON CONFLICT (listing_id) DO UPDATE` for idempotency) |
  | `prices` | `public.listing_prices` | UPSERT a single row with `(listing_id, currency_code, amount, is_primary=true)` using `ON CONFLICT (listing_id, currency_code) DO UPDATE SET amount=EXCLUDED.amount`. Per Q3 / FR-016 / R-12, every Phase 10 listing has exactly one row; if the publisher CHANGES the currency on an existing draft, the BLoC issues `DELETE FROM listing_prices WHERE listing_id=<id>` followed by INSERT (because UPSERT keyed on `(listing_id, currency_code)` would create a second row instead of replacing). The repository's `upsertListingPrice` method handles this delete-then-insert when the saved row's `currency_code` differs from the existing row's `currency_code`. |
  | `visibility` | `public.listings` | UPDATE by `id` | `location_visibility`, `contact_name_visibility`, `hide_until`, `phone`, `whatsapp` (the `listing_visibility_sync_trigger` propagates `location_visibility` + `contact_name_visibility` to the child `public.listing_visibility` row automatically; the BLoC does NOT write the child row directly) |
  | `media` | no-op | — | (Phase 11 will own this step; T072 ships the placeholder) |
  | `review` | no-op | — | (Submit is a separate use case `SubmitListing` per T059) |

  If any UPDATE/UPSERT fails (network drop, RLS deny, etc.), the use case throws — the BLoC catches and surfaces a localized retry affordance per FR-014 / R-13. No partial-save state is tolerated; the per-step save is atomic at the use case level even when it touches two tables (the repository's method composes the two writes in sequence and surfaces failures uniformly).

- [ ] T059 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\submit_listing.dart`. Class `SubmitListing` with method `Future<SubmitListingResult> call(String listingId)`. Behavior: call the repository's `submitListing(listingId)` method which invokes the `submit_listing` RPC; on PostgrestException with code='22023' and details containing `missing_fields`, parse and throw a typed `SubmitListingFailureException(List<String> missingFields)`; on other exceptions rethrow.

- [ ] T060 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\delete_draft.dart`. Class `DeleteDraft` with method `Future<void> call(String listingId)`. Behavior: ask the repository to DELETE the row (parent CASCADE deletes children). Throws if the listing's status is not `draft`.

- [ ] T061 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\derive_area_centroid.dart`. Class `DeriveAreaCentroid` with method `Future<AreaCentroid> call(String areaId)`. Per `contracts/area-centroid-autofill.md § Obligations`. Define `AreaCentroid extends Equatable { final double latitude; final double longitude; }` in the same file. The use case reads `public.areas.centroid_lat`/`centroid_lng` via the Phase 8 `LocationsRepository` (find it at `lib/features/locations/domain/repositories/locations_repository.dart` — may need to add a new method `Future<AreaCentroid> getCentroid(String areaId)` to the Phase 8 interface AND its impl; do this in this task if needed). Throws if the area row exists but has NULL centroid (defensive — shouldn't happen post-T008 seed).

- [ ] T062 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\validate_submit_payload.dart`. Class `ValidateSubmitPayload` with method `({bool ok, List<String> missingFields}) call(ListingFormState state)`. Implementation: client-side mirror of `data-model.md § RPC § Q1 Full required-field validation`. Check each Q1 required field against the in-memory state and accumulate dot-notated paths into `missingFields`. Returns `(ok: missingFields.isEmpty, missingFields)`.

### Data layer — datasource + repository impl

- [ ] T063 [US1] Author `H:\alnujom-project\lib\features\listing_form\data\datasources\supabase_listings_datasource.dart`. Class `SupabaseListingsDatasource` with constructor injecting `SupabaseClient` (from `package:supabase_flutter/supabase_flutter.dart`). Methods: `Future<Listing?> findDraftForPublisher(String publisherUserId)`, `Future<Listing> insertDraft(String publisherUserId)`, `Future<void> updateListing(String listingId, Map<String, dynamic> fields)`, `Future<void> upsertListingDetails(...)`, `Future<void> upsertListingPrice(...)`, `Future<SubmitListingResult> submitListing(String listingId)` (calls `supabase.rpc('submit_listing', params: {'p_listing_id': listingId})`), `Future<void> deleteListing(String listingId)`. Each method catches `PostgrestException`, maps to `Exception` subtypes (define `ListingsNotFoundException`, `ListingsUnauthorizedException`, `ListingsValidationException(List<String> missingFields)` in the same file). Handle the SQLSTATE mapping per `contracts/submit-listing-rpc.md § SQLSTATE ↔ HTTP error mapping`. This is the ONLY file in `lib/features/listing_form/` that imports `package:supabase_flutter` (along with T064 — Constitution IX).

- [ ] T064 [US1] Author `H:\alnujom-project\lib\features\listing_form\data\repositories\listings_repository_impl.dart`. Class `ListingsRepositoryImpl implements ListingsRepository` (the abstract from T056). Constructor injects `SupabaseListingsDatasource`. Each method delegates to the datasource, converts DTO ↔ entity (using the DTOs from T042–T047 and entities from T048–T055), and catches/rethrows datasource exceptions as domain-level exceptions where appropriate. Imports `package:supabase_flutter` only for the datasource interaction; the abstract interface and domain entities are pure.

### Presentation — BLoC + page

- [ ] T065 [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\bloc\listing_form_bloc.dart`. Per `contracts/listing-form-pages.md § BLoC events`. The BLoC owns `ListingFormState` (from T055). Events: `LoadOrCreateDraftRequested`, `FieldChanged(field, value)`, `SaveStepAndContinue`, `SaveStepAndExit`, `JumpToStep(step)`, `SubmitRequested`, `DeleteDraftRequested`. Each event handler delegates to the corresponding use case (T057–T062). On `SaveStepAndContinue`: call `SaveFormStep` first; on success, transition the in-memory state's `currentStep` to the next step; on failure, emit a state with `lastSaveFailure` populated and DO NOT transition. On `SubmitRequested`: call `ValidateSubmitPayload` first; if `!ok`, emit failure-with-missing-fields state without calling the RPC; if ok, call `SubmitListing` use case; on RPC failure with `SubmitListingFailureException`, emit failure-with-missing-fields. Use `flutter_bloc` package conventions (Bloc<Event, State>). Imports stay clean of Supabase.

- [ ] T066 [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\pages\listing_form_page.dart`. The top-level form widget. Renders the current step (based on `state.currentStep`) and a step-progress indicator at the top + Back/Continue buttons at the bottom. Per `contracts/listing-form-pages.md § Steps`. The page reads constructor params `(ListingFormMode mode, String? listingId)` (the route registration from T039 passes these). On mount, dispatches `LoadOrCreateDraftRequested` if mode=create; or load-by-id if mode=edit. Uses Phase 2 design tokens for spacing/colors/typography. No `package:supabase_flutter` import.

### Presentation — step widgets (7)

- [ ] T067 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_basics.dart`. Per `contracts/listing-form-pages.md § Step 1 basics`. Widget renders 3 fields: title (TextField), purpose (segmented control or dropdown over the 4 ListingPurpose values), property_type (dropdown over the 8 PropertyType values). Each field's onChange dispatches `FieldChanged(...)` on the bloc. Labels via ARB (`fieldLabelTitle`, `fieldLabelPurpose`, `fieldLabelPropertyType`). Validators: title non-empty.

- [ ] T068 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_location.dart`. Per `contracts/listing-form-pages.md § Step 2 location` + `contracts/area-centroid-autofill.md`. Widget renders the Phase 8 `LocationPicker` (find at `lib/features/locations/presentation/widgets/location_picker.dart` — reuse verbatim per SC-021) + an `address_text` TextField. On the location step's "Continue" handling (in the bloc, not the widget — but the widget makes this clear via a comment), the bloc calls `DeriveAreaCentroid(area_id)` and writes the result to the draft. **No lat/lng input fields** (Q2 lock). When area is missing centroid (defensive), the bloc's failure state shows a localized `validatorAreaMissingCentroid` ARB key in the step's footer; the widget renders this as a non-dismissible inline error blocking Continue.

- [ ] T069 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_details.dart`. Per `contracts/listing-form-pages.md § Step 3 details`. Widget renders: description (multiline TextField), amenities (multi-select chip group — the amenities catalog is a checked-in static list for v1 — define a const list `const List<String> kAmenitiesCatalog = ['elevator','balcony','swimming_pool','garden','security','generator','solar_panels','central_heating','air_conditioning','furnished_kitchen']` at the top of the file; ARB keys per amenity for display), year_built (numeric TextField), furnished (Switch), parking (Switch), area_size (numeric TextField with `AreaSizeValidator`), rooms (numeric TextField — visible only when property_type IN apartment/villa), bathrooms (numeric TextField — same visibility), floor (numeric TextField). Validators wired per FR-018.

- [ ] T070 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_prices.dart`. Per `contracts/listing-form-pages.md § Step 4 prices` + Q3 single-currency lock. Widget renders ONE currency dropdown + ONE amount TextField. The currency dropdown is populated by calling Phase 9's `ListCurrencies` use case (`lib/features/currencies/domain/usecases/list_currencies.dart` — probe-confirmed signature: `Future<List<Currency>> call({bool activeOnly = false})`) with `activeOnly: true` — this filters to `is_active=true` rows server-side. The currencies are loaded via a `FutureBuilder` or a sub-cubit (your choice — match Phase 9's pattern by reading `lib/features/currencies/presentation/bloc/set_exchange_rate_bloc.dart` if it loads currencies the same way). Below the amount field, render the inline `MoneyFormatter` preview via `lib/shared/presentation/money_formatter.dart` (Phase 9), passing the chosen `Currency` + the active `Locale` + a `Money({amount: Decimal.parse(controller.text), currencyCode: chosen.code})` value object. **NO "Add another currency" button, NO multi-row UI, NO `is_primary` toggle** (Q3 lock; SC-024). The single price row is auto-flagged `is_primary=true` server-side on first save via the `SaveFormStep`/`upsertListingPrice` flow (T058). Wire `PriceValidator` on the amount field (T034 — at field blur and at step-transition).

- [ ] T071 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_visibility.dart`. Per `contracts/listing-form-pages.md § Step 5 visibility`. Widget renders: location_visibility (segmented control over the 4 LocationVisibility values), contact_name_visibility (segmented control over the 2 ContactNameVisibility values), hide_until (date picker, optional), phone (TextField with `PhoneValidator`), whatsapp (TextField with `PhoneValidator`).

- [ ] T072 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_media_placeholder.dart`. Per `contracts/listing-form-pages.md § Step 6 media`. Widget renders a Phase 2 design-token-styled banner with the localized `listingFormMediaPlaceholderBanner` ARB key ("media upload coming in the next release"). The Continue button is always enabled and proceeds to step 7. No state write happens on this step.

- [ ] T073 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_review.dart`. Per `contracts/listing-form-pages.md § Step 7 review`. Widget renders a read-only summary of every field across steps 1–5 (skip step 6 media placeholder), grouped by step with each group's header per the ARB keys + an "Edit step N" affordance that dispatches `JumpToStep(step)` on the bloc. At the bottom: a Submit button. Tapping Submit dispatches `SubmitRequested`. The widget reads `state.lastSubmitFailure` to render `SubmitFailureDialog` when populated.

### Presentation — supporting widgets

- [ ] T074 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\required_field_chip.dart`. A small chip rendered next to required-field labels with the localized `requiredFieldChipLabel` ARB key. Phase 2 design tokens (color: warning/accent).

- [ ] T075 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_progress_indicator.dart`. A horizontal row of 7 dots/chips showing the current step. Uses Phase 2 design tokens (active = primary color; completed = success color; pending = neutral).

- [ ] T076 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\submit_failure_dialog.dart`. Per `contracts/listing-form-pages.md § BLoC events § SubmitRequested failure path`. The dialog opens when `state.lastSubmitFailure != null`. Body renders the localized `submitFailureMissingFieldsHeader` + a bulleted list mapping each `missingFields[i]` dot-notated path to its localized field label (use the `missingFieldLabel(path, l10n)` helper from `contracts/listings-localization.md § missing_fields[] payload localization`). Dismiss button + "Jump to step" button per missing field that dispatches `JumpToStep(<the step containing that field>)`.

- [ ] T077 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\price_preview_subline.dart`. Renders `MoneyFormatter.format(money, locale, currency)` for the entered amount + currency. Updated on every `FieldChanged` event tied to amount or currency. Phase 9 import only (`lib/shared/presentation/money_formatter.dart`).

### DI registration

- [ ] T078 [US1] Wire DI for the new feature folder. First read the Phase 9 datasource pattern at `H:\alnujom-project\lib\features\currencies\data\datasources\supabase_currencies_datasource.dart` — its annotation is the canonical convention to mirror. Apply annotations to the new classes: on `SupabaseListingsDatasource` (T063 — concrete class with no abstract base) add `@LazySingleton()` (NOT `@LazySingleton(as: ...)` — no abstract); on `ListingsRepositoryImpl` (T064) add `@LazySingleton(as: ListingsRepository)`; on each use case (T057–T062) add `@injectable`; on `ListingFormBloc` (T065) add `@injectable`; on `MyListingsBloc` (T091) add `@injectable`. Open `H:\alnujom-project\lib\core\di\injection.dart` and confirm `@InjectableInit` is configured — no edit needed unless the existing init scans a narrow path that excludes `lib/features/listing_form/`. Then from `H:\alnujom-project` run codegen: **try `dart run build_runner build --delete-conflicting-outputs` first**; if it errors with "dart run does not support that script" or similar, fall back to `flutter pub run build_runner build --delete-conflicting-outputs` (older Flutter < 3.0). One of the two will work. Confirm `lib/core/di/injection.config.dart` regenerates with entries for `SupabaseListingsDatasource`, `ListingsRepositoryImpl`, the 6 use cases (LoadOrCreateDraft, SaveFormStep, SubmitListing, DeleteDraft, DeriveAreaCentroid, ValidateSubmitPayload), and `ListingFormBloc`. If the build_runner reports conflicting outputs OR analyzer errors, STOP and address them before proceeding.

### Post-login home tile (the create entry)

**Important context** (probe-confirmed at plan time): there is NO `publisher_dashboard_page.dart` in the project. The post-login landing surface is `H:\alnujom-project\lib\features\home\presentation\pages\home_page.dart` (route `/home`). This is where the existing Phase 5/6/7/8/9 tiles render (Profile, Admin, etc.). Phase 10 adds two new tiles to this same `HomePage`.

- [ ] T079 Open `H:\alnujom-project\lib\features\home\presentation\pages\home_page.dart` and read it fully. Identify the existing tile-rendering block (a `Column` or `ListView` body of `ListTile` widgets per the Phase 5 pattern). Identify the spot to insert the two new tiles (typically near the existing Profile tile, before or after Admin).

- [ ] T080 [US1] Edit `H:\alnujom-project\lib\features\home\presentation\pages\home_page.dart` to add ONE new tile "Create listing" (the "My listings" tile is wired in T100 after MyListingsPage exists). The tile MUST be wrapped in a `BlocBuilder<AuthBloc, AuthState>(builder: (context, state) { final isApproved = state is Authenticated && state.profile.publisherStatus == PublisherStatus.approved && state.profile.accountStatus == AccountStatus.approved; if (!isApproved) return const SizedBox.shrink(); return ListTile(...) })` so non-approved users see no tile (UX hide per FR-011 / R-19). Tile label: localized `tileCreateListing` ARB key (added in T112). On tap: `context.goNamed(AppRouteNames.publisherListingsCreate)` (the route name constant from T039). Tile composes Phase 2 design tokens (use the same `ListTile` shape as the existing tiles in this file — DO NOT introduce new design-token usage). Add the imports needed: `Authenticated` from `auth_state.dart`, `AccountStatus` + `PublisherStatus` from `lib/features/profile/domain/entities/`, `AppRouteNames` from `lib/core/routing/app_router.dart`. Run `flutter analyze` and confirm 0 new errors.

### End-to-end verification for US1

- [ ] T081 [US1] Manual verification (verifies SC-001 timing + happy path). Run from `H:\alnujom-project`: `flutter run --dart-define-from-file=.env.json --release` on the connected Infinix Note 8. Sign in as the approved publisher. **Start a stopwatch when you tap "Create listing".** Walk through all 7 steps with the canonical happy-path payload from `quickstart.md § Step 6`. The exact data names (e.g., `area=Al-Maliki`) MUST match a real seeded row — substitute with an actual `name_en` from your T006 inventory if Al-Maliki was not seeded. Canonical payload: title="شقة فاخرة في المالكي", purpose=sale, property_type=apartment, governorate=Damascus, city=Damascus, area=<real seeded area>, address_text="شارع المتنبي، بناء رقم 12", area_size=180, rooms=3, bathrooms=2, floor=4, currency=USD, amount=50000, location_visibility=approximate, phone=0991234567. Submit. Confirm the success toast appears. **Stop the stopwatch — record total elapsed time.** Expected: under 4 minutes per SC-001. If over 4 minutes, identify the slow step (slow network? slow LocationPicker? slow validation?) and either tighten the UX or document a deferral in DEFERRED.md.

- [ ] T081a [US1] Submit-failure path verification (verifies SC-010 + FR-010a structured error). On the device, start a new draft. On the basics step, fill ONLY title (leave purpose blank). Use the "Save and exit" affordance or kill the app to persist the partial draft. Re-open the draft via deep-link `/publisher/listings/<draft id>/edit` — capture the `<draft id>` from `SELECT id FROM public.listings WHERE publisher_user_id='<this user uuid>' AND status='draft' ORDER BY created_at DESC LIMIT 1` via Supabase MCP. (MyListingsPage doesn't exist yet — US4 is Phase 6, later in execution order; deep-link is the only re-entry path during US1.) Navigate to the Review step (the BLoC's `JumpToStep` event lets you skip — or quickly fill the remaining steps with whatever values, leaving `governorate_id` and `area_size` null). Tap Submit. Expected: `SubmitFailureDialog` (T076) renders with a bulleted list of missing fields. The displayed labels MUST be localized (`fieldLabelTitle` etc.) — verify in both `ar` and `en` locales. From the device's logs (or a desktop tail on the Supabase function logs), confirm the RPC returned SQLSTATE `22023` with `DETAIL` carrying a JSON `{"missing_fields":[...]}` payload. The listing's status MUST remain `draft` (or `rejected` if resubmitting); from desktop: `SELECT status FROM public.listings WHERE id='<draft id>'` — confirm unchanged. Also: `SELECT count(*) FROM public.listing_status_history WHERE listing_id='<id>' AND new_status='pending_review'` — confirm the count is whatever it was before the failed submit (failed submits do NOT append a history row).

- [ ] T082 [US1] SQL verification per `quickstart.md § Step 7`. Via Supabase MCP `execute_sql`: confirm one new `public.listings` row with `status='pending_review'`; confirm one `public.listing_details` row; confirm one `public.listing_prices` row with `is_primary=true`; confirm one `public.listing_visibility` row; confirm two `public.listing_status_history` rows (NULL→draft, draft→pending_review); confirm `public.audit_logs` rows for `listing.created`, `listing.updated` (one per per-step save), `listing.submitted`; confirm `latitude≈33.5102 AND longitude≈36.2913` on the listing row (Al-Maliki centroid).

**⚠️ Checkpoint D — US1 MVP complete**: Approved publisher can create a draft and submit. The full happy path works end-to-end. Commit: `git add lib/ && git commit -m "feat(010): listing_form feature folder + 7-step form + submit_listing wiring (MVP)" && git push`.

---

## Phase 5: User Story 2 — Non-approved gate verification (Priority: P1)

**Goal**: Confirm the three-layer enforcement from Phase 3 (UX tile hide + router guard + RLS) refuses non-approved publishers.

**Independent Test**: Per `quickstart.md § Step 5`. Three sub-tests: tile hidden, deep-link refused, direct SQL INSERT denied.

- [ ] T083 [US2] Manual verification per `quickstart.md § Step 5` (verifies SC-002 + SC-020). Sign in on the device as a `publisher_status='pending'` user. Confirm: (a) the "Create listing" tile is NOT visible on the home page (HomePage tile gate from T080); (b) hand-typing the deep link (or via a dev menu navigate-by-URL feature) to `/publisher/listings/create` redirects to the `/publisher/pending-approval` screen (router guard `requirePublisherStatusRedirect` from T041); (c) RLS-deny test using Pattern A from the implementer briefing — via Supabase MCP `execute_sql`:

  ```sql
  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<PENDING_USER_UUID>","role":"authenticated"}';
  INSERT INTO public.listings (publisher_user_id, purpose, property_type, title, governorate_id)
  VALUES ('<PENDING_USER_UUID>', 'sale', 'apartment', 'test', '<ANY_GOV_UUID>');
  -- Expected: ERROR 42501 new row violates row-level security policy for table "listings"
  ROLLBACK;
  ```

  Repeat sub-test (c) for `publisher_status='rejected'` and `publisher_status='suspended'` (UPDATE the test user's `publisher_status` via direct admin SQL between runs; ROLLBACK ensures no state pollution). Repeat sub-test (c) for anonymous: `SET LOCAL ROLE anon; SET LOCAL "request.jwt.claims" TO '{"role":"anon"}'; INSERT INTO public.listings ...; ROLLBACK;` — expected: same 42501 error. SC-020 sub-test: from a desktop admin, run `UPDATE public.profiles SET publisher_status='approved' WHERE user_id='<PENDING_USER_UUID>'`; on the device, foreground-resume the app (lock screen + unlock, or background + recents-tap); confirm the "Create listing" tile appears WITHOUT a sign-out. If any sub-test fails, STOP and fix the relevant layer before proceeding.

**⚠️ Checkpoint E — US2 verified**: The three-layer gate is enforced. No code change usually required (the gate was implemented in Phase 3); if a fix was needed, commit it.

---

## Phase 6: User Story 4 — MyListingsPage (Priority: P1)

**Goal**: The publisher views their listings on `MyListingsPage` with status filters and rejection-reason rendering. (Doing US4 before US3 because US3 depends on `MyListingsPage` to expose the "Resubmit" CTA.)

**Independent Test**: Per `quickstart.md § Step 10` partial walk (just the page-render check) — after US4 ships, the publisher sees their pending_review listing on the page with the correct status badge.

### Publisher dashboard data layer

- [ ] T084 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\data\dtos\publisher_listing_dto.dart`. A flat class mirroring the columns of `public.v_publisher_listings` (see `data-model.md § View: public.v_publisher_listings` for the full column list — about 30 columns prefixed `listing_*`, `latest_history_*`, `primary_price_*`). Provide a `static PublisherListingDto.fromMap(Map<String, dynamic> row)` factory and a `PublisherListing toEntity()` method that constructs the nested `PublisherListing` shape (composed of `Listing`, `ListingStatusHistoryEntry?`, `ListingPrice?` per `data-model.md § Flutter entity shapes § PublisherListing`). Nullable fields: `latest_history_*` and `primary_price_*` columns may be null when the LEFT JOINs in the view don't match (e.g., a brand-new draft has 1 history row + 0 price rows → primary_price_* are NULL).

- [ ] T085 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\data\dtos\listing_status_history_entry_dto.dart`. A class mirroring `public.listing_status_history` columns.

- [ ] T086 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\data\datasources\supabase_publisher_dashboard_datasource.dart`. Class with one method `Future<List<PublisherListingDto>> listMyListings({String? statusFilter, int offset = 0, int limit = 20})`. Implementation: a single PostgREST query against the `public.v_publisher_listings` view (created in migration 8 / T025a) — NOT against `public.listings` directly. The view does the most-recent-history-row join + is_primary-price join server-side, so the datasource is one query. Code shape: `var query = supabase.from('v_publisher_listings').select('*').order('created_at', ascending: false); if (statusFilter != null) query = query.eq('status', statusFilter); final rows = await query.range(offset, offset + limit - 1); return rows.map(PublisherListingDto.fromMap).toList();`. Note `.range(offset, offset + limit - 1)` uses INCLUSIVE bounds — for `offset=0, limit=20` the call becomes `.range(0, 19)` returning 20 rows. The view inherits RLS from `public.listings`, so the query automatically narrows to the calling user's rows (or admin's if `listings.view_all` is held) — no explicit `publisher_user_id` filter needed. The `status='deleted'` listings are already filtered out by the view's WHERE clause. **Immediate smoke verification** (don't wait for T101): after writing the file, from `H:\alnujom-project` run `dart analyze lib/features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart` and confirm 0 errors. Then via Supabase MCP `execute_sql` using Pattern A as the test publisher: `BEGIN; SET LOCAL ROLE authenticated; SET LOCAL "request.jwt.claims" TO '{"sub":"<APPROVED_PUBLISHER_UUID>","role":"authenticated"}'; SELECT count(*) FROM public.v_publisher_listings; ROLLBACK;` — expected: count matches that publisher's non-deleted listings (likely 1 after T081 from US1 created a pending_review listing). If 0 unexpectedly, inspect the view's WHERE clause and verify the test publisher's listing isn't in `status='deleted'`.

- [ ] T087 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\data\repositories\publisher_dashboard_repository_impl.dart`. Class implementing the abstract from T089. Delegates to T086. Converts DTOs to entities.

### Publisher dashboard domain layer

- [ ] T088 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\domain\entities\publisher_listing.dart`. Per `data-model.md § Flutter entity shapes § PublisherListing`. Composite entity with computed flags `isEditable` (`listing.status IN draft, rejected`) and `hasRejectionReason` (`listing.status == rejected AND latestStatusHistoryEntry.reason != null`).

- [ ] T089 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\domain\repositories\publisher_dashboard_repository.dart`. Abstract class with one method `Future<List<PublisherListing>> listMyListings({ListingStatus? statusFilter, int offset, int limit})`.

- [ ] T090 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\domain\usecases\list_my_listings.dart`. Class wrapping the repository method. Same signature.

### Publisher dashboard presentation

- [ ] T091 [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\bloc\my_listings_bloc.dart`. Owns `MyListingsState` (loading / loaded / error + current filter + pagination cursor). Events: `LoadMyListings`, `ChangeStatusFilter(ListingStatus?)`, `LoadMore`, `Refresh`. Delegates to `ListMyListings` use case.

- [ ] T092 [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\pages\my_listings_page.dart`. Per `contracts/my-listings-page.md`. Page renders: header with title + status-filter chip row (one chip per status: All, Draft, Pending review, Approved, Rejected, Paused, Sold, Rented, Expired); ListView of `ListingCard` widgets; empty state when list is empty; pull-to-refresh dispatches `Refresh`. The status-filter chip row is a horizontally-scrollable Row of `StatusFilterChip` widgets (each chip tap dispatches `ChangeStatusFilter`).

- [ ] T093 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\listing_card.dart`. Renders one PublisherListing per `contracts/my-listings-page.md § Listing card`. Composes Phase 2 design-token primitives (Card + Padding + Column with EdgeInsetsDirectional). Tap behavior per the contract: editable statuses navigate to the form; non-editable navigate to read-only preview.

- [ ] T094 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\status_badge.dart`. Renders a chip with the listing's status label + Phase 2-design-token color per the contract's color mapping (draft=neutral, pending_review=warning, approved=success, rejected=danger, paused=neutral, sold/rented/expired=muted).

- [ ] T095 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\rejection_reason_block.dart`. Renders the rejection reason text from `publisherListing.latestStatusHistoryEntry.reason` (only when `hasRejectionReason` is true). Phase 2 design tokens (danger/warning color). Shown only inside Rejected cards.

- [ ] T096 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\resubmit_cta.dart`. A button rendered inside Rejected cards. On tap, navigates to `/publisher/listings/<id>/edit`. Phase 2 design tokens (primary color).

- [ ] T097 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\status_filter_chip_row.dart`. A horizontally-scrollable Row of ChoiceChips (or FilterChips), one per ListingStatus + an "All" chip at the start. On selection, dispatches `ChangeStatusFilter` to the bloc.

- [ ] T098 [P] [US4] Author `H:\alnujom-project\lib\features\publisher_dashboard\presentation\widgets\read_only_listing_preview.dart`. A page-level widget renderable as an alternative tap target when the listing is non-editable. Renders a read-only summary of every field. For `approved` listings, also renders the localized `approvedNotEditableMessage` ARB key.

### DI + dashboard wiring for US4

- [ ] T099 [US4] DI registration. Mirror T078 for the new `publisher_dashboard` feature: annotate the datasource, repository impl, use case, BLoC. Re-run `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] T100 [US4] Edit `H:\alnujom-project\lib\features\home\presentation\pages\home_page.dart` (the same file edited in T079/T080) to add the "My listings" entry tile alongside the "Create listing" tile. Use the same `BlocBuilder<AuthBloc, AuthState>` wrapper from T080 (both tiles share the approved-pair gate). Tile label: localized `tileMyListings` ARB key. On tap: `context.goNamed(AppRouteNames.publisherMyListings)`. The two tiles MAY be wrapped in a single `BlocBuilder` to share the state subscription (factor the gate logic into a private widget `_PublisherTiles` if it reduces duplication). Run `flutter analyze` and confirm 0 new errors.

### Verification for US4

- [ ] T101 [US4] Manual verification per `quickstart.md` partial Step 10 / SC-015. Sign in as the approved publisher. From the dashboard tap "My listings". Verify the pending_review listing from T081 is visible. Verify each status filter chip narrows the list correctly when tapped. Verify the empty state renders cleanly when "Approved" filter is selected (nothing approved yet). Tap the pending_review listing — verify the read-only preview opens. Go back to the page.

**⚠️ Checkpoint F — US4 MyListingsPage complete**: Publisher can view their listings with filters. Commit: `git add lib/features/publisher_dashboard/ lib/features/profile/ lib/core/di/ && git commit -m "feat(010): publisher_dashboard feature folder + MyListingsPage" && git push`.

---

## Phase 7: User Story 3 — Rejected listing resubmit (Priority: P1)

**Goal**: A rejected listing is editable and resubmittable; status history shows the full transition chain.

**Independent Test**: Per `quickstart.md § Step 10` (full walk).

- [ ] T102 [US3] Simulate Phase 12's reject path via direct SQL. From the desktop, via Supabase MCP `execute_sql`, take the listing from T081 (currently `status='pending_review'`) and execute: `UPDATE public.listings SET status='rejected' WHERE id='<that listing id>';`. Then `INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason) VALUES ('<that id>', 'pending_review', 'rejected', NULL, 'الموقع غير دقيق');`. (Phase 12's `reject_listing` RPC will populate reason via its own write path; for Phase 10 testing we simulate.) Verify `SELECT new_status, reason FROM public.listing_status_history WHERE listing_id='<id>' ORDER BY changed_at DESC LIMIT 1` returns `('rejected', 'الموقع غير دقيق')`.

- [ ] T103 [US3] Manual verification per `quickstart.md § Step 10`. On the device, sign in as the same approved publisher. Open the dashboard → "My listings" → tap the "Rejected" filter chip. Verify the rejected listing appears with the rejection reason text visible inline (the `rejection_reason_block` widget from T095). Verify the "Resubmit" CTA from T096 is visible.

- [ ] T104 [US3] Tap "Resubmit". Verify the multi-step form opens at step 1 (basics) pre-populated with all existing field values. Walk through steps 2–7 (every field is already filled because the listing has been saved through them once). Tap Submit on the Review step. Verify the success toast appears.

- [ ] T105 [US3] SQL verification. From the desktop: `SELECT previous_status, new_status, reason FROM public.listing_status_history WHERE listing_id='<that id>' ORDER BY changed_at ASC`. Expected: 4 rows: (NULL, draft, NULL), (draft, pending_review, NULL), (pending_review, rejected, 'الموقع غير دقيق'), (rejected, pending_review, NULL). Also verify `audit_logs` has the new `listing.submitted` row for this submission (since rejected→pending_review is a submit transition).

**⚠️ Checkpoint G — US3 resubmit complete**: Status chain preserved across reject → resubmit. Commit (if any code changed): `git add lib/ && git commit -m "feat(010): verify rejected-resubmit loop (US3)" && git push`. Most likely no code changed — the resubmit flow reuses US1's form unchanged.

---

## Phase 8: User Story 5/6/7 — Additional verifications (Priority: P2)

**Purpose**: Quick verifications for the P2 user stories. Most behavior was already shipped in Phase 2/3/4 of these tasks; this phase confirms each P2 story works independently.

### US5 — Single-currency price entry verification

- [ ] T106 [US5] Manual verification per `spec.md § US5 Independent Test`. On the device, open a new draft, reach the prices step. Verify: (a) the currency dropdown shows SYP and USD in sort_order ASC; (b) NO "Add another currency" button is visible; (c) NO multi-row UI; (d) NO is_primary toggle. Pick USD, amount=50000. Verify the inline `MoneyFormatter` preview reads `$50,000` (en) or `٥٠٬٠٠٠ $` (ar). Submit the listing. From the desktop: `SELECT count(*) FROM public.listing_prices WHERE listing_id='<this id>'` returns `1`; `is_primary=true`. Re-open the draft (if you saved one as draft instead of submitting) or rejected listing — verify changing currency from USD to SYP UPDATEs the existing row in place (same UUID); from the desktop: `SELECT id, currency_code, amount FROM public.listing_prices WHERE listing_id='<id>'` shows the same UUID with updated currency_code/amount.

### US6 — Status-transition trigger verification

- [ ] T107 [US6] SQL-only verification per `quickstart.md § Step 11` (verifies SC-003 + SC-004 + SC-019). From the desktop, simulate a full status walk via direct UPDATEs (admin SQL via Supabase MCP `execute_sql` — service_role; the status-transition trigger fires regardless of which JWT runs the UPDATE because the trigger uses `auth.uid()` for `changed_by` which returns NULL under service_role):

  ```sql
  -- Step a: simulate Phase 12 approve
  UPDATE public.listings SET status='approved', published_at=now() WHERE id='<the resubmitted listing from T104>';
  -- Step b: simulate publisher self-pause
  UPDATE public.listings SET status='paused' WHERE id='<id>';
  -- Step c: confirm history append (SC-003 + SC-019)
  SELECT count(*) FROM public.listing_status_history WHERE listing_id='<id>';
  -- Expected: 6 rows (NULL→draft, draft→pending_review, pending_review→rejected, rejected→pending_review, pending_review→approved, approved→paused)
  ```

  Then verify SC-004 (append-only) using Pattern A from the implementer briefing — even an admin holding `listings.view_all` cannot UPDATE/DELETE history rows because the policies don't admit those operations to any role except via `pg_trigger_depth() > 0`:

  ```sql
  -- Append-only test under authenticated/admin role
  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<ADMIN_USER_UUID>","role":"authenticated"}';
  UPDATE public.listing_status_history SET previous_status='approved' WHERE id='<any row id>';
  -- Expected: 0 rows affected (no UPDATE policy exists; the UPDATE silently affects 0 rows)
  DELETE FROM public.listing_status_history WHERE id='<any row id>';
  -- Expected: 0 rows affected (no DELETE policy)
  ROLLBACK;
  ```

  Note: under service_role context (default for Supabase MCP `execute_sql`), the UPDATE/DELETE would SUCCEED because service_role bypasses RLS. The append-only invariant is enforced at the RLS layer, not at the schema layer. The Pattern A wrapper is essential here.

- [ ] T108 [US6] Audit-log emission verification (verifies SC-019 audit side). From the desktop: `SELECT action, count(*) FROM public.audit_logs WHERE target_id='<the listing id from T107>' GROUP BY action ORDER BY action`. Expected counts: `listing.created`=**exactly 1** (single INSERT), `listing.updated`=**at least 7** (one per per-step save during T081 ≈ 5, plus one per status flip during T104 + T107 = 4, plus updates from the resubmit save flow = 1+; the minimum is 7 but realistic is 10–15 depending on how the implementer chunks saves), `listing.submitted`=**exactly 2** (initial submit in T081 + resubmit in T104), `listing.rejected`=**exactly 1** (T102 simulated reject), `listing.approved`=**exactly 1** (T107 step a), `listing.paused`=**exactly 1** (T107 step b). **Key invariant**: every status flip produced both a `listing.updated` row AND a status-delta-verb row in the same transaction. If `listing.submitted+listing.rejected+listing.approved+listing.paused != 5` OR `listing.created != 1`, STOP and inspect the audit-trigger function from migration 6 — the delta verb computation may have a typo.

### US7 — Validators verification

- [ ] T109 [US7] Manual verification of `AreaSizeValidator` per `contracts/validators.md § AreaSizeValidator` goldens. On the device, open a draft form, advance to the details step. Try each golden input from the contract's manual goldens table; confirm the displayed error string matches the expected ARB key's value in both `ar` and `en` locales.

- [ ] T110 [US7] Manual verification of `PriceValidator` per `contracts/validators.md § PriceValidator` goldens. On the device, advance to the prices step. Try each golden input; confirm errors match.

- [ ] T111 [US7] Manual verification of `PhoneValidator` per `contracts/validators.md § PhoneValidator` goldens. On the device, advance to the visibility step. Try each golden input; confirm errors AND auto-normalization match.

**⚠️ Checkpoint H — US5/6/7 verified**: All P2 stories pass their manual goldens. No code change typically; if a fix was needed, commit it.

---

## Phase 9: Polish & Cross-Cutting

**Purpose**: Final hardening pass before the spec is shipped.

### ARB key inventory

- [ ] T112 Author or update `H:\alnujom-project\lib\l10n\app_ar.arb` with the **48 new ARB keys** per `data-model.md § ARB key inventory` (full canonical inventory list — open that section and copy each key name verbatim). Categories with explicit counts: form chrome (15 keys), field labels (16 keys), amenities catalog labels (10 keys), validator errors (7 keys including `validatorAreaMissingCentroid` for FR-013a), status badges (9 keys), rejection/resubmit/failures (6 keys), missing-field labels (10 keys for the `missing_fields[]` paths the RPC may emit), submit_listing structured errors (3 keys), publisher-dashboard tiles + pending-approval screen (5 keys including `tileCreateListing` for T080 + `tileMyListings` for T100 + `publisherApprovalPendingTitle`/`publisherApprovalPendingMessage` for T039). Each key has a Syrian-friendly Arabic value (consult IMPLEMENTATION_PLAN.md §7 Localization guidelines + Constitution V). Wrap each entry in a `"@key": { "description": "..." }` metadata block per Phase 3 conventions. Note: total count may slightly exceed 48 if the implementer adds variants for amenity-display labels or per-status-badge color descriptions; the canonical list in `data-model.md` is the floor, not a ceiling.

- [ ] T113 Author or update `H:\alnujom-project\lib\l10n\app_en.arb` with the same **48 keys** in English. Same metadata blocks. Both files MUST be updated in the same commit per Phase 3's localization gate. Verify the ARB-key lists in both files match exactly — `grep -oE '"[a-zA-Z][a-zA-Z0-9]*":' app_ar.arb | sort -u` and the same on `app_en.arb` MUST produce identical lists (excluding the `@@locale` and `@@last_modified` metadata keys).

- [ ] T114 Regenerate the localization classes. From `H:\alnujom-project`: `flutter pub run intl_utils:generate` OR `flutter gen-l10n` (whichever Phase 3 uses — check `pubspec.yaml` for `flutter_intl` config and `lib/l10n/` for an existing `intl_*.arb` pattern). Confirm `lib/l10n/app_localizations.dart` (and its `_ar.dart`/`_en.dart` siblings) regenerate with all the new keys exposed as Dart getters.

### Phase 3 localization lint guard

- [ ] T115 Run the Phase 3 localization lint guard. From `H:\alnujom-project`: `flutter analyze --no-fatal-warnings` OR the project's specific lint command (check `analysis_options.yaml` for a custom localization-string check, OR run `grep -RE "'[^']*[a-zA-Zا-ي][^']*'" lib/features/listing_form/presentation lib/features/publisher_dashboard/presentation` for raw string literals — exclude technical strings like CSS keys, ARB keys, debug labels). If hardcoded user-facing strings are found, route them through `AppLocalizations`. Iterate until zero findings.

### Constitution IX grep audit (Supabase-free domain)

- [ ] T116 Run from `H:\alnujom-project`: `grep -RE "package:supabase_flutter" lib/features/listing_form/domain lib/features/publisher_dashboard/domain`. Expected: zero hits. If any hits found, refactor the offending import into the data layer.

### Constitution VI grep audit (Phase 2 design tokens)

- [ ] T117 Run from `H:\alnujom-project`: `grep -RE "Color\(0x|Color\.from|EdgeInsets\.only|EdgeInsets\.fromLTRB" lib/features/listing_form/presentation lib/features/publisher_dashboard/presentation`. Expected: zero hits in widget code (EdgeInsetsDirectional and ColorScheme references are fine). If any hits found, replace with Phase 2 design-token primitives.

### Analyzer parity

- [ ] T118 From `H:\alnujom-project`: `flutter analyze --no-fatal-infos --no-fatal-warnings`. Diff against the analyzer baseline in `H:\alnujom-project\specs\010-listing-creation\baseline-pre-migration.txt § (E)`. Expected: zero NEW errors. Pre-existing infos/warnings carried over from Phase 1–9 are fine. If new errors appear, fix them before proceeding.

### Quickstart end-to-end

- [ ] T119 Run the full `H:\alnujom-project\specs\010-listing-creation\quickstart.md` recipe end-to-end. Step 1 through Step 14. Tick each step's verification as it passes. If any step fails, STOP, fix the root cause, and re-run from that step.

### DEFERRED.md authoring

- [ ] T120 If any scope item was discovered during implementation that ought to be flagged for future-spec follow-up (e.g., the publisher-status three-layer enforcement may want a custom error screen, Phase 19 needs to wire the agency_id FK, Phase 11 needs the media picker, Phase 12 needs reject_listing.reason write path, post-approval edit policy is a future-spec concern, area-centroid-future-update flow when admins add new areas), author `H:\alnujom-project\specs\010-listing-creation\DEFERRED.md` mirroring `specs\008-locations\DEFERRED.md` or `specs\009-currencies\DEFERRED.md`. Each deferred item: title + scope + rationale + recommended next-phase owner. Otherwise (if nothing material to defer), skip this task.

### CLAUDE.md confirmation

- [ ] T121 Confirm `H:\alnujom-project\CLAUDE.md` between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers points to Phase 10. This was updated during `/speckit-plan` (the bottom of the plan-time report). Re-verify: open the file and confirm the first line of the speckit block reads `Active Spec Kit feature: \`010-listing-creation\` (Phase 10 — Listing Creation & Submit-for-Review)`. If it has drifted, restore it (it's the version from the plan-time report).

### Final commit and PR

- [ ] T122 Final commit. Run from `H:\alnujom-project`: `git status`, review changes, confirm only expected files. `git add -A`. `git commit -m "chore(010): polish — l10n, design tokens, analyzer parity, quickstart pass"`. `git push`.

- [ ] T123 Open the PR. Run: `gh pr create --title "Phase 10 — Listing Creation & Submit-for-Review" --base main --head 010-listing-creation --body "$(cat <<'EOF'
## Summary

Phase 10 — publisher-side listing creation pipeline.

- 5 new tables (listings, listing_details, listing_prices, listing_visibility, listing_status_history)
- 1 altered Phase 8 table (public.areas + centroid columns + Syrian-bounds CHECK + manual OpenStreetMap seed)
- 1 status-transition trigger (operational history)
- 1 sync trigger (listing_visibility parent-column-authoritative)
- 1 audit-trigger group (10 action keys via log_audit() unchanged for 7th time)
- 5 RLS policy bundles (public-when-approved SELECT + owner-when-approved-pair write + admin via listings.edit_any/delete_any + append-only history)
- 1 SECURITY DEFINER PL/pgSQL RPC submit_listing (NOT an Edge Function — R-06 carry-forward)
- 2 new Flutter feature folders: lib/features/listing_form/ (seven-step form) and lib/features/publisher_dashboard/ (MyListingsPage)
- 3 new validators under lib/core/validators/ (Area, Price, Phone)
- 3 new go_router routes + publisher-status redirect guards
- ~40 new ARB keys in both ar and en
- Zero new pubspec packages

Clarifications (Session 2026-05-18): Q1=B Full required-field set; Q2=A area-centroid auto-fill; Q3=A single-currency-only across every Phase 10 surface.

## Test plan

- [x] 7 backend migrations applied via Supabase MCP apply_migration
- [x] get_advisors clean
- [x] All 24 SC verified per quickstart.md
- [x] Three-layer non-approved gate refuses (UX/router/RLS)
- [x] Happy-path create→submit on the reference Infinix Note 8
- [x] Rejected-resubmit loop with full status-chain preservation
- [x] Append-only listing_status_history (UPDATE/DELETE refused)
- [x] Single-currency invariant + non-null lat/lng on non-draft listings + no multi-row UI surface
- [x] Mid-session publisher_status approval propagation (SC-020)
- [x] Constitution IX grep + Constitution VI design-token grep + Phase 3 l10n lint guard all clean

Closes nothing in the implementation plan beyond Phase 10's own scope; forward-stated dependencies for Phase 11 (media), Phase 12 (approve/reject), Phase 15 (pin-drop edit), Phase 19 (agency_id FK) are documented in CLAUDE.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"`. Confirm the PR URL is returned. Squash-merge per `feedback_git_workflow.md` once review passes; the squash commit message follows the project convention.

**⚠️ Checkpoint I — Phase 10 shipped**: All 123 tasks complete. PR open and squash-merged. DEFERRED.md (if any) flagged for future-spec follow-up.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1, T001–T005)**: No dependencies on prior phases.
- **Foundational Backend (Phase 2, T006–T032 incl. T011a, T025a, T025b)**: Depends on Setup. BLOCKS all user stories.
- **Foundational Flutter (Phase 3, T033–T041)**: Depends on Phase 2's migrations being applied. T036/T037 changed in this fix: T037 is a no-op task (PermissionChecker is NOT modified — see R-19 revised); the publisher-status gate lives in `requirePublisherStatusRedirect` (T041) and the HomePage BlocBuilder (T080). Can begin in parallel with Phase 2's docs (T027–T032).
- **US1 (Phase 4, T042–T082 incl. T081a)**: Depends on Phase 3 complete (validators + routes + ListingFormMode enum from T038).
- **US2 (Phase 5, T083)**: Depends on Phase 3 (the gate's three layers) — verification only.
- **US4 (Phase 6, T084–T101)**: Depends on US1's data-layer DTOs (T042–T047 — shared shapes) AND on T025a/T025b's `v_publisher_listings` view (the datasource queries the view, not the raw tables).
- **US3 (Phase 7, T102–T105)**: Depends on US1 (form) + US4 (MyListingsPage rejection-reason rendering + Resubmit CTA).
- **US5/US6/US7 (Phase 8, T106–T111)**: Depends on US1 (US5+US7 exercise form behavior) and on Phase 2 (US6 exercises the trigger).
- **Polish (Phase 9, T112–T123)**: Depends on all user-story phases.

**New tasks added during analyze fix-up**: T011a (SC-005 anon SELECT smoke test), T025a/T025b (v_publisher_listings view + verification), T038 (ListingFormMode enum), T081a (SC-010 submit-failure path).

### Parallel opportunities

- **Within Phase 2**: T011 (policy file mirror) and T014/T017/T020/T023 (policy file mirrors) can be authored in parallel after their respective migrations are applied. T027–T031 (docs) can be authored in parallel after Phase 2 migrations are applied.
- **Within Phase 3**: T033/T034/T035 (the 3 validators) can be authored in parallel.
- **Within Phase 4 / US1**: All 6 DTOs (T042–T047) can be authored in parallel. All 8 entity files (T048–T055) can be authored in parallel after the enums in T048 are defined. The 7 step widgets (T067–T073) can be authored in parallel after the BLoC (T065) and page (T066) are scaffolded. The 4 supporting widgets (T074–T077) can be authored in parallel.
- **Within Phase 6 / US4**: All 4 DTOs/entities/usecases (T084, T085, T088, T089, T090) can be authored in parallel. The 6 presentation widgets (T093–T098) can be authored in parallel after the BLoC (T091) and page (T092) are scaffolded.
- **Polish**: T115/T116/T117 (the three grep audits) can be run in parallel.

### Within each user story

- DTOs and entities first.
- Repository abstract, then use cases, then BLoC, then page, then step widgets, then DI registration.
- Manual verification last (always serial; one device, one human).

---

## Implementation Strategy

### MVP First (US1 + US2 + US3)

1. Phase 1 (Setup) → Phase 2 (Backend) → Phase 3 (Flutter foundational) → Phase 4 (US1 form).
2. Demo: an approved publisher creates a draft and submits.
3. Phase 5 (US2 gate verification) → Phase 6 (US4 MyListingsPage) → Phase 7 (US3 resubmit loop).
4. Demo: the full publisher-side approval-pending pipeline works end-to-end without admin involvement.

At this point the MVP is shippable for internal QA; admin approval (Phase 12) is the next dependency.

### Incremental delivery

- After Phase 4 (US1) → demo (single happy path only; no MyListings, no resubmit).
- After Phase 7 (US3) → demo (full publisher loop).
- After Phase 8 (US5/6/7) → polish complete; ship.

### Parallel team strategy

If two engineers are available:

- Engineer A: Phase 2 backend migrations (T006–T032).
- Engineer B: Phase 3 Flutter foundational (T033–T041) — can begin once T010 (migration 2 applied) lands.
- Both converge at Phase 4 / US1; one can do data layer (T042–T064), the other can do presentation (T065–T077).
- Phase 6 / US4 work can start after Phase 4 DTOs (T042–T047) land — Engineer A picks it up while Engineer B finishes US1 widgets.

---

## Notes

- Per `feedback_no_new_tests.md`: zero new automated tests. All verifications are manual SQL via Supabase MCP `execute_sql` or manual UI walks on the reference Infinix Note 8.
- Per `feedback_git_workflow.md`: commit + push after each ⚠️ Checkpoint marker. One PR per spec, opened at the end (T123). Squash-merge per the project convention.
- Per `project_dart_defines.md`: every `flutter run` MUST include `--dart-define-from-file=.env.json`.
- Per `project_supabase_mcp_apply_migration.md`: `apply_migration` does NOT dedupe by name — re-applying re-runs the SQL AND adds a duplicate tracker row. Migration bodies use idempotent constructs (`CREATE TABLE IF NOT EXISTS`, `DROP POLICY IF EXISTS`, `ON CONFLICT`, etc.) so re-application is safe.
- When a task says "find at `<path>` if it exists; otherwise grep" — that is the canonical hedge for path uncertainty. Phase 5/8/9's exact file layout may have drifted; the grep is the authoritative lookup.
