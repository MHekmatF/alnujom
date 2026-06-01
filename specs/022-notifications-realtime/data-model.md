# Data Model — Push Notifications + Supabase Realtime Signals (Phase 22)

This is the source-of-truth for the Phase 22 backend (11 migrations + 1 Edge Function) and the Flutter domain entities. SQL bodies are complete for NEW objects; the four transition amendments are described as **re-based CREATE-OR-REPLACE deltas** (re-base on the latest body first — R-183). Apply in timestamp order via Supabase MCP (`project_supabase_apply_via_mcp`), then `get_advisors` + a structural check.

> Conventions reused: `set_updated_at()` trigger fn (Phase 4), `app_vault_secret(name)` (Phase 4), `log_audit()` (Phase 4 — NOT used here, R-196), `current_user_has_permission(key)` (Phase 6), the REVOKE-writes + SECURITY DEFINER RPC posture (Phases 18/19/21). All new functions set `search_path = ''` and schema-qualify (advisor hardening).

---

## Migration `20260602120001_create_notification_tokens.sql`

```sql
create table public.notification_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  token       text not null,
  platform    text not null default 'android' check (platform in ('android')),  -- Android-only, XI
  is_active   boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.notification_tokens enable row level security;

-- Self-only read (R-182/R-188)
create policy notification_tokens_select_self on public.notification_tokens
  for select to authenticated using (user_id = auth.uid());

-- No client writes — registration is via RPC only (R-182)
revoke insert, update, delete on public.notification_tokens from authenticated, anon;

create index ix_notification_tokens_user on public.notification_tokens(user_id) where is_active;
```

RLS posture: **Read** self only; **Write** none from clients (RPC `register/deregister_notification_token`). Audit-logged: No (FR-025).

---

## Migration `20260602120002_create_notifications.sql`

```sql
create table public.notifications (
  id                uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  type              text not null check (type in (
                      'account_approved','account_rejected',
                      'listing_approved','listing_rejected',
                      'inquiry_received','agency_invitation')),
  params            jsonb not null default '{}'::jsonb,  -- deep-link IDs + render params (no PII free-text)
  read_at           timestamptz,                          -- null = unread
  created_at        timestamptz not null default now()
);

alter table public.notifications enable row level security;

-- Self-only read (R-188)
create policy notifications_select_self on public.notifications
  for select to authenticated using (recipient_user_id = auth.uid());

-- No client writes — rows written only by enqueue_notification; read-state via RPC (R-182)
revoke insert, update, delete on public.notifications from authenticated, anon;

create index ix_notifications_recipient_created
  on public.notifications(recipient_user_id, created_at desc);
create index ix_notifications_unread
  on public.notifications(recipient_user_id) where read_at is null;
```

`params` examples per type (UUIDs only — no free-text reason, FR-004): `account_approved`/`account_rejected` → `{}`; `listing_approved`/`listing_rejected` → `{"listing_id": "<uuid>"}`; `inquiry_received` → `{"listing_id":"<uuid>","inquiry_id":"<uuid>"}`; `agency_invitation` → `{"agency_id":"<uuid>"}`.

RLS posture: **Read** self only; **Write** none from clients. Audit-logged: No.

---

## Migration `20260602120003_create_notification_rpcs.sql`

```sql
-- Internal writer (R-183): always writes history (FR-021), regardless of notifications_enabled
create or replace function public.enqueue_notification(
  p_recipient uuid, p_type text, p_params jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_recipient is null then return null; end if;          -- defensive: skip if no recipient
  insert into public.notifications(recipient_user_id, type, params)
    values (p_recipient, p_type, coalesce(p_params, '{}'::jsonb))
    returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.enqueue_notification(uuid, text, jsonb) from anon, authenticated;

-- Client RPC: register / refresh this device's token (R-191)
create or replace function public.register_notification_token(p_token text, p_platform text default 'android')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  insert into public.notification_tokens(user_id, token, platform, is_active, last_seen_at)
    values (auth.uid(), p_token, coalesce(p_platform,'android'), true, now())
  on conflict (user_id, token)
    do update set is_active = true, last_seen_at = now();
end $$;
grant execute on function public.register_notification_token(text, text) to authenticated;

-- Client RPC: deregister THIS device only (R-191)
create or replace function public.deregister_notification_token(p_token text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.notification_tokens where user_id = auth.uid() and token = p_token;
end $$;
grant execute on function public.deregister_notification_token(text) to authenticated;

-- Client RPC: mark one own notification read (FR-008)
create or replace function public.mark_notification_read(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at = coalesce(read_at, now())
   where id = p_id and recipient_user_id = auth.uid();
end $$;
grant execute on function public.mark_notification_read(uuid) to authenticated;

-- Client RPC: mark all own notifications read (FR-008)
create or replace function public.mark_all_notifications_read()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at = now()
   where recipient_user_id = auth.uid() and read_at is null;
end $$;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- Client RPC: unread count for the badge (R-193) — bounded, self-only
create or replace function public.unread_notification_count()
returns integer language sql security definer set search_path = '' stable as $$
  select count(*)::int from public.notifications
   where recipient_user_id = auth.uid() and read_at is null;
$$;
grant execute on function public.unread_notification_count() to authenticated;
```

