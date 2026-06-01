# Contract: `notification_tokens` table + register/deregister RPCs (Phase 22)

**Migration**: `20260602120001_create_notification_tokens.sql` (table) + `20260602120003_create_notification_rpcs.sql` (RPCs)

## Table `public.notification_tokens`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `user_id` | uuid | FK `auth.users(id)` ON DELETE CASCADE |
| `token` | text | the device push (FCM) token |
| `platform` | text | CHECK ∈ (`android`) — Android-only (XI) |
| `is_active` | boolean | default true |
| `last_seen_at` | timestamptz | refreshed on each register |
| `created_at` | timestamptz | default now() |
| UNIQUE | `(user_id, token)` | one row per device-token per user |

## RLS matrix

| Actor | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| owner (`user_id = auth.uid()`) | ✅ own rows | ❌ (REVOKEd — RPC only) |
| other authenticated | ❌ | ❌ |
| anon | ❌ | ❌ |
| service_role (dispatch) | ✅ (bypasses RLS) | ✅ prune UNREGISTERED |

## RPCs

```
register_notification_token(p_token text, p_platform text default 'android') returns void
  SECURITY DEFINER; GRANT EXECUTE to authenticated.
  Behavior: upsert on (auth.uid(), p_token) → is_active=true, last_seen_at=now().
  Errors: 42501 'not_authenticated' when auth.uid() is null.

deregister_notification_token(p_token text) returns void
  SECURITY DEFINER; GRANT EXECUTE to authenticated.
  Behavior: delete WHERE user_id = auth.uid() AND token = p_token (THIS device only — R-191).
```

## Guarantees
- A client cannot write another user's token (REVOKE + RPC self-scopes `auth.uid()`) — FR-020.
- Multi-device: logout deregisters only the calling device; other devices keep their rows — SC-011.
- Tokens FCM reports `UNREGISTERED` are pruned by `dispatch_push` (service-role) — keeps the set clean.
