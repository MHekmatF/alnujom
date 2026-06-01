# Tasks: Push Notifications + Supabase Realtime Signals (Phase 22)

**Input**: Design documents from `specs/022-notifications-realtime/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: NONE — per the project's MVP convention (memory `feedback_no_new_tests`): no new automated tests; verification is manual on-device (two-device for push + counters) + wire-level/SQL inspection (see `quickstart.md`).

## Organization

Phases here are the plan's **implementation/wave phases** (PB / PD / PN / PR — see `plan.md` § Implementation Phases), NOT one-phase-per-user-story, because this tasks.md drives `/wave` and the appended Touch-Fan / Dependency-Audit / Wave-Plan / Model-Routing sections all key off PB/PD/PN/PR. Each task still carries its `[US#]` story tag for traceability (US1 in-app notifications+center · US2 device push, pluggable · US3 admin counters live · US4 live permission refresh · US5 data-layer enforcement · US6 l10n/theming).

## Format: `[ID] [P?] [Story] Description`
- **[P]**: parallelizable (different files, no incomplete-task dependency)
- **[US#]**: the user story the task serves
- Exact file paths included; backend = `supabase/migrations/` + `supabase/functions/`, app = `lib/`

> **Checkbox discipline (MANDATORY for every dispatched sub-agent)**: when you finish a task, flip its `- [ ] T<id>` to `- [X] T<id>` **in the same commit as the implementation**. Do NOT defer checkbox-flipping to a "cleanup pass" — it never happens.

---

## Phase 1: Setup (Shared)

**Purpose**: feature-tree skeleton. Folds into Wave 1 (PD creates the files). The pubspec/Firebase/Android platform changes live in PD (T026), not here.

- [X] T001 [P] Create the `lib/features/notifications/` Clean-Arch tree per `plan.md` § Project Structure: `domain/{entities,repositories,usecases}/`, `data/{datasources,dtos,repositories}/`, `presentation/{bloc,pages,widgets}/`; and the `lib/core/messaging/` folder for the provider-agnostic push interface.

---

## Phase 2 — PB: Backend (11 migrations + 1 Edge Function) [Wave 1]

**Goal**: the two new tables, the enqueue + client RPCs, the four transition fan-out amendments, the Vault secrets, the `pg_net` push-dispatch trigger + `dispatch_push` function, and the Realtime publication — the server-side foundation for every story. All SQL under `supabase/migrations/`; bodies in `data-model.md` + `contracts/`.

**Independent test**: apply via Supabase MCP; `get_advisors` clean; structural check confirms both tables (RLS on, writes REVOKEd), the RPCs with their grants, the trigger, and the publication adds.

- [X] T002 [P] [US2] Migration `supabase/migrations/20260602120001_create_notification_tokens.sql` — `notification_tokens` (id, user_id FK CASCADE, token, platform CHECK∈('android'), is_active, last_seen_at, created_at, UNIQUE(user_id,token)), index `ix_notification_tokens_user … where is_active`, RLS on, `notification_tokens_select_self` (`user_id = auth.uid()`), `REVOKE INSERT,UPDATE,DELETE … FROM authenticated, anon`.
- [X] T003 [P] [US1] Migration `supabase/migrations/20260602120002_create_notifications.sql` — `notifications` (id, recipient_user_id FK CASCADE, type CHECK [6 values], params jsonb, read_at, created_at), indexes `ix_notifications_recipient_created` + partial unread, RLS on, `notifications_select_self` (`recipient_user_id = auth.uid()`), `REVOKE INSERT,UPDATE,DELETE … FROM authenticated, anon`.
- [X] T004 [P] [US1] [US2] [US5] Migration `supabase/migrations/20260602120003_create_notification_rpcs.sql` — internal `enqueue_notification(p_recipient,p_type,p_params)` (SECURITY DEFINER, always writes history, `REVOKE EXECUTE FROM anon,authenticated`); client RPCs `register_notification_token`/`deregister_notification_token`/`mark_notification_read`/`mark_all_notifications_read`/`unread_notification_count` (SECURITY DEFINER, self-scoped on `auth.uid()`, `GRANT EXECUTE … TO authenticated`); per `contracts/phase22-notification-rpcs-and-enqueue.md`.
- [X] T005 [P] [US1] Migration `supabase/migrations/20260602120004_amend_account_decision_fanout.sql` — **re-base on the latest `20260510120001` body** (R-183), CREATE OR REPLACE `approve_account_approval_request`/`reject_account_approval_request` adding `PERFORM enqueue_notification(p_user_id,'account_approved'|'account_rejected','{}')` after the status write (NO reason in params — FR-004). Preserve all existing lines/grants — additive only.
- [X] T006 [P] [US1] Migration `supabase/migrations/20260602120005_amend_submit_inquiry_fanout.sql` — **re-base on the latest `20260527120009` body**, CREATE OR REPLACE `submit_inquiry` adding, after the inquiry INSERT, `select publisher_user_id … into v_publisher` then `PERFORM enqueue_notification(v_publisher,'inquiry_received', jsonb_build_object('listing_id',p_listing_id,'inquiry_id',v_inquiry_id))`. Same params/returns.
- [X] T007 [P] [US1] Migration `supabase/migrations/20260602120006_amend_invite_agency_member_fanout.sql` — **re-base on the latest `20260531120008` body**, CREATE OR REPLACE `invite_agency_member` adding `PERFORM enqueue_notification(v_target,'agency_invitation', jsonb_build_object('agency_id',p_agency_id))` after the `agency_members` INSERT. Same params/returns.
- [X] T008 [P] [US1] Migration `supabase/migrations/20260602120007_amend_listing_decision_fanout.sql` — **re-base on the latest `20260523120005` body** (service-role-only grants UNCHANGED), CREATE OR REPLACE `approve_listing_internal`/`reject_listing_internal` adding `PERFORM enqueue_notification(<publisher>,'listing_approved'|'listing_rejected', jsonb_build_object('listing_id',p_listing_id))` after the status UPDATE (NO reason — FR-004). Same params/returns.
- [X] T009 [P] [US2] [US5] Migration `supabase/migrations/20260602120008_create_fcm_vault_secret.sql` — idempotent `vault.create_secret(...)` for `fcm_service_account`, `push_dispatch_url`, `push_dispatch_token` reading from env/GUC (skip if env unset or secret present); NO plaintext key material in the file (ADR-0001, FR-018).
- [X] T010 [US2] Migration `supabase/migrations/20260602120009_enable_pg_net_push_dispatch.sql` — `create extension if not exists pg_net`; `notify_push_dispatch()` trigger fn (AFTER INSERT ON notifications) that reads `push_dispatch_url`/`push_dispatch_token` via `app_vault_secret` and `net.http_post`s the new row — **returns without posting if either secret is NULL** (degraded mode, FR-013); `revoke execute … from anon,authenticated`; `trg_notifications_push_dispatch` trigger. (DB-apply-order depends on T003/T004/T009.)
- [X] T011 [US2] Edge Function `supabase/functions/dispatch_push/index.ts` — per `contracts/phase22-dispatch-push-edge-function.md`: verify the dispatch token; read `fcm_service_account` via service-role (`{skipped:'no_provider'}` if null); check recipient `notifications_enabled` (`{skipped:'muted'}` — FR-021); resolve preferred language; render GENERIC bilingual copy by `type` (no reason — FR-004); select active tokens (`{skipped:'no_tokens'}`); POST FCM HTTP v1 with `data:{type,...params}`; prune UNREGISTERED tokens; never throw back into the trigger. Mirrors `supabase/functions/approve_listing/index.ts` runtime.
- [X] T012 [P] [US3] [US4] Migration `supabase/migrations/20260602120010_enable_realtime_publications.sql` — `alter publication supabase_realtime add table public.listings, public.reports, public.user_roles;` (+ REPLICA IDENTITY as needed). Row visibility stays governed by existing RLS (no policy change).
- [X] T013 [P] [US5] Migration `supabase/migrations/20260602120011_phase22_advisor_hardening.sql` — `ALTER FUNCTION … SET search_path = ''` confirmations on the new fns; resolve any advisor warning.
- [X] T014 [US5] Apply migrations T002–T010, T012, T013 in timestamp order via Supabase MCP `apply_migration` (memory `project_supabase_apply_via_mcp`); deploy `dispatch_push` (T011); register the three Vault secrets from env (only when push is being tested — omit to verify the degraded path); run `get_advisors` (no new RLS-disabled table; resolve any function-search-path warning); structural check (both tables RLS-on + writes REVOKEd; RPC grants; trigger present; `pg_publication_tables` shows the 3 adds). (Depends on T002–T013.) _(DONE 2026-06-02: all 12 migrations applied via MCP in degraded mode — Vault secrets OMITTED per SC-003; `dispatch_push` deployed ACTIVE v1 verify_jwt=false. Live verification: both tables RLS-on + 0 client write grants; 3 publication adds present; dispatch trigger present; all 13 fns have non-mutable search_path. **Added `20260602120012` (12th migration): structural check caught `enqueue_notification`/`notify_push_dispatch` still client-EXECUTE-able via Postgres PUBLIC default grant — `…003`'s `REVOKE FROM anon,authenticated` doesn't strip PUBLIC; `…012` revokes PUBLIC, re-verified anon/auth EXECUTE = false. Real-FCM two-device push path is Polish T043/T047, unverified here.)_

**Checkpoint**: backend live; `enqueue_notification` writes history on each transition; the dispatch trigger fires (or skips cleanly when unconfigured); Realtime publishes the 3 tables; advisors clean.

---

## Phase 3 — PD: Flutter domain + data + push abstraction + FCM dep [Wave 1]

**Goal**: the shared Dart contract (the provider-agnostic `PushMessagingService`, entities, repositories, use cases, datasources, DTOs, the FCM adapter + no-op fallback, the Firebase platform bootstrap, DI) that PN + PR import. Compiles/analyzes WITHOUT the DB applied (string-keyed Supabase access per `contracts/`) and **builds with push disabled** (FR-024).

**Independent test**: `flutter analyze` clean; `flutter build apk --debug` succeeds with NO Firebase config present (the no-op adapter binds); `injection.config.dart` registers the new repos/datasources/services.

- [X] T015 [P] [US2] `lib/core/messaging/push_messaging_service.dart` — domain-pure abstract `PushMessagingService` (`isAvailable`, `currentToken`, `onTokenRefresh`, `onMessage` [foreground], `onMessageOpenedApp` [tap from background], `initialMessage` [cold-start launch tap]) + `PushPayload` value object. NO SDK import (Principle IX).
- [X] T016 [P] [US1] Entities `lib/features/notifications/domain/entities/`: `notification_type.dart` (`NotificationType` enum, 6 values, `fromKey`/`key`), `app_notification.dart` (`AppNotification` + `isUnread`), `notification_deep_link.dart` (`NotificationDeepLink` target descriptor), `unread_count.dart` (`UnreadCount`).
- [X] T017 [P] [US2] Entity `lib/features/notifications/domain/entities/push_token.dart` (`PushToken`).
- [X] T018 [P] [US1] [US2] Abstract repos `lib/features/notifications/domain/repositories/notifications_repository.dart` (`loadPage`/`markRead`/`markAllRead`/`loadUnreadCount`) + `push_token_repository.dart` (`register`/`deregister`) — return `Result<T>`/`Failure`.
- [X] T019 [P] [US1] Use cases `lib/features/notifications/domain/usecases/`: `load_notifications.dart`, `mark_notification_read.dart`, `mark_all_notifications_read.dart`, `load_unread_count.dart`.
- [X] T020 [P] [US2] Use cases `lib/features/notifications/domain/usecases/`: `register_push_token.dart`, `deregister_push_token.dart`.
- [X] T021 [P] [US1] DTO `lib/features/notifications/data/dtos/app_notification_dto.dart` (↔ `notifications` row; json `params`).
- [X] T022 [US1] Datasource `lib/features/notifications/data/datasources/supabase_notifications_datasource.dart` — paginated `from('notifications').order('created_at',desc).range(…)`, `rpc('mark_notification_read'|'mark_all_notifications_read'|'unread_notification_count')`. (Depends on T016, T018, T021.)
- [X] T023 [US2] Datasource `lib/features/notifications/data/datasources/supabase_push_token_datasource.dart` — `rpc('register_notification_token'|'deregister_notification_token')`. (Depends on T017, T018.)
- [X] T024 [US2] `lib/features/notifications/data/datasources/fcm_push_messaging_service.dart` (`implements PushMessagingService` — the ONLY file importing `package:firebase_messaging`; maps FCM `onMessage`/`onMessageOpenedApp`/`getInitialMessage` → the interface streams/`initialMessage`) + `noop_push_messaging_service.dart` (`isAvailable()==false`, empty streams, `initialMessage()==null`). (Depends on T015.)
- [X] T025 [US1] [US2] Repo impls `lib/features/notifications/data/repositories/notifications_repository_impl.dart` + `push_token_repository_impl.dart` (`@LazySingleton(as:)`; map errors → `Failure`). (Depends on T022, T023.)
- [X] T026 [US2] Platform bootstrap: add `firebase_core` + `firebase_messaging` to `pubspec.yaml`; add the `google-services` Gradle plugin to `android/build.gradle(.kts)` + `android/app/build.gradle(.kts)` and the minimal `AndroidManifest.xml` entries (Android-only — Principle XI); guarded `Firebase.initializeApp` in `lib/main.dart` (try/catch → bind `NoopPushMessagingService` when config/init fails — R-195). App must still boot with `--dart-define-from-file=.env.json` (memory `project_dart_defines`).
- [X] T027 [US2] DI binding: register `PushMessagingService` → `FcmPushMessagingService` when available else `NoopPushMessagingService`; regenerate DI (`dart run build_runner build --delete-conflicting-outputs`); confirm `lib/core/di/injection.config.dart` registers the new repos/datasources/services; `flutter analyze` clean; `flutter build apk --debug` succeeds with push disabled (SC-003/SC-010). (Depends on T024, T025, T026.)

**Checkpoint**: notifications domain/data layer + push abstraction compile, are DI-wired, and the APK builds with push off; ready for PN + PR to import.

---

## Phase 4 — PN: Notification-center UI + push listener + app-bar bell + `/notifications` route + l10n [Wave 2 · depends on PD]

**Goal** (US1, US6): the in-app notification center reached from the home app-bar bell, newest-first with read/unread + deep-link-on-tap, an app-level push listener that routes taps + surfaces foreground pushes, fully localized + themed.

**Independent test**: trigger the six events; the bell badge increments; the center lists them newest-first; tapping each (in-app AND via a push) routes to the right screen + marks read; foreground push refreshes the badge with no duplicate banner; renders correct in all four (light/dark × ar/en) combinations.

- [ ] T028 [P] [US1] `lib/features/notifications/presentation/bloc/notifications_cubit.dart` — states (loading/list/paginating/error); drives `LoadNotifications`/`MarkNotificationRead`/`MarkAllNotificationsRead`; bounded pagination.
- [ ] T029 [P] [US1] `lib/features/notifications/presentation/bloc/notification_badge_cubit.dart` — unread count via `LoadUnreadCount`; refresh on mount + foreground-resume + when the push listener signals a foreground message (NOT a Realtime subscription — R-193).
- [ ] T030 [P] [US1] [US6] `lib/features/notifications/presentation/widgets/notification_tile.dart` — read/unread styling, relative time, type icon; Phase 2 tokens + direction-aware (no inline hex/font/padding).
- [ ] T031 [US1] `lib/features/notifications/presentation/widgets/notification_deep_link_resolver.dart` — maps `NotificationType`+`params` → pre-existing routes (account_approved→`AppRoutes.home`; account_rejected→Phase 5 rejected route; listing_approved→listing-details; listing_rejected→publisher My-Listings; inquiry_received→Phase 16 inquiries; agency_invitation→`/agency`); marks the notification read on navigation; graceful "content unavailable" fallback on unresolved target (FR-007/FR-018). (Imports PD `NotificationType`.)
- [ ] T032 [US1] `lib/features/notifications/presentation/pages/notification_center_page.dart` — newest-first list, unread styling, mark-all-read action, tap → resolver + `MarkNotificationRead`, empty/loading/error states. (Depends on T028, T030, T031.)
- [ ] T033 [US1] `lib/features/notifications/presentation/widgets/notification_bell_action.dart` — `IconButton` + unread-count badge from `NotificationBadgeCubit`, routes to `/notifications`. (Depends on T029.)
- [ ] T034 [US1] Route: `lib/core/routing/app_router.dart` — `AppRoutes.notifications='/notifications'` + `AppRouteNames.notifications` + a `GoRoute` (name+builder→`NotificationCenterPage`) in the authenticated branch of `buildAppRouter()`.
- [ ] T035 [US1] Insert `NotificationBellAction()` into `lib/features/home/presentation/pages/home_page.dart` AppBar `actions` — between `InquiriesAppBarAction()` and the admin-panel button (R-192). (Depends on T033, T034.)
- [ ] T036 [US1] [US2] App-level push listener `lib/features/notifications/presentation/widgets/notification_push_listener.dart` — subscribes to the PD `PushMessagingService` streams: `onMessageOpenedApp` + `initialMessage()` (cold-start) → route via `NotificationDeepLinkResolver` (marks read on nav — FR-012/SC-002); `onMessage` (foreground) → refresh `NotificationBadgeCubit`/center, OPTIONAL snackbar, NO duplicate system banner (FR-014). Registered at the app shell/router so it is live app-wide; inert when the no-op push adapter is bound (push unconfigured — FR-013). (Depends on PD T024 + T031, T029.)
- [ ] T037 [P] [US1] [US6] Add ~40 notification l10n keys (center labels, empty/loading/error, mark-all-read, relative-time, bell tooltip, the foreground/unavailable affordance strings) + the 6 GENERIC bilingual in-app copy templates (one per `type`) to BOTH `lib/l10n/app_ar.arb` + `lib/l10n/app_en.arb`; run gen-l10n (regenerates `app_localizations*.dart`).
- [ ] T038 [US1] DI regen (`dart run build_runner build --delete-conflicting-outputs`) for `NotificationsCubit` + `NotificationBadgeCubit` (+ the listener if DI-registered); wire the listener into the app shell/router; `flutter analyze` + l10n-parity clean. (Depends on T028–T037.)

**Checkpoint**: bell + badge on home; center lists + paginates + marks read; in-app AND push taps deep-link correctly; foreground push surfaces without a duplicate banner; localized + themed.

---

## Phase 5 — PR: Realtime wiring — token lifecycle + permission refresh + admin counters [Wave 2 · depends on PD]

**Goal** (US2, US3, US4): register/deregister the push token on auth transitions, add the 4th PermissionChecker observation point on `user_roles`, and make the admin dashboard counters re-fetch live on `listings`/`reports` changes.

**Independent test**: token row appears on login / disappears on logout (multi-device); granting a role on device B updates device A's UI without re-login; admin counters move on a second device without refresh and reconcile after a reconnect.

- [X] T039 [US2] Amend `lib/features/auth/presentation/bloc/auth_bloc.dart` — on the `Authenticated` transition call `RegisterPushToken(currentToken)` **regardless of `account_status`** (R-191) + subscribe `PushMessagingService.onTokenRefresh` → re-register; on `Unauthenticated`/logout call `DeregisterPushToken(currentToken)`. (Imports PD `RegisterPushToken`/`DeregisterPushToken` + `PushMessagingService`.)
- [X] T040 [US4] Amend `lib/features/auth/presentation/bloc/auth_bloc.dart` — add the **4th observation point**: a `SupabaseClientWrapper.realtimeChannel('user_roles')` subscription filtered to `user_id=eq.<auth.uid()>` that calls `_permissionChecker.refresh()` on INSERT/UPDATE/DELETE; tear down on logout. Leaves the existing three points intact (FR-017). (Same file as T039 — sequential, not `[P]`.) (Depends on T039.)
- [X] T041 [US3] Amend `lib/features/admin/dashboard/presentation/bloc/dashboard_cubit.dart` — open `realtimeChannel` on `listings` + `reports`; on a relevant change call the existing `refresh()` (debounced) to re-fetch `admin_dashboard_counts`; reconcile on (re)subscribe; tear down on close (FR-015/FR-016). (Different file from T039/T040 — `[P]`.)
- [X] T042 [US2] [US3] DI regen (`dart run build_runner build --delete-conflicting-outputs`) for any new realtime-helper service; `flutter analyze` clean. (Depends on T039–T041.)

**Checkpoint**: token lifecycle works; permissions refresh live; admin counters move + reconcile.

---

## Phase 6: Polish & Cross-Cutting Verification [post-Wave 2, sequential]

**Purpose**: the cross-cutting QA pass (US5 security, US6 l10n/theme, SC-001..SC-011). No production-file mods — verification only; on-device walk mandatory (memory `project_wave_output_needs_device_qa`, two-device for push + counters per `feedback_avd_acceptable_qa`).

- [ ] T043 [US1] [US2] Two-device walk: trigger all six events → each lands once in the recipient's center ≤5 s with a working deep link (SC-001); with push configured, a system push arrives on device A ≤10 s incl. a cold-start tap (SC-002); verify exactly-once on retry (SC-009); the unread **badge count matches** unread rows and mark-read (single + all) updates it + history persists across logout/login and a fresh reinstall on a second device (SC-008); a token is **registered on login / removed on logout** and with two devices both receive push while logging out one leaves the other (SC-011).
- [ ] T044 [US3] [US4] Two-device walk: admin counters (pending listings, reports) move ≤5 s with no refresh + reconcile after a forced network drop (SC-004); granting/revoking a role on device B updates device A's gated UI without re-login (SC-005); confirm the existing 3 observation points still work.
- [ ] T045 [US2] Degraded mode: with NO Vault secrets registered (Firebase "blocked"), `flutter build apk --debug` succeeds and all six events still deliver in-app (center + badge) with no error/crash; `notify_push_dispatch` skips silently and the no-op push adapter binds (SC-003).
- [ ] T046 [US5] Wire-level security: from user X's session, reading/writing user Y's `notifications`/`notification_tokens` and inserting a notification for Y are all DENIED; `grep -ri "fcm_service_account\|push_dispatch_token" lib/ android/ supabase/functions/dispatch_push` shows only Vault *reads* (no key material) and the built APK contains no service-account JSON or dispatch token; non-admin Realtime delivers no admin rows (SC-007). Confirm `notifications_enabled=false` mutes push but still writes history (FR-021).
- [ ] T047 [US6] Four-combination render (light/dark × ar-RTL/en-LTR) of the center (list, tile, unread badge, empty/loading/error) + the bell on the Infinix Note 8 + a 412 dp Pixel 8 Pro AVD; push-tray text appears in the recipient's preferred language (default Arabic), and the OS-tray body is GENERIC (no rejection reason — FR-004) while the full reason shows in-app (SC-006).
- [ ] T048 [US5] Structural/dependency gates + full verify suite: `grep "package:firebase" lib/features/*/domain lib/core` shows the SDK only in `notifications/data` and the interface in `lib/core/messaging` (none under any `domain/` — Principle IX); no iOS/Web files; Android-only config; no new permission key; backend surface = the enumerated set (2 tables, enqueue+client RPCs, 4 amendments, the 3 Vault secrets, `pg_net`+trigger+`dispatch_push`, 3 publication adds) — and nothing else; `dart run build_runner build` clean; full CI suite (analyze + format + design-tokens + l10n-parity + l10n-literals + SDK-boundary — memory `project_wave_run_full_verify_suite`) passes (SC-010). Execute `quickstart.md` end-to-end; reconcile spec/plan/data-model/contracts if any real behavior diverged (Principle X).

---

## Dependencies & Execution Order

### Phase Dependencies (wave phases)
- **Setup (P1)**: no deps; folds into Wave 1.
- **PB (P2)** and **PD (P3)**: no code edge between them — both implement the shared `contracts/` interface; run in parallel (Wave 1). Internally, PB's T014 (apply) depends on T002–T013; PB's T010 references T003/T004/T009 at DB-apply time; PD's T022–T027 depend on T015–T021.
- **PN (P4)** and **PR (P5)**: each depends on PD (Wave 1) only, not on each other; run in parallel (Wave 2).
- **Polish (P6)**: after PN + PR merge + PB applied + `dispatch_push` deployed; sequential QA.

### Within-phase parallelism
- PB: T002–T009, T012, T013 are `[P]` (distinct new migration files); T010→T011 (trigger then fn), T014 is the apply gate.
- PD: T015–T021 are `[P]` (distinct domain/dto files); T022/T023/T024 then T025; T026 (platform) parallel to T022–T025; T027 is the DI/build gate.
- PN: T028/T029/T030/T037 are `[P]`; T031→T032; T033 depends on T029; T034→T035; T036 (push listener) depends on T031 + T029 (+ PD T024); T038 is the DI/wiring gate.
- PR: T039→T040 (same file `auth_bloc.dart`, sequential); T041 is `[P]` (different file); T042 is the DI gate.

---

## Implementation Strategy

**MVP** = PB + PD + PN (US1 in-app notifications + center) → users are told what happened to them, fully in-app, with NO dependency on the sanctions-risky push channel. PR (US2 token lifecycle / US3 counters / US4 permission refresh) and the FCM send path then layer on push + live signals. US5 (security) is built into PB/PD and verified in Polish; US6 (l10n/theme) is built into PN and verified in Polish.

**Wave execution** (`/wave all --auto`): dispatch Wave 1 (PB, PD) → merge PD then PB (PB merges independently — see Touch-Fan) → dispatch Wave 2 (PN, PR) → merge PN then PR → run Polish QA. See the Wave Plan below.

---

# ════════ Multi-Agent Execution Plan (for `/wave`) ════════

## Touch-Fan Table

Shared/cross-cutting files each phase modifies (orchestrator: warn sub-agents up front + merge least-touch-first):

- **Setup (P1)**: *(none shared)* — creates empty `lib/features/notifications/**` + `lib/core/messaging/` folders only.
- **PB (Backend)**: `supabase/migrations/20260602120001…011_*.sql` (11 NEW files) · `supabase/functions/dispatch_push/index.ts` (NEW) — **no shared-repo-file contention** (the 4 transition amendments are NEW CREATE-OR-REPLACE migrations, NOT edits to the Phase 5/12/16/19 files).
- **PD (Domain+Data+bootstrap)**: `lib/core/messaging/**` + `lib/features/notifications/{domain,data}/**` (new) · **`pubspec.yaml`** · **`pubspec.lock`** · **`lib/main.dart`** · **`android/build.gradle(.kts)`** · **`android/app/build.gradle(.kts)`** · **`android/app/src/main/AndroidManifest.xml`** · **`lib/core/di/injection.config.dart`** (codegen).
- **PN (Center UI + push listener)**: `lib/features/notifications/presentation/**` (new — incl. `notification_push_listener.dart`) · **`lib/core/routing/app_router.dart`** (route + listener wiring) · **`lib/features/home/presentation/pages/home_page.dart`** · **`lib/l10n/app_ar.arb`** · **`lib/l10n/app_en.arb`** · `lib/l10n/app_localizations*.dart` (gen) · **`lib/core/di/injection.config.dart`** (codegen).
- **PR (Realtime wiring)**: **`lib/features/auth/presentation/bloc/auth_bloc.dart`** · **`lib/features/admin/dashboard/presentation/bloc/dashboard_cubit.dart`** · (optional) a new realtime-helper file · **`lib/core/di/injection.config.dart`** (codegen).
- **Polish (P6)**: *(none)* — verification only.

**Contended files**: `lib/core/di/injection.config.dart` (PD, PN, PR) is the ONLY cross-phase contention. ARBs (`app_ar.arb`+`app_en.arb`) are touched by **PN only**; `pubspec`/`main.dart`/`android/**` by **PD only**; `auth_bloc.dart`+`dashboard_cubit.dart` by **PR only**; `app_router.dart`+`home_page.dart` by **PN only**. PN and PR touch **disjoint** files outside `injection.config.dart`.
**Merge least-touch-first**: **PB** (0 shared repo files) → **PD** (DI + its own platform files) → **PN** (DI + ARB + routing/home) → **PR** (DI + auth/dashboard). Each successor rebases on the merged predecessor, re-runs `dart run build_runner build --delete-conflicting-outputs` (regenerates `injection.config.dart`), and re-runs the full verify suite (l10n-parity especially after PN). Per `project_wave_worktree_base`/`project_wave_merge_cascade_gotchas`: sub-agents `git reset --hard origin/022-notifications-realtime` first; verify ancestry before merge; re-anchor orchestrator CWD to repo root before each merge.

## Dependency Audit

Re-reading `plan.md` § Phase Dependencies — every declared edge, with the named consumer (false deps removed):

- **PN → PD**: ✅ REAL — `lib/features/notifications/presentation/bloc/notifications_cubit.dart` + `notification_badge_cubit.dart` import the abstract `NotificationsRepository` + the use cases `LoadNotifications`/`MarkNotificationRead`/`MarkAllNotificationsRead`/`LoadUnreadCount`; `notification_center_page.dart`/`notification_tile.dart` import the entities `AppNotification`/`NotificationType`/`UnreadCount`; `notification_deep_link_resolver.dart` consumes the `NotificationType` enum; and `notification_push_listener.dart` consumes the `PushMessagingService` streams (`onMessageOpenedApp`/`initialMessage`/`onMessage`, T015/T024) — all defined by PD (T015–T019, T024).
- **PR → PD**: ✅ REAL — `lib/features/auth/presentation/bloc/auth_bloc.dart` (PR's amendment) imports the use cases `RegisterPushToken`/`DeregisterPushToken` (T020) and the `PushMessagingService` interface (`onTokenRefresh`, T015) — all defined by PD.
- **PB → (none)**: no Dart symbol crosses out of PB. Its relationships to PD are **runtime contracts** (datasource calls `rpc('register_notification_token'…)` / `from('notifications')` by string — compiles without PB). **Not a build edge.**
- **PD → (none)**: PD has NO Dart import from PB; the DB names are string-keyed. **No edge.**
- **PN ↔ PR**: NO edge — both consume PD; PR additionally uses **pre-existing** `SupabaseClientWrapper.realtimeChannel` (Phase 1/4), `PermissionChecker.refresh` (Phase 6), `DashboardCubit.refresh` (Phase 20). PN's push listener consumes the SAME PD `PushMessagingService` streams as PR's token-refresh — both depend on PD, not on each other. PN's unread badge is **fetch-on-open / foreground-refresh** (R-193), NOT PR's Realtime. Neither imports the other.
- **Setup → ***: NO code edge — Setup only creates folders (no exported symbol). Folds into Wave 1.

**Result**: exactly **2** real edges (PN→PD, PR→PD), both with named consumers. **0** false/pessimistic edges. Graph is minimal.

## Wave Plan

Topological sort of the dispatchable phases (Setup folds into Wave 1; Polish is post-merge QA):

- **Wave 1**: **PB, PD** — no unmet deps (Setup folds in; both implement the shared contract).
- **Wave 2**: **PN, PR** — all deps (PD) satisfied by Wave 1.
- **Post-wave**: **Polish (P6)** — sequential two-device on-device QA after PN+PR merge + PB applied + `dispatch_push` deployed (not a parallel dispatch).

Both waves ≤ 4 phases (2 each) — cap respected. Execute with `/wave all --auto`; the orchestrator does NOT need to re-derive this.

## Model Routing per Phase

- **Setup (P1)**: Sonnet (folder scaffold).
- **PB (Backend)**: **Opus** — RLS + REVOKE posture + SECURITY DEFINER `enqueue_notification`/client RPCs, the four re-based transition fan-out amendments (atomic, exactly-once, re-base discipline), the `pg_net` dispatch trigger + degraded-mode skip, the Vault-secret handling, and the Realtime publication. Security invariants / RLS / atomic multi-step writes → Opus per the heuristic.
- **PD (Domain+Data+bootstrap)**: Sonnet — entities, DTOs, repository/datasource scaffolding, the FCM adapter + no-op fallback, guarded Firebase init, DI codegen. No ledger/posting/state-machine. (Care on the degraded-mode init, but it's branchy config, not an invariant.)
- **PN (Center UI + push listener)**: Sonnet — center page, tile, bell+badge, deep-link resolver, the push listener (stream→navigation glue), route, l10n. UI/navigation scaffolding.
- **PR (Realtime wiring)**: **Opus** — amends the load-bearing `AuthBloc` (auth-state transitions + Realtime **subscription lifecycle** + token register/deregister + the permission-cache 4th observation point) and the admin counter **reconnect/reconcile** logic. State-machine + concurrency → Opus per the heuristic.
- **Polish (P6)**: Sonnet — two-device QA, wire-level checks, linter suite, docs reconciliation.

Format line: `PB: Opus (RLS + SECURITY DEFINER enqueue/RPCs + re-based fan-out + pg_net dispatch). PD: Sonnet (entities/DTOs/FCM adapter/DI/bootstrap). PN: Sonnet (center + bell + push listener + deep-link + l10n). PR: Opus (auth-state + Realtime subscription lifecycle + permission-cache refresh + counter reconcile). Setup/Polish: Sonnet.`

---

## Notes
- `[P]` = different files, no incomplete-task dependency.
- `[US#]` maps each task to its user story for traceability (phases are wave units, not per-story).
- **Every dispatched sub-agent flips its `- [ ] T<id>` → `- [X] T<id>` in the same commit as the implementation** — never a deferred cleanup pass.
- No new automated tests (memory `feedback_no_new_tests`); verification is the on-device walk (two-device for push + counters) + wire/SQL checks in `quickstart.md`, recorded against SC-001..SC-011 (every SC now has a named verifying task — T043 covers SC-001/002/008/009/011, T044 SC-004/005, T045 SC-003, T046 SC-007, T047 SC-006, T048 SC-010).
- Backend applied via Supabase MCP, not `db push` (memory `project_supabase_apply_via_mcp`); MCP doesn't dedupe by name, so SQL is idempotent (memory `project_supabase_mcp_apply_migration`).
- The four transition amendments (T005–T008) MUST be re-based on the latest function body before editing (R-183, mirroring Phase 19 R-143) — read the current definition first, preserve every line, insert only the `enqueue_notification` PERFORM.