The center's **list read** is the self-RLS `select … from public.notifications order by created_at desc limit/offset` (bounded/paginated — FR-006), needing no view (RLS already self-scopes).

---

## Migrations `…004`–`…007` — transition fan-out amendments (re-based CREATE-OR-REPLACE — R-183)

Each migration re-creates the named function from its **latest** body and adds a single `PERFORM public.enqueue_notification(...)` after the status write. No edit to the original Phase 5/12/16/19 files.

**`20260602120004_amend_account_decision_fanout.sql`** — `public.approve_account_approval_request(p_user_id uuid)` + `public.reject_account_approval_request(p_user_id uuid, p_reason text)` (base `20260510120001`). After the `profiles.account_status` UPDATE add, respectively:
```sql
perform public.enqueue_notification(p_user_id, 'account_approved', '{}'::jsonb);
-- and in reject (NO reason text in params — FR-004):
perform public.enqueue_notification(p_user_id, 'account_rejected', '{}'::jsonb);
```

**`20260602120005_amend_submit_inquiry_fanout.sql`** — `public.submit_inquiry(p_listing_id uuid, p_sender_name text, p_inquirer_phone text, p_message text)` (base `20260527120009`). After the `inquiries` INSERT (capture `v_inquiry_id`), resolve the publisher and enqueue:
```sql
select l.publisher_user_id into v_publisher from public.listings l where l.id = p_listing_id;
perform public.enqueue_notification(
  v_publisher, 'inquiry_received',
  jsonb_build_object('listing_id', p_listing_id, 'inquiry_id', v_inquiry_id));
```

**`20260602120006_amend_invite_agency_member_fanout.sql`** — `public.invite_agency_member(p_agency_id uuid, p_phone text, p_role text)` (base `20260531120008`). After the `agency_members` INSERT, using the resolved invitee `v_target`:
```sql
perform public.enqueue_notification(
  v_target, 'agency_invitation', jsonb_build_object('agency_id', p_agency_id));
```

**`20260602120007_amend_listing_decision_fanout.sql`** — `public.approve_listing_internal(p_listing_id uuid, p_actor_user_id uuid)` + `public.reject_listing_internal(p_listing_id uuid, p_actor_user_id uuid, p_reason_json text)` (base `20260523120005`, service-role-only — unchanged grants). After the `listings.status` UPDATE, resolve the publisher and enqueue (NO reason in params — FR-004):
```sql
-- publisher already in scope from the UPDATE … RETURNING, else:
select l.publisher_user_id into v_publisher from public.listings l where l.id = p_listing_id;
perform public.enqueue_notification(v_publisher, 'listing_approved',
  jsonb_build_object('listing_id', p_listing_id));
-- reject variant:
perform public.enqueue_notification(v_publisher, 'listing_rejected',
  jsonb_build_object('listing_id', p_listing_id));
```

> Re-base discipline: read each function's current definition from the live DB / latest migration before authoring the amendment, preserve every existing line, and insert ONLY the `enqueue_notification` PERFORM. Exactly-once is guaranteed because each PERFORM sits on the single status-transition branch (FR-003, SC-009).

---

## Migration `20260602120008_create_fcm_vault_secret.sql` (R-186, ADR-0001)

```sql
-- Idempotent secret registration from env/GUC; NO plaintext key material in this file.
do $$
declare v_json text := current_setting('app.settings.fcm_service_account', true);
begin
  if v_json is not null and length(v_json) > 0
     and not exists (select 1 from vault.secrets where name = 'fcm_service_account') then
    perform vault.create_secret(v_json, 'fcm_service_account',
      'FCM HTTP v1 service-account JSON (Phase 22 push) — read only by dispatch_push');
  end if;
end $$;
-- Same idempotent pattern for 'push_dispatch_url' and 'push_dispatch_token'
-- (the project function-base URL + a shared token the trigger uses to authorize the Edge Function).
```

If the env var is unset (e.g., a CI run without Firebase), no secret is created → the dispatch trigger skips → degraded in-app mode (FR-013). Secrets are read via `app_vault_secret(name)` server-side only.

---

