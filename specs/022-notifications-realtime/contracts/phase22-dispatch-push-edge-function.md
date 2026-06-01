# Contract: `dispatch_push` Edge Function + push-dispatch trigger (Phase 22)

**Files**: `supabase/functions/dispatch_push/index.ts`; trigger in `20260602120009_enable_pg_net_push_dispatch.sql`. (R-185/R-186/R-187)

## Invocation (trigger → Edge Function)
AFTER INSERT on `notifications`, `notify_push_dispatch()` reads `push_dispatch_url` + `push_dispatch_token` via `app_vault_secret`; if either is NULL it **returns without posting** (degraded mode — FR-013). Otherwise it `net.http_post`s:

```jsonc
POST <push_dispatch_url>
Authorization: Bearer <push_dispatch_token>
{ "notification_id": "<uuid>", "recipient_user_id": "<uuid>", "type": "<type>", "params": { … } }
```

Async + best-effort: the AFTER-INSERT trigger never blocks or fails the actor's transaction (FR-017).

## Edge Function behavior (service-role)
1. **Auth**: verify `Authorization: Bearer <push_dispatch_token>` matches the Vault token; else `401`.
2. **Provider check**: `app_vault_secret('fcm_service_account')`; if null → `200 {skipped:'no_provider'}` (degraded — FR-013/SC-003).
3. **Preference**: read recipient `user_preferences.notifications_enabled`; if false → `200 {skipped:'muted'}` (history already written — FR-021).
4. **Language**: resolve recipient preferred language (default `ar` — Arabic-first, FR-004).
5. **Copy**: render a **generic** title/body by `type` from the bilingual template map (NO reason text — FR-004). Examples:
   - `account_approved` → ar/en "Account approved" / "Your account is approved".
   - `listing_rejected` → "Listing reviewed — tap for details" (reason revealed only in-app).
6. **Tokens**: select active `notification_tokens` for the recipient; if none → `200 {skipped:'no_tokens'}`.
7. **Send**: mint an OAuth token from the service account; POST FCM HTTP v1 per device with `notification:{title,body}` + `data:{type, ...params}` (data drives the on-tap deep link — FR-012). Prune tokens FCM returns as `UNREGISTERED`.
8. **Return**: `200` with a per-token result summary. Never throws back into the trigger.

## Degraded / skip envelopes (all `200`)
`{skipped:'no_provider'}` · `{skipped:'muted'}` · `{skipped:'no_tokens'}` · `{sent:N, pruned:M}`.

## Security
- `fcm_service_account` read only here, via Vault — never committed, never in the client (FR-018/SC-007/ADR-0001).
- Service-role client used only after the dispatch-token check.
- No PII/free-text in the payload — UUIDs + generic copy only (FR-004).

## Runtime
Mirrors `supabase/functions/approve_listing/index.ts` (createClient service-role, defensive JSON envelope, no secret logging).
