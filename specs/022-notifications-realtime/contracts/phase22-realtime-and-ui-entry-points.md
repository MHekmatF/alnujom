# Contract: Realtime subscriptions + UI entry points (Phase 22)

**Migration**: `20260602120010_enable_realtime_publications.sql`. **Flutter**: PN (UI) + PR (Realtime wiring).

## Realtime publication (PB)
`alter publication supabase_realtime add table public.listings, public.reports, public.user_roles;` Row visibility is governed by each table's EXISTING RLS (no policy change): admins read `listings`/`reports`; a user reads own `user_roles` rows (Phase 6 self-read). REPLICA IDENTITY DEFAULT (PK) suffices.

## Three subscriptions (all via the pre-existing `SupabaseClientWrapper.realtimeChannel(String)` — Principle IX)

| Subscription | Owner (file) | Filter | On event |
|---|---|---|---|
| admin pending-listing | `dashboard_cubit.dart` (PR) | `listings` changes | debounced `DashboardCubit.refresh()` → re-fetch `admin_dashboard_counts` (FR-015) |
| admin reports | `dashboard_cubit.dart` (PR) | `reports` changes | debounced `refresh()` (FR-015) |
| permission refresh | `auth_bloc.dart` (PR) | `user_roles` `user_id=eq.<auth.uid()>` | `PermissionChecker.refresh()` — the 4th observation point (FR-017/R-190) |

Reconcile on (re)subscribe via a fresh count fetch — no client-side incremental math (FR-016). Subscriptions torn down on logout.

## Token lifecycle (PR — `auth_bloc.dart`)
- On `Authenticated` (any `account_status`): `RegisterPushToken(currentToken)` + subscribe `PushMessagingService.onTokenRefresh` → re-register (FR-011/R-191).
- On `Unauthenticated`/logout: `DeregisterPushToken(currentToken)` + tear down the `user_roles` channel.

## UI entry points (PN)
- **Bell**: `NotificationBellAction` (icon + unread-count badge from `NotificationBadgeCubit`) inserted in `home_page.dart` AppBar `actions`, between `InquiriesAppBarAction()` and the admin-panel button (R-192).
- **Route**: `AppRoutes.notifications='/notifications'` + `AppRouteNames.notifications` + `GoRoute` in the authenticated branch of `buildAppRouter()`.
- **Center**: `NotificationCenterPage` — newest-first list, read/unread styling, mark-all-read, tap → `notification_deep_link_resolver` + `mark_notification_read`.
- **Deep-link resolver** (`NotificationType` → pre-existing routes, R-194):

| type | target |
|---|---|
| `account_approved` | `AppRoutes.home` |
| `account_rejected` | Phase 5 rejected route |
| `listing_approved` | listing-details route (`params.listing_id`) |
| `listing_rejected` | publisher My-Listings route (`params.listing_id`) |
| `inquiry_received` | Phase 16 inquiries route (`params.inquiry_id`) |
| `agency_invitation` | `/agency` (Phase 19) |

Unresolved target (deleted listing/inquiry) → localized "content unavailable" fallback; the notification is still marked read (FR-007/FR-018). On-tap from a push uses `PushMessagingService.onMessageOpenedApp` → same resolver (FR-012).

## Badge liveness (R-193)
`NotificationBadgeCubit` loads `unread_notification_count()` on mount + on foreground-resume — NOT a Realtime subscription (keeps Realtime scope to admin counters + permission refresh, and keeps PN independent of PR).