## Migration `20260602120009_enable_pg_net_push_dispatch.sql` (R-185)

```sql
create extension if not exists pg_net;   -- justified new extension (plan Complexity Tracking)

create or replace function public.notify_push_dispatch()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_url text; v_token text;
begin
  v_url   := public.app_vault_secret('push_dispatch_url');
  v_token := public.app_vault_secret('push_dispatch_token');
  if v_url is null or v_token is null then
    return new;  -- push not configured → degraded mode, in-app history already written (FR-013)
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type','application/json',
                                  'Authorization','Bearer '||v_token),
    body := jsonb_build_object('notification_id', new.id,
                               'recipient_user_id', new.recipient_user_id,
                               'type', new.type, 'params', new.params));
  return new;
end $$;
revoke execute on function public.notify_push_dispatch() from anon, authenticated;

create trigger trg_notifications_push_dispatch
  after insert on public.notifications
  for each row execute function public.notify_push_dispatch();
```

Dispatch is async + best-effort (FR-017); a failed/absent dispatch never blocks the actor's transaction (the trigger is AFTER INSERT and `net.http_post` enqueues without awaiting a response).

---

## Edge Function `supabase/functions/dispatch_push/index.ts` (R-187)

Contract (full detail in `contracts/phase22-dispatch-push-edge-function.md`):
1. Authorize the incoming request with the shared `push_dispatch_token` (Bearer); reject otherwise.
2. `adminClient` (service-role) reads `fcm_service_account` via `app_vault_secret`. If null → 200 `{skipped:'no_provider'}` (degraded — FR-013).
3. Read the recipient's `notifications_enabled` (skip push if false — FR-021) and preferred language.
4. Render generic bilingual title/body keyed by `type` (NO free-text reason — FR-004) in the recipient's language (default Arabic).
5. Select active `notification_tokens` for the recipient. If none → 200 `{skipped:'no_tokens'}`.
6. Mint an OAuth access token from the service account and POST FCM HTTP v1 per token; collect per-token results; prune tokens FCM reports as `UNREGISTERED`.
7. Return 200 with a per-token summary. Never throws back into the trigger path.

Runtime mirrors `supabase/functions/approve_listing/index.ts` (createClient service-role; defensive JSON envelope). The deep-link `params` ride along as FCM `data` so the app can route on tap (FR-012).

---

## Migration `20260602120010_enable_realtime_publications.sql` (R-190)

```sql
-- Admin counters (listings status, reports new/resolved) + user_roles permission refresh
alter publication supabase_realtime add table public.listings;
alter publication supabase_realtime add table public.reports;
alter publication supabase_realtime add table public.user_roles;
-- REPLICA IDENTITY DEFAULT (PK) suffices for the change events the clients consume.
```

Realtime row visibility is still governed by each table's existing RLS: admins see `listings`/`reports` (existing policies); a user sees their own `user_roles` rows (Phase 6 self-read). No policy change needed.

---

## Migration `20260602120011_phase22_advisor_hardening.sql`

`set search_path = ''` confirmations on the new functions; `get_advisors` review; any missing index/grant cleanup surfaced by the advisor (e.g., function-search-path warnings). No new RLS-disabled table (both new tables have RLS on — Principle III).

---

## Dart domain entities (PD — `lib/features/notifications/domain/entities/`)

```text
NotificationType  (enum) — accountApproved, accountRejected, listingApproved,
                           listingRejected, inquiryReceived, agencyInvitation
                           + fromKey(String)/key getter mirroring the SQL CHECK values
AppNotification   — id (String), type (NotificationType), params (Map<String,dynamic>),
                    readAt (DateTime?), createdAt (DateTime); isUnread getter
NotificationDeepLink — resolved target descriptor (route + args) produced from type+params
PushToken         — token (String), platform (String), isActive (bool), lastSeenAt (DateTime)
UnreadCount       — value (int)
```

`lib/core/messaging/push_messaging_service.dart` (domain-pure interface — Principle IX):
```text
abstract interface class PushMessagingService {
  Future<bool> isAvailable();              // false ⇒ NoopPushMessagingService (degraded)
  Future<String?> currentToken();
  Stream<String> onTokenRefresh();
  Stream<PushPayload> onMessage();         // foreground; PushPayload = {type, params}
  Stream<PushPayload> onMessageOpenedApp();// tap (background/cold) → deep link
}
```

Repositories (abstract, `domain/repositories/`): `NotificationsRepository { Future<Result<List<AppNotification>>> loadPage({int limit, int offset}); Future<Result<void>> markRead(String id); Future<Result<void>> markAllRead(); Future<Result<int>> loadUnreadCount(); }` and `PushTokenRepository { Future<Result<void>> register(String token, String platform); Future<Result<void>> deregister(String token); }`. Use cases wrap each. Repos return `Result<T>`/`Failure` (Phase 1).

