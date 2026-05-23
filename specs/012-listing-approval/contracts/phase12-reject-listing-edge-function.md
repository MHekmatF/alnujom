# Contract: `reject_listing` Edge Function

**Path**: `supabase/functions/reject_listing/index.ts`
**Runtime**: Deno + TypeScript (Supabase Edge Functions)
**Implements**: FR-002, FR-008, FR-013 (server side of dialog), FR-014 (Q4=A storage rep)
**Verifies**: SC-004, SC-006, SC-007, SC-018, SC-022, SC-024, SC-027, SC-028 (server-side baseline), SC-029, SC-030

## Endpoint

`POST {SUPABASE_URL}/functions/v1/reject_listing`

## Request

**Headers**:
- `Authorization: Bearer <user JWT>` — required
- `Content-Type: application/json`

**Body**:
```json
{
  "listing_id": "<UUID>",
  "reason_preset": "missing_or_low_quality_photos | incorrect_location | unrealistic_price | incomplete_description | duplicate_listing | other",
  "reason_detail": "<string up to 500 chars, optional>"
}
```

`reason_detail` is optional in all cases at the server (per Q5=A — the UX layer requires it when `reason_preset='other'`, but the server is permissive).

## Response

**Success — HTTP 200**:
```json
{
  "status": "rejected",
  "reason_preset": "<the preset key>",
  "reason_detail": "<the detail or null>"
}
```

**Error responses**:

| HTTP | `code` | Additional fields | When |
|---|---|---|---|
| 400 | `invalid_listing_id` | — | Body missing or `listing_id` not a UUID |
| 400 | `invalid_reason_preset` | `allowed: [<6 keys>]` | `reason_preset` missing OR not in the 6-key allowlist |
| 400 | `reason_detail_too_long` | `max: 500` | `reason_detail.length > 500` |
| 403 | `permission_denied` | — | Caller lacks `listings.reject` |
| 404 | `listing_not_found` | — | UUID does not exist |
| 409 | `invalid_status_transition` | `current_status` | Status is not `pending_review` AND not `rejected` |
| 409 | `already_acted_on` | `current_status: 'rejected'` | Concurrent admin already rejected |
| 500 | `internal_error` | `message` | Runtime error |

## Call sequence (server side)

1. Parse + validate `listing_id` UUID. HTTP 400 on failure.
2. Validate `reason_preset` against the hard-coded array `['missing_or_low_quality_photos', 'incorrect_location', 'unrealistic_price', 'incomplete_description', 'duplicate_listing', 'other']`. HTTP 400 `invalid_reason_preset` on mismatch.
3. Validate `reason_detail` length ≤ 500. HTTP 400 `reason_detail_too_long` on overflow.
4. JWT-bound client → `current_user_has_permission('listings.reject')`. HTTP 403 on false.
5. Service-role client `adminClient`.
6. `await adminClient.rpc('set_app_user_id_for_session', { user_id: jwt.sub })`.
7. Build the JSON-encoded reason: `const reasonJson = JSON.stringify({ preset: reason_preset, detail: reason_detail ?? null });`
8. `await adminClient.rpc('set_app_rejection_reason_for_session', { reason_json: reasonJson })`.
9. UPDATE: `await adminClient.from('listings').update({ status: 'rejected' }).eq('id', body.listing_id).eq('status', 'pending_review').select('id, status').maybeSingle()`.
10. Zero-rows path → fetch current status → HTTP 409.
11. The amended `listing_status_transition_trigger_fn` fires AND inserts a `listing_status_history` row with `changed_by = admin_uid` AND `reason = reasonJson`. The amended `listings_audit_trigger_fn` fires AND inserts an `audit_logs` row with `action='listing.rejected'` AND `before_state={status:'pending_review'}` AND `after_state={status:'rejected', reason_preset, reason_detail}`.
12. Return HTTP 200 with `{ status: 'rejected', reason_preset, reason_detail }`.

## Latency budget

≤ 2 seconds p95 — slightly higher median than `approve_listing` (~1 second) due to the second session-variable RPC AND the input validation.

## Idempotency

NOT idempotent. A second call with the same `listing_id` after a successful first call returns HTTP 409 `already_acted_on`.
