# Phase 0 Research — Push Notifications + Supabase Realtime Signals (Phase 22)

Locked plan-time decisions. Each: **Decision**, **Rationale**, **Alternatives rejected**. Numbering continues after Phase 21 (R-164..R-180), so Phase 22 owns **R-181..R-196**. These resolve every NEEDS-CLARIFICATION the Technical Context would otherwise carry; the spec's 8 clarifications (Sessions 2026-06-02) are upstream of these and not re-litigated here.

---

**R-181 — A `notifications` history table is added (beyond plan §6.2).**
Decision: create `public.notifications` (per-user, `type` + `params` JSONB + `read_at` + `created_at`) as the durable in-app history store backing the notification center. Plan §6.2 named only `notification_tokens` for Phase 22; the spec's clarified decision (3) (server-side history, cross-device, survives reinstall) requires this table.
Rationale: history must survive logout/reinstall and sync across devices (SC-008) — a client-only store cannot. One row per qualifying transition is the durable record of "this happened to you," independent of whether push was delivered.
Alternatives rejected: **client-only local history** (no cross-device, lost on reinstall — fails SC-008); **derive history from existing domain rows** (no per-event read-state, no agency-invite/account events in one stream, brittle).

**R-182 — Both new tables are client-write-REVOKEd; writes go through SECURITY DEFINER RPCs.**
Decision: `notification_tokens` and `notifications` have RLS self-SELECT only (`user_id`/`recipient_user_id = auth.uid()`) and `REVOKE INSERT,UPDATE,DELETE FROM authenticated, anon`. Token writes via `register_notification_token`/`deregister_notification_token`; read-state via `mark_notification_read`/`mark_all_notifications_read`; history rows written ONLY by the internal `enqueue_notification` definer fn.
Rationale: matches the Phase 18 reports / Phase 19 agencies / Phase 21 ads "REVOKE-all-writes, RPC-only" posture; prevents a client forging a notification to another user or writing another user's token (FR-019/FR-020, Principle III "checks at both ends").
Alternatives rejected: **client INSERT with a WITH CHECK policy** (clients could still self-insert arbitrary notifications/types, and `enqueue_notification` must run as definer to write *other* users' rows anyway — two write paths to reason about); a single shared "notifications" RLS for admins too (unneeded — self-only is sufficient, R-188).

**R-183 — One `enqueue_notification(recipient, type, params)` SECURITY DEFINER writer, hung off the existing transitions.**
Decision: a single internal definer fn INSERTs exactly one `notifications` row; it is `PERFORM`ed from CREATE-OR-REPLACE amendments to the four existing transition paths after their status write — `approve/reject_account_approval_request` (`20260510120001`), `submit_inquiry` (`20260527120009`), `invite_agency_member` (`20260531120008`), `approve/reject_listing_internal` (`20260523120005`). The amendments are **re-based on the latest body** of each function (mirroring the Phase 19 R-143 "re-base first" discipline).
Rationale: one funnel guarantees exactly-once-per-transition (FR-003, SC-009), a single place to evolve recipient resolution + payload shape, and uniform behavior across SQL-RPC and Edge-Function transitions. Recipient is resolved server-side from the domain row (FR-002): account→`p_user_id`; listing→`listings.publisher_user_id`; inquiry→the listing's `publisher_user_id`; agency→the resolved invitee `v_target`.
Alternatives rejected: **per-transition bespoke INSERTs** (duplicates recipient-resolution + payload logic five places, drift risk); **a generic trigger on each source table** (status-change triggers can't always distinguish a qualifying transition from a no-op re-save, risking duplicate/spurious notifications — FR-003).

**R-184 — Provider-agnostic core; FCM is a pluggable `PushMessagingService` adapter (the one justified new client dep).**
Decision: define a domain-pure `PushMessagingService` interface in `lib/core/messaging/`; implement `FcmPushMessagingService` (the ONLY file importing `package:firebase_messaging`) and a `NoopPushMessagingService` (registered when Firebase config is absent, `isAvailable()==false`). Add `firebase_core` + `firebase_messaging` to `pubspec.yaml`, confined to `data/`. The app builds + runs with push disabled.
Rationale: the spec's clarified decision (1) — in-app + Realtime always work; push degrades silently under the Syria/Firebase sanction risk (FR-010/FR-013). Confining the SDK to `data/` preserves Principle IX; a no-op adapter makes "push unconfigured" a first-class state, not an error path.
Alternatives rejected: **commit to FCM as primary** (highest sanction risk; a missing/blocked Firebase project breaks the headline flow); **in-app-only, defer push** (can't wake a closed app — the plan's headline "FCM push" deliverable would be unmet); a third-party push vendor (none reliably serves Syria better than FCM; same sanction surface).

**R-185 — Push dispatch is async via `pg_net` trigger → `dispatch_push` Edge Function (a justified new Postgres extension).**
Decision: enable `pg_net`; an AFTER-INSERT trigger `notify_push_dispatch()` on `notifications` `net.http_post`s the new row to the `dispatch_push` Edge Function, which reads `fcm_service_account` from Vault and sends FCM. The trigger reads the dispatch URL/token from Vault and **skips silently when any secret is NULL** (degraded mode). The §6.7 "Edge Functions add a notification fan-out call" wording is realized as this trigger-driven dispatch (recorded for X/XII).
Rationale: decouples push (best-effort, off the actor's critical path) from the synchronous in-app history INSERT; works uniformly for SQL-RPC transitions (account/inquiry/agency) AND Edge-Function transitions (listing) since all funnel through `notifications`; source-controlled (a SQL trigger, not a dashboard webhook — Principle II).
Alternatives rejected: **dashboard Database Webhook** (not in the repo — violates II); **inline FCM call inside each transition** (blocks the actor; the SQL-only RPCs can't call FCM without becoming Edge Functions — a large rewrite); **pg_cron drain of a pending queue** (adds polling latency + a second extension; pg_net is the lighter, event-driven fit).

**R-186 — `fcm_service_account` (+ dispatch URL/token) are Vault secrets registered from env, never plaintext.**
Decision: a migration calls `vault.create_secret(...)` reading the service-account JSON from a CI/local env var/GUC (idempotent: skip if already present or env unset); same for `push_dispatch_url` + `push_dispatch_token`. The `dispatch_push` fn reads `fcm_service_account` via `app_vault_secret` (Phase 4) at request time.
Rationale: ADR-0001 mandates the FCM service account be a single Vault secret read server-side only, never committed, never shipped to the client (FR-018, SC-007); reuses the Phase 4 Vault scaffolding + the Phase 5/16/19 secret-from-env migration idiom.
Alternatives rejected: **service-account JSON in an Edge-Function env var baked into the image** (the plan explicitly forbids this); **a config table column** (plaintext at rest, leaks in pg_dump — the exact ADR-0001 threat).

**R-187 — `dispatch_push` mirrors the Phase 12 Edge-Function runtime; renders generic, locale-correct tray copy.**
Decision: `dispatch_push/index.ts` is service-role (invoked by the trigger with the `push_dispatch_token`), reads `fcm_service_account` via `app_vault_secret`, checks the recipient's `notifications_enabled` (skip push if off — FR-021), resolves the recipient's preferred language, renders a **generic** bilingual title/body keyed by `type` (NO moderator free-text — FR-004), looks up active `notification_tokens`, and POSTs FCM HTTP v1. It no-ops cleanly when the secret or tokens are absent.
Rationale: reuses the Phase 12 `approve_listing` JWT/service-role pattern (familiar runtime); generic tray copy keeps rejection reasons off the lock screen (FR-004, clarified 2026-06-02); preferred-language rendering satisfies Arabic-first push (FR-004, Principle V).
Alternatives rejected: **client-side push rendering** (impossible — the OS renders the tray before the app opens); **reason text in the push body** (lock-screen leak of moderator notes — rejected in clarification).

**R-188 — `notifications`/`notification_tokens` are self-only (no admin cross-read).**
Decision: both tables expose self-SELECT only; admins do NOT read other users' notifications/tokens.
Rationale: FR-009's primary clause is self-only; nothing in Phase 22 needs an admin to read another user's notification stream, so the least-privilege posture is simplest and safest (Principle III). The §6.4 matrix has no `notifications` row to satisfy.
Alternatives rejected: **admin read-all** (no consumer; widens the blast radius of a leak for zero feature value).

**R-189 — `notifications_enabled` mutes push + active alerts; history is always written.**
Decision: `enqueue_notification` ALWAYS writes the history row; `dispatch_push` (and any active in-app alert) checks `notifications_enabled` and skips when off. Events that occur while off appear as unread when the user next opens the center.
Rationale: the spec's clarified decision (FR-021) — the flag means "don't interrupt me," not "hide what happened"; keeps the center complete and avoids a confusing history gap.
Alternatives rejected: **suppress history too when off** (silent data loss — the user can never learn an account/listing decision happened); **flag mutes push only, alert still fires** (contradicts the user's "active alerts" choice).

**R-190 — Realtime scope: `listings` + `reports` (admin counters) + `user_roles` (permission refresh) only.**
Decision: `ALTER PUBLICATION supabase_realtime ADD TABLE listings, reports, user_roles`. Admin dashboard subscribes to `listings`/`reports` and re-fetches `admin_dashboard_counts` on a debounced event; `AuthBloc` subscribes to `user_roles` filtered to `user_id=eq.auth.uid()` and calls `PermissionChecker.refresh()`. No other table is published; no user-facing live data (My Listings, the unread badge) uses Realtime this phase.
Rationale: the spec's clarified Realtime scope (FR-015/FR-016/FR-017) + the Phase 6 deferred follow-up (memory `project-phase22-perm-cache-revisit`); re-fetching counts on an event (vs client-side row math) keeps RLS authoritative and the counter logic in one RPC.
Alternatives rejected: **also stream user-facing live data** (broader load + RLS surface for marginal value — deferred); **client-side incremental counter math from Realtime payloads** (drifts on reconnect; the re-fetch reconciles correctly — FR-016).

**R-191 — Token registration on successful auth regardless of `account_status`; deregister this device on logout.**
Decision: `AuthBloc` registers the device token on the `Authenticated` transition (and re-registers on `PushMessagingService.onTokenRefresh`) for any successfully-authenticated user including `pending`; logout deregisters only this device's token.
Rationale: the spec's clarified decision (FR-011) — a pending user on the approval screen must be reachable by the "account approved/rejected" push, so registration cannot wait for `approved`. Per-device deregister supports multi-device (SC-011).
Alternatives rejected: **register only when approved** (the flagship approval push can't reach a pending user); **deregister all tokens on logout** (would silently stop push on the user's other logged-in devices).

**R-192 — Notification center reached from an app-bar bell + unread badge → `/notifications`.**
Decision: a `NotificationBellAction` (icon + unread-count badge) in the home AppBar `actions` (between `InquiriesAppBarAction` and the admin button) routes to a new `/notifications` route; NOT a Profile-only tile.
Rationale: the spec's clarified decision (FR-006) — the unread badge belongs on an always-visible surface; matches the existing app-bar action pattern (`LocaleToggleAction`, `InquiriesAppBarAction`).
Alternatives rejected: **Profile tile only** (hides the unread signal); **both** (redundant for v1 — the bell suffices; a Profile tile can be added later).

**R-193 — The unread badge is fetch-on-open + refresh-on-resume, NOT a Realtime subscription.**
Decision: `NotificationBadgeCubit` loads the unread count on app start / when the home surface mounts and refreshes on foreground-resume; it does not subscribe to Realtime.
Rationale: the spec scopes Realtime to admin counters + permission refresh only (FR-017 / R-190); a per-user Realtime badge would widen the published surface and the home performance budget for little gain (push already alerts the user). Keeps PN free of any PR edge.
Alternatives rejected: **Realtime-driven badge** (out of the clarified Realtime scope; adds load + a PN→PR coupling).

**R-194 — Deep-link resolution maps `NotificationType` → pre-existing routes, with graceful fallback.**
Decision: `notification_deep_link_resolver.dart` maps each type to an existing route (account_approved→`AppRoutes.home`; account_rejected→the Phase 5 rejected route; listing_approved→the listing-details route; listing_rejected→the publisher My-Listings route; inquiry_received→the Phase 16 inquiries route; agency_invitation→`/agency`). An unresolved target (deleted listing, removed inquiry) shows a localized "content unavailable" fallback and still marks the notification read (FR-007/FR-018).
Rationale: reuses prior-phase route constants (no new edges to PA-style siblings); the fallback prevents crashes on stale deep links (edge cases).
Alternatives rejected: **new dedicated routes per type** (unnecessary; the targets already exist); **hard-fail on unresolved target** (crash/broken screen — rejected by FR-018).

**R-195 — Guarded Firebase init in `main.dart`; Android-only platform config.**
Decision: `main.dart` calls `Firebase.initializeApp` inside try/catch; on failure or missing config it registers `NoopPushMessagingService`. `google-services` Gradle plugin + the minimal manifest entries are Android-only.
Rationale: makes "no Firebase project" a clean degraded path (FR-013/SC-003), keeps the build green with push disabled (SC-010), and honors Android-First (Principle XI). The Phase 1 `--dart-define-from-file=.env.json` run discipline (memory `project_dart_defines`) is unchanged.
Alternatives rejected: **unguarded init** (red-screens when config absent — breaks SC-003); **conditional dependency exclusion** (can't conditionally drop a pubspec dep at runtime; the no-op adapter is the right seam).

**R-196 — No new audited action, no new permission key, no §9.1 change.**
Decision: Phase 22 adds no `log_audit()` trigger and no permission key; the notification center is available to every signed-in user; admin counters reuse existing admin permissions.
Rationale: the four transitions are already audit-logged in Phases 5/12/16/19 (§9.4 does not list notification fan-out — FR-025); a notification center is a personal surface needing no permission gate; the `user_roles` Realtime refresh strengthens existing permission enforcement without new keys (Principle VII).
Alternatives rejected: **audit each notification send** (high-volume, redundant with the already-audited source transition); **a `notifications.view` permission** (every user has their own center — a gate would be meaningless).

---

## Resolved unknowns (Technical Context)

| Unknown | Resolution |
|---|---|
| New `notifications` table vs plan §6.2 | R-181 — add it (clarified decision 3) |
| Write posture for the two new tables | R-182 — REVOKE client writes, RPC/definer-only |
| How fan-out attaches to transitions | R-183 — single `enqueue_notification` PERFORMed from re-based CREATE-OR-REPLACE of the 4 paths |
| Push provider + sanction fallback | R-184 — provider-agnostic `PushMessagingService`; FCM adapter + no-op |
| Server→FCM dispatch mechanism | R-185 — `pg_net` trigger → `dispatch_push` Edge Function |
| FCM credential storage | R-186 — Vault secret from env (ADR-0001) |
| Push copy localization + privacy | R-187 — generic bilingual server-rendered copy in recipient's language |
| Realtime scope + tables | R-190 — `listings`+`reports`+`user_roles` only |
| Token lifecycle | R-191 — register on auth (any status), deregister per-device on logout |
| Center entry point | R-192 — app-bar bell + badge → `/notifications` |
| Badge liveness | R-193 — fetch-on-open + resume, no Realtime |
| Deep-link targets | R-194 — pre-existing routes + graceful fallback |
| Build-with-push-disabled | R-195 — guarded `Firebase.initializeApp` + no-op adapter |
| Audit / permissions impact | R-196 — none new |

All NEEDS CLARIFICATION resolved. Ready for Phase 1 (data-model, contracts, quickstart).