DTO (`data/dtos/`): `AppNotificationDto` ↔ `notifications` row (json `params`). Datasources string-key all RPC/select calls.

---

## Per-FR verification map

| FR | Where satisfied | How verified |
|---|---|---|
| FR-001 events+payload | `enqueue_notification` + 4 amendments (`…004`–`…007`); `notifications.type` CHECK | SQL: trigger each event; one row per recipient with correct `type`/`params` |
| FR-002 server-side recipient | recipient resolved in each amendment (no client param) | Code review of `…004`–`…007`; wire test cannot set recipient |
| FR-003 exactly-once on transition | single PERFORM on the status branch | SC-009 count test (retry → no dup) |
| FR-004 localized + generic tray | `dispatch_push` renders by `type` in preferred lang, no reason text; `params` carry UUIDs only | Inspect push tray (no reason); switch language → tray language follows |
| FR-005 server history store | `notifications` table | Row persists; visible after logout/login (SC-008) |
| FR-006 center + bell + paginate | `NotificationCenterPage`, `NotificationBellAction`, `/notifications`, limit/offset read | On-device: bell+badge on home, list newest-first, paginates |
| FR-007 deep-link + mark read | `notification_deep_link_resolver` + `mark_notification_read` | Tap each type → correct screen; row `read_at` set |
| FR-008 mark read/all | `mark_notification_read`/`mark_all_notifications_read` | Badge count drops; SC-008 |
| FR-009 self-only read | `notifications_select_self` policy | SC-007 cross-user read denied |
| FR-010 pluggable push | `PushMessagingService` + FCM adapter + no-op | Push arrives when configured; SC-002 |
| FR-011 register/deregister (any status) | `AuthBloc` + `register/deregister_notification_token` | SC-011; pending user receives approval push (SC-002) |
| FR-012 tap opens deep link (bg/cold) | `onMessageOpenedApp` → resolver | SC-002 cold-start tap |
| FR-013 degrade silently | no-op adapter + trigger skip when secret null | SC-003: push disabled → app works, no error |
| FR-014 fg vs bg surfacing | `onMessage` (in-app surface) vs system tray | On-device fg/bg test |
| FR-015 admin counters live | `DashboardCubit` Realtime → `refresh()`; publication add | SC-004 two-device |
| FR-016 admin-gated + reconcile | existing RLS on listings/reports; re-fetch on (re)subscribe | SC-004 drop/reconnect; non-admin gets nothing |
| FR-017 live permission refresh | `AuthBloc` `user_roles` subscription → `PermissionChecker.refresh()` | SC-005 grant/revoke without re-login |
| FR-018 FCM secret in Vault only | `fcm_service_account` secret; `app_vault_secret` read | SC-007 grep repo+artifact |
| FR-019 self-RLS + definer fan-out | policies + REVOKE + `enqueue_notification` | SC-007 wire tests |
| FR-020 no forge/cross-write | REVOKE writes; RPCs self-scope `auth.uid()` | SC-007 |
| FR-021 flag mutes push, keeps history | `enqueue` always writes; `dispatch_push` checks `notifications_enabled` | On-device: flag off → no push, history present |
| FR-022 localized UI + templates | ~40 ARB keys + 6 bilingual templates | l10n-parity linter; SC-006 |
| FR-023 themed + RTL/LTR | Phase 2 tokens, direction-aware center/bell | SC-006 four-combination |
| FR-024 domain provider-agnostic; Android-only; builds disabled | `PushMessagingService` in core; SDK in data; guarded init | SC-010 grep + build-with-push-off |
| FR-025 no new key/audit/table change | no permission/audit/business-table change beyond 3 publication adds | SC-010 structural check |

## Per-SC verification map

SC-001 (one notification/event, ≤5 s in center, deep link) → trigger all six, observe center. SC-002 (push ≤10 s on device B incl. cold-start) → two-device. SC-003 (push disabled → in-app works, no error/build break) → unset secret/config. SC-004 (admin counters ≤5 s, reconcile on reconnect) → two-device + network drop. SC-005 (live permission refresh, no re-login) → grant/revoke on device B. SC-006 (four-combination + push language) → Infinix Note 8 + 412 dp AVD. SC-007 (cross-user denied; secret absent from repo+artifact; non-admin no channel) → wire + grep. SC-008 (badge matches; persists across login/reinstall). SC-009 (exactly-once on retry). SC-010 (no push SDK in domain; Android-only; runs disabled; no new key; backend surface = enumerated set). SC-011 (token register on login/remove on logout; multi-device).
