# DEFERRED — Phase 22 (022-notifications-realtime)

Status at handoff: **PB + PD + PN + PR implemented, merged, verified, and pushed** to `022-notifications-realtime`. Backend applied live via Supabase MCP in **degraded mode** (no Vault secrets). All static/structural gates + the full lint suite pass; `flutter analyze --fatal-infos` clean. The items below need a human (physical devices / Firebase / platform) and are NOT done.

Last orchestrator commit: `19fddd7`. Wave-by-wave history: PB `71d2986` · PD `ebecc8c` · backend-apply+hardening `699a87d` · PN `7c9cca9` · PR `3113c14` · PN review fixes `785a741` · format `19fddd7`.

---

## 1. On-device two-device QA — DEFERRED (T043, T044, T047; live portions of T045/T046/T048)

These require **two physical devices** (Infinix Note 8 + Pixel 8 Pro AVD per `feedback_avd_acceptable_qa`) and, for push, a **real Firebase/FCM config**. Not performable by the orchestrator.

- **T043 (SC-001/002/008/009/011)** — six-event in-app delivery ≤5 s + deep links; device push ≤10 s incl. cold-start tap; exactly-once on retry; badge-count-matches-rows + mark-read (single/all) + history persistence across logout/login/reinstall; token registered-on-login / removed-on-logout across two devices.
- **T044 (SC-004/005)** — admin counters move ≤5 s + reconcile after a forced network drop; live role grant/revoke on device B refreshes device A's gated UI without re-login; existing 3 permission observation points still work.
- **T045 (SC-003)** — *build + degraded-skip logic verified*; REMAINING: confirm all six events still deliver in-app (center + badge) on-device with push blocked, no crash.
- **T046 (SC-007)** — *RLS posture / secret-leak / forge-lock verified live + static*; REMAINING: cross-user RLS-denial from a real user-X JWT session; binary scan of the built APK for secrets; non-admin Realtime delivers no admin rows.
- **T047 (SC-006)** — four-combination render (light/dark × ar-RTL/en-LTR) of center/tile/badge/bell; push-tray locale (default Arabic) + generic OS-tray body while full reason shows in-app.
- **T048 (SC-010)** — *all static gates + lint suite verified*; REMAINING: execute `quickstart.md` end-to-end on devices.

## 2. Push enablement — prerequisite for any push QA (degraded by design today)

Phase 22 runs **push-disabled** until an operator does ALL of:
1. Register the three Vault secrets from env (NO plaintext in repo — ADR-0001): `fcm_service_account` (FCM HTTP v1 service-account JSON), `push_dispatch_url` (the deployed `dispatch_push` URL), `push_dispatch_token` (a shared bearer). Apply `20260602120008` with the `app.settings.*` GUCs set, or register via the Vault UI/API.
2. Provide `android/app/google-services.json` (the conditional Gradle guard skips the plugin when absent — that is why the app builds today).
3. Redeploy `dispatch_push` from source (see item 3).

Until then: `notify_push_dispatch` skips silently and `NoopPushMessagingService` is bound — **in-app delivery + center + Realtime still work** (the provider-agnostic core, FR-013).

## 3. `dispatch_push` redeploy — DEFERRED (transient platform error)

The live function is **v1 ACTIVE** but predates the `notification_id`-in-data fix (commit `785a741`). Two redeploy attempts returned `InternalServerErrorException` (Supabase platform-side, not content). **Non-blocking**: the function is never invoked in degraded mode. Redeploy from `supabase/functions/dispatch_push/` (source is correct + committed) when the platform recovers — folds naturally into the push-enablement step (item 2).

## 4. Plan divergences to reconcile (Principle X)

Two real deviations from `plan.md`/`data-model.md`, both intentional and committed:
- **12th migration `20260602120012_revoke_internal_fn_execute_from_public.sql`** — the plan enumerated 11 PB migrations. Live `has_function_privilege` showed `enqueue_notification`/`notify_push_dispatch` were still client-EXECUTE-able via Postgres's PUBLIC default grant (`…003`'s `REVOKE FROM anon,authenticated` does not strip PUBLIC). `…012` revokes PUBLIC and re-verifies the lock. No new surface — it hardens the same RPCs. (Gotcha: memory `project_supabase_view_rls_gotchas`.)
- **New `RealtimeSignals` seam** (`lib/core/network/realtime_signals.dart` + `realtime_signals_impl.dart`) — PR found `SupabaseClientWrapper.realtimeChannel()` was still an `UnimplementedError('wired up in Phase 22')` stub with no filtered-postgres-changes API, so it added a `@LazySingleton` seam that confines `package:supabase_flutter` (Principle IX) and exposes the filtered subscription the blocs need. data-model/contracts describe the blocs consuming `realtimeChannel` directly; reconcile to name the seam.

## 5. Pre-existing baseline lint debt (NOT Phase 22 — informational)

The full lint suite reports **12 pre-existing violations** (9 l10n-literals + 3 design-tokens) in Phase 18/19/20 files (`agency_*`, `report_*`). Wave 1+2 added **zero** new violations and touched none of those files. `dart format` also flags ~76 pre-existing unformatted files repo-wide (Phase 22 files were formatted in `19fddd7`). Out of scope for this spec; track separately if desired.
