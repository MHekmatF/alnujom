# Implementation Plan: Push Notifications + Supabase Realtime Signals (Phase 22)

**Branch**: `022-notifications-realtime` (spec tracked via `.specify/feature.json` → `specs/022-notifications-realtime`) | **Date**: 2026-06-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/022-notifications-realtime/spec.md`

## Summary

Phase 22 ships the **notification + live-signal layer**: every signed-in user gets told (in-app, and as device push when available) when their account is approved/rejected, their listing is approved/rejected, an inquiry lands on their listing, or they're invited to an agency; and the admin dashboard's pending-listing + reports counters move on their own. The design is **provider-agnostic** — in-app delivery + the notification center + Realtime ALWAYS work, and device push is a **pluggable** channel (FCM v1 adapter) that **degrades silently** when Firebase is unreachable/unconfigured (the plan's flagged Syria sanction risk; spec FR-013). All notifications funnel through one server-side `enqueue_notification(...)` definer call hung off the existing transition RPCs, which writes exactly **one** `notifications` history row (the in-app, always-works path); a `pg_net` trigger on that insert fires the `dispatch_push` Edge Function, which reads the `fcm_service_account` Vault secret, looks up the recipient's registered device tokens, renders the tray copy in the recipient's preferred language, and POSTs to FCM — no-opping gracefully when the secret/tokens are absent (degraded mode). The in-app center is reached from a **bell + unread badge in the home app bar** (`/notifications`), and Realtime is enabled on `listings` + `reports` (admin counters) and `user_roles` (the **fourth** PermissionChecker observation point Phase 6 deferred here).

**Backend** (11 migrations `20260602120001`–`…011` + 1 Edge Function): two new tables — `notification_tokens` (self-RLS device registrations) and `notifications` (self-RLS per-user history) — both client-write-REVOKEd (RPC-only, matching the Phase 18/19/21 posture); a SECURITY DEFINER `enqueue_notification(...)` writer + client RPCs (`register_notification_token` / `deregister_notification_token` / `mark_notification_read` / `mark_all_notifications_read`); CREATE-OR-REPLACE amendments hanging `enqueue_notification` off the four existing transition paths (`approve_account_approval_request` / `reject_account_approval_request`, `submit_inquiry`, `invite_agency_member`, `approve_listing_internal` / `reject_listing_internal` — re-based on their latest bodies); the `fcm_service_account` Vault secret registered from an env var (no plaintext, ADR-0001); `pg_net` enabled + a `notify_push_dispatch()` trigger on `notifications`; the `dispatch_push` Edge Function (Vault-read FCM sender, mirrors the Phase 12 JWT→service-role runtime); Realtime publication on `listings` / `reports` / `user_roles`; advisor hardening. **Frontend** (`lib/features/notifications/` + 4 amended files): the shared domain/data layers including a provider-agnostic `PushMessagingService` abstraction (FCM adapter + no-op fallback in `data/`, Principle IX), the notification-center surface + app-bar bell, and the Realtime wiring (token register/deregister + `user_roles` permission refresh in `AuthBloc`; counter refresh in `DashboardCubit`). **One justified new dependency** (`firebase_core` + `firebase_messaging`, data-layer only, app builds with push disabled — FR-024); **one new Postgres extension** (`pg_net`, for the push-dispatch webhook); **no new permission key**, **no §9.1 catalog change**, **no new audited action** (the four transitions are already audited in their own phases), **no existing-table change** beyond the three Realtime publication adds.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase); PL/pgSQL; Deno/TypeScript (Edge Function)
**Primary Dependencies**: `supabase_flutter`, `flutter_bloc`, `get_it` + `injectable`, `go_router`, `equatable`, `intl`, `cached_network_image` (ALL already present) **plus NEW `firebase_core` + `firebase_messaging`** (the pluggable FCM adapter — the one justified new client dep per FR-024, confined to `lib/features/notifications/data/` behind the `PushMessagingService` interface; the app builds + runs with push unconfigured)
**Storage**: Supabase Postgres — 2 NEW tables (`notification_tokens`, `notifications`), ~6 NEW SECURITY DEFINER functions/RPCs (`enqueue_notification` writer + 4 client RPCs + `notify_push_dispatch` trigger fn), CREATE-OR-REPLACE amendments to 6 existing transition RPCs, 1 NEW Vault secret (`fcm_service_account`), `pg_net` enabled, Realtime publication on 3 existing tables. NO change to the §9.1 permission catalog, no new permission key, no new `listings.status`/`lead_events` change (FR-025).
**Testing**: Manual on-device verification — two devices for push + counters (Infinix Note 8 + Pixel 8 Pro AVD) per the no-new-tests MVP convention (memory `feedback_no_new_tests`, `feedback_avd_acceptable_qa`); SQL/RPC wire-level RLS checks; repo/artifact grep for the FCM secret; `flutter analyze` + the full CI linter suite (format / design-tokens / l10n-parity / l10n-literals / SDK-boundary — memory `project_wave_run_full_verify_suite`)
**Target Platform**: Android (minSdk per project); Arabic-first RTL + English LTR. Firebase/`google-services` config is Android-only (Principle XI); NO iOS/Web.
**Project Type**: Mobile app (Flutter) + Supabase backend — the established two-tree layout
**Performance Goals**: in-app delivery is a synchronous single-row INSERT inside the existing transition txn (no added round-trip on the admin's action path); push dispatch is **async** (trigger → `pg_net` → Edge Function), off the actor's critical path; the notification-center list read is bounded/paginated (FR-006); the unread badge is fetch-on-open + refresh-on-resume (NOT a Realtime subscription — Realtime is reserved for admin counters + permission refresh); admin counters re-fetch via the existing `admin_dashboard_counts` RPC on a debounced Realtime event (no per-row client math)
**Constraints**: provider-agnostic core — push is pluggable and degrades silently with no user-visible error when Firebase/Vault-secret is absent (FR-010/FR-013); FCM service-account is a Vault secret only, never committed/shipped (FR-018, ADR-0001); self-only RLS on both new tables, fan-out via controlled definer path, no client forge (FR-019/FR-020); the global `notifications_enabled` flag mutes push + active alerts but history is still written (FR-021, clarified 2026-06-02); OS-tray copy is generic (no moderator free-text on the lock screen — FR-004, clarified); domain stays provider-agnostic (no push SDK in `domain/`, Principle IX — FR-024); no new permission key / no §9.1 change / no new audited action (FR-025)
**Scale/Scope**: 11 migrations + 1 Edge Function; 1 Flutter feature tree (`lib/features/notifications/` — domain + data + presentation); 4 amended Flutter files (`auth_bloc.dart`, `dashboard_cubit.dart`, `home_page.dart`, `app_router.dart`) + platform bootstrap (`main.dart`, `pubspec.yaml`, `android/`); 1 new route (`/notifications`); ~40 l10n keys + 6 bilingual notification-copy templates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development | ✅ Pass | spec.md + 8 clarifications complete before this plan; data-model / contracts / quickstart accompany it |
| II. Source-Controlled Backend | ✅ Pass | 11 migration files + 1 Edge Function under `supabase/`; the `fcm_service_account` secret is registered via a migration reading an env var (no plaintext); `pg_net` enablement + the Realtime publication adds are checked-in migrations; applied via Supabase MCP per `project_supabase_apply_via_mcp`; no Studio-only changes (no dashboard Database Webhook — the trigger is SQL) |
| III. Security-First Supabase | ✅ Pass | RLS on both new tables; ALL client writes REVOKEd (RPC-only); `notifications`/`notification_tokens` self-only read; fan-out writes ONLY via the `enqueue_notification` definer path (no client forge); FCM secret in Vault read server-side only; `dispatch_push` re-checks via service-role; admin Realtime governed by existing RLS — checks-at-both-ends (FR-018/019/020) |
| IV. Clean Architecture | ✅ Pass | `lib/features/notifications/{domain,data,presentation}`; `supabase_flutter` + `firebase_messaging` confined to `data/`; business rules (deep-link resolution, read-state) in use cases |
| V. Arabic-First Localization | ✅ Pass | ~40 new keys in both ARBs; the 6 notification-copy templates exist in `ar` + `en`; in-app copy follows the active locale, push tray copy is server-rendered in the recipient's preferred language (FR-004, FR-022); RTL-safe center + bell badge |
| VI. Theme System | ✅ Pass | Phase 2 tokens only; no inline hex/font/padding (FR-023); center list, tile, unread badge, empty/error states themed |
| VII. Dynamic Roles & Permissions | ✅ Pass | No new permission key, no §9.1 change (FR-025); admin counters reuse existing admin permissions; the `user_roles` Realtime refresh makes permission grants/revokes take effect live (strengthens VII); notification fan-out adds no new audited action (the 4 transitions are already audited in Phases 5/12/16/19) |
| VIII. Approval Workflow & Identity | ✅ Pass | No approval/identity mutation; Phase 22 *notifies about* existing approval transitions. OS-tray copy is generic so moderator free-text (rejection reasons) never leaks to a lock screen (FR-004) — reinforces the admin-only-private-fields posture |
| IX. Future Backend Portability | ✅ Pass | `NotificationsRepository` / `PushTokenRepository` / `PushMessagingService` interfaces in `domain/` (or `core/`); `supabase_flutter` + `firebase_messaging` only in `data/`; Realtime consumed via the existing `SupabaseClientWrapper.realtimeChannel()` wrapper (no raw SDK in features) |
| X. Testable AI Workflow | ✅ Pass | Per-FR / per-SC verification map in data-model + quickstart; the plan's §6.2 omission of a `notifications` table and the §6.7 "Edge Function fan-out" wording vs the SQL-`enqueue` + `pg_net`-dispatch reality are recorded (research R-181, R-185) and reconciled into the spec |
| XI. Android-First MVP | ✅ Pass | Firebase config + `google-services` + manifest changes are Android-only; no iOS/Web; the app builds with push disabled (FR-024) |
| XII. No Hidden Decisions | ✅ Pass | 8 clarifications resolved in spec; every plan-time choice recorded as a locked decision (research R-181..R-196) with rejected alternatives |

**Gate result**: PASS — no violations. The new client dependency (`firebase_*`) and new Postgres extension (`pg_net`) are feature-justified, scoped, and documented (research R-184, R-185), not constitution violations — no Complexity Tracking rows required.

## Project Structure

### Documentation (this feature)

```text
specs/022-notifications-realtime/
├── plan.md              # This file
├── research.md          # Phase 0 — locked decisions R-181..R-196
├── data-model.md        # Phase 1 — full migration SQL + Dart entities + per-FR/SC map
├── quickstart.md        # Phase 1 — end-to-end manual verification recipe (two-device)
├── contracts/           # Phase 1 — 6 interface contracts
│   ├── phase22-notification-tokens-table.md
│   ├── phase22-notifications-table.md
│   ├── phase22-notification-rpcs-and-enqueue.md
│   ├── phase22-transition-fanout-amendments.md
│   ├── phase22-dispatch-push-edge-function.md
│   └── phase22-realtime-and-ui-entry-points.md
├── checklists/
│   └── requirements.md  # spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 — (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/notifications/                # NEW — notifications feature tree
├── domain/
│   ├── entities/        # AppNotification, NotificationType (enum), NotificationDeepLink,
│   │                    #   PushToken, UnreadCount
│   ├── repositories/    # NotificationsRepository, PushTokenRepository (abstract)
│   └── usecases/        # LoadNotifications, MarkNotificationRead, MarkAllNotificationsRead,
│                        #   LoadUnreadCount, RegisterPushToken, DeregisterPushToken
├── data/
│   ├── datasources/     # SupabaseNotificationsDatasource, SupabasePushTokenDatasource,
│   │                    #   FcmPushMessagingService (FCM adapter), NoopPushMessagingService
│   ├── dtos/            # AppNotificationDto
│   └── repositories/    # NotificationsRepositoryImpl, PushTokenRepositoryImpl
└── presentation/
    ├── bloc/            # NotificationsCubit (center), NotificationBadgeCubit (unread count)
    ├── pages/           # NotificationCenterPage
    └── widgets/         # notification_tile.dart, notification_bell_action.dart,
                         #   notification_deep_link_resolver.dart

