---
description: "Task list for Phase 12 — Listing Approval Workflow"
---

# Tasks: Phase 12 — Listing Approval Workflow

**Input**: Design documents from `/specs/012-listing-approval/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md
**Tests**: NO new automated tests per `feedback_no_new_tests.md` durable rule. All verification is manual via Supabase MCP `execute_sql` + UI walks on the Infinix Note 8 (publisher device) + Pixel 8 Pro emulator (admin device).

**Organization**: Tasks grouped by user story (US1..US6) so each story can be implemented and verified independently. Each task is specific enough to execute without re-reading the design docs.

## Format: `[ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: Maps to user story in spec.md (US1, US2, US3, US4, US5, US6). Setup/Foundational/Polish phases carry no story label.
- Each task description includes the exact file path to edit/create.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Pre-flight checks + scaffold the new directory structures so all later parallel work has a stable home.

- [X] T001 Create new admin feature directory tree at `lib/features/admin/listing_review/` with `data/datasources/`, `data/dtos/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `domain/usecases/`, `presentation/bloc/`, `presentation/pages/`, `presentation/widgets/` subdirectories.
- [X] T002 Create new shared display widget directory `lib/shared/presentation/widgets/listing_display/` (will house the five Q8=A widgets per FR-011).
- [X] T003 [P] Re-verify R-45's Phase 6 permission seed audit against the LIVE remote project via Supabase MCP `execute_sql` (R-45 was a plan-time conclusion; this is a deploy-time re-confirmation). Run: `SELECT key FROM public.permissions WHERE key IN ('listings.approve','listings.reject')` AND `SELECT r.key AS role_key, p.key AS perm_key FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key IN ('listings.approve','listings.reject') AND r.key IN ('moderator','admin','super_admin')`. **Expected per R-45**: 2 permission rows + 6 role-mapping rows. If both queries match expected, T011 is a NO-OP and is OMITTED from the PR diff. If a gap is detected, execute T011.
- [X] T004 [P] Add 5 new `Failure` subtypes to `lib/core/errors/failure.dart` per data-model.md §3.5: `PermissionDeniedFailure`, `InvalidStatusTransitionFailure(currentStatus)`, `AlreadyActedOnFailure(currentStatus)`, `InvalidReasonPresetFailure`, `ReasonDetailTooLongFailure(max)`. Each is a sealed-class subtype of the existing `Failure` base.
- [X] T005 [P] Audit Phase 10 trigger source — read `supabase/migrations/20260519120006_create_listing_status_history.sql` and copy the body of `listing_status_transition_trigger_fn()` AND `listings_audit_trigger_fn()` verbatim into a scratch file `specs/012-listing-approval/.phase10-trigger-bodies.sql` (gitignored) for use during T009's migration drafting.
- [X] T006 [P] Audit Phase 4 `log_audit()` source — read `supabase/migrations/20260506120004_create_audit_logs.sql` and copy the function body verbatim into `specs/012-listing-approval/.phase4-log-audit-body.sql` (gitignored) for use during T009.

**Checkpoint**: All directories exist; permission audit result known; failure types ready; original Phase 4 + Phase 10 function bodies captured for the amendment migration.

---

## Phase 2: Foundational (Blocking Prerequisites for ALL user stories)

**Purpose**: Ship the FR-024 amendment migration + (conditional) seed migration. Without this, every approve/reject action will fail to attribute correctly to the admin (the trigger reads `auth.uid()` which is NULL under the service-role client), and the rejection reason will not persist.

**⚠️ CRITICAL**: User stories US1..US6 cannot be implemented until Phase 2 is complete.

- [X] T007 Create `supabase/migrations/20260523120004_amend_phase10_phase4_triggers_for_session_var.sql` containing FIVE `CREATE OR REPLACE FUNCTION` statements per data-model.md §1.1–§1.4: (1) `public.set_app_user_id_for_session(user_id UUID)` SECURITY DEFINER with `GRANT EXECUTE ... TO service_role`; (2) `public.set_app_rejection_reason_for_session(reason_json TEXT)` SECURITY DEFINER with `GRANT EXECUTE ... TO service_role`; (3) amended `public.listing_status_transition_trigger_fn()` with COALESCE on `changed_by` AND `nullif(current_setting('app.current_rejection_reason', true), '')` on `reason` (transcribe Phase 10 body from T005's scratch file); (4) amended `public.listings_audit_trigger_fn()` with COALESCE on every `auth.uid()` inside `INSERT INTO audit_logs` (transcribe Phase 10 body from T005); (5) amended `public.log_audit()` with COALESCE on `actor_user_id` (transcribe Phase 4 body from T006).
- [X] T008 Apply T007's migration via Supabase MCP `apply_migration(name="20260523120004_amend_phase10_phase4_triggers_for_session_var", query=<file body>)`. Per `project_supabase_mcp_apply_migration.md`, the migration name must be unique on the remote project.
- [X] T009 Verify migration applied via Supabase MCP `execute_sql` running the two verification queries from data-model.md §1.5: (a) `SELECT proname FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('set_app_user_id_for_session','set_app_rejection_reason_for_session','listing_status_transition_trigger_fn','listings_audit_trigger_fn','log_audit')` — expect 5 rows; (b) the COALESCE-presence check — expect all 3 amended triggers `has_coalesce=true`. Capture results for SC-005, SC-030, SC-031.
- [X] T010 Verify Phase 4 + Phase 10 original migration files UNEDITED via `git diff --stat -- supabase/migrations/20260506120004_create_audit_logs.sql supabase/migrations/20260519120006_create_listing_status_history.sql` returning zero lines (SC-031).
- [ ] T011 CONDITIONAL — if T003 revealed a gap, create AND apply `supabase/migrations/20260523120005_seed_listings_reject_permission_if_missing.sql` per plan.md §Storage: `INSERT INTO public.permissions (key, description_ar, description_en, category) VALUES ('listings.reject', 'رفض الإعلانات', 'Reject listings', 'listings') ON CONFLICT (key) DO NOTHING;` AND `INSERT INTO public.role_permissions (role_id, permission_id) SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p WHERE r.key IN ('moderator','admin','super_admin') AND p.key='listings.reject' ON CONFLICT DO NOTHING;`. Skip this task if R-45 audit passed (most likely path).
- [ ] T012 [P] Smoke-verify Phase 10 `submit_listing` still attributes correctly under the amended trigger — submit a fresh draft via the existing Phase 10 form on the Infinix Note 8 emulator, then `SELECT changed_by FROM public.listing_status_history WHERE listing_id=<the new id> AND new_status='pending_review'` via Supabase MCP `execute_sql`. Expect a non-NULL UUID matching the publisher (verifies the COALESCE's `auth.uid()` fallback works for direct-JWT callers; covers SC-030 regression side).
- [X] T013 [P] Update `supabase/docs/listings.md` — add a short section noting Phase 12's `approve_listing` is the only writer that flips `status` to `approved` AND that `expires_at` is left at the column default NULL per Q2=A.
- [X] T014 [P] Update `supabase/docs/listing_status_history.md` — note the Q4=A JSON-encoded `reason` storage shape `{"preset":"<key>","detail":"<string|null>"}` written by `reject_listing` via the amended trigger AND the session-variable handoff design.
- [X] T015 [P] Update `supabase/docs/audit_logs.md` — note the new action keys `listing.approved` + `listing.rejected` emitted by the amended `listings_audit_trigger_fn`, AND the narrow R-05 relaxation on `log_audit()` (byte-identical except for the actor-source COALESCE).
- [X] T016 [P] Create `lib/core/listing/rejection_reason.dart` (feature-neutral location per analysis finding C2 — both `admin/listing_review` AND `publisher_dashboard` consume this enum, so a cross-feature-shared domain primitive belongs under `lib/core/listing/`, not inside one feature's `domain/`). Contains the `RejectionReason` Dart enum with the six Q3=A preset keys per data-model.md §3.1: `missingOrLowQualityPhotos('missing_or_low_quality_photos')`, `incorrectLocation('incorrect_location')`, `unrealisticPrice('unrealistic_price')`, `incompleteDescription('incomplete_description')`, `duplicateListing('duplicate_listing')`, `other('other')`. Include the `fromKey(String)` static helper. NO `package:supabase_flutter` import (Constitution IX-clean).

**Checkpoint**: Backend migration applied + verified; Phase 10/4 immutability preserved; documentation updated; rejection-reason enum + failure types in place. User stories can now begin in parallel.

---

## Phase 3: User Story 1 — Admin reviews pending queue, opens preview, approves → public (Priority: P1) MVP

**Goal**: An admin holding `listings.approve` can open the pending queue, tap a listing, review its preview at full fidelity, and approve it. The approval flips `status` to `approved`, sets `published_at=now()`, leaves `expires_at=NULL`, writes one `listing_status_history` row, writes one `audit_logs` row, and the listing immediately becomes anonymous-readable.

**Independent Test**: Per spec.md US1 Independent Test — apply migration, sign in as admin, open admin home → Pending review tile → tap a queue card → preview → Approve → confirm. Verify via SQL that status='approved', published_at non-NULL, expires_at=NULL, one new listing_status_history + audit_logs row with admin's UID. From an anonymous client, confirm the listing AND its media are both visible.

### Backend — approve_listing Edge Function

- [X] T017 [US1] Create `supabase/functions/approve_listing/index.ts` per `contracts/phase12-approve-listing-edge-function.md`. Implements the 10-step call sequence from data-model.md §2.3: (1) parse body + validate `listing_id` UUID → HTTP 400 on failure; (2) extract `Authorization` header → JWT.sub; (3) JWT-bound client; (4) `current_user_has_permission('listings.approve')` → HTTP 403 on false; (5) service-role client; (6) `set_app_user_id_for_session(jwt.sub)`; (7) `UPDATE listings SET status='approved', published_at=now() WHERE id=$1 AND status='pending_review'` with `.maybeSingle()` returning `id,status,published_at,expires_at`; (8) zero-rows path → fetch current status → HTTP 409 (`invalid_status_transition` or `already_acted_on`); (9) return HTTP 200 `{status,published_at,expires_at}`. Use `@supabase/supabase-js@2` import. ~80 LOC TypeScript.
- [X] T018 [US1] Deploy `approve_listing` via Supabase MCP `deploy_edge_function(name="approve_listing", entrypoint_path="index.ts", import_map_path=null, source_files=[{name:"index.ts", content:<T017 body>}])`.
- [ ] T019 [US1] Smoke-test approve_listing happy path via `curl -X POST $SUPABASE_URL/functions/v1/approve_listing -H "Authorization: Bearer <admin JWT>" -H "Content-Type: application/json" -d '{"listing_id":"<a pending_review listing>"}'`. Expect HTTP 200 with `{status:"approved",published_at:<ISO>,expires_at:null}`. Capture the Edge Function logs' `duration_ms` for the SC-029 latency baseline.

### Frontend — domain layer (no UI yet)

- [X] T020 [P] [US1] Create `lib/features/admin/listing_review/domain/entities/pending_listing_summary.dart` with the fields per data-model.md §3.1: `id`, `title`, `mainImageStoragePath?`, `purpose`, `propertyType`, `governorateName`, `cityName`, `areaName`, `primaryPrice` (Phase 9 `Money`), `publisherDisplayName`, `submittedAt`.
- [X] T021 [P] [US1] Create `lib/features/admin/listing_review/domain/entities/listing_preview.dart` aggregate entity composing Phase 10 `Listing` + `ListingDetails`, Phase 9 `List<ListingPrice>`, Phase 11 `List<ListingMedia>`, Phase 8 `Governorate`+`City`+`Area`, Phase 5 `Publisher`.
- [X] T022 [P] [US1] Create `lib/features/admin/listing_review/domain/repositories/listing_review_repository.dart` abstract class with the four methods per data-model.md §3.3: `loadPendingQueue({cursor, limit})`, `loadListingPreview(listingId)`, `approveListing(listingId)`, `rejectListing(listingId, preset, detail)`. Include the supporting types `PendingQueueCursor(lastSubmittedAt, lastId)`, `ApproveResult(publishedAt, expiresAt)`, `RejectResult(preset, detail)`. **Must land before T023–T025** (use-case files import this abstract).
- [X] T023 [US1] Create `lib/features/admin/listing_review/domain/usecases/load_pending_queue.dart` — `@injectable class LoadPendingQueueUseCase` with `call({cursor, limit})` delegating to the repository. **Depends on T022.** Can run in parallel with T024 + T025 once T022 is committed.
- [X] T024 [US1] Create `lib/features/admin/listing_review/domain/usecases/load_listing_preview.dart` — `LoadListingPreviewUseCase` with `call(listingId)`. **Depends on T022.** Parallel with T023 + T025.
- [X] T025 [US1] Create `lib/features/admin/listing_review/domain/usecases/approve_listing.dart` — `ApproveListingUseCase` with `call(listingId)` returning `Future<Result<ApproveResult, Failure>>`. **Depends on T022.** Parallel with T023 + T024.

### Frontend — data layer

- [X] T026 [US1] Create `lib/features/admin/listing_review/data/dtos/pending_listing_summary_dto.dart` — mirrors the queue-join PostgREST SELECT shape from `contracts/phase12-admin-queue-page.md` (id, title, property_type, purpose, nested publisher/governorate/city/area, prices array, media array). Exposes `toEntity()` mapping. **`submittedAt` source locked per analysis finding C8**: use `listings.created_at` (indexed, no aggregate needed). Do NOT join `listing_status_history` for the cursor field in v1.
- [X] T027 [US1] Create `lib/features/admin/listing_review/data/datasources/supabase_listing_review_datasource.dart` exposing `loadPendingQueue(cursor, limit)`, `loadListingPreview(id)`, `approveListing(id)`. The queue method runs the PostgREST nested-select query from `contracts/phase12-admin-queue-page.md` ordering by `created_at ASC, id ASC` per C8's locked decision (drop the `listing_status_history` nested select from the queue query — only the preview path needs status history); the preview method joins listings + listing_details + listing_prices + listing_media + governorates/cities/areas + profiles; the approve method calls `Supabase.instance.client.functions.invoke('approve_listing', body: {'listing_id': id})` and maps the response (status code → Failure subtype if non-200) to `ApproveResult`. THIS IS THE ONLY FILE IN `lib/features/admin/listing_review/` THAT MAY IMPORT `package:supabase_flutter`.
- [X] T028 [US1] Create `lib/features/admin/listing_review/data/repositories/listing_review_repository_impl.dart` — concrete impl injecting the datasource, exposing the four abstract methods, mapping Edge Function HTTP error codes (`permission_denied`/`invalid_status_transition`/`already_acted_on`/`invalid_reason_preset`/`reason_detail_too_long`) to the matching `Failure` subtype added in T004 per R-52.

### Frontend — shared display widgets (Q8=A) — required by preview page

- [X] T029 [P] [US1] Create `lib/shared/presentation/widgets/listing_display/listing_gallery.dart` per `contracts/phase12-shared-display-widgets.md` §`ListingGallery`. Horizontal carousel ordered by `ordering ASC` with `is_main=true` first; each item 16:9 aspect; image items use `cached_network_image` against `supabase.storage.from('listing-images').getPublicUrl(storagePath)`; video/external-link items render a static play-button overlay on neutral background. Empty list → 16:9 placeholder card with localized "no media available" text. NO `package:supabase_flutter` import — accept `List<ListingMedia>` only.
- [X] T030 [P] [US1] Create `lib/shared/presentation/widgets/listing_display/listing_price_block.dart` per contract — `ListingPriceBlock({required prices, required displayCurrency})`. Renders primary price prominently via Phase 9 `MoneyFormatter`; if displayCurrency differs from publisher's stored currency, secondary line shows the original.
- [X] T031 [P] [US1] Create `lib/shared/presentation/widgets/listing_display/listing_location_block.dart` — `ListingLocationBlock({required governorate, required city, required area, addressText})`. Joins names with " / " (Phase 8 convention), RTL-aware, no map embed.
- [X] T032 [P] [US1] Create `lib/shared/presentation/widgets/listing_display/listing_amenities_block.dart` — `ListingAmenitiesBlock({required Map<String,dynamic> amenities})`. Renders only truthy keys as `Wrap` of Phase 2 chip-token chips.
- [X] T033 [P] [US1] Create `lib/shared/presentation/widgets/listing_display/listing_description_block.dart` — `ListingDescriptionBlock({required description})`. Multi-line text via `bodyLarge` token. Long descriptions truncate at ~10 lines with localized "Read more" affordance that expands inline.

### Frontend — presentation BLoC + pages

- [X] T034 [US1] Create `lib/features/admin/listing_review/presentation/bloc/pending_queue_bloc.dart` per data-model.md §3.6. Events: `PendingQueueLoadFirstPage`, `PendingQueueLoadNextPage`, `PendingQueueRefresh`. State: `PendingQueueState(listings, nextCursor, isLoadingFirstPage, isLoadingNextPage, failure, isEmpty)`. Handlers delegate to `LoadPendingQueueUseCase` and accumulate the listings list across pages.
- [X] T035 [US1] Create `lib/features/admin/listing_review/presentation/bloc/listing_preview_bloc.dart` per data-model.md §3.6. Events (approve-only for US1; reject events wired in US2): `ListingPreviewLoad(listingId)`, `ListingPreviewApprovePressed`. State: `ListingPreviewState(preview, isLoading, isMutatorInFlight, failure, lastSuccess)`. Approve handler calls `ApproveListingUseCase` and emits success on HTTP 200; maps `Failure` subtypes into the state's `failure` field.
- [X] T036 [US1] Create `lib/features/admin/listing_review/presentation/widgets/pending_queue_card.dart` per `contracts/phase12-admin-queue-page.md` §Card composition. 64×64dp thumbnail via `cached_network_image` with placeholder fallback; title (`titleMedium`, maxLines:1, ellipsis); property-type + purpose chips; location names joined; primary price via `MoneyFormatter`; footer "by {publisher} • {time-ago}". Tap → `context.push('/admin/listing-review/preview/${summary.id}')`.
- [X] T037 [US1] Create `lib/features/admin/listing_review/presentation/pages/pending_queue_page.dart` per `contracts/phase12-admin-queue-page.md` §Page composition. `BlocProvider<PendingQueueBloc>` triggers `LoadFirstPage` on init; `ListView.builder` of `PendingQueueCard`; pull-to-refresh dispatches `PendingQueueRefresh`; infinite-scroll listener at bottom dispatches `LoadNextPage`. Empty state uses `AppLocalizations.of(context).adminQueueEmpty`.
- [X] T038 [US1] Create `lib/features/admin/listing_review/presentation/widgets/approve_confirmation_dialog.dart` per `contracts/phase12-listing-preview-page.md` §Approve confirmation dialog. `AlertDialog` with localized title + body + Cancel + Confirm buttons. Confirm pops the dialog AND dispatches `ListingPreviewApprovePressed` to the parent BLoC.
- [X] T039 [US1] Create `lib/features/admin/listing_review/presentation/pages/listing_preview_page.dart` per `contracts/phase12-listing-preview-page.md`. AppBar + scrollable body composing the five Q8=A shared widgets (T029–T033) in order: gallery → price → location → amenities → description. Sticky `bottomNavigationBar` with `SafeArea` + `BottomAppBar` containing two `Expanded` buttons: OutlinedButton (Reject — disabled in US1; wires in US2 task T053) + FilledButton (Approve). Approve tap → `_openApproveDialog`. Both buttons disabled when `state.isMutatorInFlight`. `BlocListener` shows the success snackbar on `lastSuccess`, then pops back to queue; shows error snackbar per failure subtype.

### Frontend — routing + admin home tile

- [X] T040 [US1] Update `lib/core/routing/app_router.dart` to add TWO new GoRoutes: `/admin/listing-review/pending` (PendingQueuePage) AND `/admin/listing-review/preview/:id` (ListingPreviewPage). Both gated via `redirect` that checks AuthCubit + `PermissionChecker.any(const ['listings.approve','listings.reject'])`; non-permitted redirects to `/admin?denied=listing_review`. (Moderation history route added in US6 T067.)
- [X] T041 [US1] Update `lib/features/admin/presentation/pages/admin_home_page.dart` (Phase 6 file) to add a new "Pending review" tile gated by `PermissionChecker.any(['listings.approve','listings.reject'])`. Tile tap → `context.push('/admin/listing-review/pending')`. Use Phase 2 design tokens; tile label sources `admin.tile.pendingReview` ARB key.

### Localization — ARB keys for US1 chrome (approve flow subset)

- [X] T042 [US1] Add the US1-scoped ARB keys to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` (same commit) per data-model.md §4: `admin.tile.pendingReview`, `admin.queue.title`, `admin.queue.empty`, `admin.queue.submittedAt.{justNow,minutes,hours,days}`, `admin.queue.publisherPrefix`, `admin.preview.title`, `admin.preview.cta.approve`, `admin.preview.cta.reject`, `admin.approveDialog.{title,body,confirm,cancel}`, `admin.error.{permission_denied,invalid_status_transition,already_acted_on,unknown}`, `admin.toast.approveSuccess`, `media_gallery_empty`, `media_gallery_video_play`, `description_read_more`, `price_originally_was`. Both locales in the same commit per Phase 3 gate.

### DI wiring + manual verification

- [X] T043 [US1] Add `@injectable` annotations to T027/T028/T023/T024/T025/T034/T035 (datasource, repository, three use cases, two BLoCs) AND run `flutter pub run build_runner build --delete-conflicting-outputs`. **Acceptance**: (a) `lib/core/injection/injection.config.dart` contains generated registrations for `SupabaseListingReviewDatasource`, `ListingReviewRepositoryImpl`, `LoadPendingQueueUseCase`, `LoadListingPreviewUseCase`, `ApproveListingUseCase`, `PendingQueueBloc`, `ListingPreviewBloc`; (b) `flutter analyze` returns zero errors; (c) `flutter build apk --debug --dart-define-from-file=.env.json` completes without "GetIt could not find" exceptions at boot.
- [ ] T044 [US1] Manual verification — flutter run on Pixel 8 Pro emulator with `--dart-define-from-file=.env.json` per `project_dart_defines.md`. **Pre-flight**: grep `lib/core/routing/app_router.dart` for Phase 10's existing edit route path; confirm the publisher-edit path matches what T058's Resubmit button will deep-link to (`/publisher/listings/:id/edit` per the contract). If the actual route differs, update T058's `context.push(...)` AND the moderation-history contract's deep-link string before proceeding. **Then**: sign in as admin; tap Pending review tile; confirm queue page loads ≥1 pending listing oldest-first; tap card; confirm preview renders gallery + price + location + amenities + description at full fidelity; tap Approve; confirm dialog; confirm. Pop back to queue; confirm listing no longer appears. From an anonymous Supabase client (e.g., curl with anon key), confirm `GET /rest/v1/listings?id=eq.<that id>&select=status` returns `status="approved"`. (SC-001, SC-003, SC-009, SC-011 partial.)

**Checkpoint**: User Story 1 fully functional and independently testable. MVP slice ready.

---

## Phase 4: User Story 2 — Admin rejects with reason; publisher sees reason + can resubmit (Priority: P1)

**Goal**: Admin selects a rejection preset (1 of 6) + optional detail, taps Confirm; the Edge Function persists `{preset,detail}` as JSON-encoded TEXT in `listing_status_history.reason`. Publisher's `MyListingsPage` Rejected filter shows the rejection banner with localized preset label + free-text detail + Resubmit button + View moderation history link.

**Independent Test**: Per spec.md US2 — open a `pending_review` listing preview as admin, tap Reject, select "Photos missing or low quality" + free-text detail, Confirm. Verify SQL `(reason::jsonb)->>'preset'` returns the key and `(reason::jsonb)->>'detail'` returns the text. Sign in as publisher; open MyListingsPage → Rejected; confirm banner renders preset label + detail + Resubmit + history link. Tap Resubmit; confirm Phase 10 form opens pre-populated.

### Backend — reject_listing Edge Function

- [X] T045 [US2] Create `supabase/functions/reject_listing/index.ts` per `contracts/phase12-reject-listing-edge-function.md`. Implements the 12-step call sequence: (1) parse + validate `listing_id` UUID; (2) validate `reason_preset` against the hard-coded array `['missing_or_low_quality_photos','incorrect_location','unrealistic_price','incomplete_description','duplicate_listing','other']` → HTTP 400 `invalid_reason_preset` with `allowed` array on mismatch; (3) validate `reason_detail.length ≤ 500` → HTTP 400 `reason_detail_too_long` with `max:500` on overflow; (4–6) JWT-bound + service-role clients + `set_app_user_id_for_session`; (7–8) build JSON `JSON.stringify({preset: reason_preset, detail: reason_detail ?? null})` AND call `set_app_rejection_reason_for_session(reasonJson)`; (9) UPDATE under status-guard; (10) zero-rows → HTTP 409; (12) HTTP 200 `{status:'rejected', reason_preset, reason_detail}`. ~110 LOC TypeScript.
- [X] T046 [US2] Deploy `reject_listing` via Supabase MCP `deploy_edge_function`.
- [ ] T047 [US2] Smoke-test reject_listing happy path via `curl -X POST $SUPABASE_URL/functions/v1/reject_listing -d '{"listing_id":"<id>","reason_preset":"missing_or_low_quality_photos","reason_detail":"The main photo appears to be a stock image."}'`. Expect HTTP 200. Run `SELECT reason, (reason::jsonb)->>'preset' AS preset, (reason::jsonb)->>'detail' AS detail FROM public.listing_status_history WHERE listing_id='<id>' AND new_status='rejected' ORDER BY changed_at DESC LIMIT 1` via Supabase MCP `execute_sql` — expect the JSON shape from `contracts/phase12-rejection-reason-storage-format.md`.

### Frontend — domain use case + datasource extension

- [X] T048 [P] [US2] Create `lib/features/admin/listing_review/domain/usecases/reject_listing.dart` — `RejectListingUseCase` with `call(listingId, preset, detail)` returning `Future<Result<RejectResult, Failure>>`.
- [X] T049 [US2] Extend `lib/features/admin/listing_review/data/datasources/supabase_listing_review_datasource.dart` (T027) with `rejectListing(id, preset, detail)` calling `functions.invoke('reject_listing', body: {'listing_id': id, 'reason_preset': preset.key, if (detail != null) 'reason_detail': detail})`. Map non-200 responses to the matching `Failure` subtype.
- [X] T050 [US2] Extend `lib/features/admin/listing_review/data/repositories/listing_review_repository_impl.dart` (T028) — implement `rejectListing` delegating to the datasource; the `invalid_reason_preset` + `reason_detail_too_long` HTTP 400 codes map to `InvalidReasonPresetFailure` + `ReasonDetailTooLongFailure`.

### Frontend — reject reason dialog + preview wiring

- [X] T051 [US2] Create `lib/features/admin/listing_review/presentation/widgets/reject_reason_dialog.dart` per `contracts/phase12-reject-reason-dialog.md`. `StatefulWidget` returning `RejectDialogResult(preset, detail)` via `Navigator.pop`. Layout: title + 6 `RadioListTile<RejectionReason>` widgets (one per preset, in enum order, labels via ARB `rejectPreset<Preset>` keys) + multi-line `TextField` (maxLength:500) + counter "{n}/500" + Cancel + Confirm. Confirm enable rule per Q5=A: enabled only when `_selectedPreset != null AND (preset != other OR detail.trim().isNotEmpty)`. When `preset==other`, field label flips from `admin.rejectDialog.detailLabel.optional` to `.required` AND hint `admin.rejectDialog.detailHint.other` appears.
- [X] T052 [US2] Extend `lib/features/admin/listing_review/presentation/bloc/listing_preview_bloc.dart` (T035) — add `ListingPreviewRejectPressed(preset, detail)` event handler calling `RejectListingUseCase`; emit success / failure into state; treat `AlreadyActedOnFailure` + `InvalidStatusTransitionFailure` as pop-back-to-queue conditions per `contracts/phase12-listing-preview-page.md`.
- [X] T053 [US2] Wire reject dialog launch in `lib/features/admin/listing_review/presentation/pages/listing_preview_page.dart` (T039) — Reject button's `onPressed` opens `showDialog<RejectDialogResult>(builder: RejectReasonDialog())`; if result non-null, dispatches `ListingPreviewRejectPressed(result.preset, result.detail)`. Reject button is enabled (US1 left it disabled placeholder).

### Frontend — publisher dashboard banner + Resubmit + history link

- [X] T054 [P] [US2] Create `lib/features/publisher_dashboard/domain/entities/moderation_history_entry.dart` per data-model.md §3.1: `id`, `previousStatus?` (Phase 10 `ListingStatus`), `newStatus`, `changedAt`, `rejectionPreset?` (`RejectionReason` — imported from `lib/core/listing/rejection_reason.dart` per T016's relocation; no cross-feature import into `admin/listing_review/`), `rejectionDetail?`.
- [X] T055 [P] [US2] Create `lib/features/publisher_dashboard/domain/usecases/load_moderation_history.dart` — `LoadModerationHistoryUseCase` with `call(listingId)` returning `Future<Result<List<ModerationHistoryEntry>, Failure>>`. (Used by the US6 moderation history page; the banner uses the focused use case below.)
- [X] T055a [P] [US2] Create `lib/features/publisher_dashboard/domain/usecases/load_most_recent_rejection.dart` — `LoadMostRecentRejectionUseCase` with `call(listingId)` returning `Future<Result<ModerationHistoryEntry?, Failure>>` — returns the single most-recent `listing_status_history` row where `new_status='rejected'`, or null if none. **Rationale (analysis finding C3)**: the banner needs only the most-recent rejection, not the full history; a dedicated focused query avoids loading N history rows per rejected card on every MyListingsPage render.
- [X] T056 [US2] Extend `lib/features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart` — add TWO methods: (1) `loadModerationHistory(listingId)` running the SELECT from `contracts/phase12-moderation-history-page.md` §Data source contract (full chronological list with JSON parse of `reason` to `preset` + `detail`); (2) `loadMostRecentRejection(listingId)` running the indexed-lookup query from `contracts/phase12-publisher-rejection-banner.md` §Data input: `SELECT id, changed_at, CASE WHEN reason LIKE '{%}' THEN (reason::jsonb)->>'preset' END AS preset, CASE WHEN reason LIKE '{%}' THEN (reason::jsonb)->>'detail' END AS detail FROM public.listing_status_history WHERE listing_id=$1 AND new_status='rejected' ORDER BY changed_at DESC LIMIT 1` — returns a single optional `ModerationHistoryEntry`.
- [X] T057 [US2] Extend `lib/features/publisher_dashboard/domain/repositories/publisher_dashboard_repository.dart` abstract + its impl (`...repository_impl.dart`) with BOTH `loadModerationHistory(listingId)` AND `loadMostRecentRejection(listingId)` methods.
- [X] T058 [US2] Create `lib/features/publisher_dashboard/presentation/widgets/rejection_reason_banner.dart` per `contracts/phase12-publisher-rejection-banner.md`. `StatelessWidget` accepting `{listingId, preset, detail?, rejectedAt}`. Layout: attribution line ("Reviewed by admin team • {time-ago}") + preset label (titleSmall) + detail in quoted block (border-start 3px `onDangerContainer.withOpacity(0.5)`) + Resubmit `FilledButton.tonal` + "View moderation history" `TextButton`. Background `dangerContainer` token; foreground `onDangerContainer`. Resubmit `onPressed: () => context.push('/publisher/listings/${listingId}/edit')` (path confirmed in T044). History link `onPressed: () => context.push('/publisher/listings/${listingId}/moderation-history')`. Admin identity NEVER displayed — always "Admin team" via ARB key.
- [X] T059 [US2] Extend `lib/features/publisher_dashboard/presentation/pages/my_listings_page.dart` (Phase 10 file) — in the Rejected filter section, for each rejected listing, call `LoadMostRecentRejectionUseCase(listingId)` (T055a) via a `FutureBuilder` (or fold into the existing `MyListingsBloc` if it already loads per-card metadata). When the result is non-null, render `RejectionReasonBanner` above the card; when null (no rejection history — should not happen for a card in the Rejected filter, but defensive), skip the banner. Loading state: skeleton placeholder where the banner would appear.

### Localization — US2-scoped ARB keys

- [X] T060 [US2] Add the US2-scoped ARB keys to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` per data-model.md §4: `admin.rejectDialog.{title,detailLabel.optional,detailLabel.required,detailHint.other,counter,confirm,cancel}`, `reject_preset_missing_or_low_quality_photos`, `reject_preset_incorrect_location`, `reject_preset_unrealistic_price`, `reject_preset_incomplete_description`, `reject_preset_duplicate_listing`, `reject_preset_other`, `publisher.rejection.attribution`, `publisher.rejection.resubmit`, `publisher.rejection.viewHistory`, `admin.error.{invalid_reason_preset,reason_detail_too_long}`, `admin.toast.rejectSuccess`. Both locales in the same commit.
- [X] T061 [US2] Re-run `flutter pub run build_runner build --delete-conflicting-outputs` AND `flutter gen-l10n` to regenerate the AppLocalizations + injectable graph. **Acceptance**: (a) `lib/core/injection/injection.config.dart` now contains registrations for `RejectListingUseCase`, `LoadModerationHistoryUseCase`, `LoadMostRecentRejectionUseCase`; (b) generated AppLocalizations exposes the new US2 keys (e.g., `AppLocalizations.rejectPresetMissingOrLowQualityPhotos` exists in `lib/l10n/app_localizations.dart`); (c) `flutter analyze` returns zero errors.

### Manual verification — US2

- [ ] T062 [US2] Manual verification on Pixel 8 Pro emulator (admin) + Infinix Note 8 (publisher) per quickstart.md Steps 10–12. Admin: open preview → Reject → confirm 6 presets render localized + Confirm disabled until preset selected + counter updates as text typed + Confirm disabled when `other` selected with empty detail + Confirm enabled when `other` has non-empty detail. Submit a rejection. Verify SQL `(reason::jsonb)->>'preset'` returns the chosen preset key. Publisher: sign in on Infinix Note 8; open MyListingsPage → Rejected; confirm banner with preset label + detail + Resubmit + history link in both locales. Tap Resubmit; confirm Phase 10 form opens. (SC-004, SC-012, SC-013, SC-027 partial, SC-028 UX side.)

**Checkpoint**: User Stories 1 + 2 both fully functional. The full approve/reject loop ships.

---

## Phase 5: User Story 3 — Public-read RLS end-to-end (Priority: P1)

**Goal**: Verify Phase 10's public-read RLS on `public.listings` AND Phase 11's storage RLS honor `status='approved'` end-to-end against real approved rows produced by US1's approve_listing. No new code; pure verification.

**Independent Test**: Per spec.md US3 — seed 1 listing per status; anonymous SELECT returns only the approved one; flip approved → paused → anonymous SELECT no longer returns it; flip back to approved → it reappears.

- [X] T063 [US3] Seed test dataset via Supabase MCP `execute_sql` — create 9 listings (or repurpose existing ones via direct UPDATE), one in each of the 9 statuses: draft, pending_review, approved, rejected, paused, sold, rented, expired, deleted. Capture each listing's `id` for the verification queries.
- [X] T064 [US3] Anonymous SELECT verification (SC-002) — run `SELECT id, status FROM public.listings ORDER BY created_at ASC` from an anonymous (no-auth) Supabase client. Confirm exactly one row returned (the `approved` one).
- [X] T065 [US3] Owner SELECT verification — sign in as the publisher of the `draft` listing; confirm their own draft is visible to them AND no other publisher's drafts are visible (Phase 10 owner-RLS).
- [X] T066 [US3] Admin SELECT verification — sign in as an admin holding `listings.view_all`; confirm all 9 statuses are visible (Phase 6 + Phase 10 admin-RLS).
- [X] T067 [US3] Storage RLS on approve (SC-009) — for an approved listing's media, run anonymous `supabase.storage.from('listing-images').getPublicUrl(<path>)` AND `curl` the URL; expect HTTP 200 + image bytes.
- [X] T068 [US3] Storage RLS on status revert (SC-008) — `UPDATE public.listings SET status='paused' WHERE id='<approved id>'` via Supabase MCP; re-issue both the anonymous SELECT AND the anonymous storage download. Expect zero rows from SELECT AND HTTP 403 from storage. Then `UPDATE ... SET status='approved'`; re-verify both queries return the listing AND its media again.
- [X] T069 [US3] Expired listing verification (SC-002 corner) — `UPDATE public.listings SET expires_at = now() - interval '1 hour' WHERE id='<approved id>'`; re-issue anonymous SELECT; confirm the listing is no longer returned (Phase 10 RLS `expires_at IS NULL OR expires_at > now()` clause). Reset `expires_at = NULL` after the test to restore Q2=A invariant.

**Checkpoint**: US3 verified. RLS posture is correct end-to-end against real approved data.

---

## Phase 6: User Story 4 — Audit + status-history completeness (Priority: P1)

**Goal**: Verify every approve + reject action emits exactly one `audit_logs` row + one `listing_status_history` row, with correct attribution under the FR-024 amendment.

**Independent Test**: Per spec.md US4 — execute one approve + one reject; SQL-verify both audit rows + both history rows with the correct actor and JSON-encoded reason.

- [X] T070 [US4] Approve action audit completeness — execute one approve via the UI. Run `SELECT action, actor_user_id, target_type, target_id, before_state, after_state, ip, user_agent, created_at FROM public.audit_logs WHERE action='listing.approved' AND target_id='<the listing id>'` — expect exactly one row with `actor_user_id=<admin uid>`, `target_type='listings'`, before_state showing `status:'pending_review'`, after_state showing `status:'approved',published_at:<iso>,expires_at:null`. (SC-003.)
- [X] T071 [US4] Approve status-history completeness — run `SELECT previous_status, new_status, changed_by, reason FROM public.listing_status_history WHERE listing_id='<the listing id>' ORDER BY changed_at DESC LIMIT 1` — expect `previous_status='pending_review'`, `new_status='approved'`, `changed_by=<admin uid>`, `reason IS NULL`. (SC-030 approve side.)
- [X] T072 [US4] Reject action audit completeness — execute one reject via the UI. Run same query but `action='listing.rejected'`. Expect exactly one row with `actor_user_id=<admin uid>`, after_state containing the preset + detail JSONB shape. (SC-004.)
- [X] T073 [US4] Reject status-history completeness — run `SELECT previous_status, new_status, changed_by, reason, (reason::jsonb)->>'preset' AS preset, (reason::jsonb)->>'detail' AS detail FROM public.listing_status_history WHERE listing_id='<the listing id>' ORDER BY changed_at DESC LIMIT 1`. Expect `new_status='rejected'`, `changed_by=<admin uid>`, valid `preset` + `detail` parse. (SC-004, SC-027, SC-030 reject side.)
- [X] T074 [US4] Phase 5–11 caller regression — perform one non-Phase-12 audit-emitting action (e.g., approve an account via Phase 5's existing flow, OR add a role mapping via Phase 7's RPC). Run `SELECT actor_user_id FROM public.audit_logs ORDER BY created_at DESC LIMIT 1` — expect a non-NULL UUID matching the caller (confirms the COALESCE fallback path works for direct-JWT callers).
- [X] T075 [US4] log_audit byte-identical-except-COALESCE verification (SC-005) — `SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname='log_audit'` via Supabase MCP; diff against the Phase 4 original body captured in T006. Confirm the only difference is the `actor_user_id` source line — every other line byte-identical.
- [X] T076 [US4] Phase 10/4 file immutability re-check (SC-031) — `git diff --stat -- supabase/migrations/20260506120004_create_audit_logs.sql supabase/migrations/20260519120006_create_listing_status_history.sql` should still return zero lines after all US1+US2 work.
- [X] T077 [US4] Failed-action transaction-rollback verification — invoke `approve_listing` with `listing_id` pointing at a listing in `status='rejected'`. Expect HTTP 409. Run `SELECT count(*) FROM public.audit_logs WHERE target_id='<that id>' AND action='listing.approved'` — expect the count UNCHANGED from before the failed call (no audit row written on failure).

**Checkpoint**: US4 verified. Audit + history posture is durable across the amendment.

---

## Phase 7: User Story 5 — Pending queue pagination, sort, refresh (Priority: P2)

**Goal**: Verify cursor-based pagination, oldest-first ordering, pull-to-refresh, on-pop refresh, and placeholder behavior on the queue page. Most of the queue infrastructure shipped in US1; this phase verifies and polishes edge cases.

**Independent Test**: Per spec.md US5 — seed 25 pending_review listings with staggered timestamps; confirm first page = 20 oldest-first; scroll to bottom; confirm next 5 load; pull-to-refresh; confirm re-fetch.

- [X] T078 [US5] Seed 25 `pending_review` listings via Supabase MCP `execute_sql` with staggered timestamps using `submit_listing` calls OR direct INSERTs. Record the 25 listing IDs.
- [ ] T079 [US5] First-page load verification (SC-010) — open the queue on the Pixel 8 Pro emulator. Confirm exactly 20 cards render. Confirm the order matches `SELECT id FROM public.listings WHERE status='pending_review' ORDER BY created_at ASC LIMIT 20` (or `submitted_at ASC` per the use-case dartdoc choice in T026).
- [ ] T080 [US5] Infinite-scroll verification — scroll to the bottom of the 20-card list. Confirm the remaining 5 cards load AND the order continues from the first page's last card chronologically.
- [ ] T081 [US5] Pull-to-refresh verification — pull down from the top of the list. Confirm the spinner appears AND the page re-fetches from the first cursor (oldest 20).
- [ ] T082 [US5] On-pop refresh verification — approve one listing from the preview; on returning to the queue, confirm the approved listing no longer appears AND a new listing (the previously-26th, if any) appears at the tail.
- [ ] T083 [US5] Missing-main-image placeholder verification — for one queue listing, UPDATE `public.listing_media SET is_main = false WHERE listing_id='<id>'` (no main image now); reload the queue; confirm a Phase 2 placeholder thumbnail renders (no broken-image icon, no crash). Restore `is_main=true` after the test.
- [ ] T084 [US5] Scroll-position retention verification — scroll partway down the list, tap a card, back-button to the queue. Confirm the queue retains its scroll position.

**Checkpoint**: US5 verified. Queue chrome is production-ready.

---

## Phase 8: User Story 6 — Publisher moderation history page + admin-identity privacy (Priority: P2)

**Goal**: Ship the read-only moderation history page; verify the rejection-resubmit-reject chain renders correctly; confirm admin identity is never exposed.

**Independent Test**: Per spec.md US6 — open a multi-rejected listing's history page; confirm every transition row renders chronologically with preset + detail for rejections; confirm "Admin team" attribution (never the admin's name).

- [X] T085 [US6] Create `lib/features/publisher_dashboard/presentation/bloc/moderation_history_cubit.dart` — lightweight `Cubit<ModerationHistoryState>` with a single `load(listingId)` method calling `LoadModerationHistoryUseCase` (T055) and emitting a state `{entries, isLoading, failure}`.
- [X] T086 [US6] Create `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart` per `contracts/phase12-moderation-history-page.md`. AppBar + chronological `ListView` of entry cards. Each card: arc "Previous → New" (via 9 status ARB labels), timestamp + " • Admin team", and (for rejection rows) preset label + detail in a quoted block. Empty state defensive but should never occur. Loading state: centered `CircularProgressIndicator`.
- [X] T087 [US6] Add the third new GoRoute to `lib/core/routing/app_router.dart` at path `/publisher/listings/:id/moderation-history` → `ListingModerationHistoryPage(listingId: state.pathParameters['id']!)`. Redirect guard: `if (user == null) return '/login'` — owner-only access is enforced server-side by Phase 10's `listing_status_history` RLS (`publisher_user_id = auth.uid()`); no extra frontend gate.
- [X] T088 [US6] Add the US6-scoped ARB keys to `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`: `publisher.history.title`, `publisher.history.adminTeam`, `publisher.history.firstEntry`, `publisher.history.empty`, `publisher.history.status.{draft,pending_review,approved,rejected,paused,sold,rented,expired,deleted}` (9 status labels for the arc rendering).
- [X] T089 [US6] Re-run `flutter gen-l10n` AND `flutter pub run build_runner build --delete-conflicting-outputs`. **Acceptance**: (a) generated AppLocalizations exposes the 13 US6 keys (e.g., `AppLocalizations.publisherHistoryTitle`, `AppLocalizations.publisherHistoryStatusDraft` through `publisherHistoryStatusDeleted`); (b) `lib/core/injection/injection.config.dart` registers `ModerationHistoryCubit`; (c) `flutter analyze` returns zero errors.
- [ ] T090 [US6] Manual verification — reject-resubmit-reject chain (SC-020) — on a single listing, perform reject → resubmit → reject sequence via the UI (3 admin actions). Open the moderation history page as the publisher. Confirm exactly four chronological entries: draft creation → pending_review (submit) → rejected (1st) → pending_review (resubmit) → rejected (2nd). Confirm both rejection entries show their respective preset + detail. Confirm admin identity NEVER displayed (only "Admin team"). Run `SELECT count(*) FROM public.audit_logs WHERE target_id='<id>' AND action='listing.rejected'` — expect exactly 2.
- [ ] T091 [US6] Manual verification — approve-revert-approve chain (SC-021) — approve a listing → direct SQL `UPDATE public.listings SET status='paused' WHERE id='<id>'` (simulating future-spec moderation) → re-approve via UI. `SELECT count(*) FROM public.audit_logs WHERE target_id='<id>' AND action='listing.approved'` — expect 2; both have `published_at` non-NULL AND the second's `published_at` later than the first's.

**Checkpoint**: All six user stories independently functional.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Constitution compliance grep audits + latency probe + full quickstart pass + final cleanup. These tasks may run in parallel (different files / different verification targets).

- [X] T092 [P] Constitution IX-clean grep (SC-015) — `grep -R "package:supabase_flutter" lib/features/admin/listing_review/presentation/ lib/shared/presentation/widgets/listing_display/` must return ZERO hits. If any, refactor the offending import down into `data/datasources/`.
- [X] T093 [P] Constitution V grep (SC-016) — run the Phase 3 localization lint guard / grep for hardcoded user-facing strings in `lib/features/admin/listing_review/`, `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart`, `lib/features/publisher_dashboard/presentation/widgets/rejection_reason_banner.dart`. Zero hits expected.
- [X] T094 [P] Constitution VI grep (SC-017) — `grep -RnE "Color\(0x|EdgeInsets\.only\(left:|SizedBox\(width: [0-9]" lib/features/admin/listing_review/presentation/ lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart lib/features/publisher_dashboard/presentation/widgets/rejection_reason_banner.dart lib/shared/presentation/widgets/listing_display/` — zero hits. All spacing/color/typography sourced from Phase 2 tokens.
- [X] T095 [P] No-notification-subsystem grep (SC-025 + FR-019) — `grep -RnE "notifications|Realtime|channel\.subscribe|fcm|onesignal|push_token" supabase/migrations/20260523120004*.sql supabase/functions/approve_listing/ supabase/functions/reject_listing/ lib/features/admin/listing_review/` — zero hits across BOTH the SQL migration AND both Edge Function bodies AND the admin presentation/data layers (analysis finding C4 added the Edge Function source paths).
- [X] T096 [P] Shared widget count verification (SC-032) — `ls lib/shared/presentation/widgets/listing_display/` returns exactly 5 files: `listing_gallery.dart`, `listing_price_block.dart`, `listing_location_block.dart`, `listing_amenities_block.dart`, `listing_description_block.dart`.
- [X] T097 [P] Two-Edge-Function existence verification (SC-022) — `ls supabase/functions/approve_listing/index.ts supabase/functions/reject_listing/index.ts` — both files exist. `git log --diff-filter=A -- supabase/migrations/*approve_listing* supabase/migrations/*reject_listing*` returns nothing (zero new RPC migrations bearing those names).
- [X] T097a [P] Server-side permission re-check code review (SC-018 + Constitution III + VII) — open `supabase/functions/approve_listing/index.ts` AND `supabase/functions/reject_listing/index.ts`. **Acceptance**: each file MUST contain (a) a JWT-bound Supabase client created via `createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: <header> } } })`; (b) a call `jwtClient.rpc('current_user_has_permission', { perm_key: 'listings.approve' })` (or `'listings.reject'`); (c) the permission check MUST appear BEFORE any service-role client creation OR any UPDATE statement; (d) the file MUST NOT contain `createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)` anywhere ABOVE the permission check line. Record the line number of each `current_user_has_permission` call in the PR description. This task closes analysis finding C1.
- [X] T098 [P] expires_at=NULL invariant verification (SC-023) — `SELECT count(*) FROM public.listings WHERE status='approved' AND expires_at IS NOT NULL AND id IN (<every listing approved via Phase 12>)` — expect 0.
- [X] T099 [P] Preset enum match verification (SC-024) — read the Dart enum in `lib/core/listing/rejection_reason.dart` (relocated per C2) AND the TypeScript array in `supabase/functions/reject_listing/index.ts`. Both must contain exactly the six Q3=A keys in the same order: `missing_or_low_quality_photos`, `incorrect_location`, `unrealistic_price`, `incomplete_description`, `duplicate_listing`, `other`.
- [X] T100 [P] "Other"-detail-non-empty invariant (SC-028) — `SELECT count(*) FROM public.listing_status_history WHERE new_status='rejected' AND (reason::jsonb)->>'preset' = 'other' AND ((reason::jsonb)->>'detail' IS NULL OR trim((reason::jsonb)->>'detail') = '')` — expect 0 (for any rejection issued through the Phase 12 UI).
- [ ] T101 Edge Function p95 latency probe (SC-029) — perform ≥ 10 approve + ≥ 10 reject invocations through the UI. Retrieve Supabase Edge Function logs via Supabase MCP `get_logs(service="edge-function")`. Compute the 95th-percentile `duration_ms` across the 20 invocations; assert ≤ 2000. If breached, document in DEFERRED.md and flag for Phase 24 observability.
- [X] T102 Concurrent admin race verification (SC-007 + R-54) — fire two `curl` requests in true parallel against the same `pending_review` listing using shell background jobs: `LISTING=<id>; ADMIN_JWT=<token>; curl -X POST "$SUPABASE_URL/functions/v1/approve_listing" -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" -d "{\"listing_id\":\"$LISTING\"}" -w "\n%{http_code}\n" & curl -X POST "$SUPABASE_URL/functions/v1/approve_listing" -H "Authorization: Bearer $ADMIN_JWT" -H "Content-Type: application/json" -d "{\"listing_id\":\"$LISTING\"}" -w "\n%{http_code}\n" & wait`. **Acceptance**: among the two responses, exactly one returns HTTP 200 with `status:"approved"` AND exactly one returns HTTP 409 with `code:"already_acted_on"` and `current_status:"approved"`. Then `SELECT count(*) FROM public.audit_logs WHERE target_id='<id>' AND action='listing.approved'` returns exactly 1 (no double-audit). Then `SELECT count(*) FROM public.listings WHERE id='<id>' AND status='approved'` returns exactly 1 (status-guard predicate enforced).
- [ ] T103 Non-admin route-guard verification (SC-026 + FR-023) — sign in as a `user`-role account; attempt to deep-link to `/admin/listing-review/pending`. Expect redirect to `/admin?denied=listing_review` + a localized "Insufficient permissions" toast.
- [ ] T104 Non-admin Edge Function direct-call verification (SC-006) — from a `user`-role JWT, `curl -X POST $SUPABASE_URL/functions/v1/approve_listing -H "Authorization: Bearer <user JWT>" -d '{"listing_id":"<any>"}'` → expect HTTP 403 `{"code":"permission_denied"}`. Confirm no `audit_logs` row was written.
- [ ] T105 Run quickstart.md full pass — execute all 19 steps end-to-end on a fresh emulator install. Record any deviations in `specs/012-listing-approval/DEFERRED.md`.
- [X] T106 Confirm zero new pubspec packages — `git diff -- pubspec.yaml pubspec.lock` returns zero lines (Phase 12's zero-package invariant per plan.md).
- [X] T107 Confirm zero AndroidManifest changes — `git diff -- android/app/src/main/AndroidManifest.xml` returns zero lines.
- [X] T108 Confirm zero CI workflow changes — `git diff -- .github/workflows/ci.yml` returns zero lines.
- [X] T109 Create OR extend `specs/012-listing-approval/DEFERRED.md` per `project_deferred_work.md`. **Pre-seed the three plan-time deferrals carried from research.md regardless of T105 outcome**: (1) **D-12-01** — Fullscreen viewer affordance on `ListingGallery` (Phase 12 ships horizontal carousel only; pinch-to-zoom + fullscreen overlay deferred to Phase 13's listing-details enhancement); (2) **D-12-02** — Listing price display currency choice (admin's preferred vs publisher's stored — Phase 12 displays publisher's stored currency; admin-side currency conversion deferred); (3) **D-12-03** — Audit-log detail surface on the moderation history page (publisher sees preset + detail only; full audit_logs JSONB surface deferred to a future super-admin spec). **Then add** any NEW deferrals encountered during T105's quickstart pass.
- [X] T110 Final code review pass — re-grep for stray TODO/FIXME comments in Phase 12 files; ensure all are tracked in DEFERRED.md if intentional.

**Checkpoint**: All 32 SCs verified. Phase 12 ready for squash-merge per `feedback_git_workflow.md`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately.
- **Phase 2 (Foundational)**: Depends on T003 (permission audit) + T005 + T006 (Phase 4/10 body capture). **BLOCKS all user-story phases** — without the FR-024 migration, mutators cannot attribute audit rows.
- **Phase 3 (US1)**: Depends on Phase 2 complete (specifically T008 migration applied + T016 RejectionReason enum present + T004 Failure subtypes).
- **Phase 4 (US2)**: Depends on Phase 2 + Phase 3 (US2 extends datasource + BLoC + preview page from US1; the rejection banner depends on the data layer scaffolded in T027/T028).
- **Phase 5 (US3)**: Depends on Phase 3 (needs at least one approved listing produced by US1's approve_listing).
- **Phase 6 (US4)**: Depends on Phase 3 + Phase 4 (needs both approve + reject actions executed).
- **Phase 7 (US5)**: Depends on Phase 3 (queue page exists). Independent of US2/US4.
- **Phase 8 (US6)**: Depends on Phase 4 (needs the publisher_dashboard datasource extension + rejection banner already in place). Adds the moderation history page on top.
- **Phase 9 (Polish)**: Depends on all user stories complete.

### Story Independence

- **US1** (approve flow) is the MVP slice — can ship alone with just Phase 1 + Phase 2 + Phase 3.
- **US2** (reject flow + publisher banner) builds incrementally on US1's infrastructure but can be tested independently once Phase 4 completes.
- **US3** is pure verification — no new code, can run in parallel with US4–US6.
- **US4** is pure verification — can run in parallel with US3, US5, US6.
- **US5** is pure verification — can run in parallel with US3, US4, US6.
- **US6** ships a new page + cubit + use case; depends on US2's data layer but adds no further mutators.

### Within Each User Story

- Backend (Edge Function deploy) → frontend (datasource → repository → use case → BLoC → page).
- Shared widgets (T029–T033) can build in parallel with the BLoC + page work since they accept domain entities only.
- ARB key task always lands LAST in each user story so all chrome strings get added in one commit per Phase 3's localization gate.
- DI registration task (T043) lands after all `@injectable` annotations are added in that story.

### Parallel Opportunities

- T003 (perm audit), T004 (Failure subtypes), T005/T006 (function body capture) all run in parallel in Phase 1.
- T012–T016 all run in parallel in Phase 2 (independent doc + enum files; T016 ships the relocated `lib/core/listing/rejection_reason.dart`).
- **Phase 3 wave 1**: T020, T021, T022 in parallel (entities + repository abstract — no cross-deps).
- **Phase 3 wave 2**: T023, T024, T025 in parallel (use cases — all depend on T022 only, no cross-deps).
- T029–T033 (5 shared display widgets) all run in parallel — each is a distinct file with domain-entity inputs.
- T048 (use case), T054 (entity), T055 (history use case), T055a (most-recent rejection use case) all run in parallel in Phase 4.
- T092–T100 + T097a (all 10 Constitution + invariant grep audits including the C1 server-perm code-review) all run in parallel in Phase 9.

---

## Parallel Example: Phase 3 (US1) widget burst

```text
# All five Q8=A shared widgets — independent files, no cross-deps:
Task T029: lib/shared/presentation/widgets/listing_display/listing_gallery.dart
Task T030: lib/shared/presentation/widgets/listing_display/listing_price_block.dart
Task T031: lib/shared/presentation/widgets/listing_display/listing_location_block.dart
Task T032: lib/shared/presentation/widgets/listing_display/listing_amenities_block.dart
Task T033: lib/shared/presentation/widgets/listing_display/listing_description_block.dart

# All three use cases — independent files, all delegate to the repository abstract.
# These can run in parallel BUT only AFTER T022 (the abstract repository file) lands.
Task T023: lib/features/admin/listing_review/domain/usecases/load_pending_queue.dart
Task T024: lib/features/admin/listing_review/domain/usecases/load_listing_preview.dart
Task T025: lib/features/admin/listing_review/domain/usecases/approve_listing.dart
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1: Setup (T001–T006).
2. Complete Phase 2: Foundational (T007–T016) — apply FR-024 migration; this is the blocking critical path.
3. Complete Phase 3: User Story 1 (T017–T044) — approve flow end-to-end.
4. **STOP and VALIDATE**: Run T044's manual verification. If clean, the MVP slice is ready to demo (admin can approve listings → they go public).
5. The reject flow + publisher banner are NOT in the MVP slice; deliberate scope cut for an interim demo if needed.

### Incremental Delivery

1. Setup + Foundational → Foundation ready.
2. US1 (approve) → MVP demo.
3. US2 (reject + publisher banner) → close the publisher feedback loop.
4. US3 + US4 verifications (RLS + audit) → launch-readiness gate.
5. US5 (queue polish) → production-quality admin UX.
6. US6 (moderation history) → publisher-side transparency.
7. Polish phase → Constitution audits + latency probe + full quickstart pass → merge.

### Single-Developer Sequential Strategy (most likely path)

Given the workflow described in `feedback_git_workflow.md` (one PR per spec), execute phases strictly sequentially with frequent intermediate commits. Each task above is roughly atomic — commit after each completed task or natural cluster. Aim for ~3–5 commits per phase.

---

## Notes

- [P] tasks = different files, no incomplete-dependency overlap.
- [Story] label = which user story owns this task.
- Each task includes the exact file path or SQL query.
- Manual UI verification replaces automated tests per `feedback_no_new_tests.md` — every `flutter run`/`build` MUST include `--dart-define-from-file=.env.json` per `project_dart_defines.md`.
- Pixel 8 Pro emulator on Windows may need the SetWindowPos recipe in `docs/dev/android-emulator-windows.md` per `project_android_emulator_window_offscreen.md`.
- Supabase MCP `apply_migration` does NOT dedupe by name per `project_supabase_mcp_apply_migration.md` — never re-apply T008.
- Stop at any checkpoint (end of Phase 2 / Phase 3 / Phase 4 / etc.) to validate independently.
- Phase 12 introduces ZERO new pubspec packages, ZERO AndroidManifest changes, ZERO new automated tests.
