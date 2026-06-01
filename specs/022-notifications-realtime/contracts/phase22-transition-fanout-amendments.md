# Contract: transition fan-out amendments (Phase 22)

**Migrations**: `20260602120004`–`20260602120007` (re-based CREATE-OR-REPLACE — R-183). Each re-creates the named function from its **latest** body and inserts ONE `PERFORM public.enqueue_notification(...)` after the status write. No edits to the original Phase 5/12/16/19 migration files.

## Recipient-resolution + payload table

| Transition fn (base migration) | Event `type` | Recipient | `params` |
|---|---|---|---|
| `approve_account_approval_request(p_user_id)` (`20260510120001`) | `account_approved` | `p_user_id` | `{}` |
| `reject_account_approval_request(p_user_id, p_reason)` (`20260510120001`) | `account_rejected` | `p_user_id` | `{}` (NO reason — FR-004) |
| `submit_inquiry(p_listing_id, …)` (`20260527120009`) | `inquiry_received` | `listings.publisher_user_id` for `p_listing_id` | `{listing_id, inquiry_id}` |
| `invite_agency_member(p_agency_id, p_phone, p_role)` (`20260531120008`) | `agency_invitation` | resolved invitee `v_target` (profiles by phone) | `{agency_id}` |
| `approve_listing_internal(p_listing_id, p_actor)` (`20260523120005`) | `listing_approved` | listing's `publisher_user_id` | `{listing_id}` |
| `reject_listing_internal(p_listing_id, p_actor, p_reason_json)` (`20260523120005`) | `listing_rejected` | listing's `publisher_user_id` | `{listing_id}` (NO reason — FR-004) |

## Re-base discipline (R-183, mirrors Phase 19 R-143)
1. Read the function's CURRENT definition (live DB or latest migration) before authoring the amendment.
2. Preserve every existing line (validation, grants, GUC `set_config`, RETURNS shape). The listing fns stay **service-role-only** (grants unchanged).
3. Insert ONLY the `enqueue_notification` PERFORM, on the success/transition branch, after the status write.
4. For `submit_inquiry`/`invite_agency_member`, capture the inserted id / resolved target already present in the body (`v_inquiry_id`, `v_target`); add a `select … into v_publisher` only where the publisher isn't already in scope.

## Guarantees
- **Exactly-once per qualifying transition** (FR-003) — the PERFORM is on the single transition branch.
- **No new audit action** (FR-025/R-196) — these transitions are already audit-logged in their phases; the amendment adds only the enqueue.
- **No behavior change** to the transition's own contract (same params, same RETURNS, same error codes) — additive only.