lib/core/messaging/                        # NEW — provider-agnostic push abstraction (Principle IX)
└── push_messaging_service.dart            # abstract PushMessagingService (domain-pure interface)

lib/features/auth/presentation/bloc/
└── auth_bloc.dart                          # AMENDED — register/deregister token on auth transition;
                                            #   4th observation point (user_roles Realtime → PermissionChecker.refresh)

lib/features/admin/dashboard/presentation/bloc/
└── dashboard_cubit.dart                    # AMENDED — subscribe listings+reports Realtime → refresh()

lib/features/home/presentation/pages/
└── home_page.dart                          # AMENDED — NotificationBellAction in AppBar actions

lib/core/routing/
└── app_router.dart                         # AMENDED — notifications route/name + GoRoute under authed shell

lib/l10n/{app_ar.arb, app_en.arb}          # AMENDED — ~40 notification keys
lib/main.dart                              # AMENDED — guarded Firebase.initializeApp (no-op when unconfigured)
pubspec.yaml                               # AMENDED — firebase_core + firebase_messaging (data-layer only)
android/                                   # AMENDED — google-services gradle + (minimal) manifest (Android-only)

supabase/migrations/
├── 20260602120001_create_notification_tokens.sql          # PB
├── 20260602120002_create_notifications.sql                # PB
├── 20260602120003_create_notification_rpcs.sql            # PB (enqueue + client RPCs)
├── 20260602120004_amend_account_decision_fanout.sql       # PB
├── 20260602120005_amend_submit_inquiry_fanout.sql         # PB
├── 20260602120006_amend_invite_agency_member_fanout.sql   # PB
├── 20260602120007_amend_listing_decision_fanout.sql       # PB
├── 20260602120008_create_fcm_vault_secret.sql             # PB
├── 20260602120009_enable_pg_net_push_dispatch.sql         # PB
├── 20260602120010_enable_realtime_publications.sql        # PB
└── 20260602120011_phase22_advisor_hardening.sql           # PB

