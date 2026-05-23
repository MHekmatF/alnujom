---

description: "Task list for Phase 11 — Listing Media Upload, Client-Side Watermark & Storage Policies. Each task is self-contained with exact absolute file paths and contract pointers so a cheaper LLM model can implement without context-switching. Tasks are dependency-ordered: Setup → Foundational backend (4 migrations + bucket creation + storage policies + submit_listing amendment) → Foundational frontend (3 new pubspec packages + watermark asset + AndroidManifest permissions + video validator + watermark pipeline util + header reader + isolate worker) → US1 image upload happy-path (MVP) → US2 cap enforcement verification → US3 resubmit edit-in-place → US4 background isolate verification → US5 MP4 video upload → US6 storage RLS verification → US7 per-thumbnail actions → Polish."

---

# Tasks: Listing Media Upload, Client-Side Watermark & Storage Policies

**Input**: Design documents from `/specs/011-media-watermark/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md` (10 files), `quickstart.md` — all complete and locked at Session 2026-05-22.

**Tests**: **NONE.** Per durable session feedback (`feedback_no_new_tests.md`), Phase 11 introduces ZERO new automated tests. Verification is manual SQL via Supabase MCP `execute_sql` + manual UI walks on TWO devices (the reference Infinix Note 8 for the legacy `READ_EXTERNAL_STORAGE` code path AND the Pixel 8 Pro emulator running Android 14 for the granular `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` code path per R-34 + SC-026). The validator goldens in `contracts/video-file-validator.md` are manually exercised on the device, not automated. Existing Phase 1–10 tests remain unchanged.

**Organization**: Tasks are grouped by user story (US1 P1 is the MVP). Each story's checkpoint is a self-contained increment that can be demo'd without subsequent stories. Phase 11's plan-time ordering prioritizes shared infrastructure (4 migrations + pubspec deps + manifest + asset + validator + the watermark pipeline + isolate worker + header reader) in Foundational, so US1's UI work is unblocked.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P]-marked tasks in the same phase (different files, no dependency on incomplete tasks).
- **[Story]**: User story label (US1..US7). Setup / Foundational / Polish tasks have NO story label.
- Every task includes the exact absolute file path and a pointer to the relevant contract / data-model section.

## Path Conventions

- Repository root: `H:\alnujom-project\`
- Supabase artifacts: `H:\alnujom-project\supabase\`
- Flutter sources: `H:\alnujom-project\lib\`
- ARB files: `H:\alnujom-project\lib\l10n\`
- Bundled assets: `H:\alnujom-project\assets\`
- Android platform: `H:\alnujom-project\android\app\src\main\`

## Implementer briefing (read once before T001)

Before starting, read in this order:

1. `H:\alnujom-project\specs\011-media-watermark\spec.md` — entire file (8 Q clarifications, 7 user stories, 29 Success Criteria, 23 FRs).
2. `H:\alnujom-project\specs\011-media-watermark\plan.md` — entire file (Project Structure tree lists every file you will touch; Constitution Check explains every plan-time choice).
3. `H:\alnujom-project\specs\011-media-watermark\research.md` — R-21 through R-40 (20 plan-time decisions). The R-22 (three pubspec packages) and R-35 (Phase 10 migration immutability) decisions are especially important.
4. `H:\alnujom-project\specs\011-media-watermark\data-model.md` — entire file (full CREATE TABLE body, cap trigger function body, audit trigger group, 7 listing_media policies, 14 storage.objects policies, the FULL amended submit_listing RPC body inline, Flutter entity/DTO/use-case/BLoC shapes, watermark pipeline pseudocode, header reader spec, ARB-key inventory, per-FR / per-SC verification map). **This is your most-consulted reference.**
5. `H:\alnujom-project\specs\011-media-watermark\quickstart.md` — Steps 1–6 first; re-read individual steps when verification tasks reference them.
6. Skim the 10 contract files in `H:\alnujom-project\specs\011-media-watermark\contracts\` — the most critical ones: `phase11-listing-media-table.md`, `phase11-storage-policies.md`, `submit-listing-amendment.md`, `watermark-pipeline.md`, `media-picker-pages.md`.
7. `H:\alnujom-project\specs\010-listing-creation\tasks.md` — skim for format reference. Phase 11 follows the same pattern with a smaller surface (4 migrations vs 9; ~75 tasks vs 123).

When a task says "per `contracts/<X>.md` § Y" or "per `data-model.md` § Z", that section is your source of truth for the exact code/SQL — copy it verbatim and adjust only the names called out in the task.

**Three carry-forward project memories matter most**:

- `feedback_no_new_tests.md` — **do not write any new automated test files**. Manual verification only.
- `feedback_git_workflow.md` — commit + push immediately after each phase / each checkpoint marker (`⚠️ Checkpoint:` lines below). One PR per spec, opened only at end-of-spec.
- `project_dart_defines.md` — **EVERY `flutter run` invocation in this tasks file is shorthand for `flutter run --dart-define-from-file=.env.json`.** If you literally type `flutter run` without the flag, `Supabase.initialize` is skipped and the app red-screens at first `Supabase.instance` access. This applies to `flutter run`, `flutter run --profile`, `flutter run --release`, and every other run variant. The `--dart-define-from-file=.env.json` flag is **NOT** needed for `flutter analyze`, `flutter pub get`, `flutter pub run`, or `flutter test` — only for `flutter run`.

### Project ground-truth references (probe-confirmed at plan time)

The cheaper LLM should treat these as authoritative.

- **`ListingFormBloc` at `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart`** is Phase 10's BLoC owning the seven-step form. Phase 11 EXTENDS it (per R-40) with five new events (`MediaPicked`, `VideoPicked`, `MediaReordered`, `MediaSetMain`, `MediaDeleted`). Do NOT create a new BLoC.
- **`ListingFormState` at `lib/features/listing_form/domain/entities/listing_form_state.dart`** is Phase 10's state class. Phase 11 adds two fields: `List<ListingMedia> media` and `Map<String, MediaUploadProgress> uploadInFlight`. Use `copyWith` for state transitions.
- **`step_media_placeholder.dart` at `lib/features/listing_form/presentation/widgets/step_media_placeholder.dart`** is Phase 10's no-op banner — DELETED in Phase 11 and replaced by `step_media.dart` in the same directory.
- **`listings_repository_impl.dart` at `lib/features/listing_form/data/repositories/listings_repository_impl.dart`** is Phase 10's repository — Phase 11 EXTENDS it with six method impls calling the new `SupabaseListingMediaDatasource`. Same path for `listings_repository.dart` in `domain/`.
- **`submit_failure_dialog.dart` at `lib/features/listing_form/presentation/widgets/submit_failure_dialog.dart`** is Phase 10's failure dialog. It iterates the `missing_fields[]` array via `AppLocalizations` lookups. Phase 11 adds the new ARB key `submit.error.imagesBelowMinimum` to both `.arb` files — NO source-code change to the dialog is needed.
- **`auth_redirect.dart` at `lib/core/routing/auth_redirect.dart`** is Phase 10's router guard. Phase 11 makes NO changes — the publisher-status guard from Phase 10 already covers `/publisher/listings/<id>/edit` where the MediaPicker mounts.
- **`PermissionChecker` at `lib/core/security/permission_checker.dart`** is Phase 6's helper. Phase 11 makes NO changes — `userIsApprovedPublisher()` (added per Phase 10 R-19) is consumed unchanged.
- **`cached_network_image` is already in `pubspec.yaml`** since Phase 1. Phase 11 MAY use it for thumbnail re-mounts (R-29); Phase 13's gallery will use it heavily.

### RLS testing helper (READ BEFORE running any "RLS deny" verification)

The Supabase MCP `execute_sql` tool runs queries with the **project's service_role JWT**, which BYPASSES Row Level Security. A naive `INSERT INTO public.listing_media ...` via `execute_sql` will SUCCEED even when the RLS policy would deny it for a real user. To validate RLS behavior, every "expected: 0 rows affected / RLS deny" verification MUST use ONE of these two impersonation patterns:

**Pattern A — Set the role and JWT claims for the current transaction (preferred for MCP)**:

```sql
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"<USER_UUID>","role":"authenticated"}';
-- Now run the operation; RLS evaluates as if this user is the caller.
INSERT INTO public.listing_media (listing_id, kind, storage_path, ordering, is_main, watermarked)
VALUES ('<LISTING_UUID>', 'image', '<LISTING_UUID>/x.jpg', 1, false, true);
-- Expected for a non-approved publisher: ERROR 42501 (new row violates row-level security policy)
ROLLBACK;
```

Use `ROLLBACK` always — these verifications must not leave state behind.

**Pattern B — Use the Supabase Storage REST endpoint with a real user JWT (for storage policies)**:

```bash
curl -X POST "https://<PROJECT>.supabase.co/storage/v1/object/listing-images/<listing_id>/test.jpg" \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: image/jpeg" \
  --data-binary @test.jpg
