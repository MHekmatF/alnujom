# Contract — `moderate_agency` Edge Function + `moderate_agency_internal` RPC

**Files**: `supabase/functions/moderate_agency/index.ts` + `supabase/migrations/20260531120010_create_agency_moderation_rpcs.sql` (Sub-Phase E). Mirrors the Phase 12 `approve_listing` Edge Function + `approve_listing_internal` wrapper (`20260523120005`). Full RPC SQL in `data-model.md §1.10`.

## Edge Function `POST /functions/v1/moderate_agency`

- Headers: `Authorization: Bearer <user JWT>`, `Content-Type: application/json`.
- Body in: `{ agency_id: "<UUID>", action: "approve"|"reject"|"suspend"|"reinstate", reason?: { preset: "<string>", detail?: "<string>" } }`. `reject` requires a `reason` (the `reject_listing` preset+detail shape; `detail` ≤ 500 chars).
- Body out (200): `{ agency_id, status }`.
- Sequence (copying `approve_listing/index.ts`): validate body (UUID + action enum; reason on reject) → `parseJwtSub` → build `jwtClient` → **per-action permission gate** via `jwtClient.rpc('current_user_has_permission', { perm_key })`:
  - `approve` / `reject` → `perm_key = 'agencies.approve'`
  - `suspend` / `reinstate` → `perm_key = 'agencies.suspend'`
  - **403 `permission_denied`** on false (FR-008/FR-039) → `adminClient.rpc('moderate_agency_internal', { p_agency_id, p_actor_user_id: jwtSub, p_action: action, p_reason_json: reason ? JSON.stringify(reason) : null })` → map `agency_not_found`→404, `invalid_transition`/`name_taken`/`no_pending_verification`→409, `rejection_reason_required`→400, success→200.

## RPC `moderate_agency_internal(p_agency_id, p_actor_user_id, p_action, p_reason_json)`

- `SECURITY DEFINER SET search_path = public, pg_temp`; **`GRANT EXECUTE TO service_role` only** (never client-callable — the second enforcement layer, SC-011).
- One transaction: `set_config('app.current_user_id', actor, true)` → transition guard → `name_taken` guard on `approve` (R-145) → UPDATE `agencies.status` (fires `trg_agencies_audit_status`) → for `approve`/`reject` UPDATE the open `agency_verification_requests` row's `decision`/`decision_reason`/`reviewed_by`/`reviewed_at` (fires `trg_agency_verification_audit`).

## Action → transition

| action | permission | precondition | agency → | verification → |
|--------|-----------|--------------|----------|----------------|
| `approve` | `agencies.approve` | `pending` (+ name free among approved) | `approved` | `approved` |
| `reject` | `agencies.approve` | `pending` | `rejected` | `rejected` (reason) |
| `suspend` | `agencies.suspend` | `approved` | `suspended` | — |
| `reinstate` | `agencies.suspend` | `suspended` | `approved` | — |

## Smoke tests

1. `agencies.approve` caller, `approve` → 200; agency `approved`; request `approved`; 1 `audit_logs` (`agency.status_changed`) + 1 (`agency_verification.decided`).
2. Non-`agencies.approve` caller → 403 (Edge Fn); a direct `rpc('moderate_agency_internal', …)` from the client → permission denied (no grant) (SC-011).
3. `suspend` an `approved` agency by an `agencies.suspend` holder → `suspended`; its approved listings keep their status; profile/badge gone (SC-005).
4. `approve` when another approved agency holds the same name → `name_taken` 409 (R-145).
5. `approve` an already-`approved` agency → `invalid_transition` 409.