supabase/functions/
└── dispatch_push/index.ts                                 # PB — Vault-read FCM sender (pluggable)
```

**Structure Decision**: Established two-tree layout (Flutter `lib/features/` + Supabase `supabase/`). The new `lib/features/notifications/` tree mirrors the Phase 16 `inquiries/` + Phase 19 `agency/` Clean-Arch shape. The provider-agnostic `PushMessagingService` interface lives in `lib/core/messaging/` (domain-pure, so the FCM SDK never reaches any feature `domain/` — Principle IX), with its FCM adapter and no-op fallback in `notifications/data/datasources/`. Migration timestamps continue the series after Phase 21's last (`20260601120015`), starting at `20260602120001`.

## Implementation Phases

> Phase 22 is one PR, decomposed into **four** implementation phases so `/wave` fans out **two wide waves**. The split is along the build-edge boundary: **PB** (all SQL + the Edge Function) and **PD** (Flutter domain+data + the push abstraction + the FCM dep) implement the shared contract from `data-model.md`/`contracts/` and share NO Dart symbol, so they run in parallel; **PN** (notification-center UI + bell + route) and **PR** (Realtime wiring: token register/deregister + `user_roles` permission refresh + admin-counter refresh) each import PD's Dart symbols but not each other's, so they run in parallel after PD.

### PB — Backend: tables, enqueue + client RPCs, transition fan-out amendments, Vault secret, pg_net dispatch, Realtime, Edge Function (11 migrations + 1 fn)
All SQL under `supabase/migrations/` + one Edge Function. (1) `notification_tokens` — `id`, `user_id` (FK auth.users), `token` (TEXT), `platform` CHECK∈('android'), `is_active`, `last_seen_at`, `created_at`; UNIQUE `(user_id, token)`; RLS on; self SELECT `USING (user_id = auth.uid())`; `REVOKE INSERT,UPDATE,DELETE … FROM authenticated, anon` (writes via RPC). (2) `notifications` — `id`, `recipient_user_id` (FK), `type` CHECK∈(account_approved, account_rejected, listing_approved, listing_rejected, inquiry_received, agency_invitation), `params` JSONB (deep-link IDs + render params), `read_at` (nullable), `created_at`; RLS on; self SELECT `USING (recipient_user_id = auth.uid())`; REVOKE writes; index `(recipient_user_id, created_at DESC)` + partial `(recipient_user_id) WHERE read_at IS NULL`. (3) `enqueue_notification(p_recipient UUID, p_type TEXT, p_params JSONB)` SECURITY DEFINER — INSERTs one `notifications` row (always, regardless of `notifications_enabled` — FR-021); REVOKE EXECUTE from anon/authenticated (internal, called only by the definer transition fns). Client RPCs (SECURITY DEFINER, re-check `auth.uid()`): `register_notification_token(p_token TEXT, p_platform TEXT)` (upsert on `(user_id, token)`, set `is_active`), `deregister_notification_token(p_token TEXT)` (this device only), `mark_notification_read(p_id UUID)` (own row only), `mark_all_notifications_read()`; a read helper/view for the bounded list + unread count. (4) CREATE-OR-REPLACE the four transition paths, **re-based on their latest bodies**, adding one `PERFORM enqueue_notification(...)` after the status write: `approve_account_approval_request`/`reject_account_approval_request` (`20260510120001` body → recipient = `p_user_id`); `submit_inquiry` (`20260527120009` body → recipient = `listings.publisher_user_id` for `p_listing_id`); `invite_agency_member` (`20260531120008` body → recipient = the resolved invitee `v_target`); `approve_listing_internal`/`reject_listing_internal` (`20260523120005` body → recipient = the listing's `publisher_user_id`). (5) `fcm_service_account` Vault secret via `vault.create_secret(current_setting('app.settings.fcm_service_account', true), 'fcm_service_account', …)` reading an env/GUC — idempotent, no plaintext (ADR-0001); also `push_dispatch_url` + `push_dispatch_token` secrets the trigger needs. (6) enable `pg_net`; `notify_push_dispatch()` trigger fn (AFTER INSERT ON `notifications`) that reads the dispatch URL/token via `app_vault_secret` and `net.http_post`s the new row to `dispatch_push` — **skips silently if any secret is NULL** (degraded mode, FR-013). (7) `dispatch_push/index.ts` Edge Function — service-role, reads `fcm_service_account` via `app_vault_secret`, checks the recipient's `notifications_enabled` (skip push if off — FR-021), resolves the recipient's preferred language, renders the generic bilingual tray copy by `type` (NO free-text reason — FR-004), looks up active `notification_tokens`, POSTs FCM v1; no-ops cleanly if the secret/tokens are absent. (8) `ALTER PUBLICATION supabase_realtime ADD TABLE public.listings, public.reports, public.user_roles;` + `REPLICA IDENTITY` as needed. (9) advisor hardening (search_path on new fns). Apply in timestamp order via Supabase MCP; run `get_advisors` after.
**Touch fan**: `supabase/migrations/20260602120001..011_*.sql` (11 new files), `supabase/functions/dispatch_push/index.ts` (new). No shared-repo-file contention (amendments are new CREATE-OR-REPLACE migrations, NOT edits to the Phase 5/12/16/19 files).

### PD — Flutter domain + data + push abstraction + FCM dependency + DI
Build `lib/core/messaging/push_messaging_service.dart` (abstract `PushMessagingService`: `Future<String?> currentToken()`, `Stream<String> onTokenRefresh()`, `Stream<PushPayload> onMessage()`, `Future<bool> isAvailable()` — domain-pure, no SDK import). Build `lib/features/notifications/domain/` (entities `AppNotification`, `NotificationType` enum [6 values + deep-link mapping], `NotificationDeepLink`, `PushToken`, `UnreadCount`; abstract `NotificationsRepository` [`loadPage`, `markRead`, `markAllRead`, `loadUnreadCount`] + `PushTokenRepository` [`register`, `deregister`]; use cases `LoadNotifications`/`MarkNotificationRead`/`MarkAllNotificationsRead`/`LoadUnreadCount`/`RegisterPushToken`/`DeregisterPushToken`). Build `lib/features/notifications/data/` (`AppNotificationDto`; `SupabaseNotificationsDatasource` selecting `notifications` paginated + calling `mark_notification_read`/`mark_all_notifications_read` + unread count; `SupabasePushTokenDatasource` calling `register_notification_token`/`deregister_notification_token`; `FcmPushMessagingService implements PushMessagingService` [the ONLY file importing `package:firebase_messaging`] + `NoopPushMessagingService` [returned when Firebase unconfigured — `isAvailable()==false`]; `@LazySingleton(as:)` repo impls). Add `firebase_core` + `firebase_messaging` to `pubspec.yaml`; guarded `Firebase.initializeApp` in `main.dart` (try/catch → no-op + register `NoopPushMessagingService` when config absent). All Supabase access string-keyed per `contracts/` — compiles + analyzes WITHOUT the DB applied. Regenerate DI.
**Touch fan**: `lib/core/messaging/**`, `lib/features/notifications/domain/**`, `lib/features/notifications/data/**` (new), `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `android/app/build.gradle(.kts)`, `android/build.gradle(.kts)`, `android/app/src/main/AndroidManifest.xml`, `lib/core/di/injection.config.dart` (codegen).

### PN — Notification-center UI + app-bar bell + `/notifications` route + l10n
Build `lib/features/notifications/presentation/` (`NotificationsCubit` [load page, mark read/all, paginate]; `NotificationBadgeCubit` [unread count, refresh on resume — NOT Realtime]; `NotificationCenterPage` — newest-first list, read/unread styling, mark-all-read, tap → resolve deep link + mark read; `notification_tile.dart`; `notification_bell_action.dart` — `IconButton` + unread-count badge; `notification_deep_link_resolver.dart` — maps `NotificationType`+params → pre-existing routes [account_approved→`AppRoutes.home`; account_rejected→the Phase 5 rejected route; listing_approved→listing-details route; listing_rejected→publisher My-Listings route; inquiry_received→the Phase 16 inquiries route; agency_invitation→the Phase 19 `/agency` route], graceful fallback when target unresolved — FR-018). Register the route: `AppRoutes.notifications='/notifications'` + `AppRouteNames.notifications` + a `GoRoute` in the authenticated branch of `buildAppRouter()`. Insert `NotificationBellAction()` into `home_page.dart` AppBar `actions` (between `InquiriesAppBarAction()` and the admin-panel button). Add ~40 notification l10n keys (center labels, empty/loading/error, mark-all-read, relative-time, the 6 in-app copy templates) to both ARBs + run gen-l10n. DI for the two cubits.
**Touch fan**: `lib/features/notifications/presentation/**` (new), `lib/core/routing/app_router.dart`, `lib/features/home/presentation/pages/home_page.dart`, `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_localizations*.dart` (gen), `lib/core/di/injection.config.dart` (codegen).

### PR — Realtime wiring: token register/deregister + user_roles permission refresh + admin-counter refresh
Amend `lib/features/auth/presentation/bloc/auth_bloc.dart`: on the `Authenticated` transition (`_onSessionRefreshed` success) call `RegisterPushToken` (+ subscribe `PushMessagingService.onTokenRefresh` → re-register) **regardless of `account_status`** (FR-011); on `Unauthenticated`/logout call `DeregisterPushToken`; add the **fourth observation point** — a `SupabaseClientWrapper.realtimeChannel('user_roles')` subscription filtered to `user_id=eq.<auth.uid()>` that calls `_permissionChecker.refresh()` on INSERT/UPDATE/DELETE, torn down on logout (leaves the existing three points intact — FR-017). Amend `lib/features/admin/dashboard/presentation/bloc/dashboard_cubit.dart`: open a `realtimeChannel` on `listings` + `reports`, and on a relevant change event call the existing `refresh()` (debounced) so counters re-fetch via `admin_dashboard_counts` (FR-015/FR-016); reconcile on (re)subscribe. DI for any new realtime-service helper.
**Touch fan**: `lib/features/auth/presentation/bloc/auth_bloc.dart`, `lib/features/admin/dashboard/presentation/bloc/dashboard_cubit.dart`, (optional) `lib/features/notifications/data/datasources/*realtime*` helper (new), `lib/core/di/injection.config.dart` (codegen).

## Phase Dependencies

> Rule honored: every declared "B depends on A" names the exact file path AND the exported Dart symbol B consumes from A. A Dart datasource calling a Postgres RPC/view/Realtime channel by **string name**, or SQL migrations sharing a database, are **runtime/DB contracts** — they compile and `flutter analyze` independently — so they are listed separately as "Runtime/DB contracts," NOT as build-order edges. Cross-phase edits to the same shared file (ARBs, `injection.config.dart`) are **merge-contention** items handled by Touch-fan merge order, NOT build edges (no symbol crosses).

**Declared code dependencies (build/merge order edges):**

- **PN depends on PD** — `lib/features/notifications/presentation/bloc/notifications_cubit.dart` + `notification_badge_cubit.dart` + `pages/notification_center_page.dart` (PN) import the abstract `NotificationsRepository`, the entities `AppNotification`/`NotificationType`/`NotificationDeepLink`/`UnreadCount`, and the use cases `LoadNotifications`/`MarkNotificationRead`/`MarkAllNotificationsRead`/`LoadUnreadCount` — all defined under `lib/features/notifications/domain/` by PD. `notification_deep_link_resolver.dart` consumes PD's `NotificationType` enum. Without PD's symbols, PN does not compile.
- **PR depends on PD** — `lib/features/auth/presentation/bloc/auth_bloc.dart` (PR's amendment) imports the use cases `RegisterPushToken`/`DeregisterPushToken` and the `PushMessagingService` interface (`onTokenRefresh`), all defined by PD (`lib/features/notifications/domain/usecases/` + `lib/core/messaging/push_messaging_service.dart`). Without PD's symbols, PR's `auth_bloc.dart` amendment does not compile.

**Runtime/DB contracts (NOT build-order edges — no named Dart symbol crosses the boundary):**

- PD's `SupabaseNotificationsDatasource`/`SupabasePushTokenDatasource` call the Postgres RPCs `register_notification_token`/`deregister_notification_token`/`mark_notification_read`/`mark_all_notifications_read` and select `notifications` (created by PB) via `supabase.rpc('…')` / string-keyed selects — runtime calls, not Dart imports. PD compiles + `flutter analyze`s without PB applied. End-to-end verification (quickstart) requires PB applied + the `dispatch_push` fn deployed.
- PR's `auth_bloc.dart`/`dashboard_cubit.dart` open `SupabaseClientWrapper.realtimeChannel('user_roles' | 'listings' | 'reports')` — these consume the **pre-existing** `SupabaseClientWrapper.realtimeChannel(String)` symbol (Phase 1/4) and `PermissionChecker.refresh()` (Phase 6) and `DashboardCubit.refresh()` (Phase 20, the same file), NOT any PB or PD symbol. Realtime *delivery* depends on PB's `20260602120010` publication adds — a **DB/runtime** contract, not a build edge.
- Within PB, the fan-out amendment migrations (`…004`–`…007`) `PERFORM enqueue_notification(...)` (created in `…003`) and the dispatch trigger (`…009`) references the `notifications` table (`…002`) and Vault secrets (`…008`). These are **DB apply-order** dependencies satisfied automatically by the migration timestamp order (`…001` < `…002` < … < `…011`); internal to PB (one sub-agent, one ordered file set), not cross-phase edges.

**Self-audit**: Declared code deps = **2** (PN→PD, PR→PD). Deps lacking a named consumer = **0** — each names the consuming file(s) AND the imported symbol(s). PB has **0** inbound/outbound Dart edges (its only relationships are runtime contracts + internal DB apply-order). PD has **0** Dart edge to PB. PN and PR have **0** edge to each other — PR amends `auth_bloc.dart`/`dashboard_cubit.dart` (consuming PD's push use cases + pre-existing Phase 6/20 symbols), while PN builds the center UI + amends `home_page.dart`/`app_router.dart`; they import PD but never each other (PN's bell does not consume PR's Realtime; the unread badge is fetch-on-open per the spec, NOT a Realtime subscription). Graph is minimal — no over-conservative edges.

**Resulting execution waves:**

- **Wave 1 (parallel):** PB, PD — no Dart edge between them; both implement the shared `contracts/` interface.
- **Wave 2 (parallel):** PN, PR — each depends on PD only, not on each other.

**Merge-order guidance for `/wave`** (from Touch-fan overlap, not code edges): three phases regenerate `lib/core/di/injection.config.dart` (PD, PN, PR); **only PN** touches the two ARBs + the generated `app_localizations*.dart` (so no ARB merge contention between phases — PR adds no user-visible strings; if PR needs any, it must coordinate with PN). Merge order: **PD → PN → PR** (PD first as both successors import it; PN/PR order between themselves is free, but PD must land first). Each successor sub-agent MUST rebase on the merged predecessor and re-run `dart run build_runner build --delete-conflicting-outputs` to regenerate `injection.config.dart`, then re-run the full verify suite (`project_wave_run_full_verify_suite`) — especially l10n-parity after PN. **PB merges independently** (touches only its 11 new migration files + the new `dispatch_push` dir — no shared-file contention) but MUST be APPLIED via Supabase MCP (`project_supabase_apply_via_mcp`) and the `dispatch_push` fn deployed before the quickstart's live verification of PD/PN/PR. PR's `auth_bloc.dart` (auth) and `dashboard_cubit.dart` (admin) edits and PN's `home_page.dart`/`app_router.dart` edits touch DISJOINT files, so PN and PR do not contend outside `injection.config.dart`. Per `project_wave_worktree_base` + `project_wave_merge_cascade_gotchas`: brief sub-agents to `git reset --hard origin/022-notifications-realtime` first, verify ancestry before merge, and re-anchor the orchestrator CWD to repo root before each merge.

## Complexity Tracking

No constitution violations. The two additions that depart from the recent "zero new deps / zero new extension" pattern are feature-justified and recorded as research decisions, not violations:

| Addition | Why Needed | Simpler Alternative Rejected Because |
|----------|------------|--------------------------------------|
| `firebase_core` + `firebase_messaging` (Flutter) | Device push (background/closed reach) is the phase's headline goal (FR-010); FCM is the only viable Android push transport | A pure in-app/Realtime build (no push) was the *fallback*, not the goal — it cannot wake a closed app. The dep is confined to `data/` behind `PushMessagingService` and the app builds with it disabled (FR-024), so portability (IX) is preserved |
| `pg_net` (Postgres extension) | Async server→Edge-Function dispatch on a `notifications` insert, off the actor's critical path, uniformly for SQL-RPC *and* Edge-Function transitions | A dashboard Database Webhook is not source-controlled (violates II); calling FCM inline inside each transition would block the actor and can't cover the SQL-only RPCs (account/inquiry/agency) without converting them to Edge Functions — a far larger change |

*Plan version: 1.0 | Generated by /speckit-plan | Aligned with constitution v1.0.0*
