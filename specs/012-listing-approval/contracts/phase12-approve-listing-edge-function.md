# Contract: `approve_listing` Edge Function

**Path**: `supabase/functions/approve_listing/index.ts`
**Runtime**: Deno + TypeScript (Supabase Edge Functions)
**Implements**: FR-001, FR-008 (route guard mirrors permission check), FR-021 (audit emission)
**Verifies**: SC-003, SC-006, SC-007, SC-018, SC-022, SC-023, SC-029, SC-030

## Endpoint

`POST {SUPABASE_URL}/functions/v1/approve_listing`

## Request

**Headers**:
- `Authorization: Bearer <user JWT>` — required
- `Content-Type: application/json`

**Body**:
```json
{ "listing_id": "<UUID>" }
```

## Response

**Success — HTTP 200**:
```json
{
  "status": "approved",
  "published_at": "<ISO 8601>",
  "expires_at": null
}
```

`expires_at` is always `null` per Q2=A.

**Error responses** (each carries `Content-Type: application/json`):

| HTTP | `code` | Additional fields | When |
|---|---|---|---|
| 400 | `invalid_listing_id` | — | Body missing or `listing_id` not a UUID |
| 403 | `permission_denied` | — | Caller lacks `listings.approve` |
| 404 | `listing_not_found` | — | UUID does not exist in `public.listings` |
| 409 | `invalid_status_transition` | `current_status` | Status is not `pending_review` AND not `approved` |
| 409 | `already_acted_on` | `current_status: 'approved'` | Concurrent admin already approved |
| 500 | `internal_error` | `message` | Edge Function runtime / Supabase service error |

## Call sequence (server side)

1. Parse `req.json()` → validate `listing_id` is a UUID. On failure, return HTTP 400.
2. Extract `Authorization` header → parse JWT `sub` claim. On failure, return HTTP 403.
3. JWT-bound client `jwtClient = createClient(URL, ANON_KEY, { global: { headers: { Authorization } } })`.
4. `await jwtClient.rpc('current_user_has_permission', { perm_key: 'listings.approve' })`. If false / error → HTTP 403.
5. Service-role client `adminClient = createClient(URL, SERVICE_ROLE_KEY)`.
6. `await adminClient.rpc('set_app_user_id_for_session', { user_id: jwt.sub })` — sets `app.current_user_id`.
7. `const { data, error } = await adminClient.from('listings').update({ status: 'approved', published_at: new Date().toISOString() }).eq('id', body.listing_id).eq('status', 'pending_review').select('id, status, published_at, expires_at').maybeSingle()`.
8. If `data === null` (zero rows) → fetch current status → return HTTP 409 (`invalid_status_transition` or `already_acted_on`).
9. The amended `listing_status_transition_trigger_fn` fires automatically AND inserts a `listing_status_history` row with `changed_by` populated from `app.current_user_id`. The amended `listings_audit_trigger_fn` fires automatically AND inserts an `audit_logs` row with `action='listing.approved'` AND `actor_user_id` populated from `app.current_user_id`.
10. Return HTTP 200 with `{status, published_at, expires_at}`.

## Latency budget (Q6=A + SC-029)

≤ 2 seconds p95 measured at the admin device. Cold-start tail ≤ 3 seconds is acknowledged outside the p95 budget.

## Idempotency

NOT idempotent. A second call with the same `listing_id` after a successful first call returns HTTP 409 `already_acted_on` (status_guard blocks the UPDATE).

## Deployment

Via Supabase MCP `deploy_edge_function(name="approve_listing", source=<file body>)`. Local-dev via `supabase functions serve approve_listing --env-file .env.local`.