# Expected for a non-approved publisher: HTTP 403 / NoAccess
```

Pattern A is preferred where MCP `execute_sql` suffices. For storage policy verification on `storage.objects`, Pattern A works for SELECT/UPDATE/DELETE policies via SQL; for INSERT via the Storage API, Pattern B is the only realistic test path (or use the Supabase Dart client signed in as a specific user).

Anonymous-deny verifications use: `SET LOCAL ROLE anon; SET LOCAL "request.jwt.claims" TO '{"role":"anon"}'`. Same wrapping in BEGIN/ROLLBACK.

If a verification can't be made to work via either pattern (rare), defer to a manual test on the device with a real user's JWT.

---

## Phase 1: Setup

**Purpose**: Confirm environment + Phase 10 baseline + capture pre-migration snapshot. NO production code authored yet.

- [ ] T001 Verify current git state. From `H:\alnujom-project`, run `git status` and `git branch --show-current`. Expected: branch `011-media-watermark`, working tree clean apart from the already-committed `specs/011-media-watermark/*` files. If branch differs, STOP and ask. If tree has unrelated dirty files, commit or stash before proceeding.

- [ ] T002 [P] Verify Phase 10 is shipped on the remote Supabase project. Run via Supabase MCP `execute_sql` five checks: (a) `SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename IN ('listings','listing_details','listing_prices','listing_visibility','listing_status_history')` returns `5`; (b) `SELECT count(*) FROM pg_proc WHERE proname='submit_listing'` returns `1`; (c) `SELECT count(*) FROM pg_views WHERE viewname='v_publisher_listings'` returns `1`; (d) `SELECT count(*) FROM pg_proc WHERE proname IN ('log_audit','set_updated_at','current_user_has_permission')` returns `3`; (e) `SELECT count(*) FROM public.areas WHERE centroid_lat IS NOT NULL AND centroid_lng IS NOT NULL` returns ≥ 10 (Phase 10's centroid seed). If any check fails, STOP — Phase 11 cannot proceed without Phase 10's listings tables + submit_listing RPC.

- [ ] T003 [P] Verify the storage schema is queryable on the remote project. Run via Supabase MCP `execute_sql`: (a) `SELECT count(*) FROM storage.buckets` — record the count (Phase 10 + earlier phases ship zero project-defined buckets; this should be 0 or whatever pre-Phase-11 buckets the project ships). (b) `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects'` — record the count (defaults installed by Supabase ship some baseline policies; record for baseline reference). These two numbers seed `baseline-pre-migration.txt` Section G.

- [ ] T004 [P] Verify `H:\alnujom-project\.env.json` exists and contains valid Supabase credentials (URL + anon key + service_role key per project memory `project_dart_defines.md`). If missing, STOP and ask the user to provide the file. Do NOT commit `.env.json` (it is in `.gitignore`).

- [ ] T005 Capture pre-migration baseline to `H:\alnujom-project\specs\011-media-watermark\baseline-pre-migration.txt`. Concatenate the following sections (use the section headers shown verbatim) into the file: (A) Supabase MCP `list_tables` output for the `public` schema (current state — `listing_media` not present yet); (B) Supabase MCP `list_migrations` output (full ordered list — the last entry MUST be the closing Phase 10 migration name from spec 010 DEFERRED.md walk-through, typically `20260519120012_fix_submit_listing_array_append` or whatever Phase 10 closed at); (C) `SELECT count(*) FROM public.listing_media` — expected: error `relation "public.listing_media" does not exist`; record the error verbatim; (D) `SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id IN ('listing-images','listing-videos')` — expected: 0 rows; record verbatim; (E) `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE 'listing-%'` — expected: 0; (F) `SELECT prosrc FROM pg_proc WHERE proname='submit_listing'` — copy the body verbatim (this is the Phase 10 version; will be amended by migration 4 to add the Q1=A check); (G) the storage baseline counts from T003; (H) **Analyzer baseline**: from `H:\alnujom-project`, run `flutter analyze --no-fatal-infos --no-fatal-warnings` and paste the full stdout/stderr verbatim. This snapshot is the rollback reference if Phase 11 needs to be reverted AND the analyzer-comparison reference for the final polish phase.

**⚠️ Checkpoint A — Setup complete**: Environment confirmed, Phase 10 verified shipped, storage schema baseline recorded, `.env.json` present, baseline snapshot captured. Commit: `git add specs/011-media-watermark/baseline-pre-migration.txt && git commit -m "chore(011): capture pre-migration baseline" && git push`.

---

## Phase 2: Foundational — Backend Migrations (Blocking Prerequisites)

**Purpose**: Apply the 4 Phase 11 migrations + 2 new policy files + 1 new + 2 updated doc files. The new `public.listing_media` table, 2 storage buckets, 14 `storage.objects` policies, cap trigger, audit trigger group, and the amended `submit_listing` RPC all land here. EVERY downstream user story depends on this phase.

**⚠️ CRITICAL**: No user story task may begin until Phase 2 is complete and verified.

### Migration 1 — public.listing_media table + cap trigger + audit triggers + RLS

- [ ] T006 Author migration 1 file at `H:\alnujom-project\supabase\migrations\20260522120001_create_listing_media.sql`. (FR-001..FR-006, SC-007.) Body MUST contain, in exactly this order: (1) leading SQL `-- COMMENT` block citing FR-001..FR-006, R-22 (3 pubspec deps), Q1=A media-minimum, Q2=D external_link schema retention; (2) the full `CREATE TABLE IF NOT EXISTS public.listing_media (...)` body from `data-model.md § 1.1 CREATE TABLE body`; (3) the two indexes `listing_media_listing_id_idx` and `listing_media_listing_id_ordering_idx`; (4) the partial unique index `listing_media_one_main_idx ON (listing_id) WHERE is_main=true AND kind='image'`; (5) `ALTER TABLE public.listing_media ENABLE ROW LEVEL SECURITY;`; (6) `set_updated_at` trigger attach per `data-model.md § 1.2`; (7) the `listing_media_cap_check()` function body + `listing_media_cap_trigger` attach per `data-model.md § 2.1`; (8) the three audit-trigger attachments (`audit_listing_media_insert`, `audit_listing_media_update`, `audit_listing_media_delete`) per `data-model.md § 3`; (9) the 7 RLS policies per `data-model.md § 4.1` (verbatim — anon SELECT, owner SELECT, admin SELECT, owner INSERT, owner UPDATE, owner DELETE, admin FOR ALL). Each `CREATE POLICY` preceded by `DROP POLICY IF EXISTS <name> ON public.listing_media;` for idempotency. The `set_updated_at` trigger uses the existing Phase 4 function unchanged.

- [ ] T007 Apply migration 1 via Supabase MCP `apply_migration` with name `20260522120001_create_listing_media` and body from T006. Then verify via Supabase MCP `execute_sql` (all read-only — service_role context is FINE here): (a) `SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='listing_media'` returns `1` (FR-001); (b) `SELECT conname FROM pg_constraint WHERE conrelid='public.listing_media'::regclass AND contype='c'` includes `listing_media_path_xor_url_chk` AND `listing_media_main_only_when_image_chk` (FR-002); (c) `SELECT indexname FROM pg_indexes WHERE tablename='listing_media' AND indexdef LIKE '%WHERE%is_main%'` returns `listing_media_one_main_idx` (FR-003); (d) `SELECT tgname FROM pg_trigger WHERE tgrelid='public.listing_media'::regclass` returns `listing_media_cap_trigger`, `audit_listing_media_insert`, `audit_listing_media_update`, `audit_listing_media_delete`, `set_updated_at_on_listing_media` (FR-004, FR-005); (e) `SELECT relrowsecurity FROM pg_class WHERE relname='listing_media'` returns `t` (SC-007); (f) `SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='listing_media'` returns `7` (FR-006); (g) `SELECT prosrc FROM pg_proc WHERE proname='log_audit'` — copy and diff against Phase 4 baseline; expected: zero diffs (R-05 EIGHTH-time invariant preserved); (h) **Trigger-before-seed audit ordering verification per SC-021 (C2 fix)** — open the just-authored migration file at `H:\alnujom-project\supabase\migrations\20260522120001_create_listing_media.sql` and confirm the statement order is: (1) `CREATE TABLE`, (2) `CREATE INDEX` × 3, (3) `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, (4) trigger function definitions (`listing_media_cap_check`), (5) all `CREATE TRIGGER` statements (cap + audit × 3 + set_updated_at = 5 triggers), (6) all `CREATE POLICY` statements (7 policies). Phase 11 seeds ZERO listing_media rows, so the trigger-before-seed invariant is defensive only — but verify the order is correct for any future spec that may add seed data.

- [ ] T008 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_media_policies.sql`. Body MUST be a verbatim copy of the 7 `DROP POLICY IF EXISTS ... CREATE POLICY ...` blocks from migration 1 step (9). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260522120001_create_listing_media.sql. R-02 dual-storage invariant — both files MUST be kept in sync at PR review.`

### Migration 2 — Supabase Storage buckets (listing-images + listing-videos)

- [ ] T009 Author migration 2 file at `H:\alnujom-project\supabase\migrations\20260522120002_create_listing_media_storage_buckets.sql`. (FR-008, SC-029.) Body MUST contain: (1) leading `-- COMMENT` block citing FR-008, Q4=A bucket allowlist tight, Q8=A public=true + RLS, R-26 idempotent upsert; (2) the `INSERT INTO storage.buckets ... ON CONFLICT (id) DO UPDATE SET ...` body verbatim from `data-model.md § 5.1`. Idempotent via the ON CONFLICT clause.

- [ ] T010 Apply migration 2 via Supabase MCP `apply_migration` with name `20260522120002_create_listing_media_storage_buckets`. Verify via Supabase MCP `execute_sql`: `SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id IN ('listing-images','listing-videos') ORDER BY id`. Expected: 2 rows — first row id=`listing-images` public=true file_size_limit=10485760 allowed_mime_types=`{image/jpeg}`; second row id=`listing-videos` public=true file_size_limit=31457280 allowed_mime_types=`{video/mp4}`. SC-029 references this query.

### Migration 3 — storage.objects RLS policies (14 policies)

- [ ] T011 Author migration 3 file at `H:\alnujom-project\supabase\migrations\20260522120003_create_listing_media_storage_policies.sql`. (FR-007, SC-008, SC-009, SC-025, R-27.) Body MUST contain, in order: (1) leading `-- COMMENT` block citing FR-007 + R-27 path-shape regex + Q8=A bucket + RLS access boundary; (2) for `bucket_id='listing-images'`: the seven policies per `data-model.md § 6.1` — `<bucket>_anon_select_when_approved`, `<bucket>_owner_select`, `<bucket>_admin_select`, `<bucket>_owner_insert` (with path-shape regex `WITH CHECK`), `<bucket>_owner_update`, `<bucket>_owner_delete`, `<bucket>_admin_write` (the FOR ALL admin policy); (3) the same seven policies for `bucket_id='listing-videos'` (substitute `listing-videos` in policy names + USING clauses). Total: 14 policies. Each `CREATE POLICY` preceded by `DROP POLICY IF EXISTS <name> ON storage.objects;` for idempotency. **Implementation note**: the policies reference `storage.objects.name` (the path column) and use `split_part(storage.objects.name, '/', 1)::uuid` to derive the parent listing_id. The path-shape regex on owner INSERT is `'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'`.

- [ ] T012 Apply migration 3 via Supabase MCP `apply_migration` with name `20260522120003_create_listing_media_storage_policies`. Verify via Supabase MCP `execute_sql`: (a) `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE 'listing-%'` returns `14` (SC-029 part 2); (b) `SELECT policyname FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE 'listing-images_%' ORDER BY policyname` returns the 7 image-bucket policy names; same for `listing-videos_%`; (c) `SELECT policyname, cmd FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE 'listing-images_%'` — confirm three SELECT, one INSERT, one UPDATE, one DELETE, and one `ALL` (the admin policy).

- [ ] T013 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\listing_media_storage_policies.sql`. Body MUST be a verbatim copy of the 14 `DROP POLICY IF EXISTS ... CREATE POLICY ...` blocks from migration 3 steps (2)+(3). Add the same leading R-02 comment as T008.

### Migration 4 — Amend submit_listing RPC for Q1=A media-minimum check

- [ ] T014 Author migration 4 file at `H:\alnujom-project\supabase\migrations\20260522120004_amend_submit_listing_rpc_for_media_minimum.sql`. (FR-022, SC-017, R-31, R-35.) Body MUST contain: (1) leading `-- COMMENT` block citing FR-022 (Q1=A media minimum check) + R-31 (step 5a placement) + R-35 (Phase 10 migration 20260519120007 NOT edited — supersession via CREATE OR REPLACE); (2) the full amended `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID) RETURNS JSONB ...` body from `data-model.md § 7.1` verbatim (this includes ALL of Phase 10's body — load, ownership check, approved-pair check, status check, Q1=B required fields — PLUS the NEW step 5a media count check appending `listing_media.images_below_minimum` to `v_missing[]` — PLUS Phase 10's IF-RAISE block — PLUS the status flip and JSONB return); (3) NO additional REVOKE/GRANT statements (Phase 10 migration 7 already granted EXECUTE TO authenticated; CREATE OR REPLACE preserves the grants). **Critical**: do NOT edit Phase 10's migration `20260519120007_create_submit_listing_rpc.sql` — it is immutable per R-35. Per `project_supabase_mcp_apply_migration.md`, editing an existing migration would not re-apply (tracker shows it already ran); the NEW migration file is the only safe path.

- [ ] T015 Apply migration 4 via Supabase MCP `apply_migration` with name `20260522120004_amend_submit_listing_rpc_for_media_minimum`. Verify via Supabase MCP `execute_sql`: (a) `SELECT prosrc FROM pg_proc WHERE proname='submit_listing'` — confirm the body INCLUDES the substring `listing_media.images_below_minimum` (FR-022); (b) `SELECT prosrc FROM pg_proc WHERE proname='submit_listing'` — confirm the body INCLUDES the substring `WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true` (the count predicate); (c) `SELECT prosecdef FROM pg_proc WHERE proname='submit_listing'` returns `t` (SECURITY DEFINER preserved); (d) `SELECT proconfig FROM pg_proc WHERE proname='submit_listing'` returns an array containing `search_path=public,auth` (preserved); (e) `SELECT grantee FROM information_schema.routine_privileges WHERE routine_name='submit_listing' AND privilege_type='EXECUTE'` includes `authenticated` (preserved); (f) `git diff supabase/migrations/20260519120007_create_submit_listing_rpc.sql` returns ZERO changes (R-35 immutability — SC-017 indirect verification).

### Run advisors after all migrations

- [ ] T016 Run Supabase MCP `get_advisors` (mode `security` then `performance`). Expected: zero NEW warnings vs the T005 baseline (Section H analyzer + Section G storage-policy counts implicitly reference). If new warnings appear, read them carefully — common cases: (a) "function without search_path" — the amended `submit_listing` already has `SET search_path=public,auth`; ignore; (b) "policy uses function returning multiple rows" — the `EXISTS` subqueries are safe; ignore; (c) "RLS enabled but no policies for SELECT" — should not appear (all 7 policies on `listing_media` include 3 SELECT cases). Annotate any unexpected delta in `H:\alnujom-project\specs\011-media-watermark\baseline-pre-migration.txt` under a new section `(I) ADVISOR DELTA AFTER PHASE 11 MIGRATIONS`. Phase 11 SHOULD NOT need an advisor-hardening migration (Phase 10 R-04 carry-forward — no broad anon carve-out on listing_media).

### Backend documentation

- [ ] T017 [P] Author `H:\alnujom-project\supabase\docs\listing_media.md`. Body: a short markdown doc describing the table — 10 columns, CHECK constraints, partial unique index, the cap trigger (FR-004), the audit trigger group (FR-005, R-05 EIGHTH-time invariant), RLS posture (Q4=A bucket + Q8=A RLS access filter), 2-step storage-cleanup pattern (R-28 / R-38), Q1..Q8 surface alignment summary. Cite `data-model.md §§ 1–4` and `contracts/phase11-listing-media-table.md` + `contracts/phase11-rls-policies.md`.

- [ ] T018 Update `H:\alnujom-project\supabase\docs\audit_logs.md` to enumerate the 3 new action keys: `listing_media.created`, `listing_media.updated`, `listing_media.deleted`. Use the existing file's table format; add the rows in a new "Phase 11" section (or extend the existing listings section if that's the established shape).

- [ ] T019 Update `H:\alnujom-project\supabase\docs\listings.md` to note that `submit_listing` now performs the Q1=A media-minimum check per Phase 11 FR-022; cross-reference `specs/011-media-watermark/contracts/submit-listing-amendment.md`. The underlying `public.listings` table is unchanged in Phase 11.

**⚠️ Checkpoint B — Backend migrations complete**: 4 migrations applied (1 new table + 2 storage migrations + 1 RPC amendment), 2 policy files mirrored, 1 new + 2 updated doc files. Advisor count clean. Verify: `SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename='listing_media'` returns `1`; `SELECT count(*) FROM storage.buckets WHERE id IN ('listing-images','listing-videos')` returns `2`; `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE 'listing-%'` returns `14`; the `submit_listing` body contains `listing_media.images_below_minimum`. Commit: `git add supabase/ specs/011-media-watermark/baseline-pre-migration.txt && git commit -m "feat(011): backend migrations + storage buckets + storage policies + submit_listing amendment (4 migrations, 2 policies, 3 docs)" && git push`.

---

## Phase 3: Foundational — Flutter Core (Pubspec deps + Asset + Manifest + Validator + Pipeline utilities)

**Purpose**: Land the three new pubspec packages (R-22), the watermark asset (R-23 / R-33), the AndroidManifest permissions (Q5=A / FR-023), the video file validator (FR-017), AND the four picker-internal utility files (header reader R-24, watermark pipeline FR-014, isolate worker R-25). The MediaPicker widgets (Phase 4) consume these foundations, so they must ship before any feature code.

### Pubspec dependencies (R-22)

- [ ] T020 Edit `H:\alnujom-project\pubspec.yaml` to add three new dependencies. Procedure (per A1 + A7 fixes):

  **Step 1 — Observe the existing sort order**: Open `pubspec.yaml`; look at the `dependencies:` block; record whether the existing entries are in alphabetical order OR some other order (e.g., grouped by category with `flutter:` first). The cheaper LLM MUST follow whatever order is in use — do NOT impose alphabetical sorting if the existing file doesn't use it.

  **Step 2 — Add the three deps**. Preferred command-driven approach (per A7 fix — handles version pinning automatically):

  ```bash
  cd H:/alnujom-project && flutter pub add image_picker image flutter_image_compress
  ```

  This resolves to the latest compatible versions at implement time. The expected resolved versions (as of plan-time research): `image_picker: ^1.1.2`, `image: ^4.5.4`, `flutter_image_compress: ^2.4.0`. If `flutter pub add` produces materially different (major-version) versions, STOP and re-evaluate R-22 before proceeding — a major-version bump may change the API surface T026 (watermark pipeline) and T031 (datasource) depend on.

  **Step 3 — Re-sort the dependencies block** (only if the existing file is alphabetized) so the three new entries land in their alphabetical positions: `flutter_image_compress` between `flutter_*` entries; `image` between `i*` entries; `image_picker` after `image`. If the file is NOT alphabetized, leave `flutter pub add`'s default placement (typically appended to the end).

  **Step 4 — Add the watermark asset directory** to the existing `flutter.assets:` list. Open `pubspec.yaml`, find `flutter:` → `assets:`, and APPEND a new entry `- assets/images/watermark/`. Match the indentation of existing entries (typically 4 spaces for the `-` + 1 space + path). If the file uses individual file paths (not directories), use `- assets/images/watermark/logo_watermark.png` instead.

  **Step 5 — Regenerate lock + verify**: Run `flutter pub get` from `H:\alnujom-project` and confirm the lock regenerates without errors. Capture the diff: `git diff pubspec.lock | wc -l` — total new lines bounded per R-37 to ≤ 100 lines (~12 transitive entries × ~8 lines each). If the diff is significantly larger, inspect for unexpected transitive deps (especially iOS-only packages — STOP if any iOS-only or web-only plugin is added; verify via `grep "platform" pubspec.lock` for the new entries).

  **Step 6 — Commit**: `git add pubspec.yaml pubspec.lock && git commit -m "feat(011): pubspec — image_picker + image + flutter_image_compress (R-22)"`. Do NOT push yet — checkpoint C does the combined push.

### Watermark asset (R-23, R-33)

- [ ] T021 Create the watermark asset file at `H:\alnujom-project\assets\images\watermark\logo_watermark.png`. **HARD GATE — DO NOT PROCEED WITH A PLACEHOLDER.** Procedure (execute in this exact order):

  **Step 1 — Probe**: Check whether the design team supplied an asset. From `H:\alnujom-project` run:
  ```
  ls docs/design/assets/watermark/ 2>&1
  ls assets/branding/ 2>&1
  ls docs/design/exports/watermark*.png 2>&1
  ```
  If ANY of these returns a file (likely names: `logo_watermark.png`, `alnujom_watermark.png`, `watermark.png`, `alnujom-logo-watermark.png`), copy that file to `H:\alnujom-project\assets\images\watermark\logo_watermark.png` and SKIP to Step 4.

  **Step 2 — STOP and ask**: If Step 1's probes all return "No such file or directory" / not-found, the asset has NOT been supplied. STOP. Output to the user the literal message:
  ```
  PHASE 11 BLOCKED ON HUMAN HAND-OFF: T021 cannot proceed.
  The AlNujom watermark asset (PNG, ~512×128, alpha channel, AlNujom wordmark + icon)
  is required to land at: H:\alnujom-project\assets\images\watermark\logo_watermark.png
  AND its SVG source at:   H:\alnujom-project\docs\design\assets\watermark\logo_watermark.svg

  Per R-23 the watermark composites at bottom-end corner, 15% opacity, 18% of long edge.
  Per R-33 the pipeline fails closed if the asset is missing — Phase 11 cannot ship without it.

  Options:
  (a) Design team supplies the PNG + SVG → drop them at the paths above and resume T021.
  (b) Generate via the project's existing AlNujom logo at lib/core/assets/logo.png
      (if it exists) using a one-line ImageMagick script:
      magick lib/core/assets/logo.png -resize 512x128 -alpha set assets/images/watermark/logo_watermark.png
      AND export the SVG via Inkscape or a similar tool to docs/design/assets/watermark/.
  (c) DO NOT use any other placeholder. The pipeline fails closed.
  ```
  Wait for the human operator to drop the asset OR explicitly approve option (b). DO NOT proceed without one of these.

  **Step 3 — Verify the asset is NOT a placeholder**. Once an asset is in place, run a sanity check to confirm it's not an obvious placeholder:
  ```bash
  # File size — a real wordmark PNG with alpha is typically 5-50 KB; a 1x1 placeholder is ~100 bytes
  ls -l H:/alnujom-project/assets/images/watermark/logo_watermark.png
  # Expected: file size > 2048 bytes
  ```
  If the file size is < 2 KB, this is likely a placeholder. STOP per Step 2.

  **Step 4 — Verify the SVG source is present** at `H:\alnujom-project\docs\design\assets\watermark\logo_watermark.svg`. If missing, STOP per Step 2 option (b).

  **Step 5 — Commit both files**: `git add assets/images/watermark/logo_watermark.png docs/design/assets/watermark/logo_watermark.svg`. Do NOT commit until Step 3 passes.

  **Failure-mode reminder**: If you ship T021 with a 1x1 transparent placeholder or any non-brand image, every Phase 11 image upload composites that placeholder onto the publisher's photos — visible in production immediately. The fail-closed invariant in FR-014 catches a missing asset (the pipeline throws); it does NOT catch a present-but-wrong asset. Step 3's size check is the only programmable defense.

- [ ] T022 Verify the asset loads at runtime. Add a temporary one-shot debug check (delete after this task): in `lib/main.dart` or in a quick test page, instantiate `AssetImage('assets/images/watermark/logo_watermark.png')`, await its `resolve()`, and confirm the resulting `ui.Image` has `width > 0 && height > 0`. Run `flutter run --dart-define-from-file=.env.json` on the Infinix Note 8 (or emulator) once; confirm no asset-loading exception in the console. Remove the debug check; do NOT commit it.

### AndroidManifest permissions (Q5=A, FR-023, R-32)

- [ ] T023 Edit `H:\alnujom-project\android\app\src\main\AndroidManifest.xml` to add three `<uses-permission>` declarations BEFORE the `<application>` tag (the conventional location for permission declarations). The exact lines per `data-model.md § 11`:

  ```xml
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
  <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
  ```

  Do NOT add `CAMERA` permission (not in Phase 11 scope per FR-023). Do NOT remove or modify any existing permissions. Verify with `grep -E "READ_EXTERNAL_STORAGE|READ_MEDIA_IMAGES|READ_MEDIA_VIDEO" android/app/src/main/AndroidManifest.xml` → 3 hits (SC-026 part 1).

### Video file validator (FR-017)

- [ ] T024 [P] Author `H:\alnujom-project\lib\core\validators\video_file_validator.dart`. Per `contracts/video-file-validator.md § API` and `data-model.md § 9` for the two ARB error keys (`media.error.videoFormatMustBeMp4`, `media.error.videoSizeExceeded`). The file MUST export a class `VideoFileValidator` with one static method `static String? validate(XFile file, {required int sizeBytes})` returning `null` on success or the ARB key string on failure. Logic per the contract's rules table: (a) MIME type check — accept `video/mp4` OR (MIME is null AND filename ends `.mp4`); (b) size cap — `sizeBytes <= 31457280`. Imports: `package:image_picker/image_picker.dart` for `XFile` (added via R-22's pubspec deps). No `package:supabase_flutter`. No `package:flutter_image_compress`. Run `dart analyze lib/core/validators/video_file_validator.dart` and confirm 0 errors.

### Image-header reader (R-24)

- [ ] T025 [P] Author `H:\alnujom-project\lib\features\listing_form\presentation\util\image_header_reader.dart`. Per `data-model.md § 8.8` and `contracts/watermark-pipeline.md § R-24 header-reader contract`. The file MUST export: (1) class `ImageDimensions { final int width; final int height; ... }`; (2) enum `ImageFormat { jpeg, png, heic, webp, unsupported }`; (3) function `ImageFormat detectFormat(Uint8List bytes)` with the magic-byte detection logic from data-model.md § 8.8; (4) function `Future<ImageDimensions?> readImageDimensions(Uint8List bytes, ImageFormat format)` that returns dimensions WITHOUT decoding pixels. For JPEG: walk SOF0 marker. For PNG: read IHDR chunk at offset 16. For HEIC: use `flutter_image_compress` metadata API. For WebP: read VP8X chunk. Returns `null` on corrupt header. Imports: `package:flutter_image_compress/flutter_image_compress.dart` only for the HEIC path. No `package:supabase_flutter`. Constitution IX-clean.

### Watermark pipeline (FR-014, R-23)

- [ ] T026 Author `H:\alnujom-project\lib\features\listing_form\presentation\util\watermark_pipeline.dart`. Per `contracts/watermark-pipeline.md` and `data-model.md § 8.7`. The file MUST export a top-level pure function `Future<Uint8List> processImageForUpload({required Uint8List sourceBytes, required Uint8List watermarkAssetBytes, required bool isRtl})` implementing the seven FR-014 steps. Define custom exception classes at the top: `class UnsupportedFormatException implements Exception {}`, `class ImageTooLargeException implements Exception { final int width; final int height; ImageTooLargeException(this.width, this.height); }`, `class WatermarkAssetMissingException implements Exception {}`. Imports: `dart:typed_data`, `dart:ui` (NO — actually `package:image/image.dart` brings its own pixel type; avoid `dart:ui` since this runs on a background isolate); `package:image/image.dart as img`; `package:flutter_image_compress/flutter_image_compress.dart`; the project's `image_header_reader.dart`. **No `package:supabase_flutter`, no Flutter widgets** (pure Dart so it runs in the R-25 isolate worker).

  **Concrete implementation** (per U3 fix — copy this scaffold verbatim, fill in TODO blocks):

  ```dart
  import 'dart:typed_data';
  import 'package:image/image.dart' as img;
  import 'package:flutter_image_compress/flutter_image_compress.dart';
  import 'image_header_reader.dart';

  class UnsupportedFormatException implements Exception {}
  class ImageTooLargeException implements Exception {
    final int width; final int height;
    ImageTooLargeException(this.width, this.height);
  }
  class WatermarkAssetMissingException implements Exception {}

  Future<Uint8List> processImageForUpload({
    required Uint8List sourceBytes,
    required Uint8List watermarkAssetBytes,
    required bool isRtl,
  }) async {
    // (a) FORMAT DETECT — Q4 accept set
    final format = detectFormat(sourceBytes);
    if (format == ImageFormat.unsupported) {
      throw UnsupportedFormatException();
    }

    // (a-pre) Q6 HEADER DIMENSION CAP — reject pre-decode if > 8000×8000
    final dims = await readImageDimensions(sourceBytes, format);
    if (dims == null) throw UnsupportedFormatException(); // corrupt header
    if (dims.width > 8000 || dims.height > 8000) {
      throw ImageTooLargeException(dims.width, dims.height);
    }

    // (b) DECODE — pure-Dart for JPEG/PNG/WebP; native for HEIC
    img.Image? decoded;
    if (format == ImageFormat.heic) {
      // FlutterImageCompress decodes HEIC → JPEG bytes; then we re-decode via `image` package.
      final jpegBytes = await FlutterImageCompress.compressWithList(
        sourceBytes,
        format: CompressFormat.jpeg,
        quality: 100, // preserve quality at this stage — we re-encode later at 85
      );
      decoded = img.decodeJpg(jpegBytes);
    } else {
      decoded = img.decodeImage(sourceBytes); // handles JPEG, PNG, WebP
    }
    if (decoded == null) throw UnsupportedFormatException(); // decoder couldn't read it

    // PNG transparency → composite against white background per Q4=A's PNG handling
    if (format == ImageFormat.png && decoded.hasAlpha) {
      final flat = img.Image(width: decoded.width, height: decoded.height);
      img.fill(flat, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, decoded);
      decoded = flat;
    }

    // (c) EXIF ROTATION + STRIP — `bakeOrientation` applies the EXIF rotation to pixels and strips the EXIF block
    decoded = img.bakeOrientation(decoded);
    decoded.exif = img.ExifData(); // empty EXIF — strip GPS / camera-make / camera-model

    // (d) DOWNSCALE — long edge ≤ 1920 px
    final longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longEdge > 1920) {
      final scale = 1920.0 / longEdge;
      decoded = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // (e) WATERMARK COMPOSITE — R-23 params: bottom-end corner, 15% opacity, 18% of long edge, 24 px padding
    final watermark = img.decodePng(watermarkAssetBytes);
    if (watermark == null) throw WatermarkAssetMissingException();

    final finalLong = decoded.width > decoded.height ? decoded.width : decoded.height;
    final finalShort = decoded.width > decoded.height ? decoded.height : decoded.width;
    // R-23 aspect-ratio cap: min(18% of long edge, 50% of short edge)
    final wmTargetWidth = (0.18 * finalLong).round().clamp(1, (0.50 * finalShort).round());
    final wmScale = wmTargetWidth / watermark.width;
    final scaledWatermark = img.copyResize(
      watermark,
      width: wmTargetWidth,
      height: (watermark.height * wmScale).round(),
      interpolation: img.Interpolation.cubic,
    );

    // RTL-aware positioning: bottom-end means bottom-RIGHT in LTR, bottom-LEFT in RTL
    final padding = 24;
    final dstY = decoded.height - scaledWatermark.height - padding;
    final dstX = isRtl
      ? padding
      : decoded.width - scaledWatermark.width - padding;

    // Composite with 15% opacity — multiply the watermark's alpha channel by 0.15 before drawing
    img.compositeImage(
      decoded,
      scaledWatermark,
      dstX: dstX,
      dstY: dstY,
      blend: img.BlendMode.alpha,
      // The `image` package's compositeImage with BlendMode.alpha respects the source's alpha channel.
      // For 15% opacity, we pre-multiply the watermark's alpha:
    );
    // ↑ NOTE: the `image` package (v4.x) does NOT have a direct "opacity" parameter on compositeImage.
    // Pre-multiply approach: walk the scaled watermark and multiply each pixel's alpha by 0.15 before composite.
    // Insert this loop BEFORE the compositeImage call above:
    //   for (final pixel in scaledWatermark) {
    //     pixel.a = (pixel.a * 0.15).round().clamp(0, 255);
    //   }
    // Then call compositeImage(decoded, scaledWatermark, dstX: dstX, dstY: dstY).
    // Verify the resulting JPEG visually shows a ~15% opacity wordmark on a test image at quickstart Step 4.

    // (f) RE-ENCODE as JPEG quality 85
    final jpegOut = img.encodeJpg(decoded, quality: 85);

    // (g) Return bytes
    return Uint8List.fromList(jpegOut);
  }
  ```

  **Implementation note**: the `image` package's API evolves; if `compositeImage` signature differs between versions, consult the package's README at the version locked by `pubspec.lock` (per R-22). The pixel iteration to pre-multiply alpha is the most version-fragile part — if `image` v4.x exposes a direct opacity parameter on `compositeImage`, use that instead.

  **RTL parameter**: the caller (BLoC handler) passes `isRtl` based on `Directionality.of(context) == TextDirection.rtl` AT PICKER MOUNT TIME (the watermark position is set per upload session — not re-computed if the publisher switches locale mid-session). The BLoC's `MediaPicked` handler captures the value at event-handle time and passes it through to the isolate worker job.

  Re-run `dart analyze` after authoring and confirm 0 errors.

### Isolate worker (R-25)

- [ ] T027 Author `H:\alnujom-project\lib\features\listing_form\presentation\util\image_isolate_worker.dart`. Per `contracts/watermark-pipeline.md § R-25 isolate model` and `data-model.md § 8.5` / § 8.7. The file MUST export a class `ImageIsolateWorker` with: (a) `Future<void> start()` — spawns a single isolate via `Isolate.spawn(_workerEntry, sendPort)`; (b) `Future<Uint8List> processImage({required Uint8List sourceBytes, required Uint8List watermarkAssetBytes})` — sends the bytes via the spawned isolate's SendPort, awaits the result via a ReceivePort; (c) `void stop()` — terminates the isolate cleanly. The `_workerEntry` static method runs on the isolate side and calls `watermark_pipeline.processImageForUpload(...)` per received job; it returns the watermarked JPEG bytes OR an error code string. The worker processes jobs SEQUENTIALLY (one at a time) per R-25 to bound peak RAM. **Implementation note**: pass the watermark asset bytes per job (the isolate has no asset bundle access). Use `StreamQueue<_Job>` on the main side to bound the queue. The lifecycle: instantiated on MediaPicker mount, disposed on MediaPicker unmount. No `package:supabase_flutter`. Pure Dart.

### Pubspec sanity check + commit

- [ ] T028 Run `flutter analyze --no-fatal-infos --no-fatal-warnings` from `H:\alnujom-project`. Compare against the baseline in `baseline-pre-migration.txt § H`. Expected: zero NEW errors. The new utility files + validator should not introduce any analyzer errors.

**⚠️ Checkpoint C — Flutter foundational complete**: 3 pubspec packages added (image_picker, image, flutter_image_compress), watermark asset bundled, AndroidManifest permissions added, video validator authored, header reader + watermark pipeline + isolate worker authored. The MediaPicker widgets (Phase 4) now have all infrastructure to be authored. Commit: `git add pubspec.yaml pubspec.lock assets/ docs/design/ android/app/src/main/AndroidManifest.xml lib/core/validators/video_file_validator.dart lib/features/listing_form/presentation/util/ && git commit -m "feat(011): pubspec deps + watermark asset + AndroidManifest permissions + video validator + watermark pipeline foundation" && git push`.

---

## Phase 4: User Story 1 — Approved publisher uploads images, watermark applied, reorders, marks main, submits (Priority: P1) 🎯 MVP

**Goal**: An approved publisher walks through the seven-step form (Phase 10) and at step 6 uploads 4 images via the new MediaPicker. The watermark + downscale + upload pipeline runs on the background isolate; the publisher sees thumbnails appear, drags to reorder, sets one as main, advances to Review, and submits. The listing flips to `pending_review` with the Q1=A media-minimum check satisfied.

**Independent Test**: After Phase 3 + this phase, the publisher (with `publisher_status='approved' AND account_status='approved'`) can open the form on a draft listing, walk to step 6, upload 4 images, reorder + set-main, advance to Review, tap Submit. The database shows the listing at `status='pending_review'` with 4 rows in `public.listing_media` (`watermarked=true`, exactly 1 with `is_main=true`), bucket objects in `listing-images`, and the audit_logs row count matches per FR-021. Verified per `quickstart.md` Step 4.

### Data layer — Entity + DTO + Datasource

- [ ] T029 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_media.dart`. Per `data-model.md § 8.1`. A Dart class `ListingMedia extends Equatable` carrying the 10 fields (id, listingId, kind, storagePath, externalUrl, ordering, isMain, watermarked, createdAt, updatedAt). Per L1 fix, the `Equatable.props` getter MUST enumerate every field explicitly:

  ```dart
  @override
  List<Object?> get props => [
    id, listingId, kind, storagePath, externalUrl,
    ordering, isMain, watermarked, createdAt, updatedAt,
  ];
  ```

  Define enum `ListingMediaKind { image, video }` in the same file — note `external_link` is intentionally omitted from the Dart entity surface per Q2=D + data-model § 8.1. Each enum value has `String toDbValue()` returning the snake-case database string (`'image'`, `'video'`). `ListingMediaKind.fromDbValue(String)` accepts `'image'` / `'video'` / `'external_link'` defensively (admin direct SQL could insert external_link; the entity layer maps it gracefully — per data-model.md § 8.2 the DTO maps unknown values to `image` so the picker renders an error placeholder).

- [ ] T030 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\data\dtos\listing_media_dto.dart`. Per `data-model.md § 8.2`. The class `ListingMediaDto` mirrors the DB column shape (10 fields, all DB types). Provides `factory ListingMediaDto.fromJson(Map<String, dynamic>)` and `ListingMedia toEntity()`. The `kind` field deserializes from the DB string; unknown values map to `ListingMediaKind.image` per data-model § 8.2 (defensive — admin direct SQL could insert external_link rows that Phase 11's UI never produces).

- [ ] T031 [US1] Author `H:\alnujom-project\lib\features\listing_form\data\datasources\supabase_listing_media_datasource.dart`. Per `data-model.md § 8.3`. The abstract class `SupabaseListingMediaDatasource` exposes six methods: `loadForListing`, `uploadImage`, `uploadVideo`, `reorder`, `setMain`, `deleteMedia`. The concrete impl `SupabaseListingMediaDatasourceImpl` is annotated `@LazySingleton(as: SupabaseListingMediaDatasource)` (per A3 — matches Phase 10's `SupabaseListingsDatasourceImpl` annotation; verify the exact form by grepping `@LazySingleton` in `lib/features/listing_form/data/datasources/supabase_listings_datasource.dart`). The constructor takes one parameter `final SupabaseClient _client` — **inject the raw `SupabaseClient` directly from `supabase_flutter`, NOT Phase 1's wrapper at `lib/core/network/supabase_client.dart`** (per A2 — Phase 10's `SupabaseListingsDatasourceImpl` uses the raw client; verify via the same grep). The constructor parameter is typically resolved by `injectable` codegen via the existing `lib/core/di/modules/supabase_module.dart` factory (if your project has one; grep `@module` in `lib/core/di/`). **Method bodies**:

  **`uploadImage({required String listingId, required Uint8List watermarkedJpegBytes, required int ordering, required bool isMain})`** — returns `Future<ListingMediaDto>`:
  ```dart
  // 1. Compute storage path
  final randomSuffix = const Uuid().v4().substring(0, 8); // requires uuid package — already in pubspec via Phase 1
  final path = '$listingId/${ordering}_$randomSuffix.jpg';
  // 2. Upload bytes to bucket
  await _client.storage.from('listing-images').uploadBinary(
    path,
    watermarkedJpegBytes,
    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
  );
  // 3. Insert row — per U1 fix, enumerate ALL columns explicitly
  try {
    final row = await _client.from('listing_media').insert({
      'listing_id': listingId,
      'kind': 'image',
      'storage_path': path,
      'external_url': null,
      'ordering': ordering,
      'is_main': isMain,
      'watermarked': true, // ← FR-016: ALWAYS true for Phase 11 client uploads
    }).select().single();
    return ListingMediaDto.fromJson(row);
  } catch (e) {
    // 4. On INSERT failure (cap trigger, RLS deny, etc.), remove the orphaned bucket object
    try { await _client.storage.from('listing-images').remove([path]); } catch (_) { /* swallow cleanup failure */ }
    rethrow;
  }
  ```

  **`uploadVideo({required String listingId, required String filePath, required int ordering})`** — returns `Future<ListingMediaDto>`:
  ```dart
  final randomSuffix = const Uuid().v4().substring(0, 8);
  final path = '$listingId/${ordering}_$randomSuffix.mp4';
  await _client.storage.from('listing-videos').upload(
    path,
    File(filePath),
    fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
  );
  try {
    final row = await _client.from('listing_media').insert({
      'listing_id': listingId,
      'kind': 'video',
      'storage_path': path,
      'external_url': null,
      'ordering': ordering,
      'is_main': false, // ← FR-002 CHECK: video rows can never be main
      'watermarked': false, // ← videos are not watermarked in Phase 11
    }).select().single();
    return ListingMediaDto.fromJson(row);
  } catch (e) {
    try { await _client.storage.from('listing-videos').remove([path]); } catch (_) {}
    rethrow;
  }
  ```

  **`deleteMedia(String mediaId)`** — returns `Future<void>`. Per R-38 + L3 fix (handle BOTH the Storage-fail-before-SQL case AND the SQL-fail-after-Storage-succeeded case):
  ```dart
  // 1. Read row to get path + bucket
  final row = await _client.from('listing_media').select('storage_path, kind').eq('id', mediaId).maybeSingle();
  if (row == null) return; // already gone — idempotent
  final path = row['storage_path'] as String?;
  final bucket = row['kind'] == 'video' ? 'listing-videos' : 'listing-images';

  // 2. Remove bucket object (skip if null path — external_link rows have no object)
  if (path != null) {
    Object? lastStorageError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _client.storage.from(bucket).remove([path]);
        lastStorageError = null;
        break;
      } catch (e) {
        lastStorageError = e;
        if (attempt < 1) await Future.delayed(const Duration(seconds: 1));
      }
    }
    if (lastStorageError != null) {
      throw MediaDeleteException('Storage remove failed for $path: $lastStorageError');
    }
  }

  // 3. SQL DELETE — per L3 fix, retry up to 2× if storage already succeeded
  Object? lastSqlError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      await _client.from('listing_media').delete().eq('id', mediaId);
      lastSqlError = null;
      break;
    } catch (e) {
      lastSqlError = e;
      if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
    }
  }
  if (lastSqlError != null) {
    // Per L3 fix: bucket object is already gone; row is orphaned. Best-effort: surface a localized
    // "cleanup partial" message via the exception. The picker will reload from the server and the
    // orphaned row will reappear momentarily (since SQL DELETE failed), which is correct behavior —
    // the publisher can retry the delete.
    throw MediaDeleteException('Row delete failed after storage cleanup: $lastSqlError');
  }
  ```

  **`setMain({required String listingId, required String mediaId})`** — returns `Future<void>`. A two-row transactional UPDATE via PostgREST:
  ```dart
  // Flip target row to true; the partial unique index serializes — first attempt the target,
  // then unconditionally clear prior mains in a second statement
  await _client.from('listing_media')
    .update({'is_main': false})
    .eq('listing_id', listingId)
    .eq('is_main', true);
  await _client.from('listing_media')
    .update({'is_main': true})
    .eq('id', mediaId);
  ```
  (Note: PostgREST does not support multi-statement transactions from the SDK; the partial unique index acts as the serialization barrier — if a concurrent set-main fires between the two UPDATEs, one will fail with 23505 unique_violation; surface that as a retry.)

  **`reorder({required String listingId, required List<String> newOrderIds})`** — single transactional UPDATE re-sequencing `ordering`:
  ```dart
  // Use an .upsert with the ids' new ordering values
  final updates = newOrderIds.asMap().entries.map((e) => {'id': e.value, 'ordering': e.key + 1}).toList();
  await _client.from('listing_media').upsert(updates);
  ```

  **`loadForListing(String listingId)`** — returns `Future<List<ListingMediaDto>>`. Sort by `ordering ASC` (per M6 fix — sorting is the datasource's responsibility, not the use case):
  ```dart
  final rows = await _client.from('listing_media')
    .select()
    .eq('listing_id', listingId)
    .order('ordering', ascending: true);
  return (rows as List).map((r) => ListingMediaDto.fromJson(r as Map<String, dynamic>)).toList();
  ```

  **Imports**: `package:supabase_flutter/supabase_flutter.dart` for `SupabaseClient` + `FileOptions` + the storage SDK; `package:uuid/uuid.dart` (already in Phase 1 pubspec); `dart:io` for `File`; `dart:typed_data` for `Uint8List`; the project's `MediaDeleteException` (define at the top of this file as a simple `class MediaDeleteException implements Exception { final String message; MediaDeleteException(this.message); @override String toString() => 'MediaDeleteException: $message'; }`). This is the ONLY Phase 11 file importing `package:supabase_flutter` from the feature side (Constitution IX — SC-014 verifies).

### Repository layer

- [ ] T032 [US1] Edit `H:\alnujom-project\lib\features\listing_form\domain\repositories\listings_repository.dart` (existing Phase 10 file) to add six new abstract methods: `Future<List<ListingMedia>> loadMediaForListing(String listingId)`, `Future<ListingMedia> uploadImage({required String listingId, required Uint8List watermarkedBytes, required int ordering, required bool isMain})`, `Future<ListingMedia> uploadVideo({required String listingId, required String filePath, required int ordering})`, `Future<void> reorderMedia({required String listingId, required List<String> newOrderIds})`, `Future<void> setMainImage({required String listingId, required String mediaId})`, `Future<void> deleteMedia({required String mediaId})`. Add the necessary imports (`ListingMedia` entity, `Uint8List` from `dart:typed_data`). No `package:supabase_flutter` import.

- [ ] T033 [US1] Edit `H:\alnujom-project\lib\features\listing_form\data\repositories\listings_repository_impl.dart` (existing Phase 10 file) to add six new method implementations corresponding to T032's abstract methods. Each impl delegates to the new `SupabaseListingMediaDatasource` (injected as a constructor parameter — extend the existing constructor). The repo class converts datasource DTOs to entities via the DTO's `toEntity()` method.

### Domain use cases

- [ ] T034 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\upload_image.dart`. Per `data-model.md § 8.4`. Class `UploadImage` with constructor injecting `ListingsRepository`. Signature: `Future<ListingMedia> call({required String listingId, required Uint8List watermarkedBytes, required int ordering, required bool isMain}) => repository.uploadImage(...)`. **The watermark pipeline is invoked from the BLoC**, not from this use case — the use case sees only the post-pipeline JPEG bytes per FR-015 (atomic-from-publisher-perspective). The use case is thin.

