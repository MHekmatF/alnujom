# Contract — `resolve_report` Edge Function + `resolve_report_internal` RPC

**Files**: `supabase/functions/resolve_report/index.ts` + `supabase/migrations/20260530120007_create_resolve_report_rpcs.sql` (Sub-Phase E). Mirrors the Phase 12 `approve_listing` Edge Function + `approve_listing_internal` wrapper (`20260523120005`).

## Edge Function `POST /functions/v1/resolve_report`

- Headers: `Authorization: Bearer <user JWT>`, `Content-Type: application/json`.
- Body in: `{ report_id: "<UUID>", action: "dismiss"|"hide"|"mark_duplicate"|"delete", note?: "<string>" }`.
- Body out (200): `{ report_status, listing_id, listing_status }`.
- Sequence (copying `approve_listing/index.ts`): validate body (UUID + action enum) → `parseJwtSub` → `jwtClient.rpc('current_user_has_permission', { perm_key: 'reports.manage' })` → **403 `permission_denied`** on false (FR-012) → `adminClient.rpc('resolve_report_internal', { p_report_id, p_actor_user_id: jwtSub, p_action: action, p_note: note })` → map a null/empty result to `report_not_found` (404) / `already_resolved` (409); success → 200.

## RPC `resolve_report_internal(p_report_id, p_actor_user_id, p_action, p_note)`

- `SECURITY DEFINER  SET search_path = public, pg_temp`; **`GRANT EXECUTE TO service_role` only** (never client-callable — the second enforcement layer, SC-010).
- One transaction (FR-013 / SC-006): `set_config('app.current_user_id', actor, true)` → open-status guard (`already_resolved` if terminal, SC-015) → capture `before_state` → UPDATE `reports` to terminal → listing transition per action (Q1=A: `dismiss` none, `hide`→`paused`, `mark_duplicate`→`rejected` with `app.current_rejection_reason='duplicate'`, `delete`→`deleted`) firing the existing Phase 10/12 listing triggers → INSERT `moderation_actions` (before/after) → sibling auto-resolve for listing-affecting actions (FR-016) → the `trg_reports_audit_resolution` trigger writes the `audit_logs` row.

## Action → listing status (Q1=A)

| action | report → | listing → | sibling auto-resolve |
|--------|----------|-----------|----------------------|
| `dismiss` | `dismissed` | unchanged | ❌ |
| `hide` | `resolved` | `paused` | ✅ |
| `mark_duplicate` | `resolved` | `rejected` (reason `duplicate`) | ✅ |
| `delete` | `resolved` | `deleted` | ✅ |

## Smoke tests

1. `reports.manage` caller, `hide` → 200; listing `paused`; 1 `moderation_actions` + 1 `audit_logs`; report `resolved`.
2. Non-`reports.manage` caller → 403 (Edge Fn); a direct `rpc('resolve_report_internal', …)` from the client → permission denied (no grant) (SC-010).
3. Resolve an already-terminal report → `already_resolved` (SC-015).
4. Resolve a report on a listing with siblings via `delete` → siblings auto-resolved; one action row each (FR-016).
5. `dismiss` leaves the listing unchanged and does NOT auto-resolve siblings (FR-016).