- [ ] T035 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\upload_video.dart`. Per `data-model.md § 8.4`. Class `UploadVideo` with constructor injecting `ListingsRepository`. Signature: `Future<ListingMedia> call({required String listingId, required String filePath, required int ordering})`. **The `VideoFileValidator.validate()` from T024 is invoked at the BLoC layer**, not here — the use case sees only validated input.

- [ ] T036 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\reorder_media.dart`. Class `ReorderMedia` with `call({required String listingId, required List<String> newOrderIds}) => repository.reorderMedia(...)`.

- [ ] T037 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\set_main_image.dart`. Class `SetMainImage` with `call({required String listingId, required String mediaId}) => repository.setMainImage(...)`.

- [ ] T038 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\delete_media.dart`. Class `DeleteMedia` with `call({required String mediaId}) => repository.deleteMedia(...)`.

- [ ] T039 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\domain\usecases\load_media_for_listing.dart`. Class `LoadMediaForListing` with `call({required String listingId}) => repository.loadMediaForListing(...)`. Returns list sorted by `ordering ASC`.

### DI registration

- [ ] T040 [US1] Run `dart run build_runner build --delete-conflicting-outputs` from `H:\alnujom-project` to regenerate `lib/core/di/injection.config.dart`. The Phase 10 `@injectable` annotations on `SupabaseListingMediaDatasourceImpl`, `ListingsRepositoryImpl` (if it gained the new datasource constructor parameter — verify the annotation persists), and each of the six new use cases will be picked up. Verify codegen completes without errors. Run `flutter analyze` to confirm no DI-related errors.

### BLoC extension (R-40 — extend ListingFormBloc, do NOT create a new BLoC)

- [ ] T041 [US1] Edit `H:\alnujom-project\lib\features\listing_form\presentation\bloc\listing_form_event.dart` (Phase 10 file) to add five new event classes per `data-model.md § 8.5`: `MediaPicked(List<XFile> files)`, `VideoPicked(XFile file)`, `MediaReordered(List<String> newOrder)`, `MediaSetMain(String mediaId)`, `MediaDeleted(String mediaId)`. Each extends Phase 10's `ListingFormEvent` base (verify the base class name from the existing file). Add the `import 'package:image_picker/image_picker.dart' show XFile;` directive.

- [ ] T042 [US1] Edit `H:\alnujom-project\lib\features\listing_form\domain\entities\listing_form_state.dart` (Phase 10 file) to add two new fields per `data-model.md § 8.5`: `final List<ListingMedia> media` (default `const []`) and `final Map<String, MediaUploadProgress> uploadInFlight` (default `const {}`). Define `MediaUploadProgress` as a small sealed class in the same file: `sealed class MediaUploadProgress` with variants `MediaUploadProgressIdle`, `MediaUploadProgressProcessing`, `MediaUploadProgressUploading`, `MediaUploadProgressError(String? errorKey)`, `MediaUploadProgressCompleted`. Extend the existing `copyWith` and `props` to include the two new fields. Add the `ListingMedia` import.

- [ ] T043 [US1] Edit `H:\alnujom-project\lib\features\listing_form\presentation\bloc\listing_form_bloc.dart` (Phase 10 file) to add five new event handlers via `on<...>` registrations in the existing constructor. Verify the existing Phase 10 handlers are unchanged. Concrete code per A5 fix:

  **Step 1 — Register the five new handlers** inside the constructor (add these after Phase 10's existing `on<...>` registrations):

  ```dart
  on<MediaPicked>(_onMediaPicked);
  on<VideoPicked>(_onVideoPicked);
  on<MediaReordered>(_onMediaReordered);
  on<MediaSetMain>(_onMediaSetMain);
  on<MediaDeleted>(_onMediaDeleted);
  ```

  **Step 2 — Add the isolate-worker field** to the BLoC class:

  ```dart
  ImageIsolateWorker? _imageWorker;
  Uint8List? _watermarkAssetBytes; // lazily loaded on first MediaPicked
  ```

  Override `close()` to dispose: `_imageWorker?.stop(); return super.close();`.

  **Step 3 — Implement the central cap-trigger error mapper** (used by `_onMediaPicked` AND `_onVideoPicked`):

  ```dart
  String _mapMediaErrorToArbKey(Object error) {
    if (error is UnsupportedFormatException) return 'mediaErrorFormatNotSupported';
    if (error is ImageTooLargeException) return 'mediaErrorImageTooLarge';
    if (error is WatermarkAssetMissingException) return 'mediaErrorWatermarkAssetMissing';
    if (error is TimeoutException) return 'mediaErrorTimeout';
    if (error is MediaDeleteException) return 'mediaErrorUploadFailed';

    // PostgrestException — check for the cap-trigger error first
    if (error is PostgrestException) {
      if (error.message == 'listing_media.cap_exceeded') {
        // Parse the DETAIL JSONB payload to extract the kind (R-30)
        try {
          final detail = error.details;
          // detail can be a String (JSONB-as-text) or a Map (depends on supabase_flutter version)
          final detailMap = detail is String ? jsonDecode(detail) as Map<String, dynamic> : detail as Map<String, dynamic>;
          final kind = detailMap['kind'] as String?;
          if (kind == 'image') return 'mediaCapImages10';
          if (kind == 'video') return 'mediaCapVideos2';
        } catch (_) {
          // If parsing fails, fall through to generic message
        }
        return 'mediaErrorUploadFailed'; // fallback if kind can't be parsed
      }
      // RLS deny (42501) or other PostgrestException — generic upload-failed message
      return 'mediaErrorUploadFailed';
    }
    return 'mediaErrorUploadFailed';
  }
  ```

  Import `dart:convert` for `jsonDecode`, `dart:async` for `TimeoutException`, and `package:supabase_flutter/supabase_flutter.dart` for `PostgrestException`.

  **Step 4 — Implement `_onMediaPicked`** (per Q7=B + R-39 + R-25):

  ```dart
  Future<void> _onMediaPicked(MediaPicked event, Emitter<ListingFormState> emit) async {
    final listingId = state.listing?.id;
    if (listingId == null) return; // safety — should be impossible at step 6

    // Lazily start the isolate worker + load watermark asset bytes (run once per BLoC lifecycle)
    _imageWorker ??= await ImageIsolateWorker().also((w) => w.start());
    _watermarkAssetBytes ??= (await rootBundle.load('assets/images/watermark/logo_watermark.png')).buffer.asUint8List();
    final isRtl = state.locale == const Locale('ar'); // OR: pass isRtl in the event payload from the widget

    var nextOrdering = (state.media.map((m) => m.ordering).fold<int>(0, (a, b) => a > b ? a : b)) + 1;

    for (final file in event.files) {
      final localId = const Uuid().v4();
      emit(state.copyWith(uploadInFlight: {...state.uploadInFlight, localId: const MediaUploadProgressProcessing()}));

      try {
        final sourceBytes = await file.readAsBytes();

        // Run the FR-014 pipeline on the isolate worker, wrapped in Q7=B's 60s timeout
        final watermarkedJpeg = await _imageWorker!
          .processImage(sourceBytes: sourceBytes, watermarkAssetBytes: _watermarkAssetBytes!, isRtl: isRtl)
          .timeout(const Duration(seconds: 60));

        // Upload + INSERT via the use case
        final isMain = state.media.where((m) => m.kind == ListingMediaKind.image).isEmpty; // first image auto-main
        final inserted = await _uploadImage(
          listingId: listingId,
          watermarkedBytes: watermarkedJpeg,
          ordering: nextOrdering,
          isMain: isMain,
        );

        // Update state
        final newInFlight = {...state.uploadInFlight}..remove(localId);
        emit(state.copyWith(
          media: [...state.media, inserted],
          uploadInFlight: newInFlight,
        ));
        nextOrdering++;
      } catch (e) {
        final errorKey = _mapMediaErrorToArbKey(e);
        emit(state.copyWith(uploadInFlight: {...state.uploadInFlight, localId: MediaUploadProgressError(errorKey)}));
        // Continue processing the rest of the batch — one failure does not abort sibling images
      }
    }
  }
  ```

  **Step 5 — Implement `_onVideoPicked`**:

  ```dart
  Future<void> _onVideoPicked(VideoPicked event, Emitter<ListingFormState> emit) async {
    final listingId = state.listing?.id;
    if (listingId == null) return;

    final sizeBytes = await event.file.length();
    final l10n = AppLocalizationsHolder.current; // OR pass via event — match the project's existing pattern for accessing l10n from BLoC
    final validationError = VideoFileValidator.validate(event.file, sizeBytes: sizeBytes);
    if (validationError != null) {
      final localId = const Uuid().v4();
      emit(state.copyWith(uploadInFlight: {...state.uploadInFlight, localId: MediaUploadProgressError(validationError)}));
      return;
    }

    final localId = const Uuid().v4();
    emit(state.copyWith(uploadInFlight: {...state.uploadInFlight, localId: const MediaUploadProgressUploading()}));

    try {
      final nextOrdering = (state.media.map((m) => m.ordering).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final inserted = await _uploadVideo(listingId: listingId, filePath: event.file.path, ordering: nextOrdering)
        .timeout(const Duration(seconds: 60));
      final newInFlight = {...state.uploadInFlight}..remove(localId);
      emit(state.copyWith(media: [...state.media, inserted], uploadInFlight: newInFlight));
    } catch (e) {
      final errorKey = _mapMediaErrorToArbKey(e);
      emit(state.copyWith(uploadInFlight: {...state.uploadInFlight, localId: MediaUploadProgressError(errorKey)}));
    }
  }
  ```

  **Step 6 — Implement the three simpler handlers** (`_onMediaReordered`, `_onMediaSetMain`, `_onMediaDeleted`):

  ```dart
  Future<void> _onMediaReordered(MediaReordered event, Emitter<ListingFormState> emit) async {
    final listingId = state.listing?.id;
    if (listingId == null) return;
    try {
      await _reorderMedia(listingId: listingId, newOrder: event.newOrder);
      // Re-load media to reflect server-side ordering
      final reloaded = await _loadMediaForListing(listingId: listingId);
      emit(state.copyWith(media: reloaded));
    } catch (e) {
      // Leave existing state.media untouched on failure; surface a generic error toast via the widget layer
    }
  }

  Future<void> _onMediaSetMain(MediaSetMain event, Emitter<ListingFormState> emit) async {
    final listingId = state.listing?.id;
    if (listingId == null) return;
    try {
      await _setMainImage(listingId: listingId, mediaId: event.mediaId);
      final reloaded = await _loadMediaForListing(listingId: listingId);
      emit(state.copyWith(media: reloaded));
    } catch (_) {/* generic error */}
  }

  Future<void> _onMediaDeleted(MediaDeleted event, Emitter<ListingFormState> emit) async {
    try {
      await _deleteMedia(mediaId: event.mediaId);
      emit(state.copyWith(media: state.media.where((m) => m.id != event.mediaId).toList()));
    } catch (_) {
      // On failure, reload from server (the row may or may not actually be deleted depending on R-38 path)
      final listingId = state.listing?.id;
      if (listingId != null) {
        final reloaded = await _loadMediaForListing(listingId: listingId);
        emit(state.copyWith(media: reloaded));
      }
    }
  }
  ```

  All six use-case fields (`_uploadImage`, `_uploadVideo`, `_reorderMedia`, `_setMainImage`, `_deleteMedia`, `_loadMediaForListing`) are constructor-injected (extend the existing constructor parameter list + `final` declarations).

  **Step 7 — Run `flutter analyze`** and confirm 0 new errors. The Equatable extension (`also` in Step 4) may need a small helper extension if not already present; if so, replace `await ImageIsolateWorker().also((w) => w.start())` with an explicit `final w = ImageIsolateWorker(); await w.start(); return w;` pattern.

### Presentation widgets — replace placeholder with real picker

- [ ] T044 [US1] DELETE `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_media_placeholder.dart` AND replace its import + widget reference everywhere it's used. Procedure (per A4 fix):

  **Step 1 — Find every usage**:
  ```bash
  grep -rln "step_media_placeholder\|StepMediaPlaceholder" H:/alnujom-project/lib/features/listing_form/
  ```
  Expected hits: the placeholder file itself + 1–2 caller files (the step router OR the form page that switches by `currentStep`). Record each caller's path.

  **Step 2 — In each caller file**, perform two replacements:
  - Replace the import line `import '../widgets/step_media_placeholder.dart';` (or wherever Phase 10 placed it) with `import 'step_media.dart';` (or the equivalent relative path to T045's new file).
  - Replace every reference to the class name `StepMediaPlaceholder` (likely used as `const StepMediaPlaceholder()` or `StepMediaPlaceholder()` inside a step-switch block) with `const StepMedia()` (or `StepMedia()` — match the existing const-ness pattern).

  **Step 3 — Delete the placeholder file**: `git rm lib/features/listing_form/presentation/widgets/step_media_placeholder.dart`.

  **Step 4 — Verify zero hits remain**:
  ```bash
  grep -R "step_media_placeholder\|StepMediaPlaceholder" H:/alnujom-project/lib/
  ```
  Expected: 0 hits.

  **Step 5 — Run `flutter analyze`** — confirm 0 new errors. If the analyzer reports unresolved imports OR unresolved class references, re-run Step 1 to find any missed usages.

- [ ] T045 [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\step_media.dart`. Per `contracts/media-picker-pages.md`. The widget tree per the contract's tree diagram: top-level `StatelessWidget` containing a `BlocBuilder<ListingFormBloc, ListingFormState>` that yields a `Column` with: (a) the read-only banner (rendered via `Visibility(visible: state.listing.status NOT IN draft|rejected)` — when shown, displays `AppLocalizations.of(context)!.mediaReadOnlyPendingOrApproved`); (b) the upload-affordance row — two `ElevatedButton` widgets ("Add images" + "Add video") wired to fire `MediaPicked` / `VideoPicked` events via `BlocProvider.of<ListingFormBloc>(context).add(...)`. Each button calls `ImagePicker().pickMultiImage()` or `.pickVideo(source: ImageSource.gallery)` respectively (per R-32 the plugin handles version-aware permissions internally); on the publisher denying gallery permission, the picker returns null and surface the localized `media.error.galleryPermissionDenied` with an `media.action.openSettings` CTA that fires an Android intent (see T046 below for the intent-channel implementation). The "Add images" button is disabled when `state.media.where((m) => m.kind == ListingMediaKind.image).length >= 10`; "Add video" disabled when `state.media.where((m) => m.kind == ListingMediaKind.video).length >= 2`; (c) the `MediaPicker` widget below. Use Phase 2 design tokens (FR-020) — Theme.of(context).colorScheme + AppSpacing. No inline hex.

- [ ] T046 [US1] Author the "Open settings" intent helper — concrete Kotlin + Dart code per U4 fix.

  **Step 1 — Locate the existing MainActivity**:
  ```bash
  grep -rl "class MainActivity" H:/alnujom-project/android/app/src/main/kotlin/
  ```
  Expected: one hit at a path like `android/app/src/main/kotlin/com/alnujom/realestate/MainActivity.kt` (the exact package depends on Phase 1's bundle id; capture the full path). Record the path as `<MAIN_ACTIVITY_PATH>`.

  **Step 2 — Check for an existing method channel**: `grep "MethodChannel\|setMethodCallHandler" <MAIN_ACTIVITY_PATH>`. If a channel already exists (likely for the emulator window-position hack per `project_android_emulator_window_offscreen.md`), REUSE its name + ADD a new method to its `setMethodCallHandler` block. Otherwise, create a new channel.

  **Step 3 — Edit `<MAIN_ACTIVITY_PATH>`** to add (or extend) the method channel. The file's content after the edit should look like this (existing imports and class declaration are usually present — only the imports + the override block change):

  ```kotlin
  package com.alnujom.realestate  // ← match the existing package declaration; do NOT change

  import android.content.Intent
  import android.net.Uri
  import android.provider.Settings
  import androidx.annotation.NonNull
  import io.flutter.embedding.android.FlutterActivity
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.MethodChannel

  class MainActivity : FlutterActivity() {
      private val ANDROID_SETTINGS_CHANNEL = "alnujom.app/android_settings"

      override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
          super.configureFlutterEngine(flutterEngine)
          MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ANDROID_SETTINGS_CHANNEL)
              .setMethodCallHandler { call, result ->
                  when (call.method) {
                      "openAppSettings" -> {
                          val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                              data = Uri.fromParts("package", packageName, null)
                              flags = Intent.FLAG_ACTIVITY_NEW_TASK
                          }
                          startActivity(intent)
                          result.success(null)
                      }
                      else -> result.notImplemented()
                  }
              }
      }
  }
  ```

  **Important** — if MainActivity already extends a different class or has other channel handlers, MERGE the `configureFlutterEngine` block additively rather than replacing it. The cheaper LLM MUST preserve any pre-existing channel logic; only ADD the `MethodChannel(... ANDROID_SETTINGS_CHANNEL ...).setMethodCallHandler { ... }` block.

  **Step 4 — Author the Dart-side wrapper** at `H:\alnujom-project\lib\features\listing_form\presentation\util\android_settings_channel.dart`:

  ```dart
  import 'package:flutter/services.dart';

  class AndroidSettingsChannel {
    static const _channel = MethodChannel('alnujom.app/android_settings');

    /// Fires the Android ACTION_APPLICATION_DETAILS_SETTINGS intent to deep-link
    /// to this app's settings page. Used when the publisher denies gallery permission
    /// (Q5=A flow). No-op on non-Android platforms (Phase 11 is Android-only per Constitution XI).
    static Future<void> openAppSettings() async {
      try {
        await _channel.invokeMethod<void>('openAppSettings');
      } on PlatformException {
        // Swallow — the deep-link is a convenience; the publisher can still navigate manually.
      }
    }
  }
  ```

  **Step 5 — Verify**: Run `flutter analyze` from `H:\alnujom-project` and confirm 0 new errors. Run `flutter run --dart-define-from-file=.env.json` on the Infinix Note 8; in the picker, tap "Add images" → deny the permission → tap "Open settings" CTA (added in T045's denied-state handler) → confirm Android Settings opens at the app's permission page. (Full verification happens in T086 against the Pixel 8 Pro emulator; this step is just a smoke test that the channel wires correctly.)

- [ ] T047 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\media_picker.dart`. Per `contracts/media-picker-pages.md`. A `StatefulWidget` (for drag-reorder gesture state) rendering a `ReorderableGridView.builder` (use `package:reorderable_grid_view` if it's already in pubspec; otherwise use the built-in `ReorderableListView` with a custom 3-column wrap). The grid is 3-column on the Infinix Note 8 portrait screen (6.78"). Per-tile widget is `MediaThumbnail` (T048). On reorder gesture commit, fire `MediaReordered` with the new id sequence. Read media from `BlocSelector<ListingFormBloc, ListingFormState, List<ListingMedia>>` to avoid widget rebuilds when `uploadInFlight` changes.

- [ ] T048 [P] [US1] Author `H:\alnujom-project\lib\features\listing_form\presentation\widgets\media_thumbnail.dart`. Per `contracts/media-picker-pages.md`. A `StatelessWidget` rendering: (a) the image preview — for `kind=image`, use `Image.memory(localBytes)` if the thumbnail just uploaded (state.uploadInFlight has the bytes cached) OR `Image.network(getPublicUrl(storagePath))` for re-mount sessions per R-29 — fall back to `CachedNetworkImage` if the project's existing image-loading convention uses it; for `kind=video`, render a `Container` with a `play_arrow` icon overlay on a neutral background (Phase 11 does NOT generate frame thumbnails per FR-013); (b) "main" badge top-end-corner (FloatingActionButton-style chip) when `media.isMain == true` — only for image rows; (c) ordering badge top-start-corner showing `media.ordering` as a 1-based index; (d) progress overlay — when `state.uploadInFlight[media.id] is MediaUploadProgressProcessing` or `MediaUploadProgressUploading`, show a `CircularProgressIndicator`; when `MediaUploadProgressError`, show error icon + localized message + Retry button (Retry re-fires the original `MediaPicked` event for that file); (e) `GestureDetector` with `onLongPress` opening a `BottomSheet` action sheet with three actions: "Set as main" (hidden when `kind=video` per FR-013), "Delete" with a confirmation dialog, and a reorder hint. Wire actions to fire `MediaSetMain` / `MediaDeleted` events. Use Phase 2 design tokens; no inline hex, no inline EdgeInsets.only.

### Wire the step into the router (no new go_router routes per plan)

- [ ] T049 [US1] Verify that `lib/features/listing_form/presentation/pages/listing_form_page.dart` (Phase 10 file) routes step 6 (media) to `step_media.dart`. If Phase 10's step-router (likely a `switch (state.currentStep)` inside the page) references `step_media_placeholder.dart`, update the import + the widget reference to `step_media.dart`. Run `flutter analyze`; expected: 0 new errors. Run `flutter run --dart-define-from-file=.env.json` on the Infinix Note 8; navigate to step 6 of an existing draft listing; confirm `step_media.dart` renders with the "Add images" + "Add video" CTAs visible.

### ARB keys (subset for US1)

- [ ] T050 [US1] Add the US1-relevant ARB keys to BOTH `H:\alnujom-project\lib\l10n\app_ar.arb` and `H:\alnujom-project\lib\l10n\app_en.arb`. Per `data-model.md § 9` — the keys needed for US1's happy path: `media.addImages`, `media.addVideo`, `media.action.setMain`, `media.action.delete`, `media.action.reorderHint`, `media.thumbnail.mainBadge`, `media.error.galleryPermissionDenied`, `media.action.openSettings`, `media.error.uploadFailed`, `media.readOnly.pendingOrApproved`. (The other ~10 keys land in T067 / Polish — added per US they support.) Both files updated in the same commit. Wrap each entry in the existing `"@key": { "description": "..." }` metadata block per Phase 3 conventions. Arabic copy per data-model § 9 draft column (Syrian-friendly; reviewed at PR time).

- [ ] T051 [US1] Regenerate localization classes. Run `flutter pub run intl_utils:generate` OR `flutter gen-l10n` (whichever Phase 3 uses — check `pubspec.yaml`). Confirm `lib/l10n/app_localizations.dart` regenerates with the new getter methods.

### Manual happy-path verification on Infinix Note 8

- [ ] T052 [US1] On the Infinix Note 8 — run the Step 4 walk from `quickstart.md`. Sign in as the approved publisher. Open the form on an existing Phase 10 draft listing (or create a fresh one). Advance to step 6. Tap "Add images" — on first invocation, accept the `READ_EXTERNAL_STORAGE` permission dialog. Pick 4 images from a prepared gallery (mix JPEG + at least one HEIC if available + at least one PNG); wait for processing. Confirm each thumbnail renders with the watermark visible. Drag thumbnail 3 to position 1. Long-press the new position-3 thumbnail; tap "Set as main". Long-press position 4; tap "Delete"; confirm. Advance to step 7 (Review); confirm the carousel shows 3 watermarked thumbnails with the main one highlighted. Tap Submit. Confirm the listing flips to `pending_review` per Phase 10 US1's success toast. From desktop via Supabase MCP `execute_sql`: `SELECT count(*), max(ordering), bool_or(is_main) FROM public.listing_media WHERE listing_id='<id>'` → (3, 3, true). Download one bucket object via `mcp__supabase__execute_sql` `SELECT name FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<listing_id>/%' LIMIT 1` then via the Supabase Storage REST endpoint; open the JPEG; confirm: (a) long edge = 1920 px (SC-002), (b) watermark visible at bottom-end corner ~15% opacity (SC-003), (c) `exiftool` reports zero GPS / camera-make / camera-model fields (SC-024). Record the SC-001 stopwatch baseline.

**⚠️ Checkpoint D — US1 complete (MVP)**: An approved publisher can upload images, see watermarks, reorder, set main, delete, submit. Bucket objects exist + audit logs emit. SC-001..SC-005 + SC-024 verified. Commit: `git add lib/ android/app/src/main/kotlin/ && git commit -m "feat(011): US1 — MediaPicker + watermark pipeline + Supabase storage integration (MVP)" && git push`.

---

## Phase 5: User Story 2 — 10-image / 2-video cap enforced client + server (Priority: P1)

**Goal**: Confirm the cap trigger fires at both layers (UX disable + DB trigger). No new code typically — the cap logic was wired in T045 (UX disable) and T007 (DB trigger). This phase is verification only.

**Independent Test**: Upload 10 images successfully; confirm the "Add images" CTA disables. Attempt 11th upload via direct SQL with Pattern A (owner JWT); expect SQLSTATE P0001. Repeat for videos.

- [ ] T053 [US2] On the Infinix Note 8, run quickstart.md Step 5. Upload 10 images on a fresh draft (use the existing batch from T052 if the resulting listing has 3 — add 7 more to reach 10). Confirm the "Add images" CTA disables with the localized `media.cap.images10` label after the 10th commit. Confirm `SELECT count(*) FROM public.listing_media WHERE listing_id='<id>' AND kind='image'` returns 10.

- [ ] T054 [US2] Test the trigger bypass via Pattern A from the implementer briefing. Get the publisher's USER_UUID (e.g., from `SELECT user_id FROM public.profiles WHERE username='<test user>'`). Run via Supabase MCP `execute_sql`:

  ```sql
  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<USER_UUID>","role":"authenticated"}';
  INSERT INTO public.listing_media (listing_id, kind, storage_path, ordering, is_main, watermarked)
  VALUES ('<the 10-image listing id>', 'image', '<listing_id>/11_test.jpg', 11, false, true);
  -- Expected: ERROR P0001 with MESSAGE 'listing_media.cap_exceeded'; DETAIL JSONB {kind: 'image', current_count: 10, max: 10}
  ROLLBACK;
  ```

  Record the exact error message + DETAIL payload. SC-004 + R-30 verification.

- [ ] T055 [US2] Same as T054 but for videos. Upload 2 MP4 videos via the picker on the test draft (use any small MP4 files < 30 MB). Confirm "Add video" CTA disables with `media.cap.videos2` label. Attempt 3rd video direct SQL INSERT via Pattern A. Expected: ERROR P0001 with MESSAGE 'listing_media.cap_exceeded'; DETAIL JSONB `{kind: 'video', current_count: 2, max: 2}`. SC-005 verification.

- [ ] T056 [US2] Verify admin bypass also fails. Use Pattern A with an admin user's UUID (one who has `listings.edit_any` per the Phase 6 catalog). Attempt INSERT of an 11th image. Expected: same P0001 error — the cap is structural, not policy. SC-018 verification.

**⚠️ Checkpoint E — US2 verified**: Cap trigger fires at both layers; admins cannot bypass. Commit (if any fixups): `git add -A && git commit -m "test(011): US2 cap-trigger verification (manual quickstart Step 5)" && git push` — but typically no code change is needed; if so, skip the commit.

---

## Phase 6: User Story 3 — Resubmit-after-rejection preserves existing media (Q3=A edit-in-place) (Priority: P1)

**Goal**: A publisher whose listing was rejected reopens it via Phase 10's `MyListingsPage` "Resubmit" CTA. The MediaPicker at step 6 surfaces all existing watermarked thumbnails with stable UUIDs preserved (R-14 invariant). The publisher may delete / add / reorder / re-set-main; on re-Submit, the listing flips back to `pending_review`.

**Independent Test**: From a `rejected` listing with ≥ 3 existing `listing_media` rows, open Resubmit, advance to step 6 — confirm existing thumbnails render with preserved UUIDs (verified by SQL before/after the picker mount). Delete one, add a new one, re-submit. Confirm row UUIDs intact for the surviving rows.

- [ ] T057 [US3] Verify Phase 10's `MyListingsPage` Resubmit CTA wires to the form. Sign in as the publisher; navigate to MyListingsPage; tap the "Rejected" filter chip. If no rejected listing exists, create one via admin direct SQL: `UPDATE public.listings SET status='rejected' WHERE id='<a pending_review listing>'`. Tap the rejected card's Resubmit button; confirm the form opens pre-populated at step 1.

- [ ] T058 [US3] **Unconditionally extend the Phase 10 draft-load path to populate `state.media`** (per U6 fix — this fix is NOT conditional; Phase 10's load path predates the `listing_media` table and never queries it, so this edit is always required). Procedure:

  **Step 1 — Locate the Phase 10 load handler**:
  ```bash
  grep -nE "_onLoadOrCreateDraftRequested\|_onLoadOrCreateDraft\|LoadOrCreateDraft" H:/alnujom-project/lib/features/listing_form/presentation/bloc/listing_form_bloc.dart
  ```
  Expected: hits on the BLoC's load-handler method name. Also check the edit-mode load handler (Phase 10's spec 010 DEFERRED.md noted that resubmit-mode load was a Phase 10 bug fix — there's a separate handler for `event.listingId != null`).

  **Step 2 — Edit the BLoC**: Inside both the draft-load handler AND the edit-mode load handler (whichever currently exists in Phase 10's file), add a call to `LoadMediaForListing.call(listingId: <the loaded listing's id>)` AFTER the existing listing/details/prices/visibility load calls. Merge the result into the emitted state via `state.copyWith(media: <result>)`. Concrete pattern (adapt to the existing handler's variable names):

  ```dart
  // INSIDE the existing _onLoadOrCreateDraftRequested / _onLoadDraftForEdit handler,
  // after the existing listing+details+prices+visibility loads have populated state:
  final media = await _loadMediaForListing(listingId: listing.id);
  emit(state.copyWith(
    /* existing fields */,
    media: media, // ← NEW Phase 11 field per T042
    uploadInFlight: const {}, // ← reset progress map on a fresh load
  ));
  ```

  The `_loadMediaForListing` field is a constructor-injected `LoadMediaForListing` use case (from T039). Add it to the BLoC's constructor parameter list + `final` field declaration. The DI codegen (T040) handles wiring.

  **Step 3 — Verify on the rejected listing**: Sign in as the publisher; open the rejected listing from `MyListingsPage`; tap Resubmit; advance to step 6 (Media). The picker MUST render the existing `listing_media` rows as thumbnails with watermark + ordering + is_main preserved (per Q3=A FR-011). If the picker is empty when existing rows are in the database, the BLoC edit from Step 2 did not take effect — re-check the handler that's actually triggered on edit-mode entry (verify with a one-shot `debugPrint('media count: ${state.media.length}');` inside step_media.dart's `BlocBuilder.builder`; remove after verifying).

  **Step 4 — Verify Phase 10's existing fresh-create path is not broken**: Create a fresh draft (no existing media); confirm `state.media` is `[]` (empty list, not null) and the picker renders the empty state. The `media` field MUST default to `const []` per T042's state extension.

- [ ] T059 [US3] Verify the R-14 stable-UUID invariant. From desktop via Supabase MCP `execute_sql`: `SELECT id, created_at, ordering, is_main, storage_path FROM public.listing_media WHERE listing_id='<rejected id>' ORDER BY ordering ASC` — capture BEFORE entering step 6. After entering step 6 (which calls `LoadMediaForListing`), re-run the same query — confirm row UUIDs, created_at, ordering, and storage_path are IDENTICAL (no DELETE+INSERT churn). SC-020 verification.

- [ ] T060 [US3] Delete one image via the picker (long-press → Delete → confirm). Confirm the row + bucket object are removed (SQL count drops by 1). Add one new image via "Add images". Confirm the new row has a fresh UUID and `ordering` higher than the max existing ordering.

- [ ] T061 [US3] Submit (advance to step 7, tap Submit). Confirm the listing flips to `pending_review`. From SQL: `SELECT previous_status, new_status, changed_at, reason FROM public.listing_status_history WHERE listing_id='<id>' ORDER BY changed_at ASC` — confirm the chain `(NULL→draft, draft→pending_review, pending_review→rejected, rejected→pending_review)` per Phase 10 US3.

- [ ] T062 [US3] Edge case verification: re-enter the resubmit form, delete ALL images down to zero, advance to Review, tap Submit. Confirm the RPC returns HTTP 400 with `missing_fields[]` containing `listing_media.images_below_minimum` per FR-022. The Q3=A path correctly flows through the Q1=A check at submit. SC-017 + spec US3 acceptance scenario 4 verification.

**⚠️ Checkpoint F — US3 verified**: Resubmit preserves media in-place; Q1=A media check runs against post-edit state; row UUIDs preserved. Commit if any fixes were needed: `git add lib/ && git commit -m "fix(011): wire LoadMediaForListing into draft-load path for Q3=A resubmit (US3)" && git push`.

---

## Phase 7: User Story 4 — Background isolate keeps UI responsive (Priority: P1)

**Goal**: Confirm the R-25 isolate worker model keeps the picker grid scrollable at ≥ 30 fps during an 8-image batch upload on the Helio G80.

**Independent Test**: Pick 8 high-resolution images simultaneously (each ≥ 4000×3000 px ≈ 5 MB JPEG); scroll the picker grid up/down; confirm 30 fps maintained; confirm sequential commits (first picked image's row INSERTs first).

- [ ] T063 [US4] Prepare a gallery folder on the Infinix Note 8 with 8 JPEG photos at ≥ 4000×3000 px. (`adb push test_*.jpg /sdcard/DCIM/Camera/` from desktop if the device has no large source images.) Sign in; open a fresh draft; advance to step 6.

- [ ] T064 [US4] Enable Flutter's frame-time overlay via `MaterialApp(debugShowCheckedModeBanner: false, showPerformanceOverlay: true)` (temporarily, for this verification only — revert after). OR launch with `flutter run --dart-define-from-file=.env.json --profile` to capture frame timings.

- [ ] T065 [US4] Tap "Add images"; select all 8 at once. Confirm each thumbnail appears in the picker grid IMMEDIATELY (placeholder/progress spinner). While the pipeline runs in the background, SCROLL the picker grid up and down. Confirm the scroll remains smooth — frame-time overlay should stay green (≥ 30 fps target). SC-011 verification. Confirm each thumbnail's progress spinner is replaced by the watermarked thumbnail as its row commits (sequential commits — first picked → first commits per R-25 sequential queue).

- [ ] T066 [US4] Record the wall-clock time for the full 8-image batch. Expected per US4 independent test: ≤ 45 seconds on the Infinix Note 8. If significantly slower, profile the isolate worker — common culprits: (a) the isolate spawning per-image instead of staying alive (verify `ImageIsolateWorker.start()` is called once on MediaPicker mount); (b) the watermark composite using inefficient pixel iteration (the `image` package has SIMD paths; verify `compositeImage()` is used); (c) the JPEG re-encode at too-high quality (verify quality 85). Record the actual time in DEFERRED.md.

- [ ] T067 [US4] Remove the frame-time overlay debug code from `MaterialApp`. Do NOT commit the overlay.

**⚠️ Checkpoint G — US4 verified**: Background isolate keeps UI responsive; sequential commits work; 8-image batch ≤ 45s. No code commits typically unless profiling required a fix.

---

## Phase 8: User Story 5 — Direct MP4 video upload (Priority: P2)

**Goal**: Confirm the publisher can upload an MP4 file ≤ 30 MB via the "Add video" CTA; the upload commits a `listing_media` row with `kind='video'`; the file_size_limit + allowed_mime_types reject malformed uploads.

**Independent Test**: Pick an MP4 ≤ 30 MB; expect row INSERT. Pick an MP4 > 30 MB; expect client validator reject. Pick a non-MP4 video file (e.g., MKV); expect validator reject.

- [ ] T068 [US5] On the Infinix Note 8, on a fresh draft, advance to step 6. Tap "Add video"; pick an MP4 file ≤ 30 MB. Confirm the upload commits a row. From SQL: `SELECT kind, storage_path, external_url, is_main FROM public.listing_media WHERE listing_id='<id>' AND kind='video'` — confirm `external_url IS NULL`, `storage_path` is the bucket path, `is_main=false`.

- [ ] T069 [US5] Pick a non-MP4 file (`.mkv` or `.mov`) — confirm the client validator (`VideoFileValidator` from T024) rejects with `media.error.videoFormatMustBeMp4`.

- [ ] T070 [US5] Pick an MP4 file > 30 MB — confirm the client validator rejects with `media.error.videoSizeExceeded`. As an additional verification, bypass the validator by attempting a direct upload via Supabase Storage REST endpoint (Pattern B in implementer briefing); confirm the bucket's `file_size_limit: 31457280` rejects with HTTP 413 Payload Too Large.

- [ ] T071 [US5] Attempt to set a video row as main via Pattern A:

  ```sql
  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<USER_UUID>","role":"authenticated"}';
  UPDATE public.listing_media SET is_main=true WHERE id='<video row id>';
  ROLLBACK;
  ```

  Expected: ERROR — the `listing_media_main_only_when_image_chk` CHECK constraint rejects. SC-023 verification.

- [ ] T072 [US5] Verify Q2=D — confirm the picker has NO "Add external link" CTA. From `H:\alnujom-project`, run (per A6 fix — `URL` removed from the grep to avoid false-positive matches on legitimate `getPublicUrl()` calls):

  ```bash
  grep -iE "external_link|externalLink|Add external link|addExternalLink|MediaExternalLinkAdded" lib/features/listing_form/presentation/widgets/step_media.dart
  ```

  Expected: 0 hits (FR-010). Also verify no `external_video_url_validator.dart` exists: `ls lib/core/validators/external_video_url_validator.dart` should return "No such file or directory". Also verify the BLoC event surface excludes the future-spec event: `grep -E "MediaExternalLinkAdded\|AddExternalLink" lib/features/listing_form/` should return 0 hits. SC-019 verification.

**⚠️ Checkpoint H — US5 verified**: Direct MP4 upload works; client + server reject oversized + non-MP4; no external_link UI surface. No code commits typically.

---

## Phase 9: User Story 6 — Storage RLS denies anon on non-approved listings (Priority: P2)

**Goal**: Confirm the 14 `storage.objects` policies + the 7 `listing_media` policies correctly gate access. Anon SELECT against draft listings' media → 403. After approval + within publish window → 200. After re-flip to rejected → 403 again.

**Independent Test**: Upload 1 image to a draft. Anon download of the path returns 403. Flip listing to approved via admin SQL. Anon download returns 200. Re-flip to rejected. Anon download returns 403.

- [ ] T073 [US6] On the test listing from T052 (currently in `pending_review` status), capture the storage path of one image: `SELECT storage_path FROM public.listing_media WHERE listing_id='<id>' AND kind='image' LIMIT 1`. Construct the public URL via `https://<PROJECT>.supabase.co/storage/v1/object/public/listing-images/<storage_path>`. From a desktop browser (anonymous — no Supabase Auth session), navigate to the URL. Expected: 403 / NoAccess (the listing is in `pending_review`, not `approved`). SC-008 verification.

- [ ] T074 [US6] Flip the listing to approved via Pattern A from the implementer briefing — or simply use `mcp__supabase__execute_sql` (service_role context — fine for UPDATE on listings since we're acting as admin):

  ```sql
  UPDATE public.listings SET status='approved', published_at=now() WHERE id='<id>';
  ```

  Retry the anonymous URL fetch. Expected: 200 + JPEG bytes. SC-025 verification — confirms storage RLS reads `listings.status` at request time, not at upload time.

- [ ] T075 [US6] Flip the listing back to rejected:

  ```sql
  UPDATE public.listings SET status='rejected', published_at=NULL WHERE id='<id>';
  ```

  Retry the anonymous URL fetch. Expected: 403 again. SC-025 second-direction verification.

- [ ] T076 [US6] Verify path-shape WITH CHECK enforcement (R-27). Attempt to upload a malformed path object via Pattern A:

  ```sql
  -- This is an SQL-level test using the storage.objects insert directly; the real Storage SDK call would already fail at the bucket level
  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<USER_UUID>","role":"authenticated"}';
  INSERT INTO storage.objects (bucket_id, name, owner)
  VALUES ('listing-images', 'no-uuid-prefix/test.jpg', '<USER_UUID>'::uuid);
  -- Expected: ERROR 42501 (path-shape WITH CHECK on owner_insert policy rejects)
  ROLLBACK;
  ```

  SC-009-adjacent verification.

- [ ] T077 [US6] Verify another non-admin authenticated user cannot read another publisher's draft objects (per I1 fix — placeholder names disambiguated as DRAFT_LISTING_UUID vs OTHER_USER_UUID; `<original publisher draft id>` was confusingly named — it's the LISTING's UUID because the bucket path is `<listing_id>/<filename>`). Use Pattern A with a different authenticated user's UUID:

  ```sql
  -- Find a different non-admin user (replace ORIGINAL_PUBLISHER_USER_UUID with the publisher who owns the draft listing):
  -- SELECT user_id FROM public.profiles WHERE user_id != '<ORIGINAL_PUBLISHER_USER_UUID>' AND account_status='approved' LIMIT 1;
  -- Save the returned UUID as <OTHER_USER_UUID>.

  BEGIN;
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" TO '{"sub":"<OTHER_USER_UUID>","role":"authenticated"}';
  SELECT count(*) FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<DRAFT_LISTING_UUID>/%';
  -- Expected: 0 rows (the parent draft listing's owner_select policy denies other authenticated users)
  ROLLBACK;
  ```

  Where `<DRAFT_LISTING_UUID>` is the LISTING id (not a publisher id) — the value used as the path prefix in the `listing-images` bucket.

**⚠️ Checkpoint I — US6 verified**: Storage RLS gates anon + non-owner correctly; path-shape enforcement works; status-flip immediately propagates.

---

## Phase 10: User Story 7 — Set-main / reorder / delete actions (Priority: P2)

**Goal**: Confirm the per-thumbnail actions on the picker grid work as specified. Already largely exercised in T052 (the US1 walk) but this phase formalizes the verification of each action's atomic effect (audit log emission + DB state).

**Independent Test**: On a draft with 5 images, drag thumbnail 3 to position 1; verify `ordering` re-sequenced. Set thumbnail 3 (new position) as main; verify `is_main` flipped on 2 rows. Delete thumbnail 4; verify row removed + bucket object removed + audit log emitted.

- [ ] T078 [US7] On a draft with 5 images (use the T052 listing + add 2 more), drag thumbnail 3 to position 1. Confirm grid reorders visually. SQL verify: `SELECT id, ordering FROM public.listing_media WHERE listing_id='<id>' AND kind='image' ORDER BY ordering ASC` — confirm the new order matches the visual order. Per C3 fix, also verify the per-row audit emission for the reorder: capture `SELECT count(*) FROM audit_logs WHERE action='listing_media.updated' AND target_id IN (SELECT id FROM listing_media WHERE listing_id='<id>')` BEFORE the reorder; perform the reorder; capture the count AGAIN. Expected delta = number of rows whose `ordering` changed (typically 3 when moving row 3 to position 1: row 3 → position 1, row 1 → position 2, row 2 → position 3 → all three rows emit an `audit_logs.updated` per FR-021). If the delta is only 1 (just the moved row, not the shifted rows), the reorder datasource impl in T031 is not re-sequencing all affected rows in a single transaction — STOP and revisit the `upsert(updates)` call in T031's `reorder` method.

- [ ] T079 [US7] Long-press the new position-3 thumbnail; tap "Set as main". Confirm main badge moves. SQL: `SELECT id, is_main FROM public.listing_media WHERE listing_id='<id>'` — confirm exactly one row has `is_main=true` and all others false. Audit: `SELECT count(*) FROM audit_logs WHERE action='listing_media.updated' AND target_id IN (SELECT id FROM listing_media WHERE listing_id='<id>')` — confirm the count increased by 2 (one for the new main, one for the prior main per FR-021 set-as-main two-row update).

- [ ] T080 [US7] Long-press position 4; tap "Delete"; confirm the confirmation dialog (localized "delete this image?" with destructive styling); tap Confirm. Visually confirm the thumbnail disappears (4 remain). SQL: `SELECT count(*) FROM public.listing_media WHERE listing_id='<id>'` → 4. Storage object check: `SELECT count(*) FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<id>/%'` → 4. Audit: `SELECT count(*) FROM audit_logs WHERE action='listing_media.deleted' AND target_id='<deleted row id>'` → 1.

- [ ] T081 [US7] On a video row (from T068), long-press; confirm the action sheet does NOT show "Set as main" (image-only per FR-013). Delete + Reorder actions remain. SC-023 verification.

- [ ] T082 [US7] Full audit-log emission completeness check per quickstart.md Step 13. From SQL:

  ```sql
  SELECT action, count(*) FROM audit_logs
  WHERE target_type = 'listing_media'
    AND target_id IN (SELECT id FROM listing_media WHERE listing_id='<test listing>')
  GROUP BY action;
  ```

  Expected per spec FR-021 + the manual session: counts of `listing_media.created`, `listing_media.updated`, `listing_media.deleted` should equal the number of insertions + 2×(set-main operations) + reorder UPDATE count + deletions. SC-006 verification.

**⚠️ Checkpoint J — US7 verified**: Set-main / reorder / delete all work; audit emission complete; image-only restriction on set-main holds.

---

## Phase 11: Polish & Cross-Cutting

**Purpose**: Final hardening pass before the spec ships.

### Remaining ARB keys

- [ ] T083 Add the remaining ~10 ARB keys to `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` (the ones not added in T050). Per `data-model.md § 9`: `media.cap.images10`, `media.cap.videos2`, `media.error.formatNotSupported`, `media.error.imageTooLarge`, `media.error.timeout`, `media.error.videoSizeExceeded`, `media.error.videoFormatMustBeMp4`, `media.error.watermarkAssetMissing`, `media.review.carouselLabel`, `submit.error.imagesBelowMinimum`. Both files updated in the same commit per Phase 3 localization gate. Regenerate AppLocalizations via `flutter gen-l10n` or `intl_utils`.

### Q5 = A Pixel 8 Pro emulator walk

- [ ] T084 Launch the Pixel 8 Pro emulator (Android 14, API 34). If window is off-screen, run the SetWindowPos PowerShell recipe from `docs/dev/android-emulator-windows.md` per `project_android_emulator_window_offscreen.md`. Sign in to the app as the approved publisher; navigate to step 6 of a fresh draft. Tap "Add images" for the FIRST time. Confirm the system dialog requests `READ_MEDIA_IMAGES` (NOT `READ_EXTERNAL_STORAGE`) — Android 14 uses the granular permission. Tap Allow. Confirm the gallery opens. Pick 1 image and verify it uploads.

- [ ] T085 On the same emulator, tap "Add video" for the FIRST time. If the granular `READ_MEDIA_VIDEO` permission was not requested in the prior step (some `image_picker` versions request both at once on first image pick), confirm the system dialog requests `READ_MEDIA_VIDEO` now. Pick a small MP4 and verify it uploads. SC-026 part 2 verification.

- [ ] T086 Verify the Settings-deep-link helper. Wipe app data on the emulator (Settings → Apps → AlNujom → Storage → Clear data). Sign in; tap "Add images"; this time tap Deny on the permission dialog. Confirm the picker surfaces the localized `media.error.galleryPermissionDenied` AND a `media.action.openSettings` CTA. Tap the CTA. Confirm Android Settings opens at the app's permission page (the `ACTION_APPLICATION_DETAILS_SETTINGS` intent fired from T046). Grant `Photos and videos` permission; return to the app; retry "Add images" — confirm the picker opens the gallery.

### Q6 = B + Q7 = B verifications

- [ ] T087 Q6=B verification per quickstart.md Step 10. Generate a 9000×9000 px test image on desktop: `magick -size 9000x9000 xc:red H:\Temp\test_9000x9000.jpg`. Push to the Infinix Note 8: `adb push H:\Temp\test_9000x9000.jpg /sdcard/Pictures/test_9000x9000.jpg`. Open the picker; pick the file. Confirm the picker rejects within < 1 second with `media.error.imageTooLarge`. Confirm no `listing_media` row inserted. SC-027 verification.

- [ ] T088 Q7=B verification per quickstart.md Step 11. On the Infinix Note 8, enable Developer Options → Network throttling to ~50 kbps (or use `adb shell tc qdisc add ...` to throttle outbound bandwidth). Pick a single 5 MB JPEG via the picker. Wait ~65 seconds — confirm the thumbnail switches to error state with `media.error.timeout` and a Retry button. SQL verify: `SELECT count(*) FROM public.listing_media WHERE listing_id='<id>'` before AND after — confirm identical (no row inserted per FR-015). Also confirm no orphaned bucket object: `SELECT count(*) FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<id>/<expected path prefix>'` — should be 0. Disable throttling; tap Retry; confirm pipeline restarts cleanly. SC-028 verification.

### Constitution gates

- [ ] T089 [P] Constitution IX grep audit (Supabase-free domain). Run from `H:\alnujom-project`: `grep -RE "package:supabase_flutter" lib/features/listing_form/presentation/widgets/{step_media,media_picker,media_thumbnail}.dart lib/features/listing_form/presentation/util/` — expected: 0 hits. If hits found, refactor the offending import into the data layer (likely the datasource). SC-014 verification.

- [ ] T090 [P] Constitution VI grep audit (design tokens). Run from `H:\alnujom-project`: `grep -RE "Color\(0xFF|EdgeInsets\.only\(left:|SizedBox\(height: [0-9]+|SizedBox\(width: [0-9]+" lib/features/listing_form/presentation/widgets/{step_media,media_picker,media_thumbnail}.dart`. Expected: 0 hits in widget code (EdgeInsetsDirectional and theme tokens are fine). Replace any hits with Phase 2 design-token primitives. SC-016 verification.

- [ ] T091 [P] Constitution V check (no hardcoded user-facing strings). Run from `H:\alnujom-project`: `grep -RE "Text\(['\"][a-zA-Zا-ي]" lib/features/listing_form/presentation/widgets/{step_media,media_picker,media_thumbnail}.dart`. Expected: 0 hits — all user-facing strings flow through `AppLocalizations.of(context)!`. SC-015 verification.

- [ ] T092 Verify R-05 invariant (log_audit unchanged). Run `git diff` against Phase 4's `log_audit` definition (in the Phase 4 migration body — find via `grep -l "log_audit" supabase/migrations/`). Expected: 0 edits to the function body. SC-013 verification.

- [ ] T093 Verify SC-019 / Q2=D — no external_link UI surface. Run `grep -RE "external_link|externalLink|Add external link" lib/features/listing_form/`. Expected: only references in the entity layer (data-model § 8.1 / § 8.2 defensive parse) — NO references in presentation widgets. Verify no `lib/core/validators/external_video_url_validator.dart` exists.

- [ ] T093a Verify FR-018 — Phase 10 validators unchanged (per C1 fix). Run `git diff main -- lib/core/validators/area_size_validator.dart lib/core/validators/price_validator.dart lib/core/validators/phone_validator.dart` from `H:\alnujom-project`. Expected: zero changes (Phase 11 adds `video_file_validator.dart` but does NOT touch the three Phase 10 validators). If any diff appears, STOP and revert the unrelated edits — Phase 11 may have accidentally refactored shared code while authoring T024.

- [ ] T094 Verify SC-022 / FR-009 — no new permission key. Run `git diff` against the Phase 6 permissions seed migration. Expected: 0 new rows in `public.permissions` from Phase 11.

### Analyzer parity

- [ ] T095 Final analyzer pass. From `H:\alnujom-project`: `flutter analyze --no-fatal-infos --no-fatal-warnings`. Diff against `baseline-pre-migration.txt § H`. Expected: zero NEW errors. Pre-existing infos/warnings from Phase 1–10 are fine. If new errors, fix before proceeding.

### Quickstart end-to-end

- [ ] T096 Run the full `H:\alnujom-project\specs\011-media-watermark\quickstart.md` recipe end-to-end as a final smoke test. Step 0 through Step 15. Tick each step's verification as it passes. If any step fails, STOP, fix the root cause, and re-run from that step. Record the actual SC-001 wall-clock time + any advisor warnings + any orphaned bucket objects in DEFERRED.md.

### DEFERRED.md authoring

- [ ] T097 Author `H:\alnujom-project\specs\011-media-watermark\DEFERRED.md` mirroring `specs/010-listing-creation/DEFERRED.md`'s structure. Include sections: **Resolved During Implementation**, **Accepted As-Is For Phase 11**, **Deferred**. Capture at minimum: (a) any bugs found during the quickstart walk + their fix commits; (b) the SC-001 stopwatch baseline + the SC-011 fps observation; (c) the Phase 23 forward-stated reconciliation job for orphaned bucket objects per R-28; (d) the future-spec external_link UI work per Q2=D; (e) the Pubspec.lock new transitive-entry count per R-37 — useful regression baseline; (f) any advisor warnings introduced + their justifications; (g) the absence of automated tests per `feedback_no_new_tests.md` (durable rule applies EIGHTH time across Phases 5–11); (h) the SC-026 dual-device requirement — note that the Pixel 8 Pro emulator walk is permission-focused, not a full E2E; the Infinix Note 8 walk is the canonical SC-001 timing reference.

### CLAUDE.md confirmation

- [ ] T098 Confirm `H:\alnujom-project\CLAUDE.md` between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers points to Phase 11. This was updated during `/speckit-plan` (end-of-plan output). Re-verify: open the file and confirm the first line of the speckit block reads `Active Spec Kit feature: \`011-media-watermark\` (Phase 11 — Listing Media Upload, Client-Side Watermark & Storage Policies)`. If it has drifted, restore from the plan-time output.

### Final commit + PR

- [ ] T099 Final commit + push. Run from `H:\alnujom-project`: `git status` — review changes. `git add -A`. `git commit -m "chore(011): polish — remaining ARB keys, dual-device walks, Constitution gate audits, DEFERRED.md"`. `git push`.

- [ ] T100 Open the PR. Run: `gh pr create --title "Phase 11 — Listing Media Upload, Client-Side Watermark & Storage Policies" --base main --head 011-media-watermark --body "$(cat <<'EOF'
## Summary

Phase 11 — publisher-side media upload pipeline + storage layer.

- 1 new table (public.listing_media) with cap trigger + audit trigger group + 7 RLS policies
- 2 new Supabase Storage buckets (listing-images JPEG-only + listing-videos MP4-only; public=true + RLS access filter per Q8=A)
- 14 new storage.objects RLS policies (6 per bucket × 2 buckets + path-shape WITH CHECK enforcement per R-27)
- 1 amended Phase 10 RPC (submit_listing gains Q1=A media-minimum check via CREATE OR REPLACE in a new migration; Phase 10 migration file remains immutable per R-35)
- Phase 4 log_audit() reused unchanged for the EIGHTH time (R-05 invariant)
- 3 new Flutter widgets under lib/features/listing_form/presentation/widgets/ (step_media, media_picker, media_thumbnail)
- 3 new utility files under lib/features/listing_form/presentation/util/ (watermark_pipeline, image_isolate_worker, image_header_reader)
- Phase 10's ListingFormBloc extended with 5 new events (R-40 — no new BLoC)
- Phase 10's ListingsRepository extended with 6 new methods
- 1 new datasource SupabaseListingMediaDatasource
- 1 new validator (video_file_validator.dart) under lib/core/validators/
- ~20 new ARB keys (form chrome, errors, badges, action labels)
- 3 new pubspec packages (image_picker, image, flutter_image_compress per R-22 — first deviation from Phase 10's R-03)
- AndroidManifest declares Q5=A version-aware permissions (READ_EXTERNAL_STORAGE maxSdkVersion=32 + READ_MEDIA_IMAGES + READ_MEDIA_VIDEO)
- Bundled watermark asset at assets/images/watermark/logo_watermark.png

Clarifications (Session 2026-05-22): Q1=A require ≥1 image at submit; Q2=D disable external_link UI in Phase 11; Q3=A edit-in-place + Add more on resubmit; Q4=A bucket stores JPEG only, picker accepts JPEG/PNG/HEIC/HEIF/WebP; Q5=A both legacy + granular Android permissions; Q6=B 8000×8000 px hard cap; Q7=B 60-second timeout per image; Q8=A public bucket + RLS access boundary.

## Test plan

- [x] 4 backend migrations applied via Supabase MCP apply_migration
- [x] get_advisors clean
- [x] All 29 SC verified per quickstart.md
- [x] Happy-path upload+reorder+set-main+delete on Infinix Note 8 (SC-001..SC-005, SC-024)
- [x] 10-image / 2-video caps enforce at both UX + DB-trigger layers; admins cannot bypass (SC-004, SC-005, SC-018)
- [x] Q3=A resubmit preserves row UUIDs (R-14 + SC-020)
- [x] Background isolate keeps UI ≥30 fps during 8-image batch (SC-011)
- [x] Q1=A media-minimum check rejects zero-image submits (SC-017)
- [x] Q5=A version-aware permissions: legacy path on Infinix Note 8 + granular path on Pixel 8 Pro emulator Android 14 (SC-026)
- [x] Q6=B pre-decode 8000×8000 reject (SC-027)
- [x] Q7=B 60-second timeout under throttled network (SC-028)
- [x] Q8=A public bucket + RLS — status-flip immediately propagates to anon read (SC-025, SC-029)
- [x] Phase 10 submit_listing migration unedited (R-35 + SC-017 indirect)
- [x] Constitution IX grep + Constitution VI design-token grep + Phase 3 l10n lint guard all clean
- [x] log_audit unchanged (R-05 EIGHTH-time invariant + SC-013)

Closes the Phase 10 forward-stated media-step placeholder; opens the consumer side for Phase 12 admin approval (will use listing_media via listings.view_all) + Phase 13 public gallery (will consume stable getPublicUrl URLs per R-29). Forward-stated dependencies for the external_link UI (Q2=D future-spec), Phase 23 orphaned-object reconciliation job (R-28), and Phase 15 pin-drop edit (Phase 10 R-07) are documented in CLAUDE.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"`. Confirm the PR URL is returned. Squash-merge per `feedback_git_workflow.md` once review passes.

**⚠️ Checkpoint K — Phase 11 shipped**: All 100 tasks complete. PR open and (eventually) squash-merged. DEFERRED.md flagged for future-spec follow-up.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1, T001–T005)**: No dependencies on prior phases.
- **Foundational Backend (Phase 2, T006–T019)**: Depends on Setup. BLOCKS all user stories.
- **Foundational Frontend (Phase 3, T020–T028)**: Depends on Setup but NOT on Phase 2's migrations (the foundational frontend work is package + asset + manifest + utility files, none of which touch the backend). MAY run in parallel with Phase 2 if two implementers are available.
- **US1 (Phase 4, T029–T052)**: Depends on Phase 2 (migrations applied) AND Phase 3 (pubspec + asset + utilities).
- **US2 (Phase 5, T053–T056)**: Depends on Phase 4 (the cap-trigger verification needs a populated listing AND working picker for the UX disable observation).
- **US3 (Phase 6, T057–T062)**: Depends on US1 (picker is the resubmit surface) and US4 (background isolate handles the resubmit-edit pipeline same as US1).
- **US4 (Phase 7, T063–T067)**: Depends on US1 (picker is the surface) — but the isolate worker (T027) was authored in Phase 3; this phase is verification only.
- **US5 (Phase 8, T068–T072)**: Depends on US1 (picker) + Phase 2 (caps trigger).
- **US6 (Phase 9, T073–T077)**: Depends on US1 (uploaded media to verify against) + Phase 2 (storage policies).
- **US7 (Phase 10, T078–T082)**: Depends on US1 (picker has the actions).
- **Polish (Phase 11, T083–T100)**: Depends on all user-story phases. T084–T088 are the dual-device + Q6/Q7 verifications.

### Parallel opportunities

- **Within Phase 2**: T008 (policy mirror) and T013 (policy mirror) can be authored in parallel after T007/T012 apply migrations. T017–T019 (docs) can be authored in parallel after migrations are applied.
- **Within Phase 3**: T024 (validator), T025 (header reader), T026 (watermark pipeline), T027 (isolate worker) can be authored largely in parallel (T026 depends on T025 — author T025 first; T027 depends on T026 — author T026 second; T024 is independent).
- **Within Phase 4 / US1**: All 6 use cases (T034–T039) can be authored in parallel after T029 (entity), T030 (DTO), T032 (repository abstract). The 3 widget files (T045, T047, T048) can be authored in parallel after T041–T043 (BLoC extension).
- **Within Polish**: T089/T090/T091 (the three Constitution grep audits) can run in parallel.

### Within each user story

- Entity + DTO first.
- Repository abstract + datasource, then use cases, then BLoC events, then state extension, then widget files, then DI regen.
- Manual verification last (always serial; one device, one human).

---

## Implementation Strategy

### MVP First (US1 + US2 + US3)

1. Phase 1 (Setup) → Phase 2 (Backend) → Phase 3 (Flutter foundational) → Phase 4 (US1 image upload happy path).
2. Demo: an approved publisher uploads 4 images, sees watermarks, sets main, submits.
3. Phase 5 (US2 cap verification) → Phase 6 (US3 resubmit) → Phase 7 (US4 isolate verification).
4. Demo: full publisher media-workflow including resubmit-after-rejection with stable UUIDs.

At this point the MVP is shippable; the remaining P2 stories (US5/US6/US7) are verifications that the trigger + RLS work correctly.

### Incremental delivery

- After Phase 4 (US1) → demo (image upload happy path only).
- After Phase 6 (US3) → demo (full publisher loop including resubmit).
- After Phase 10 (US7) → polish complete; ship.

### Parallel team strategy

If two engineers are available:

- Engineer A: Phase 2 backend migrations (T006–T019).
- Engineer B: Phase 3 Flutter foundational (T020–T028) — can begin immediately, NO dependency on Phase 2.
- Both converge at Phase 4 / US1. One picks up data layer (T029–T040); the other picks up BLoC + widgets (T041–T048).
- US3/US4 verification work can start as soon as US1's MVP is demoable.

---

## Notes

- Per `feedback_no_new_tests.md`: zero new automated tests. All verifications are manual SQL via Supabase MCP `execute_sql` or manual UI walks on the reference Infinix Note 8 + Pixel 8 Pro emulator (per R-34 + SC-026).
- Per `feedback_git_workflow.md`: commit + push after each ⚠️ Checkpoint marker. One PR per spec, opened at the end (T100). Squash-merge per the project convention.
- Per `project_dart_defines.md`: every `flutter run` MUST include `--dart-define-from-file=.env.json`.
- Per `project_supabase_mcp_apply_migration.md`: `apply_migration` does NOT dedupe by name — re-applying re-runs the SQL AND adds a duplicate tracker row. Migration bodies use idempotent constructs (`CREATE TABLE IF NOT EXISTS`, `DROP POLICY IF EXISTS`, `ON CONFLICT (id) DO UPDATE` for bucket creation, `CREATE OR REPLACE FUNCTION` for the RPC amendment). The Phase 10 `submit_listing` migration is IMMUTABLE per R-35 — never edit it; the amendment is a NEW migration file per T014.
- Per Phase 10 R-22 deviation: Phase 11 adds 3 pubspec packages. This is the first relaxation of Phase 10's R-03 zero-new-packages invariant; justified by Q4=A HEIC support requirement.
- Per Phase 4 R-05 invariant (EIGHTH time): Phase 11 attaches new audit triggers on `public.listing_media` without editing the `log_audit()` function body.
- When a task says "find at `<path>` if it exists; otherwise grep" — that is the canonical hedge for path uncertainty. Phase 10's exact file layout may have drifted; the grep is the authoritative lookup.
